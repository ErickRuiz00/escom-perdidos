import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/escom.dart';
import '../core/errors/app_exception.dart';
import '../data/models/report.dart';
import '../data/models/user.dart';
import '../data/services/location_service.dart';
import '../data/services/media_service.dart';
import 'reports_viewmodel.dart';

/// Estado del formulario para crear o editar un reporte.
class ReportFormViewModel extends ChangeNotifier {
  ReportFormViewModel({
    required ReportsViewModel reports,
    required MediaService media,
    required LocationService location,
    required this.author,
    this.original,
    ReportType? initialType,
  })  : _reports = reports,
        _media = media,
        _location = location,
        type = original?.type ?? initialType ?? ReportType.lost,
        category = original?.category ?? ItemCategory.electronics,
        place = original?.location ?? Escom.locations.first,
        eventDate = original?.eventDate ?? DateTime.now(),
        photoPath = original?.photoPath,
        point = original?.hasLocation == true
            ? GeoPoint(original!.latitude!, original.longitude!)
            : null;

  final ReportsViewModel _reports;
  final MediaService _media;
  final LocationService _location;
  final AppUser author;
  final Report? original;

  ReportType type;
  ItemCategory category;
  String place;
  DateTime eventDate;
  String? photoPath;
  GeoPoint? point;

  bool _saving = false;
  bool _locating = false;
  final List<String> _discardedPhotos = [];

  bool get isEditing => original != null;
  bool get saving => _saving;
  bool get locating => _locating;

  void setType(ReportType value) => _set(() => type = value);
  void setCategory(ItemCategory value) => _set(() => category = value);
  void setPlace(String value) => _set(() => place = value);
  void setEventDate(DateTime value) => _set(() => eventDate = value);

  Future<String?> pickPhoto({required bool fromCamera}) async {
    try {
      final path = await _media.pickImage(fromCamera: fromCamera);
      if (path == null) return null;
      _replacePhoto(path);
      return null;
    } catch (e) {
      return userMessageFor(e);
    }
  }

  void removePhoto() => _replacePhoto(null);

  Future<String?> captureLocation() async {
    _set(() => _locating = true);
    try {
      point = await _location.currentPosition();
      return null;
    } catch (e) {
      return userMessageFor(e);
    } finally {
      _set(() => _locating = false);
    }
  }

  void clearLocation() => _set(() => point = null);

  /// Guarda el reporte. Devuelve un mensaje de error o `null` si tuvo éxito.
  Future<String?> save({
    required String title,
    required String description,
    String? contact,
  }) async {
    _set(() => _saving = true);
    try {
      final now = DateTime.now();
      final cleanContact = contact?.trim().isEmpty ?? true ? null : contact!.trim();
      if (original == null) {
        await _reports.create(
          Report(
            id: const Uuid().v4(),
            userId: author.id,
            type: type,
            title: title,
            description: description,
            category: category,
            location: place,
            eventDate: eventDate,
            status: ReportStatus.active,
            createdAt: now,
            updatedAt: now,
            photoPath: photoPath,
            latitude: point?.latitude,
            longitude: point?.longitude,
            contact: cleanContact,
          ),
          author,
        );
      } else {
        await _reports.update(
          original!.copyWith(
            type: type,
            title: title,
            description: description,
            category: category,
            location: place,
            eventDate: eventDate,
            updatedAt: now,
            photoPath: photoPath,
            clearPhoto: photoPath == null,
            latitude: point?.latitude,
            longitude: point?.longitude,
            clearCoordinates: point == null,
            contact: cleanContact ?? '',
          ),
          replacedPhoto: original!.photoPath,
        );
      }
      // Fotos tomadas durante la edición que al final no se usaron.
      for (final path in _discardedPhotos) {
        if (path != original?.photoPath) await _media.deleteImage(path);
      }
      _discardedPhotos.clear();
      return null;
    } catch (e) {
      return userMessageFor(e);
    } finally {
      _set(() => _saving = false);
    }
  }

  /// Si el usuario sale sin guardar, se borran las fotos nuevas que tomó.
  Future<void> discard() async {
    final unsaved = {..._discardedPhotos, ?photoPath}
      ..remove(original?.photoPath);
    for (final path in unsaved) {
      await _media.deleteImage(path);
    }
  }

  void _replacePhoto(String? path) {
    final previous = photoPath;
    if (previous != null) _discardedPhotos.add(previous);
    _set(() => photoPath = path);
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}
