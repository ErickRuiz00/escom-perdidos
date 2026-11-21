import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../models/publication_photo.dart';
import '../models/report.dart';
import '../services/supabase_service.dart';

/// Única fuente del catálogo compartido. No consulta ni importa SQLite.
class FoundItemsRepository {
  FoundItemsRepository(this._supabase);
  final SupabaseService _supabase;
  static const bucket = 'found-item-photos';
  static const columns =
      'id,finder_id,title,category,description,found_on,zone,custody,status,photo_path,created_at,updated_at';
  sb.SupabaseClient get _client => _supabase.client;
  String get _userId =>
      _client.auth.currentUser?.id ??
      (throw const AuthException(
        'Inicia sesión para consultar los hallazgos.',
      ));

  Future<List<Report>> fetchAll() => _fetch(mine: false);
  Future<List<Report>> fetchMine() => _fetch(mine: true);
  Future<List<Report>> _fetch({required bool mine}) => _guard(() async {
    final uid = _userId;
    final result = <String, Report>{};
    const pageSize = 200;
    for (var offset = 0; ; offset += pageSize) {
      final query = _client.from('found_items').select(columns);
      final rows =
          await (mine
                  ? query.eq('finder_id', uid)
                  : query.eq('status', 'active'))
              .order('created_at', ascending: false)
              .order('id')
              .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        final report = Report.fromRemote(row);
        result[report.id] = report;
      }
      if (rows.length < pageSize) break;
    }
    if (_userId != uid) {
      throw const AuthException(
        'La sesión cambió. Vuelve a consultar los hallazgos.',
      );
    }
    return result.values.toList();
  });

  Future<Report?> findById(String id) => _guard(() async {
    final uid = _userId;
    final row = await _client
        .from('found_items')
        .select(columns)
        .eq('id', id)
        .maybeSingle();
    _assertSessionUser(uid);
    return row == null ? null : Report.fromRemote(row);
  });

  void _assertSessionUser(String uid) {
    if (_userId != uid) {
      throw const AuthException('La sesión cambió. Abre de nuevo la pantalla.');
    }
  }

  static void validate(Report report) {
    final error =
        Validators.title(report.title) ??
        Validators.description(report.description);
    if (error != null) throw AppException(error);
    if (report.type != ReportType.found ||
        report.custody == null ||
        !Escom.locations.contains(report.location)) {
      throw const AppException(
        'Revisa el tipo de hallazgo, la zona y su custodia.',
      );
    }
    final date = DateTime(
      report.eventDate.year,
      report.eventDate.month,
      report.eventDate.day,
    );
    final now = DateTime.now();
    if (date.isBefore(DateTime(2020)) ||
        date.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const AppException('La fecha debe estar entre 2020 y hoy.');
    }
  }

  void _assertOwner(Report report) {
    if (report.userId != _userId || !report.isActive) {
      throw const PermissionException(
        'Solo puedes modificar tus publicaciones disponibles.',
      );
    }
    validate(report);
  }

  bool _matches(Report record, Map<String, dynamic> payload) {
    final remote = record.toRemote();
    return payload.entries.every(
      (e) => e.key == 'id'
          ? record.id == e.value
          : e.key == 'finder_id'
          ? record.userId == e.value
          : remote[e.key] == e.value,
    );
  }

  Future<String?> _upload(Report report, PublicationPhoto? photo) async {
    _assertOwner(report);
    if (photo == null) return report.photoObjectPath;
    final path = photo.objectPath(report.userId, report.id);
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: sb.FileOptions(
              contentType: photo.mimeType,
              upsert: false,
              cacheControl: '120',
            ),
          );
    } on sb.StorageException catch (error) {
      // Una repetición del mismo contenido utiliza exactamente la misma ruta.
      if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
    }
    return path;
  }

  Future<void> _cleanup(String? path) async {
    final uid = _client.auth.currentUser?.id;
    if (path == null || uid == null || !path.startsWith('$uid/')) return;
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {
      /* El borrado nunca convierte una publicación confirmada en error. */
    }
  }

  Future<Report> create(Report report) => _guard(() async {
    _assertOwner(report);
    final photo = report.photoPath == null
        ? null
        : await PublicationPhoto.read(report.photoPath!);
    final desiredPath =
        photo?.objectPath(report.userId, report.id) ?? report.photoObjectPath;
    final payload = {
      ...report.toRemote(),
      'id': report.id,
      'finder_id': report.userId,
      'photo_path': desiredPath,
    };
    final existing = await findById(report.id);
    if (existing != null) {
      if (existing.userId == _userId &&
          existing.isActive &&
          _matches(existing, payload)) {
        return existing;
      }
      throw const AppException(
        'Este hallazgo ya existe con otros datos. Abre su detalle antes de editarlo.',
      );
    }
    await _upload(report, photo);
    try {
      _assertOwner(report);
      final row = await _client
          .from('found_items')
          .insert(payload)
          .select(columns)
          .single();
      _assertSessionUser(report.userId);
      return Report.fromRemote(row);
    } catch (_) {
      // La respuesta puede perderse después de confirmar el INSERT. Se verifica
      // el UUID estable antes de declarar éxito o eliminar una foto vinculada.
      Report? confirmed;
      var checked = false;
      try {
        confirmed = await findById(report.id);
        checked = true;
      } catch (_) {}
      if (confirmed != null &&
          confirmed.userId == _userId &&
          confirmed.isActive &&
          _matches(confirmed, payload)) {
        return confirmed;
      }
      if (checked) await _cleanup(desiredPath);
      rethrow;
    }
  });

  Future<Report> update(Report report, {required DateTime expectedUpdatedAt}) =>
      _guard(() async {
        _assertOwner(report);
        final before = await findById(report.id);
        if (before == null || before.userId != _userId || !before.isActive) {
          throw const PermissionException(
            'Esta publicación ya no está disponible para editar.',
          );
        }
        if (before.custody == ItemCustody.prefecture &&
            report.custody != ItemCustody.prefecture) {
          throw const AppException(
            'La entrega declarada a Prefectura no puede revertirse.',
          );
        }
        final photo = report.photoPath == null
            ? null
            : await PublicationPhoto.read(report.photoPath!);
        final desiredPath =
            photo?.objectPath(report.userId, report.id) ??
            report.photoObjectPath;
        final payload = {...report.toRemote(), 'photo_path': desiredPath};
        if (_matches(before, payload)) return before;
        if (!before.updatedAt.isAtSameMomentAs(expectedUpdatedAt)) {
          throw const AppException(
            'La publicación cambió. Abre de nuevo el detalle antes de editar.',
          );
        }
        await _upload(report, photo);
        Report? confirmed;
        try {
          _assertOwner(report);
          final row = await _client
              .from('found_items')
              .update(payload)
              .eq('id', report.id)
              .eq('finder_id', report.userId)
              .eq('status', 'active')
              .eq('updated_at', expectedUpdatedAt.toUtc().toIso8601String())
              .select(columns)
              .maybeSingle();
          if (row == null) {
            throw const AppException(
              'La publicación cambió. Vuelve a abrir su detalle.',
            );
          }
          _assertSessionUser(report.userId);
          confirmed = Report.fromRemote(row);
        } catch (_) {
          var checked = false;
          try {
            final row = await findById(report.id);
            _assertSessionUser(report.userId);
            checked = true;
            if (row != null &&
                row.userId == report.userId &&
                row.isActive &&
                _matches(row, payload)) {
              confirmed = row;
            }
          } catch (_) {}
          if (confirmed == null) {
            if (checked && desiredPath != before.photoObjectPath) {
              await _cleanup(desiredPath);
            }
            rethrow;
          }
        }
        if (before.photoObjectPath != desiredPath) {
          await _cleanup(before.photoObjectPath);
        }
        return confirmed;
      });

  Future<Report> withdraw(Report report) => _guard(() async {
    _assertOwner(report);
    try {
      final row = await _client
          .from('found_items')
          .update({'status': 'withdrawn'})
          .eq('id', report.id)
          .eq('finder_id', report.userId)
          .eq('status', 'active')
          .eq('updated_at', report.updatedAt.toUtc().toIso8601String())
          .select(columns)
          .maybeSingle();
      _assertSessionUser(report.userId);
      if (row == null) {
        throw const AppException(
          'La publicación cambió. Actualiza el detalle antes de retirarla.',
        );
      }
      return Report.fromRemote(row);
    } catch (_) {
      // Un retiro confirmado también es seguro de reintentar si se perdió su
      // respuesta. Nunca se intenta reactivar ni sobrescribir una versión nueva.
      try {
        final confirmed = await findById(report.id);
        _assertSessionUser(report.userId);
        if (confirmed?.userId == report.userId &&
            confirmed?.status == ReportStatus.withdrawn) {
          return confirmed!;
        }
      } catch (_) {}
      rethrow;
    }
  });

  Future<String> signedPhotoUrl(String path) => _guard(() async {
    final uid = _userId;
    final url = await _client.storage.from(bucket).createSignedUrl(path, 120);
    _assertSessionUser(uid);
    return url;
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 45));
    } on AppException {
      rethrow;
    } on sb.PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const PermissionException(
          'No tienes permiso para modificar esta publicación.',
        );
      }
      if (error.code == 'PGRST205' || error.code == '42P01') {
        throw const StorageException(
          'El servicio de hallazgos todavía no está disponible. Intenta más tarde.',
        );
      }
      throw const StorageException(
        'No pudimos confirmar los cambios. Reintenta o actualiza el detalle.',
      );
    } on sb.StorageException {
      throw const StorageException(
        'No pudimos guardar o consultar la fotografía. Revisa tu conexión y reintenta.',
      );
    } on SocketException {
      throw const NetworkException(
        'Revisa tu conexión a internet e intenta de nuevo.',
      );
    } on TimeoutException {
      throw const NetworkException(
        'No pudimos confirmar la operación a tiempo. Reintenta con este mismo formulario.',
      );
    } catch (error) {
      throw AppException(
        'No pudimos consultar el servicio de hallazgos. Intenta de nuevo.',
        cause: error,
      );
    }
  }
}
