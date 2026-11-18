import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/escom.dart';
import '../../data/models/report.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../reports/report_detail_view.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';

class MyReportsView extends StatelessWidget {
  const MyReportsView({super.key, required this.onNewReport});
  final VoidCallback onNewReport;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final uid = context.watch<AuthViewModel>().user?.id;
    final mine = uid == null ? const <Report>[] : vm.mine(uid);
    const states = [
      ReportStatus.active,
      ReportStatus.withdrawn,
      ReportStatus.returned,
    ];
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis hallazgos'),
          actions: [
            IconButton(
              tooltip: 'Actualizar mis hallazgos',
              onPressed: vm.loading ? null : vm.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final status in states)
                Tab(
                  text:
                      '${status.label} (${mine.where((r) => r.status == status).length})',
                ),
            ],
          ),
        ),
        body: vm.loading && mine.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : vm.error != null
            ? SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'No pudimos consultar tus hallazgos',
                  message: vm.error!,
                  action: TextButton(
                    onPressed: vm.load,
                    child: const Text('Reintentar'),
                  ),
                ),
              )
            : TabBarView(
                children: [
                  for (final status in states)
                    Builder(
                      builder: (context) {
                        final items = mine
                            .where((r) => r.status == status)
                            .toList();
                        if (items.isEmpty) {
                          return SingleChildScrollView(
                            child: EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: status == ReportStatus.active
                                  ? 'No tienes hallazgos publicados'
                                  : 'Sin publicaciones en este estado',
                              message:
                                  'Tus publicaciones confirmadas aparecerán aquí. Los registros locales anteriores no se publican automáticamente.',
                              action: status == ReportStatus.active
                                  ? FilledButton.tonalIcon(
                                      onPressed: onNewReport,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Publicar hallazgo'),
                                    )
                                  : null,
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: vm.load,
                          child: ReportList(
                            reports: items,
                            padding: const EdgeInsets.all(16),
                            onTap: (r) => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ReportDetailView(reportId: r.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
