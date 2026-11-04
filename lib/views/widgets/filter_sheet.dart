import 'package:flutter/material.dart';

import '../../core/constants/escom.dart';
import '../../data/models/report_filter.dart';

/// Hoja inferior para filtrar por categoría, estado y lugar, y para ordenar.
Future<ReportFilter?> showFilterSheet(BuildContext context, ReportFilter current) {
  return showModalBottomSheet<ReportFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final ReportFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ReportFilter _filter = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Text('Filtros y orden', style: theme.textTheme.titleLarge),
                _section('Ordenar por'),
                _chips<ReportSort>(
                  values: ReportSort.values,
                  label: (s) => s.label,
                  selected: _filter.sort,
                  allowNone: false,
                  onSelected: (s) => _filter = _filter.copyWith(sort: s),
                ),
                _section('Estado'),
                _chips<ReportStatus>(
                  values: ReportStatus.values,
                  label: (s) => s.label,
                  selected: _filter.status,
                  onSelected: (s) => _filter = _filter.copyWith(status: () => s),
                ),
                _section('Categoría'),
                _chips<ItemCategory>(
                  values: ItemCategory.values,
                  label: (c) => c.label,
                  selected: _filter.category,
                  onSelected: (c) => _filter = _filter.copyWith(category: () => c),
                ),
                _section('Lugar'),
                _chips<String>(
                  values: Escom.locations,
                  label: (l) => l,
                  selected: _filter.location,
                  onSelected: (l) => _filter = _filter.copyWith(location: () => l),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, _filter.clearFilters()),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _filter),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _chips<T>({
    required List<T> values,
    required String Function(T) label,
    required T? selected,
    required void Function(T?) onSelected,
    bool allowNone = true,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: value == selected,
            onSelected: (on) => setState(() {
              if (on) {
                onSelected(value);
              } else if (allowNone) {
                onSelected(null);
              }
            }),
          ),
      ],
    );
  }
}
