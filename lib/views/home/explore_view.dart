import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/escom.dart';
import '../../data/models/report_filter.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import 'community_views.dart';

class ExploreView extends StatefulWidget {
  const ExploreView({super.key, required this.searchController});
  final TextEditingController searchController;
  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  ReportFilter _filter = const ReportFilter();
  Future<void> _filters() async {
    final result = await showFilterSheet(context, _filter);
    if (result != null && mounted) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar')),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const PageStorageKey('explore-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            ConstrainedContent(
              maxWidth: 880,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tu objeto puede estar más cerca.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Busca entre los hallazgos de la comunidad por nombre, categoría o zona del campus.',
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.searchController,
                    builder: (context, value, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('explore-search'),
                          controller: widget.searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            hintText: 'Buscar un objeto encontrado',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: value.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Borrar búsqueda',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: widget.searchController.clear,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.tune_rounded, size: 18),
                              label: Text(
                                _filter.activeCount == 0
                                    ? 'Filtros y orden'
                                    : 'Filtros (${_filter.activeCount})',
                              ),
                              onPressed: _filters,
                            ),
                            if (_filter.category != null)
                              InputChip(
                                label: Text(_filter.category!.label),
                                onDeleted: () => setState(
                                  () => _filter = _filter.copyWith(
                                    category: () => null,
                                  ),
                                ),
                              ),
                            if (_filter.location != null)
                              InputChip(
                                label: Text(_filter.location!),
                                onDeleted: () => setState(
                                  () => _filter = _filter.copyWith(
                                    location: () => null,
                                  ),
                                ),
                              ),
                            if (_filter.status != null)
                              InputChip(
                                label: Text(_filter.status!.label),
                                onDeleted: () => setState(
                                  () => _filter = _filter.copyWith(
                                    status: () => null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Todas las categorías'),
                                selected: _filter.category == null,
                                onSelected: (_) => setState(
                                  () => _filter = _filter.copyWith(
                                    category: () => null,
                                  ),
                                ),
                              ),
                              for (final category in ItemCategory.values) ...[
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(category.label),
                                  avatar: Icon(category.icon, size: 18),
                                  selected: _filter.category == category,
                                  onSelected: (selected) => setState(
                                    () => _filter = _filter.copyWith(
                                      category: () =>
                                          selected ? category : null,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        CommunityResults(
                          reports: _filter
                              .copyWith(query: value.text)
                              .apply(
                                context
                                    .watch<ReportsViewModel>()
                                    .communityFound,
                              ),
                          searching:
                              value.text.trim().isNotEmpty ||
                              _filter.activeCount > 0,
                          onClear: () {
                            widget.searchController.clear();
                            setState(() => _filter = const ReportFilter());
                          },
                        ),
                      ],
                    ),
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
