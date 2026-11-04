import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/media_service.dart';
import '../data/services/notification_service.dart';
import 'auth_viewmodel.dart';

/// Gestión del perfil: datos personales, avatar, preferencias y contraseña (RF1).
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required AuthRepository repository,
    required AuthViewModel auth,
    required MediaService media,
    required NotificationService notifications,
  })  : _repository = repository,
        _auth = auth,
        _media = media,
        _notifications = notifications;

  final AuthRepository _repository;
  final AuthViewModel _auth;
  final MediaService _media;
  final NotificationService _notifications;

  bool _saving = false;
  bool get saving => _saving;

  AppUser get user => _auth.user!;

  /// Devuelve un mensaje de error, o `null` si todo salió bien.
  Future<String?> saveProfile({
    required String name,
    String? boleta,
    String? phone,
  }) =>
      _save(user.copyWith(name: name, boleta: boleta ?? '', phone: phone ?? ''));

  Future<String?> changeAvatar({required bool fromCamera}) async {
    try {
      final path = await _media.pickImage(fromCamera: fromCamera);
      if (path == null) return null;
      final previous = user.avatarPath;
      final error = await _save(user.copyWith(avatarPath: path));
      if (error == null) await _media.deleteImage(previous);
      return error;
    } catch (e) {
      return userMessageFor(e);
    }
  }

  Future<String?> setNotifications(bool enabled) async {
    if (enabled) await _notifications.requestPermission();
    return _save(user.copyWith(notificationsEnabled: enabled));
  }

  Future<String?> setDarkMode(bool enabled) => _save(user.copyWith(darkMode: enabled));

  Future<String?> changePassword(String current, String next) async {
    _setSaving(true);
    try {
      await _repository.changePassword(
        userId: user.id,
        currentPassword: current,
        newPassword: next,
      );
      return null;
    } catch (e) {
      return userMessageFor(e);
    } finally {
      _setSaving(false);
    }
  }

  Future<String?> _save(AppUser updated) async {
    _setSaving(true);
    try {
      _auth.updateUser(await _repository.updateProfile(updated));
      return null;
    } catch (e) {
      return userMessageFor(e);
    } finally {
      _setSaving(false);
    }
  }

  void _setSaving(bool value) {
    _saving = value;
    notifyListeners();
  }
}
