import 'dart:async';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/models/recovery.dart';
import 'package:escom_perdidos/viewmodels/recovery_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/recovery_chat_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import '../recovery_helpers.dart';

class _Slow extends FakeRecoveryRepository {
  _Slow() : super(uid: recoveryB);
  final delayed = Completer<List<RecoveryRequest>>();
  final delayedSend = Completer<RecoveryMessage>();
  bool delayRead = true, delaySend = false;
  int reads = 0;
  @override
  Future<List<RecoveryRequest>> requests() {
    reads++;
    return delayRead ? delayed.future : super.requests();
  }

  @override
  Future<RecoveryMessage> send({
    required String id,
    required String conversationId,
    required String body,
  }) => delaySend
      ? delayedSend.future
      : super.send(id: id, conversationId: conversationId, body: body);
}

class _Paged extends FakeRecoveryRepository {
  _Paged() : super(uid: recoveryB);
  int messageReads = 0;
  @override
  Future<List<RecoveryMessage>> messages(
    String conversationId, {
    RecoveryMessage? before,
    RecoveryMessage? after,
  }) async {
    messageReads++;
    final rows =
        sent
            .where(
              (m) =>
                  (before == null || m.createdAt.isBefore(before.createdAt)) &&
                  (after == null || m.createdAt.isAfter(after.createdAt)),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return after != null
        ? rows.take(50).toList()
        : rows.reversed.take(50).toList().reversed.toList();
  }
}

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'recargas periódicas no multiplican consultas mientras una sigue pendiente',
    () async {
      final source = _Slow();
      final root = RecoveryViewModel(repository: source)..bindUser(recoveryB);
      addTearDown(root.dispose);
      await settle();
      await root.load();
      await root.load();
      expect(source.reads, 1);
      source.delayed.complete([]);
      await settle();
      expect(root.loading, isFalse);
    },
  );
  test(
    'lectura A/B tardía se descarta al cambiar a C y se cancela suscripción',
    () async {
      final source = _Slow();
      final vm = RecoveryViewModel(repository: source)..bindUser(recoveryB);
      addTearDown(vm.dispose);
      await settle();
      source.delayRead = false;
      source.uid = recoveryC;
      vm.bindUser(recoveryC);
      await settle();
      source.delayed.complete([RecoveryRequest.fromJson(recoveryRow())]);
      await settle();
      expect(vm.requests, isEmpty);
      expect(vm.conversations, isEmpty);
      expect(vm.incomingPending, 0);
      expect(source.cancellations, 1);
    },
  );
  test('sesión anterior no puede enviar formulario privado', () async {
    final source = FakeRecoveryRepository(uid: recoveryB);
    final vm = RecoveryViewModel(repository: source)..bindUser(recoveryB);
    addTearDown(vm.dispose);
    await settle();
    final session = vm.sessionRevision;
    vm.bindUser(recoveryC);
    await settle();
    expect(
      () => vm.create(
        id: recoveryId,
        itemId: recoveryItem,
        evidence: 'Mi evidencia privada original',
        session: session,
      ),
      throwsA(isA<AuthException>()),
    );
    expect(source.creates, 0);
  });
  test(
    'mensajes fallidos reintentan con mismo UUID y se deduplican al recargar',
    () async {
      final source = FakeRecoveryRepository(uid: recoveryB)
        ..rows[recoveryId] = recoveryRow(status: 'accepted');
      source.chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
      final root = RecoveryViewModel(repository: source)..bindUser(recoveryB);
      await settle();
      final chat = RecoveryChatViewModel(
        recovery: root,
        conversation: source.chats.single,
      );
      addTearDown(() {
        chat.dispose();
        root.dispose();
      });
      await chat.start();
      source.failSend = true;
      await chat.send('Prueba con respuesta perdida');
      final id = chat.pending.single.id;
      expect(chat.pending.single.error, isNotNull);
      source.failSend = false;
      await chat.retry(id);
      await chat.load();
      expect(source.sendIds, [id, id]);
      expect(chat.pending, isEmpty);
      expect(chat.messages, hasLength(1));
    },
  );
  test(
    'respuesta de envío tardía no repuebla mensajes ni borradores de otra cuenta',
    () async {
      final source = _Slow()
        ..delayRead = false
        ..delaySend = true
        ..rows[recoveryId] = recoveryRow(status: 'accepted');
      source.chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
      final root = RecoveryViewModel(repository: source)..bindUser(recoveryB);
      await settle();
      final chat = RecoveryChatViewModel(
        recovery: root,
        conversation: source.chats.single,
      );
      addTearDown(() {
        chat.dispose();
        root.dispose();
      });
      await chat.start();
      final sending = chat.send('Contenido privado de B');
      root.bindUser(recoveryC);
      await settle();
      source.delayedSend.complete(
        RecoveryMessage(
          id: 'old',
          conversationId: recoveryConversation,
          senderId: recoveryB,
          body: 'Contenido privado de B',
          createdAt: DateTime.now(),
        ),
      );
      await sending;
      expect(chat.messages, isEmpty);
      expect(chat.pending, isEmpty);
      expect(chat.active, isFalse);
      expect(chat.sessionEnded, isTrue);
    },
  );
  test(
    'cerrar solicitud descarta mensajes y pendientes y detiene suscripción',
    () async {
      final source = FakeRecoveryRepository(uid: recoveryB)
        ..rows[recoveryId] = recoveryRow(status: 'accepted');
      source.chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
      final root = RecoveryViewModel(repository: source)..bindUser(recoveryB);
      await settle();
      final chat = RecoveryChatViewModel(
        recovery: root,
        conversation: source.chats.single,
      );
      addTearDown(() {
        chat.dispose();
        root.dispose();
      });
      await chat.start();
      await chat.send('Mensaje privado');
      source.rows[recoveryId]!['status'] = 'closed';
      await root.load();
      expect(chat.messages, isEmpty);
      expect(chat.pending, isEmpty);
      expect(chat.active, isFalse);
      expect(source.cancellations, 1);
    },
  );
  test(
    'reconexión recupera más de 50 mensajes sin huecos aunque se envíe uno antes de recargar',
    () async {
      final source = _Paged()
        ..rows[recoveryId] = recoveryRow(status: 'accepted');
      source.chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
      RecoveryMessage message(int i) => RecoveryMessage(
        id: 'message-$i',
        conversationId: recoveryConversation,
        senderId: recoveryA,
        body: 'Mensaje $i',
        createdAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
      );
      source.sent.add(message(0));
      final root = RecoveryViewModel(repository: source)..bindUser(recoveryB);
      await settle();
      final chat = RecoveryChatViewModel(
        recovery: root,
        conversation: source.chats.single,
      );
      addTearDown(() {
        chat.dispose();
        root.dispose();
      });
      await chat.start();
      for (var i = 1; i <= 120; i++) {
        source.sent.add(message(i));
      }
      await chat.send('Mensaje propio tras volver a conectar');
      await chat.load();
      expect(chat.messages, hasLength(122));
      expect(chat.messages.map((m) => m.id).toSet(), hasLength(122));
      expect(source.messageReads, 4);
    },
  );
}
