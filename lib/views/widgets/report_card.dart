import 'package:flutter/material.dart';

import '../../core/theme/app_status_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/report.dart';
import 'common.dart';

/// Tarjeta de un reporte en las listas.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, required this.onTap});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'photo-${report.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 84,
                    child: ReportImage(
                      path: report.photoPath,
                      category: report.category,
                      decodeWidth: 84,
                      iconSize: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TypeBadge(type: report.type, dense: true),
                        if (!report.isActive)
                          const StatusBadge(
                            state: ItemVisualState.delivered,
                            label: 'Resuelto',
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LocationTag(location: report.location, dense: true),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.relative(report.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista adaptable: una columna en teléfono, rejilla en tablet.
class ReportList extends StatelessWidget {
  const ReportList({
    super.key,
    required this.reports,
    required this.onTap,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
  });

  final List<Report> reports;
  final ValueChanged<Report> onTap;
  final Widget? header;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 380).floor().clamp(1, 3);
        // La altura crece con el tamaño de letra del sistema para evitar
        // textos superpuestos con fuentes grandes (accesibilidad).
        final textHeight = MediaQuery.textScalerOf(context).scale(112);
        final extent = 24 + textHeight.clamp(112.0, 320.0);
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (header != null) SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: padding,
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: extent,
                ),
                itemCount: reports.length,
                itemBuilder: (context, i) => ReportCard(
                  report: reports[i],
                  onTap: () => onTap(reports[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
