import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/escom.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/report.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../viewmodels/weather_viewmodel.dart';
import '../reports/report_detail_view.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/report_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/weather_card.dart';

/// Pantalla de inicio: búsqueda en vivo, filtros rápidos y lista de reportes.
class FeedView extends StatefulWidget {
  const FeedView({super.key, required this.onNewReport});

  final VoidCallback onNewReport;

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final _search = TextEditingController();
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _search.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<ReportsViewModel>().load(),
      context.read<WeatherViewModel>().load(),
    ]);
  }

  void _openDetail(Report report) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportDetailView(reportId: report.id),
    ));
  }

  Future<void> _openFilters() async {
    final vm = context.read<ReportsViewModel>();
    final result = await showFilterSheet(context, vm.filter);
    if (result != null) vm.updateFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final user = context.select<AuthViewModel, String>((a) => a.user?.name ?? '');
    final firstName = user.split(' ').first;
    final theme = Theme.of(context);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hola, $firstName 👋', style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('¿Qué se perdió hoy en la ESCOM?',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          const WeatherCard(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatTile(type: ReportType.lost, count: vm.count(ReportType.lost))),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(type: ReportType.found, count: vm.count(ReportType.found))),
          ]),
          const SizedBox(height: 16),
          _TypeChips(
            selected: vm.filter.type,
            onSelected: (t) => vm.updateFilter(vm.filter.copyWith(type: () => t)),
          ),
        ],
      ),
    );

    Widget content;
    if (vm.loading && vm.visible.isEmpty) {
      content = const ReportListSkeleton();
    } else if (vm.error != null && vm.visible.isEmpty) {
      content = EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar los reportes',
        message: vm.error!,
        action: FilledButton.tonal(onPressed: vm.load, child: const Text('Reintentar')),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _refresh,
        child: vm.visible.isEmpty
            ? ListView(children: [
                header,
                EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Sin resultados',
                  message: vm.filter.query.isEmpty && vm.filter.activeCount == 0
                      ? 'Aún no hay reportes. ¡Sé el primero!'
                      : 'Prueba con otras palabras o quita algunos filtros.',
                  action: vm.filter.activeCount > 0
                      ? TextButton(
                          onPressed: () => vm.updateFilter(vm.filter.clearFilters()),
                          child: const Text('Quitar filtros'),
                        )
                      : null,
                ),
              ])
            : ReportList(reports: vm.visible, onTap: _openDetail, header: header),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: SearchBar(
          controller: _search,
          hintText: 'Buscar audífonos, credencial…',
          leading: const Icon(Icons.search_rounded),
          elevation: const WidgetStatePropertyAll(0),
          onChanged: (q) {
            setState(() {}); // Muestra u oculta el botón de borrar.
            _debouncer(() => vm.search(q));
          },
          trailing: [
            if (_search.text.isNotEmpty)
              IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _search.clear();
                  vm.search('');
                  setState(() {});
                },
              ),
            Badge(
              isLabelVisible: vm.filter.activeCount > 0,
              label: Text('${vm.filter.activeCount}'),
              child: IconButton(
                tooltip: 'Filtros',
                icon: const Icon(Icons.tune_rounded),
                onPressed: _openFilters,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: content),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.type, required this.count});

  final ReportType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.typeColor(type);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(type.icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  type == ReportType.lost ? 'Buscándose' : 'Por devolver',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onSelected});

  final ReportType? selected;
  final ValueChanged<ReportType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        ChoiceChip(
          label: const Text('Todos'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final type in ReportType.values) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: Icon(type.icon, size: 18),
            label: Text(type == ReportType.lost ? 'Perdidos' : 'Encontrados'),
            selected: selected == type,
            onSelected: (_) => onSelected(type),
          ),
        ],
      ]),
    );
  }
}
