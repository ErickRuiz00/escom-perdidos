enum RecoveryStatus {
  pending('Pendiente'),
  accepted('Aceptada'),
  rejected('Rechazada'),
  cancelled('Cancelada'),
  closed('Cerrada');

  const RecoveryStatus(this.label);
  final String label;
}

class RecoveryRequest {
  const RecoveryRequest({
    required this.id,
    required this.itemId,
    required this.requesterId,
    required this.finderId,
    required this.itemTitle,
    required this.evidence,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.closeReason,
    this.meetingPoint,
    this.meetingAt,
    this.finderConfirmedAt,
    this.requesterConfirmedAt,
  });
  final String id, itemId, requesterId, finderId, itemTitle, evidence;
  final RecoveryStatus status;
  final int version;
  final DateTime createdAt, updatedAt;
  final String? closeReason, meetingPoint;
  final DateTime? meetingAt, finderConfirmedAt, requesterConfirmedAt;
  bool get active =>
      status == RecoveryStatus.pending || status == RecoveryStatus.accepted;
  bool get hasConfirmation =>
      finderConfirmedAt != null || requesterConfirmedAt != null;
  bool confirmedBy(String uid) => uid == finderId
      ? finderConfirmedAt != null
      : uid == requesterId && requesterConfirmedAt != null;
  String peer(String uid) => uid == finderId ? requesterId : finderId;
  String get stateLabel =>
      closeReason == 'returned' ? 'Devolución confirmada' : status.label;
  String? get closureLabel => switch (closeReason) {
    'returned' => 'Ambos estudiantes confirmaron la devolución.',
    'item_returned' => 'El hallazgo se devolvió mediante otra solicitud.',
    'item_withdrawn' => 'La publicación fue retirada.',
    'prefecture' =>
      'Se declaró entrega a Prefectura. Acude presencialmente a consultar el objeto.',
    'blocked' => 'La comunicación se cerró por bloqueo.',
    'participant_closed' => 'Un participante cerró la conversación.',
    _ => null,
  };
  factory RecoveryRequest.fromJson(Map<String, dynamic> row) => RecoveryRequest(
    id: row['id'] as String,
    itemId: row['item_id'] as String,
    requesterId: row['requester_id'] as String,
    finderId: row['finder_id'] as String,
    itemTitle: row['item_title'] as String,
    evidence: row['evidence'] as String,
    status: RecoveryStatus.values.byName(row['status'] as String),
    version: row['version'] as int,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    closeReason: row['close_reason'] as String?,
    meetingPoint: row['meeting_point'] as String?,
    meetingAt: _date(row['meeting_at']),
    finderConfirmedAt: _date(row['finder_confirmed_at']),
    requesterConfirmedAt: _date(row['requester_confirmed_at']),
  );
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

class RecoveryConversation {
  const RecoveryConversation({
    required this.id,
    required this.requestId,
    this.closedAt,
  });
  final String id, requestId;
  final DateTime? closedAt;
  factory RecoveryConversation.fromJson(Map<String, dynamic> row) =>
      RecoveryConversation(
        id: row['id'] as String,
        requestId: row['request_id'] as String,
        closedAt: _date(row['closed_at']),
      );
}

class RecoveryMessage {
  const RecoveryMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });
  final String id, conversationId, senderId, body;
  final DateTime createdAt;
  factory RecoveryMessage.fromJson(Map<String, dynamic> row) => RecoveryMessage(
    id: row['id'] as String,
    conversationId: row['conversation_id'] as String,
    senderId: row['sender_id'] as String,
    body: row['body'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

class RecoveryEvent {
  const RecoveryEvent({
    required this.id,
    required this.action,
    required this.createdAt,
  });
  final int id;
  final String action;
  final DateTime createdAt;
  String get label => switch (action) {
    'created' => 'Solicitud enviada',
    'accept' => 'Solicitud aceptada',
    'reject' => 'Solicitud rechazada',
    'cancel' => 'Solicitud cancelada',
    'close' => 'Conversación cerrada',
    'meeting' => 'Acuerdo de encuentro actualizado',
    'finder_confirmed' => 'El encontrador confirmó la entrega',
    'requester_confirmed' => 'El solicitante confirmó la recepción',
    'returned' => 'Ambos confirmaron la devolución',
    'item_returned' => 'Hallazgo devuelto en otra solicitud',
    'item_withdrawn' => 'Publicación retirada',
    'prefecture' => 'Entrega declarada a Prefectura',
    'blocked' => 'Comunicación bloqueada',
    _ => 'Estado actualizado',
  };
  factory RecoveryEvent.fromJson(Map<String, dynamic> row) => RecoveryEvent(
    id: row['id'] as int,
    action: row['action'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
