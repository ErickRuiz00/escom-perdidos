import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_notification.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../../viewmodels/recovery_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../recovery/recovery_chat_view.dart';
import '../recovery/recovery_hub_view.dart';
import '../recovery/recovery_request_view.dart';
import '../reports/report_detail_view.dart';
import '../widgets/common.dart';
import 'notification_preferences_view.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});
  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  bool _opening = false;
  Future<void> _readAll() async {
    try {
      await context.read<NotificationsViewModel>().markAllRead();
    } catch (e) {
      if (mounted) showSnack(context, userMessageFor(e), error: true);
    }
  }

  Future<void> _open(AppNotification item) async {
    if (_opening) return;
    setState(() => _opening = true);
    final vm = context.read<NotificationsViewModel>();
    final session = vm.sessionRevision;
    try {
      // Navegar sigue siendo posible si falla únicamente guardar la lectura.
      try {
        if (item.unread) await vm.markRead(item);
      } catch (e) {
        if (mounted) showSnack(context, userMessageFor(e), error: true);
      }
      vm.assertSession(session);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationDestinationView(item: item),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, userMessageFor(e), error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Preferencias de avisos',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationPreferencesView(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: vm.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              ConstrainedContent(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tu centro de notificaciones',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vm.unreadCount == 1
                          ? '1 aviso sin leer'
                          : '${vm.unreadCount} avisos sin leer',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vm.connected
                          ? 'Actualización en tiempo real conectada.'
                          : 'Actualiza para consultar tus avisos. Reintentamos la conexión automáticamente.',
                    ),
                    const Text(
                      'Los avisos llegan mientras usas la app. Al volver a abrirla, se recupera el historial.',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: vm.loading ? null : vm.load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar'),
                        ),
                        TextButton(
                          onPressed: vm.saving || vm.items.isEmpty
                              ? null
                              : _readAll,
                          child: const Text('Marcar todo como leído'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RecoveryHubView(),
                            ),
                          ),
                          child: const Text('Ver solicitudes'),
                        ),
                      ],
                    ),
                    if (vm.loading) const LinearProgressIndicator(),
                    if (vm.error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(vm.error!),
                        ),
                      ),
                    if (vm.items.isEmpty && !vm.loading && vm.error == null)
                      const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Sin notificaciones por ahora',
                        message:
                            'Aquí encontrarás solicitudes, mensajes y cambios de tus hallazgos.',
                      ),
                    for (final item in vm.items)
                      Card(
                        child: ListTile(
                          enabled: !_opening,
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(switch (item.kind) {
                            NotificationKind.privateMessage =>
                              Icons.chat_bubble_outline_rounded,
                            NotificationKind.returnConfirmed =>
                              Icons.task_alt_rounded,
                            NotificationKind.publicationChanged =>
                              Icons.inventory_2_outlined,
                            _ => Icons.mark_email_unread_outlined,
                          }),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.unread
                                  ? FontWeight.w800
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${item.body}\n${Formatters.dateTime(item.createdAt)}\n${!item.unread
                                ? 'Leída'
                                : item.alertEnabled
                                ? 'Sin leer'
                                : 'Aviso silenciado · conservado en el historial'}',
                          ),
                          onTap: () => _open(item),
                          trailing: item.unread
                              ? IconButton(
                                  tooltip: 'Marcar como leída',
                                  icon: const Icon(Icons.done_rounded),
                                  onPressed: vm.saving
                                      ? null
                                      : () async {
                                          try {
                                            await vm.markRead(item);
                                          } catch (e) {
                                            if (context.mounted) {
                                              showSnack(
                                                context,
                                                userMessageFor(e),
                                                error: true,
                                              );
                                            }
                                          }
                                        },
                                )
                              : null,
                        ),
                      ),
                    if (vm.hasMore)
                      TextButton(
                        onPressed: vm.loadingMore || vm.loading
                            ? null
                            : vm.loadMore,
                        child: Text(
                          vm.loadingMore
                              ? 'Cargando…'
                              : 'Mostrar notificaciones anteriores',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resuelve destinos de nuevo mediante RLS; un UUID guardado no da acceso.
class NotificationDestinationView extends StatefulWidget {
  const NotificationDestinationView({super.key, required this.item});
  final AppNotification item;
  @override
  State<NotificationDestinationView> createState() =>
      _NotificationDestinationViewState();
}

class _NotificationDestinationViewState
    extends State<NotificationDestinationView> {
  Widget? _page;
  String? _error;
  late final int _session;
  @override
  void initState() {
    super.initState();
    _session = context.read<NotificationsViewModel>().sessionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolve();
    });
  }

  Future<void> _resolve() async {
    final vm = context.read<NotificationsViewModel>();
    try {
      vm.assertSession(_session);
      if (widget.item.recipientId != vm.userId) {
        throw const PermissionException('Este aviso no pertenece a tu cuenta.');
      }
      final item = widget.item;
      Widget page;
      if (item.kind == NotificationKind.publicationChanged &&
          item.itemId != null &&
          item.requestId == null) {
        page = ReportDetailView(reportId: item.itemId!);
      } else if (item.requestId != null) {
        final recovery = context.read<RecoveryViewModel>();
        // La consulta comprueba acceso incluso si el aviso es antiguo.
        final requests = await recovery.repository.requests();
        vm.assertSession(_session);
        if (!mounted) return;
        if (!requests.any(
          (r) =>
              r.id == item.requestId &&
              (r.finderId == vm.userId || r.requesterId == vm.userId),
        )) {
          throw const PermissionException(
            'Esta solicitud ya no está disponible para tu cuenta.',
          );
        }
        page = RecoveryRequestView(requestId: item.requestId!);
        if (item.kind == NotificationKind.publicationChanged &&
            item.itemId != null) {
          final report = await context.read<ReportsViewModel>().loadDetail(
            item.itemId!,
          );
          vm.assertSession(_session);
          if (report != null) page = ReportDetailView(reportId: item.itemId!);
        }
        if (item.kind == NotificationKind.privateMessage &&
            item.conversationId != null) {
          final conversations = await recovery.repository.conversations();
          vm.assertSession(_session);
          for (final c in conversations) {
            if (c.id == item.conversationId &&
                c.requestId == item.requestId &&
                c.closedAt == null) {
              page = RecoveryChatView(conversation: c);
              break;
            }
          }
        }
      } else if (item.itemId != null) {
        page = ReportDetailView(reportId: item.itemId!);
      } else {
        throw const AppException(
          'El destino de este aviso ya no está disponible.',
        );
      }
      if (mounted) setState(() => _page = page);
    } catch (e) {
      if (mounted) setState(() => _error = userMessageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    if (vm.sessionRevision != _session) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aviso')),
        body: const Center(
          child: Text('La sesión cambió. Vuelve a tus avisos.'),
        ),
      );
    }
    if (_page != null) return _page!;
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso')),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _resolve();
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
