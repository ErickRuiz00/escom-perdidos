import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';

/// Acceso a cámara y galería (RF3 - Integración con hardware).
class MediaService {
  MediaService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Toma o elige una foto y la copia al directorio privado de la app.
  ///
  /// La imagen se redimensiona a 1280 px y se comprime al 75% para mantener
  /// bajo el consumo de memoria y almacenamiento (RNF2 - Eficiencia).
  /// Devuelve `null` si el usuario cancela.
  Future<String?> pickImage({required bool fromCamera}) async {
    try {
      final file = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (file == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final photos = Directory(p.join(dir.path, 'photos'));
      if (!photos.existsSync()) await photos.create(recursive: true);
      final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
      final target = p.join(photos.path, '${const Uuid().v4()}$ext');
      await File(file.path).copy(target);
      return target;
    } on PlatformException catch (e) {
      if (e.code.contains('access_denied') || e.code.contains('permission')) {
        throw PermissionException(
          fromCamera
              ? 'Permite el acceso a la cámara en los ajustes del teléfono.'
              : 'Permite el acceso a tus fotos en los ajustes del teléfono.',
          cause: e,
        );
      }
      throw AppException('No se pudo obtener la imagen.', cause: e);
    } on FileSystemException catch (e) {
      throw StorageException('No se pudo guardar la imagen.', cause: e);
    }
  }

  /// Borra una foto que ya no se usa para liberar espacio.
  Future<void> deleteImage(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // No es crítico si no se puede borrar.
    }
  }
}
