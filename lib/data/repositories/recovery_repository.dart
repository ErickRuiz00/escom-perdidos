import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../core/errors/app_exception.dart';
import '../models/recovery.dart';
import '../services/supabase_service.dart';

class RecoverySubscription {
  RecoverySubscription(this._cancel);
  final Future<void> Function() _cancel;
  bool _cancelled = false;
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    try {
      await _cancel();
    } catch (_) {
      /* El cierre de sesión no depende de la red. */
    }
  }
}

/// No usa perfiles ni SQLite. Toda escritura y transición se autoriza en RPC.
class RecoveryRepository {
  RecoveryRepository(this._supabase);
  final SupabaseService _supabase;
  sb.SupabaseClient get _client => _supabase.client;
  String get currentUserId =>
      _client.auth.currentUser?.id ??
      (throw const AuthException(
        'Inicia sesión para consultar tus solicitudes.',
      ));
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      final uid = currentUserId;
      final result = await action().timeout(const Duration(seconds: 30));
      if (currentUserId != uid) {
        throw const AuthException(
          'La sesión cambió. Abre de nuevo la pantalla.',
        );
      }
      return result;
    } on AppException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      if (['PGRST202', 'PGRST205', '42P01', '42883'].contains(e.code)) {
        throw const StorageException(
          'El servicio de recuperación todavía no está disponible. Reintenta más tarde.',
        );
      }
      if (e.code == '42501') {
        throw const PermissionException(
          'Esta acción no está disponible para tu cuenta o la conversación se cerró.',
        );
      }
      if (e.code == '23505') {
        throw const AppException(
          'Ya tienes una solicitud activa para este hallazgo. Revisa tus solicitudes.',
        );
      }
      if (e.code == '40001') {
        throw const AppException(
          'La solicitud cambió. Actualiza antes de continuar.',
        );
      }
      // Solo mensajes de negocio controlados por nuestras funciones SQL.
      if (e.code == 'P0001') throw AppException(e.message);
      if (e.code == '23514') {
        throw const AppException(
          'Revisa la longitud y el contenido antes de enviar.',
        );
      }
      throw const StorageException(
        'No pudimos confirmar la operación. Actualiza o reintenta.',
      );
    } on TimeoutException {
      throw const NetworkException(
        'No pudimos confirmar a tiempo. Reintenta la misma operación.',
      );
    } on SocketException {
      throw const NetworkException('Revisa tu conexión e intenta de nuevo.');
    } catch (error) {
      throw StorageException(
        'No pudimos consultar la recuperación. Reintenta.',
        cause: error,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _pages(String table) async {
    final rows = <String, Map<String, dynamic>>{};
    for (var offset = 0; ; offset += 200) {
      final page = await _client
          .from(table)
          .select()
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      for (final row in page) {
        rows[row['id'] as String] = row;
      }
      if (page.length < 200) break;
    }
    return rows.values.toList();
  }

  Future<List<RecoveryRequest>> requests() => _guard(
    () async => (await _pages(
      'recovery_requests',
    )).map(RecoveryRequest.fromJson).toList(),
  );
  Future<List<RecoveryConversation>> conversations() => _guard(
    () async => (await _pages(
      'recovery_conversations',
    )).map(RecoveryConversation.fromJson).toList(),
  );
  Future<List<String>> blockedUsers() => _guard(() async {
    final rows = await _client
        .from('recovery_blocks')
        .select('blocked_id')
        .eq('blocker_id', currentUserId);
    return rows.map((r) => r['blocked_id'] as String).toList();
  });
  Future<RecoveryRequest> create({
    required String id,
    required String itemId,
    required String evidence,
  }) => _guard(() async {
    if (evidence.trim().length < 20 || evidence.trim().length > 1200) {
      throw const AppException(
        'Describe características privadas en 20 a 1200 caracteres.',
      );
    }
    final row = await _client.rpc(
      'encuentralo_request_recovery',
      params: {
        'p_actor': currentUserId,
        'p_id': id,
        'p_item_id': itemId,
        'p_evidence': evidence.trim(),
      },
    );
    return RecoveryRequest.fromJson(Map<String, dynamic>.from(row as Map));
  });
  Future<RecoveryRequest> act(
    RecoveryRequest request,
    String action, {
    String? point,
    DateTime? at,
  }) => _guard(() async {
    final row = await _client.rpc(
      'encuentralo_manage_recovery',
      params: {
        'p_actor': currentUserId,
        'p_id': request.id,
        'p_action': action,
        'p_version': request.version,
        'p_meeting_point': point,
        'p_meeting_at': at?.toUtc().toIso8601String(),
      },
    );
    return RecoveryRequest.fromJson(Map<String, dynamic>.from(row as Map));
  });
  Future<List<RecoveryEvent>> history(String requestId) => _guard(() async {
    final rows = await _client
        .from('recovery_events')
        .select()
        .eq('request_id', requestId)
        .order('id');
    return rows.map(RecoveryEvent.fromJson).toList();
  });
  Future<List<RecoveryMessage>> messages(
    String conversationId, {
    RecoveryMessage? before,
    RecoveryMessage? after,
  }) => _guard(() async {
    var query = _client
        .from('recovery_messages')
        .select()
        .eq('conversation_id', conversationId);
    if (before != null) {
      final date = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$date,and(created_at.eq.$date,id.lt.${before.id})',
      );
    }
    if (after != null) {
      final date = after.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.gt.$date,and(created_at.eq.$date,id.gt.${after.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: after != null)
        .order('id', ascending: after != null)
        .limit(50);
    final messages = rows.map(RecoveryMessage.fromJson).toList();
    return after != null ? messages : messages.reversed.toList();
  });
  Future<RecoveryMessage> send({
    required String id,
    required String conversationId,
    required String body,
  }) => _guard(() async {
    if (body.trim().isEmpty || body.trim().length > 2000) {
      throw const AppException('Escribe un mensaje de 1 a 2000 caracteres.');
    }
    final row = await _client.rpc(
      'encuentralo_send_message',
      params: {
        'p_actor': currentUserId,
        'p_id': id,
        'p_conversation_id': conversationId,
        'p_body': body.trim(),
      },
    );
    return RecoveryMessage.fromJson(Map<String, dynamic>.from(row as Map));
  });
  Future<void> block(String peer, bool blocked) => _guard(() async {
    await _client.rpc(
      'encuentralo_block_user',
      params: {'p_actor': currentUserId, 'p_peer': peer, 'p_block': blocked},
    );
  });
  Future<void> report({
    required String id,
    required String requestId,
    required String reason,
  }) => _guard(() async {
    await _client.rpc(
      'encuentralo_report_abuse',
      params: {
        'p_actor': currentUserId,
        'p_id': id,
        'p_request_id': requestId,
        'p_reason': reason.trim(),
      },
    );
  });

  RecoverySubscription watch({
    required void Function() changed,
    required void Function(bool) connection,
    String? conversationId,
  }) {
    final uid = currentUserId;
    final channel = _client.channel(
      'recovery-$uid-${DateTime.now().microsecondsSinceEpoch}',
    );
    for (final table
        in conversationId == null
            ? ['recovery_requests', 'recovery_conversations']
            : ['recovery_messages']) {
      channel.onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: conversationId == null
            ? null
            : sb.PostgresChangeFilter(
                type: sb.PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
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
