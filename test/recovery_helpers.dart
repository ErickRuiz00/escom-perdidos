import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/models/recovery.dart';
import 'package:escom_perdidos/data/repositories/recovery_repository.dart';

const recoveryA = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const recoveryB = 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
const recoveryC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const recoveryId = '33333333-3333-4333-8333-333333333333';
const recoveryItem = '11111111-1111-4111-8111-111111111111';
const recoveryConversation = '66666666-6666-4666-8666-666666666666';
Map<String, dynamic> recoveryRow({
  String id = recoveryId,
  String requester = recoveryB,
  String finder = recoveryA,
  String status = 'pending',
  int version = 1,
}) => {
  'id': id,
  'item_id': recoveryItem,
  'requester_id': requester,
  'finder_id': finder,
  'item_title': 'Termo azul',
  'evidence': 'Marca privada dentro de la tapa del termo',
  'status': status,
  'version': version,
  'created_at': '2026-11-20T12:00:00Z',
  'updated_at': '2026-11-20T12:00:00Z',
};

class FakeRecoveryRepository implements RecoveryRepository {
  FakeRecoveryRepository({this.uid = recoveryA});
  String uid;
  final rows = <String, Map<String, dynamic>>{};
  final chats = <RecoveryConversation>[];
  final sent = <RecoveryMessage>[];
  final blocks = <String>[];
  final sendIds = <String>[];
  bool failSend = false;
  int cancellations = 0, creates = 0;
  void Function()? changed;
  @override
  String get currentUserId => uid;
  @override
  Future<List<RecoveryRequest>> requests() async => rows.values
      .where((r) => r['finder_id'] == uid || r['requester_id'] == uid)
      .map(RecoveryRequest.fromJson)
      .toList();
  @override
  Future<List<RecoveryConversation>> conversations() async => List.of(chats);
  @override
  Future<List<String>> blockedUsers() async => List.of(blocks);
  @override
  Future<List<RecoveryEvent>> history(String requestId) async => [
    RecoveryEvent(
      id: 1,
      action: 'created',
      createdAt: DateTime.utc(2026, 11, 20),
    ),
  ];
  @override
  Future<RecoveryRequest> create({
    required String id,
    required String itemId,
    required String evidence,
  }) async {
    creates++;
    rows.putIfAbsent(
      id,
      () => {
        ...recoveryRow(id: id, requester: uid),
        'item_id': itemId,
        'evidence': evidence,
      },
    );
    return RecoveryRequest.fromJson(rows[id]!);
  }

  @override
  Future<RecoveryRequest> act(
    RecoveryRequest request,
    String action, {
    String? point,
    DateTime? at,
  }) async {
    final row = rows[request.id]!;
    row['version'] = request.version + 1;
    if (action == 'accept') {
      row['status'] = 'accepted';
      chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
    }
    if (action == 'reject') row['status'] = 'rejected';
    if (action == 'cancel') row['status'] = 'cancelled';
    if (action == 'confirm') {
      row[uid == request.finderId
              ? 'finder_confirmed_at'
              : 'requester_confirmed_at'] =
          '2026-11-21T12:00:00Z';
    }
    if (action == 'meeting') {
      row['meeting_point'] = point;
      row['meeting_at'] = at?.toIso8601String();
    }
    return RecoveryRequest.fromJson(row);
  }

  @override
  Future<List<RecoveryMessage>> messages(
    String conversationId, {
    RecoveryMessage? before,
    RecoveryMessage? after,
  }) async => sent
      .where(
        (m) =>
            m.conversationId == conversationId &&
            (after == null ||
                m.createdAt.isAfter(after.createdAt) ||
                (m.createdAt == after.createdAt &&
                    m.id.compareTo(after.id) > 0)),
      )
      .toList();
  @override
  Future<RecoveryMessage> send({
    required String id,
    required String conversationId,
    required String body,
  }) async {
    sendIds.add(id);
    if (failSend) throw const NetworkException('Sin conexión de prueba');
    final message = RecoveryMessage(
      id: id,
      conversationId: conversationId,
      senderId: uid,
      body: body,
      createdAt: DateTime.now(),
    );
    if (!sent.any((m) => m.id == id)) sent.add(message);
    return message;
  }

  @override
  Future<void> block(String peer, bool blocked) async {
    if (blocked) {
      blocks.add(peer);
    } else {
      blocks.remove(peer);
    }
  }

  @override
  Future<void> report({
    required String id,
    required String requestId,
    required String reason,
  }) async {}
  @override
  RecoverySubscription watch({
    required void Function() changed,
    required void Function(bool) connection,
    String? conversationId,
  }) {
    this.changed = changed;
    return RecoverySubscription(() async {
      cancellations++;
    });
  }
}
