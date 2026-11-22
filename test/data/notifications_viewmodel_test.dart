import 'dart:async';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/models/app_notification.dart';
import 'package:escom_perdidos/viewmodels/notifications_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import '../notification_helpers.dart';
import '../recovery_helpers.dart';

void main() {
  late FakeNotificationsRepository repo;
  late NotificationsViewModel vm;
  setUp(() {
    repo = FakeNotificationsRepository();
    vm = NotificationsViewModel(repository: repo);
  });
  tearDown(() => vm.dispose());
  Future<void> start() async {
    vm.bindUser(recoveryA);
    await Future<void>.delayed(Duration.zero);
    await vm.load();
  }

  test(
    'historial persistente, contador y lectura individual sin borrar eventos',
    () async {
      repo.rows = [
        notification(),
        notification(index: 2, alert: false),
        notification(index: 3, readAt: DateTime.utc(2026)),
      ];
      await start();
      expect(vm.items.length, 3);
      expect(vm.unreadCount, 1);
      await vm.markRead(vm.items.last);
      expect(vm.unreadCount, 0);
      expect(vm.items.length, 3);
      expect(vm.items.last.readAt, isNotNull);
    },
  );
  test(
    'paginación estable, marcar todo incluye páginas antiguas y solo esta cuenta',
    () async {
      repo.rows = [
        for (var i = 1; i <= 125; i++) notification(index: i),
        notification(index: 126, uid: recoveryB),
      ];
      await start();
      expect(vm.items.length, 50);
      expect(vm.unreadCount, 125);
      expect(vm.hasMore, isTrue);
      await vm.loadMore();
      expect(vm.items.length, 100);
      await vm.loadMore();
      expect(vm.items.length, 125);
      expect(vm.hasMore, isFalse);
      await vm.markAllRead();
      expect(vm.items.every((n) => !n.unread), isTrue);
      expect(vm.unreadCount, 0);
      expect(repo.rows.last.unread, isTrue);
    },
  );
  test(
    'reconexión rellena 130 avisos nuevos sin huecos ni duplicados',
    () async {
      repo.rows = [notification()];
      await start();
      repo.rows = [for (var i = 1; i <= 131; i++) notification(index: i)];
      repo.connection!(true);
      await vm.load();
      expect(vm.connected, isTrue);
      expect(vm.items.length, 131);
      expect(vm.items.map((n) => n.id).toSet().length, 131);
      expect(vm.unreadCount, 131);
      repo.changed!();
      await vm.load();
      expect(vm.items.length, 131);
    },
  );
  test(
    'reabrir recupera lecturas y preferencias guardadas en servidor',
    () async {
      repo.rows = [notification()];
      await start();
      await vm.markAllRead();
      await vm.savePreferences(const NotificationPreferences(messages: false));
      vm.bindUser(null);
      expect(vm.items, isEmpty);
      expect(vm.unreadCount, 0);
      expect(vm.ready, isFalse);
      await start();
      expect(vm.items.single.unread, isFalse);
      expect(vm.preferences.messages, isFalse);
    },
  );
  test(
    'silenciar preferencias no elimina eventos y tutorial no cambia categorías',
    () async {
      repo.rows = [notification()];
      await start();
      await vm.savePreferences(
        const NotificationPreferences(
          requests: false,
          messages: false,
          status: false,
          matches: false,
        ),
      );
      await vm.completeTutorial();
      expect(vm.items.length, 1);
      expect(vm.preferences.tutorialVersion, 1);
      expect(vm.preferences.requests, isFalse);
      expect(vm.preferences.matches, isFalse);
    },
  );
  test('errores conservan historial y se recuperan al actualizar', () async {
    repo.rows = [notification()];
    await start();
    repo.fail = true;
    await vm.load();
    expect(vm.error, 'Sin conexión de prueba');
    expect(vm.items.length, 1);
    expect(vm.loading, isFalse);
    await expectLater(
      vm.markRead(vm.items.single),
      throwsA(isA<NetworkException>()),
    );
    expect(vm.saving, isFalse);
    repo.fail = false;
    await vm.load();
    expect(vm.error, isNull);
  });
  test(
    'cambiar cuenta cancela suscripción, limpia datos e ignora callbacks anteriores',
    () async {
      repo.rows = [notification()];
      await start();
      final old = repo.changed!, oldConnection = repo.connection!;
      repo.uid = recoveryB;
      vm.bindUser(recoveryB);
      expect(vm.items, isEmpty);
      expect(vm.unreadCount, 0);
      await Future<void>.delayed(Duration.zero);
      await vm.load();
      expect(repo.cancellations, 1);
      old();
      oldConnection(true);
      expect(vm.connected, isFalse);
      expect(vm.items, isEmpty);
    },
  );
  test(
    'lectura de otra cuenta rechazada sin transmitir al repositorio',
    () async {
      await start();
      expect(
        () => vm.markRead(notification(uid: recoveryB)),
        throwsA(isA<PermissionException>()),
      );
      expect(repo.reads, 0);
    },
  );
  test('respuesta tardía de A no entra en estado de B', () async {
    final pending = Completer<List<AppNotification>>();
    repo.onPage = (_) => pending.future;
    vm.bindUser(recoveryA);
    await Future<void>.delayed(Duration.zero);
    repo.onPage = null;
    repo.uid = recoveryB;
    repo.rows = [notification(uid: recoveryB, index: 2)];
    vm.bindUser(recoveryB);
    await Future<void>.delayed(Duration.zero);
    await vm.load();
    pending.complete([notification()]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.items.single.recipientId, recoveryB);
    expect(vm.unreadCount, 1);
  });
  test('evento llegado durante carga fuerza otra lectura', () async {
    repo.rows = [notification()];
    await start();
    final pending = Completer<List<AppNotification>>();
    var once = true;
    repo.onPage = (before) async {
      if (once) {
        once = false;
        return pending.future;
      }
      return List.of(repo.rows);
    };
    final loading = vm.load();
    repo.rows = [notification(), notification(index: 2)];
    repo.changed!();
    pending.complete([notification()]);
    await loading;
    expect(vm.items.length, 2);
  });
  test(
    'resultado ajeno no se muestra aunque el repositorio incumpla RLS',
    () async {
      repo.onPage = (_) async => [notification(uid: recoveryB)];
      await start();
      expect(vm.items, isEmpty);
      expect(vm.error, 'No pudimos verificar tus avisos.');
    },
  );
  test(
    'escritura en vuelo no aplica preferencias ni lecturas después de salir',
    () async {
      await start();
      final pending = Completer<void>();
      repo.onWrite = () => pending.future;
      final write = vm.savePreferences(
        const NotificationPreferences(messages: false),
      );
      vm.bindUser(null);
      pending.complete();
      await expectLater(write, throwsA(isA<AuthException>()));
      expect(vm.items, isEmpty);
      expect(vm.preferences.messages, isTrue);
      expect(vm.saving, isFalse);
    },
  );
}
