import 'package:flutter/material.dart';

import '../../core/constants/escom.dart';
import '../../data/models/report.dart';
import '../reports/report_detail_view.dart';
import '../widgets/common.dart';
import '../widgets/local_only_notice.dart';
import '../widgets/report_card.dart';

/// Solo recibe publicaciones públicas; nunca consulta el almacenamiento local.
class CommunityResults extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final found = reports.where((r) => r.type == ReportType.found).toList();
    if (found.isEmpty) {
      return Card(
        child: EmptyState(
          icon: searching
              ? Icons.search_off_rounded
              : Icons.inventory_2_outlined,
          title: searching
              ? 'Sin hallazgos para esta búsqueda'
              : 'El próximo reencuentro empieza aquí',
          message: searching
              ? 'Prueba otra categoría, zona o nombre. Aún no hay publicaciones disponibles para mostrar.'
              : 'Aún no hay publicaciones de hallazgos disponibles. Cuando las haya, podrás consultarlas aquí.',
          action: searching && onClear != null
              ? TextButton(
                  onPressed: onClear,
                  child: const Text('Limpiar búsqueda'),
                )
              : null,
        ),
      );
    }
    return Column(
      children: [
        for (final report in found)
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
                  const LocalOnlyNotice(),
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
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Solicitudes'),
            Tab(text: 'Conversaciones'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _ScrollableEmpty(
            icon: Icons.mark_chat_unread_outlined,
            title: 'Tus solicitudes, en un solo lugar',
            message:
                'Aquí podrás revisar solicitudes sobre objetos encontrados. Esta función estará disponible más adelante.',
          ),
          _ScrollableEmpty(
            icon: Icons.forum_outlined,
            title: 'Un espacio para reencontrarse',
            message:
                'Aquí aparecerán tus conversaciones cuando se habilite el chat. Por ahora no puedes enviar ni recibir mensajes.',
          ),
        ],
      ),
    ),
  );
}

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});
  @override
  Widget build(BuildContext context) => const PendingActivityView(
    title: 'Notificaciones',
    icon: Icons.notifications_none_rounded,
    heading: 'Tu centro de notificaciones',
    message:
        'Los avisos de tu actividad aparecerán aquí cuando esta función esté disponible. Por ahora no hay notificaciones para mostrar.',
  );
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
