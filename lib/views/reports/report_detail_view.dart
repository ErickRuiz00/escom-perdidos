import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/report.dart';
import '../../data/services/location_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../widgets/common.dart';
import 'report_form_view.dart';

/// Vista detallada de un reporte (RF2) con acciones de editar, resolver y eliminar.
class ReportDetailView extends StatelessWidget {
  const ReportDetailView({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final report = context.select<ReportsViewModel, Report?>((vm) => vm.byId(reportId));
    final userId = context.select<AuthViewModel, String?>((a) => a.user?.id);

    if (report == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Reporte no disponible',
          message: 'Es posible que haya sido eliminado.',
        ),
      );
    }

    final isOwner = report.userId == userId;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: (width * 0.75).clamp(220, 380),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReportFormView(original: report),
                  )),
                ),
              if (isOwner)
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(context, report),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'photo-${report.id}',
                child: ReportImage(
                  path: report.photoPath,
                  category: report.category,
                  decodeWidth: width.round(),
                  iconSize: 96,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ConstrainedContent(
              maxWidth: 680,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      TypeBadge(type: report.type),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(report.category.icon, size: 16),
                        label: Text(report.category.label),
                      ),
                      if (!report.isActive)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(Icons.task_alt_rounded, size: 16),
                          label: Text('Resuelto'),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    Text(report.title,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(report.description, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 20),
                    Card(
                      child: Column(children: [
                        _InfoTile(
                          icon: Icons.place_outlined,
                          title: 'Lugar',
                          value: report.location,
                        ),
                        _InfoTile(
                          icon: Icons.event_outlined,
                          title: report.type == ReportType.lost
                              ? 'Se perdió el'
                              : 'Se encontró el',
                          value: Formatters.date(report.eventDate),
                        ),
                        if (report.hasLocation)
                          _InfoTile(
                            icon: Icons.my_location_rounded,
                            title: 'Ubicación GPS',
                            value: _gpsLabel(report),
                          ),
                        _InfoTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Publicado por',
                          value:
                              '${isOwner ? 'Ti' : report.authorName ?? 'Usuario'} · ${Formatters.relative(report.createdAt)}',
                        ),
                        if (report.contact?.isNotEmpty ?? false)
                          _InfoTile(
                            icon: Icons.contact_phone_outlined,
                            title: 'Contacto',
                            value: report.contact!,
                            trailing: IconButton(
                              tooltip: 'Copiar',
                              icon: const Icon(Icons.copy_rounded),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: report.contact!));
                                showSnack(context, 'Contacto copiado');
                              },
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    if (isOwner)
                      FilledButton.icon(
                        onPressed: () => _toggle(context, report),
                        icon: Icon(report.isActive
                            ? Icons.task_alt_rounded
                            : Icons.replay_rounded),
                        label: Text(report.isActive
                            ? 'Marcar como resuelto'
                            : 'Reactivar reporte'),
                      )
                    else if (report.isActive)
                      Text(
                        report.contact?.isNotEmpty ?? false
                            ? '¿Es tuyo o lo viste? Usa el contacto de arriba.'
                            : 'Acude al Edificio de Gobierno para más información.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _gpsLabel(Report report) {
    final point = GeoPoint(report.latitude!, report.longitude!);
    final where = point.insideCampus
        ? 'Dentro del campus'
        : 'A ${Formatters.distance(point.distanceToEscom)} de la ESCOM';
    return '$where (${report.latitude!.toStringAsFixed(5)}, ${report.longitude!.toStringAsFixed(5)})';
  }

  Future<void> _toggle(BuildContext context, Report report) async {
    try {
      await context.read<ReportsViewModel>().toggleResolved(report);
      if (context.mounted) {
        showSnack(context, report.isActive
            ? '¡Qué bien! Reporte marcado como resuelto.'
            : 'Reporte reactivado.');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, userMessageFor(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, Report report) async {
    final confirmed = await confirmAction(
      context,
      title: '¿Eliminar reporte?',
      message: 'Se borrará "${report.title}" y su foto. Esta acción no se puede deshacer.',
    );
    if (!confirmed || !context.mounted) return;
    final vm = context.read<ReportsViewModel>();
    final navigator = Navigator.of(context);
    try {
      await vm.delete(report);
      navigator.pop();
      if (context.mounted) showSnack(context, 'Reporte eliminado');
    } catch (e) {
      if (context.mounted) showSnack(context, userMessageFor(e), error: true);
    }
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      trailing: trailing,
    );
  }
}
