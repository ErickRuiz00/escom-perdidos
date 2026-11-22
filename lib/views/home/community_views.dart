import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/reports_viewmodel.dart';

import '../../core/constants/escom.dart';
import '../../data/models/report.dart';
import '../reports/report_detail_view.dart';
import '../widgets/common.dart';
import '../widgets/publication_notice.dart';
import '../widgets/report_card.dart';
import '../recovery/recovery_hub_view.dart';

/// Solo recibe publicaciones públicas; nunca consulta el almacenamiento local.
class CommunityResults extends StatefulWidget {
  const CommunityResults({
    super.key,
    required this.reports,
    this.searching = false,
    this.onClear,
  });
  final List<Report> reports;
  final bool searching;
  final VoidCallback? onClear;

  @override
  State<CommunityResults> createState() => _CommunityResultsState();
}

class _CommunityResultsState extends State<CommunityResults> {
  int _limit = 30;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final found = widget.reports
        .where((r) => r.type == ReportType.found && r.isActive)
        .toList();
    if (vm.loading && found.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (vm.error != null) {
      return Card(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos consultar los hallazgos',
          message: vm.error!,
          action: TextButton(
            onPressed: vm.load,
            child: const Text('Reintentar'),
          ),
        ),
      );
    }
    if (found.isEmpty) {
      return Card(
        child: EmptyState(
          icon: widget.searching
              ? Icons.search_off_rounded
              : Icons.inventory_2_outlined,
          title: widget.searching
              ? 'Sin hallazgos para esta búsqueda'
              : 'El próximo reencuentro empieza aquí',
          message: widget.searching
              ? 'Prueba otra categoría, zona o nombre. Aún no hay publicaciones disponibles para mostrar.'
              : 'Aún no hay publicaciones de hallazgos disponibles. Cuando las haya, podrás consultarlas aquí.',
          action: widget.searching && widget.onClear != null
              ? TextButton(
                  onPressed: widget.onClear,
                  child: const Text('Limpiar búsqueda'),
                )
              : TextButton(
                  onPressed: vm.load,
                  child: const Text('Actualizar hallazgos'),
                ),
        ),
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: vm.load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar hallazgos'),
          ),
        ),
        for (final report in found.take(_limit))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReportCard(
              report: report,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReportDetailView(reportId: report.id),
                ),
              ),
            ),
          ),
        if (found.length > _limit)
          TextButton(
            onPressed: () => setState(() => _limit += 30),
            child: const Text('Mostrar más hallazgos'),
          ),
      ],
    );
  }
}

class PublishView extends StatelessWidget {
  const PublishView({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ConstrainedContent(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.volunteer_activism_outlined,
                        size: 38,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Lo encontraste.\nAyuda a reencontrarlo.',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Este espacio es para objetos encontrados en ESCOM. Si perdiste algo, consulta Explorar.',
                  ),
                  const SizedBox(height: 24),
                  const Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.photo_camera_outlined),
                          title: Text('Describe el objeto'),
                          subtitle: Text(
                            'Agrega sus características y una foto opcional.',
                          ),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: Icon(Icons.place_outlined),
                          title: Text('Ubica el hallazgo'),
                          subtitle: Text(
                            'Indica la zona y quién lo resguarda: Alumno o Prefectura.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const PublicationNotice(),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Preparar hallazgo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatsView extends StatelessWidget {
  const ChatsView({super.key});
  @override
  Widget build(BuildContext context) => const RecoveryHubView();
}

class PendingActivityView extends StatelessWidget {
  const PendingActivityView({
    super.key,
    required this.title,
    required this.icon,
    required this.heading,
    required this.message,
  });
  final String title;
  final IconData icon;
  final String heading;
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: _ScrollableEmpty(icon: icon, title: heading, message: message),
  );
}

class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: ConstrainedContent(
        maxWidth: 600,
        child: EmptyState(icon: icon, title: title, message: message),
      ),
    ),
  );
}
