import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import '../../core/errors/app_exception.dart';

/// Fotografía raster validada antes de enviarse al bucket privado.
class PublicationPhoto {
  const PublicationPhoto(this.bytes, this.extension, this.mimeType);
  static const maxBytes = 3 * 1024 * 1024;
  final Uint8List bytes;
  final String extension;
  final String mimeType;

  String objectPath(String owner, String publication) {
    final hash = sha256.convert(bytes).toString();
    final assetId =
        '${hash.substring(0, 8)}-${hash.substring(8, 12)}-${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}';
    return '$owner/$publication/$assetId.$extension';
  }

  static PublicationPhoto inspect(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const AppException('La foto debe pesar como máximo 3 MB.');
    }
    final type = switch (bytes) {
      [0xff, 0xd8, 0xff, ...] => ('jpg', 'image/jpeg'),
      [137, 80, 78, 71, 13, 10, 26, 10, ...] => ('png', 'image/png'),
      [82, 73, 70, 70, _, _, _, _, 87, 69, 66, 80, ...] => (
        'webp',
        'image/webp',
      ),
      _ => throw const AppException(
        'Selecciona una imagen JPEG, PNG o WebP válida.',
      ),
    };
    return PublicationPhoto(bytes, type.$1, type.$2);
  }

  static Future<PublicationPhoto> read(String path) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw const AppException('La foto debe pesar como máximo 3 MB.');
    }
    final photo = inspect(await file.readAsBytes());
    final buffer = await ui.ImmutableBuffer.fromUint8List(photo.bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 16000000) {
        throw const AppException(
          'La imagen es demasiado grande. Elige una foto de hasta 16 megapíxeles.',
        );
      }
      codec = await descriptor.instantiateCodec(targetWidth: 1280);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'No pudimos leer la foto. Selecciona otra imagen.',
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
    return photo;
  }
}
