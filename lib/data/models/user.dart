/// Usuario registrado en la app.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.provider,
    required this.createdAt,
    this.boleta,
    this.phone,
    this.avatarPath,
    this.avatarUrl,
    this.notificationsEnabled = true,
    this.darkMode = false,
  });

  final String id;
  final String name;
  final String email;

  /// `local` (correo/contraseña) o `google`.
  final String provider;
  final DateTime createdAt;
  final String? boleta;
  final String? phone;

  /// Foto tomada/elegida en el dispositivo.
  final String? avatarPath;

  /// Foto remota del proveedor OAuth (si existe).
  final String? avatarUrl;
  final bool notificationsEnabled;
  final bool darkMode;

  bool get isGoogle => provider == 'google';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  AppUser copyWith({
    String? name,
    String? boleta,
    String? phone,
    String? avatarPath,
    bool? notificationsEnabled,
    bool? darkMode,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      provider: provider,
      createdAt: createdAt,
      boleta: boleta ?? this.boleta,
      phone: phone ?? this.phone,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarUrl: avatarUrl,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      provider: map['provider'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      boleta: map['boleta'] as String?,
      phone: map['phone'] as String?,
      avatarPath: map['avatar_path'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      notificationsEnabled: (map['notifications_enabled'] as int? ?? 1) == 1,
      darkMode: (map['dark_mode'] as int? ?? 0) == 1,
    );
  }

  /// Solo los campos del perfil; el hash y la sal se gestionan en el repositorio.
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'provider': provider,
        'created_at': createdAt.millisecondsSinceEpoch,
        'boleta': boleta,
        'phone': phone,
        'avatar_path': avatarPath,
        'avatar_url': avatarUrl,
        'notifications_enabled': notificationsEnabled ? 1 : 0,
        'dark_mode': darkMode ? 1 : 0,
      };
}
