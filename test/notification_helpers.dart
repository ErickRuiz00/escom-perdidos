import 'dart:async';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/models/app_notification.dart';
import 'package:escom_perdidos/data/repositories/notifications_repository.dart';
import 'package:escom_perdidos/data/repositories/recovery_repository.dart';
import 'recovery_helpers.dart';

AppNotification notification({
  int index = 1,
  String uid = recoveryA,
  NotificationKind kind = NotificationKind.recoveryRequest,
  String? requestId = recoveryId,
  String? itemId = recoveryItem,
  String? conversationId,
  bool alert = true,
  DateTime? readAt,
}) => AppNotification(
  id: '99999999-9999-4999-8999-${index.toString().padLeft(12, '0')}',
  recipientId: uid,
  kind: kind,
  title: 'Aviso $index',
  body: 'Consulta los detalles privados.',
  createdAt: DateTime.utc(2026, 11, 21).add(Duration(seconds: index)),
  alertEnabled: alert,
  readAt: readAt,
  requestId: requestId,
  itemId: itemId,
  conversationId: conversationId,
);

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({
    this.uid = recoveryA,
    this.prefs = const NotificationPreferences(tutorialVersion: 1),
  });
  String uid;
  List<AppNotification> rows = [];
  NotificationPreferences prefs;
  int cancellations = 0, reads = 0, saves = 0, tutorials = 0;
  bool fail = false;
  void Function()? changed;
  void Function(bool)? connection;
  Future<List<AppNotification>> Function(AppNotification?)? onPage;
  Future<void> Function()? onWrite;
  final cursors = <AppNotification?>[];
  @override
  String get currentUserId => uid;
  void check() {
    if (fail) throw const NetworkException('Sin conexión de prueba');
  }

  @override
  Future<List<AppNotification>> page({AppNotification? before}) async {
    check();
    cursors.add(before);
    if (onPage != null) return onPage!(before);
    final page =
        rows
            .where(
              (n) =>
                  n.recipientId == uid &&
                  (before == null ||
                      n.createdAt.isBefore(before.createdAt) ||
                      (n.createdAt == before.createdAt &&
                          n.id.compareTo(before.id) < 0)),
            )
            .toList()
          ..sort((a, b) {
            final time = b.createdAt.compareTo(a.createdAt);
            return time == 0 ? b.id.compareTo(a.id) : time;
          });
    return page.take(50).toList();
  }

  @override
  Future<int> unreadCount() async {
    check();
    return rows
        .where((n) => n.recipientId == uid && n.alertEnabled && n.unread)
        .length;
  }

  @override
  Future<NotificationPreferences> preferences() async {
    check();
    return prefs;
  }

  @override
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences value,
  ) async {
    check();
    await onWrite?.call();
    saves++;
    prefs = value;
    return prefs;
  }

  @override
  Future<void> completeTutorial() async {
    check();
    await onWrite?.call();
    tutorials++;
    prefs = NotificationPreferences(
      requests: prefs.requests,
      messages: prefs.messages,
      status: prefs.status,
      matches: prefs.matches,
      tutorialVersion: 1,
    );
  }

  @override
  Future<void> markRead({String? id, DateTime? before}) async {
    check();
    await onWrite?.call();
    reads++;
    rows = rows
        .map(
          (n) =>
              n.recipientId == uid &&
                  ((id != null && n.id == id) ||
                      (id == null &&
                          before != null &&
                          !n.createdAt.isAfter(before)))
              ? n.asRead(DateTime.utc(2026, 11, 21, 1))
              : n,
        )
        .toList();
  }

  @override
  RecoverySubscription watch({
    required void Function() changed,
    required void Function(bool) connection,
  }) {
    this.changed = changed;
    this.connection = connection;
    return RecoverySubscription(() async {
      cancellations++;
    });
  }
}
