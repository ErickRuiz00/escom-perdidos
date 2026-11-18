import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/escom.dart';
import '../core/errors/app_exception.dart';
import '../data/models/report.dart';
import '../data/models/user.dart';
import '../data/models/publication_photo.dart';
import '../data/repositories/found_items_repository.dart';
import '../data/services/media_service.dart';
import 'reports_viewmodel.dart';

class ReportFormViewModel extends ChangeNotifier {
  ReportFormViewModel({
    required ReportsViewModel reports,
    required MediaService media,
    required this.author,
    this.original,
  }) : _reports = reports,
       _media = media,
       _id = original?.id ?? const Uuid().v4(),
       custody = original?.custody ?? ItemCustody.student,
       category = original?.category ?? ItemCategory.electronics,
       place = original?.location ?? Escom.locations.first,
       eventDate = original?.eventDate ?? DateTime.now();
  final ReportsViewModel _reports;
  final MediaService _media;
  final AppUser author;
  final Report? original;
  final String _id;
  final _picked = <String>{};
  bool _disposed = false;
  bool _saving = false;
  bool _picking = false;
  bool _removeRemote = false;
  ItemCustody custody;
  ItemCategory category;
  String place;
  DateTime eventDate;
  String? photoPath;
  String? get photoObjectPath =>
      _removeRemote ? null : original?.photoObjectPath;
  Report? savedReport;
  bool get isEditing => original != null;
  bool get saving => _saving;
  bool get picking => _picking;
  void setCustody(ItemCustody value) {
    if (original?.custody != ItemCustody.prefecture) {
      _set(() => custody = value);
    }
  }

  void setCategory(ItemCategory value) => _set(() => category = value);
  void setPlace(String value) => _set(() => place = value);
  void setEventDate(DateTime value) => _set(() => eventDate = value);

  Future<String?> pickPhoto({required bool fromCamera}) async {
    if (_picking || _saving) return null;
    _set(() => _picking = true);
    String? path;
    try {
      path = await _media.pickImage(fromCamera: fromCamera);
      if (path == null) return null;
      _picked.add(path);
      await PublicationPhoto.read(path);
      if (!_disposed) {
        _set(() {
          photoPath = path;
          _removeRemote = true;
        });
      }
      return null;
    } catch (e) {
      if (path != null) await _media.deleteImage(path);
      return userMessageFor(e);
    } finally {
      _set(() => _picking = false);
      if (_disposed) await discard();
    }
  }

  void removePhoto() => _set(() {
    photoPath = null;
    _removeRemote = true;
  });

  Future<String?> save({
    required String title,
    required String description,
  }) async {
    if (_saving || _picking) return 'Espera a que termine la operación actual.';
    _set(() => _saving = true);
    try {
      final now = DateTime.now();
      final report =
          original?.copyWith(
            title: title,
            description: description,
            category: category,
            location: place,
            eventDate: eventDate,
            custody: custody,
            photoPath: photoPath,
            clearPhoto: photoPath == null,
            clearRemotePhoto: _removeRemote,
          ) ??
          Report(
            id: _id,
            userId: author.id,
            type: ReportType.found,
            title: title,
            description: description,
            category: category,
            location: place,
            eventDate: eventDate,
            custody: custody,
            status: ReportStatus.active,
            createdAt: now,
            updatedAt: now,
            photoPath: photoPath,
          );
      FoundItemsRepository.validate(report);
      savedReport = original == null
          ? await _reports.create(report, author)
          : await _reports.update(
              report,
              expectedUpdatedAt: original!.updatedAt,
            );
      return null;
    } catch (e) {
      return userMessageFor(e);
    } finally {
      _set(() => _saving = false);
      if (_disposed) await discard();
    }
  }

  Future<void> discard() async {
    if (_saving || _picking) return;
    for (final path in _picked.toList()) {
      await _media.deleteImage(path);
      _picked.remove(path);
    }
  }

  void _set(VoidCallback action) {
    action();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(discard());
    super.dispose();
  }
}
