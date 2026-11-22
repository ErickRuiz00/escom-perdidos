enum NotificationKind {
  recoveryRequest('recovery_request'),
  requestStatus('request_status'),
  privateMessage('private_message'),
  returnConfirmed('return_confirmed'),
  publicationChanged('publication_changed');

  const NotificationKind(this.value);
  final String value;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.alertEnabled,
    this.itemId,
    this.requestId,
    this.conversationId,
    this.readAt,
  });
  final String id, recipientId, title, body;
  final NotificationKind kind;
  final DateTime createdAt;
  final bool alertEnabled;
  final String? itemId, requestId, conversationId;
  final DateTime? readAt;
  bool get unread => readAt == null;
  AppNotification asRead(DateTime at) => AppNotification(
    id: id,
    recipientId: recipientId,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    alertEnabled: alertEnabled,
    itemId: itemId,
    requestId: requestId,
    conversationId: conversationId,
    readAt: readAt ?? at,
  );
  factory AppNotification.fromJson(Map<String, dynamic> row) => AppNotification(
    id: row['id'] as String,
    recipientId: row['recipient_id'] as String,
    kind: NotificationKind.values.firstWhere((k) => k.value == row['kind']),
    title: row['title'] as String,
    body: row['body'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    alertEnabled: row['alert_enabled'] as bool,
    itemId: row['item_id'] as String?,
    requestId: row['request_id'] as String?,
    conversationId: row['conversation_id'] as String?,
    readAt: row['read_at'] == null
        ? null
        : DateTime.parse(row['read_at'] as String),
  );
}

class NotificationPreferences {
  const NotificationPreferences({
    this.requests = true,
    this.messages = true,
    this.status = true,
    this.matches = true,
    this.tutorialVersion = 0,
  });
  final bool requests, messages, status, matches;
  final int tutorialVersion;
  NotificationPreferences copyWith({
    bool? requests,
    bool? messages,
    bool? status,
    bool? matches,
  }) => NotificationPreferences(
    requests: requests ?? this.requests,
    messages: messages ?? this.messages,
    status: status ?? this.status,
    matches: matches ?? this.matches,
    tutorialVersion: tutorialVersion,
  );
  factory NotificationPreferences.fromJson(Map<String, dynamic> row) =>
      NotificationPreferences(
        requests: row['recovery_requests'] as bool,
        messages: row['private_messages'] as bool,
        status: row['status_returns'] as bool,
        matches: row['matches'] as bool,
        tutorialVersion: row['tutorial_version'] as int,
      );
}
