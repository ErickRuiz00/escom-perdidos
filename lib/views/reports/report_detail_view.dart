import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/report.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../widgets/common.dart';
import 'report_form_view.dart';
import '../recovery/recovery_request_form.dart';

class ReportDetailView extends StatefulWidget {
  const ReportDetailView({super.key, required this.reportId});
  final String reportId;
  @override
  State<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  bool _loading = true;
  bool _withdrawing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ReportsViewModel>().loadDetail(widget.reportId);
    } catch (e) {
      if (mounted) _error = userMessageFor(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withdraw(Report report) async {
    if (_withdrawing) return;
    final ok = await confirmAction(
      context,
      title: '¿Retirar publicación?',
      message:
          'Dejará de aparecer en el catálogo de la comunidad. La conservarás en Mis hallazgos y no podrás reactivarla.',
      confirmLabel: 'Retirar',
    );
    if (!ok || !mounted) return;
    setState(() => _withdrawing = true);
    try {
      await context.read<ReportsViewModel>().withdraw(report);
      if (mounted) showSnack(context, 'Publicación retirada');
    } catch (e) {
      if (mounted) showSnack(context, userMessageFor(e), error: true);
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = context.watch<ReportsViewModel>().byId(widget.reportId);
    final owner = report?.userId == context.watch<AuthViewModel>().user?.id;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del hallazgo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar detalle',
            onPressed: _loading || _withdrawing ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading && report == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: ConstrainedContent(
                  maxWidth: 720,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'No pudimos actualizar el hallazgo',
                          message: _error!,
                          action: TextButton(
                            onPressed: _reload,
                            child: const Text('Reintentar'),
                          ),
                        ),
                      if (report == null && _error == null)
                        const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Publicación no disponible',
                          message:
                              'Puede haber sido retirada o ya no ser visible para tu cuenta.',
                        ),
                      if (report != null) ...[
                        Hero(
                          tag: 'photo-${report.id}',
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: ReportImage(
                              path: null,
                              storagePath: report.photoObjectPath,
                              category: report.category,
                              decodeWidth: 720,
                              iconSize: 80,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text(report.status.label)),
                                  LocationTag(location: report.location),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                report.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                report.description,
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 20),
                              Card(
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(report.category.icon),
                                      title: const Text('Categoría'),
                                      subtitle: Text(report.category.label),
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.calendar_month_outlined,
                                      ),
                                      title: const Text('Fecha del hallazgo'),
                                      subtitle: Text(
                                        Formatters.date(report.eventDate),
                                      ),
                                    ),
                                    ListTile(
                                      leading: Icon(report.custody?.icon),
                                      title: const Text('Custodia'),
                                      subtitle: Text(
                                        report.custody?.label ??
                                            'Sin especificar',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (report.custody == ItemCustody.prefecture)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Reportado como entregado a Prefectura.\n\n${owner ? 'Tu responsabilidad de coordinar la devolución termina aquí. ' : ''}Acude personalmente a Prefectura de ESCOM para consultar el objeto. Esta información es una declaración del alumno; Prefectura no ha confirmado su recepción.',
                                    style: TextStyle(
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              if (!owner &&
                                  report.isActive &&
                                  report.custody == ItemCustody.student) ...[
                                FilledButton(
                                  onPressed:
                                      _loading || _withdrawing || _error != null
                                      ? null
                                      : () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  RecoveryRequestForm(
                                                    report: report,
                                                  ),
                                            ),
                                          );
                                          if (mounted) _reload();
                                        },
                                  child: const Text('Creo que es mío'),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Envía características privadas al estudiante que lo resguarda para que pueda revisarlas.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (owner && report.isActive) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _loading || _withdrawing
                                      ? null
                                      : () async {
                                          await Navigator.of(
                                            context,
                                          ).push<String>(
                                            MaterialPageRoute(
                                              builder: (_) => ReportFormView(
                                                original: report,
                                              ),
                                            ),
                                          );
                                          if (mounted) _reload();
                                        },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Editar publicación'),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _loading || _withdrawing
                                      ? null
                                      : () => _withdraw(report),
                                  icon: const Icon(Icons.archive_outlined),
                                  label: Text(
                                    _withdrawing
                                        ? 'Retirando…'
                                        : 'Retirar publicación',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
