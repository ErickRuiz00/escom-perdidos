import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/escom.dart';
import '../../data/models/report.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../reports/report_detail_view.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';
import '../widgets/skeleton.dart';

/// Hallazgos locales del usuario, separados por estado.
class MyReportsView extends StatelessWidget {
  const MyReportsView({super.key, required this.onNewReport});

  final VoidCallback onNewReport;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final userId = context.select<AuthViewModel, String?>((a) => a.user?.id);
    final mine = userId == null
        ? const <Report>[]
        : vm.mine(userId).where((r) => r.type == ReportType.found).toList();

    Widget tab(ReportStatus status) {
      if (vm.loading && mine.isEmpty) return const ReportListSkeleton(count: 3);
      final items = mine.where((r) => r.status == status).toList();
      if (items.isEmpty) {
        return SingleChildScrollView(
          child: EmptyState(
            icon: status == ReportStatus.active
                ? Icons.inventory_2_outlined
                : Icons.task_alt_rounded,
            title: status == ReportStatus.active
                ? 'No tienes hallazgos guardados'
                : 'Nada resuelto todavía',
            message: status == ReportStatus.active
                ? 'Los hallazgos que guardes en este dispositivo aparecerán aquí. Aún no son publicaciones públicas.'
                : 'Los reportes que marques como resueltos aparecerán aquí.',
            action: status == ReportStatus.active
                ? FilledButton.tonalIcon(
                    onPressed: onNewReport,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registrar hallazgo'),
                  )
                : null,
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: vm.load,
        child: ReportList(
          reports: items,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          onTap: (r) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReportDetailView(reportId: r.id)),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis hallazgos'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Activos (${mine.where((r) => r.isActive).length})'),
              Tab(text: 'Resueltos (${mine.where((r) => !r.isActive).length})'),
            ],
          ),
        ),
        body: vm.error != null
            ? SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'No pudimos leer tus hallazgos',
                  message: vm.error!,
                  action: TextButton(
                    onPressed: vm.load,
                    child: const Text('Reintentar'),
                  ),
                ),
              )
            : TabBarView(
                children: [
                  tab(ReportStatus.active),
                  tab(ReportStatus.resolved),
                ],
              ),
      ),
    );
  }
}
