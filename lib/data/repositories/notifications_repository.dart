import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../core/errors/app_exception.dart';
import '../models/app_notification.dart';
import '../services/supabase_service.dart';
import 'recovery_repository.dart';

/// El cliente solo consulta sus avisos y solicita cambios autorizados por RPC.
class NotificationsRepository {
  NotificationsRepository(this._supabase);
  final SupabaseService _supabase;
  sb.SupabaseClient get _client => _supabase.client;
  String get currentUserId =>
      _client.auth.currentUser?.id ??
      (throw const AuthException('Inicia sesión para consultar tus avisos.'));

  Future<T> _guard<T>(Future<T> Function(String uid) action) async {
    try {
      final uid = currentUserId;
      final value = await action(uid).timeout(const Duration(seconds: 30));
      if (currentUserId != uid) {
        throw const AuthException(
          'La sesión cambió. Abre de nuevo la pantalla.',
        );
      }
      return value;
    } on AppException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const PermissionException('No puedes modificar estos avisos.');
      }
      if (['PGRST202', 'PGRST205', '42P01', '42883'].contains(e.code)) {
        throw const StorageException(
          'Los avisos todavía no están disponibles. Reintenta más tarde.',
        );
      }
      throw const StorageException(
        'No pudimos guardar o consultar los avisos. Reintenta.',
      );
    } on TimeoutException {
      throw const NetworkException('La consulta tardó demasiado. Reintenta.');
    } on SocketException {
      throw const NetworkException('Revisa tu conexión e intenta de nuevo.');
    } catch (_) {
      throw const StorageException(
        'No pudimos consultar los avisos. Reintenta.',
      );
    }
  }

  Future<List<AppNotification>> page({AppNotification? before}) => _guard((
    uid,
  ) async {
    var query = _client.from('notifications').select().eq('recipient_id', uid);
    if (before != null) {
      final date = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$date,and(created_at.eq.$date,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(50);
    return rows.map(AppNotification.fromJson).toList();
  });

  Future<int> unreadCount() => _guard(
    (uid) async => await _client
        .from('notifications')
        .count(sb.CountOption.exact)
        .eq('recipient_id', uid)
        .eq('alert_enabled', true)
        .isFilter('read_at', null),
  );

  Future<NotificationPreferences> preferences() => _guard((uid) async {
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    return row == null
        ? const NotificationPreferences()
        : NotificationPreferences.fromJson(row);
  });

  Future<NotificationPreferences> savePreferences(
    NotificationPreferences value,
  ) => _guard((uid) async {
    final row = await _client.rpc(
      'encuentralo_save_notification_preferences',
      params: {
        'p_actor': uid,
        'p_requests': value.requests,
        'p_messages': value.messages,
        'p_status': value.status,
        'p_matches': value.matches,
      },
    );
    return NotificationPreferences.fromJson(
      Map<String, dynamic>.from(row as Map),
    );
  });
  Future<void> completeTutorial() => _guard((uid) async {
    await _client.rpc(
      'encuentralo_complete_tutorial',
      params: {'p_actor': uid},
    );
  });
  Future<void> markRead({String? id, DateTime? before}) => _guard((uid) async {
    await _client.rpc(
      'encuentralo_read_notifications',
      params: {
        'p_actor': uid,
        'p_id': id,
        'p_before': before?.toUtc().toIso8601String(),
      },
    );
  });

  RecoverySubscription watch({
    required void Function() changed,
    required void Function(bool) connection,
  }) {
    final uid = currentUserId;
    final channel = _client.channel(
      'notifications-$uid-${DateTime.now().microsecondsSinceEpoch}',
    );
    for (final table in ['notifications', 'notification_preferences']) {
      channel.onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: table == 'notifications' ? 'recipient_id' : 'user_id',
          value: uid,
        ),
        callback: (_) {
          if (_client.auth.currentUser?.id == uid) changed();
        },
      );
    }
    channel.subscribe((status, error) {
      if (_client.auth.currentUser?.id == uid) {
        connection(status == sb.RealtimeSubscribeStatus.subscribed);
      }
    });
    return RecoverySubscription(() async {
      await _client.removeChannel(channel);
    });
  }
}
