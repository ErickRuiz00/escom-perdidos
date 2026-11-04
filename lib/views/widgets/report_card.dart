import 'package:flutter/material.dart';

import '../../core/constants/escom.dart';
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
        child: Opacity(
          opacity: report.isActive ? 1 : 0.6,
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
                          if (!report.isActive) const _ResolvedBadge(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 14, color: muted),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${report.location} · ${Formatters.relative(report.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResolvedBadge extends StatelessWidget {
  const _ResolvedBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ReportStatus.resolved.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.onSecondaryContainer,
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
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 380).floor().clamp(1, 3);
      // La altura crece con el tamaño de letra del sistema para evitar
      // textos superpuestos con fuentes grandes (accesibilidad).
      final textHeight = MediaQuery.textScalerOf(context).scale(76);
      final extent = 24 + textHeight.clamp(84.0, 220.0);
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
    });
  }
}
