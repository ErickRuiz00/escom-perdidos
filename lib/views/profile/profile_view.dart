import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/escom.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../widgets/common.dart';
import 'change_password_view.dart';
import 'edit_profile_view.dart';

/// Perfil del usuario: datos, avatar, preferencias y cierre de sesión (RF1).
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _changeAvatar(BuildContext context) async {
    final fromCamera = await pickPhotoSource(context);
    if (fromCamera == null || !context.mounted) return;
    final error =
        await context.read<ProfileViewModel>().changeAvatar(fromCamera: fromCamera);
    if (error != null && context.mounted) showSnack(context, error, error: true);
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: '¿Cerrar sesión?',
      message: 'Tendrás que volver a ingresar tus datos para entrar.',
      confirmLabel: 'Cerrar sesión',
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await context.read<AuthViewModel>().logout();
  }

  Future<void> _run(BuildContext context, Future<String?> action) async {
    final error = await action;
    if (error != null && context.mounted) showSnack(context, error, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    if (user == null) return const SizedBox.shrink();
    final profile = context.read<ProfileViewModel>();
    final reports = context.watch<ReportsViewModel>().mine(user.id);
    final resolved = reports.where((r) => r.status == ReportStatus.resolved).length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(children: [
                    UserAvatar(user: user, radius: 52),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        tooltip: 'Cambiar foto',
                        icon: const Icon(Icons.photo_camera_rounded, size: 20),
                        onPressed: () => _changeAvatar(context),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(user.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(user.email,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                Row(children: [
                  _Stat(label: 'Reportes', value: '${reports.length}'),
                  _Stat(label: 'Resueltos', value: '$resolved'),
                  _Stat(label: 'Miembro desde', value: Formatters.date(user.createdAt).split(',').last.trim()),
                ]),
                const SizedBox(height: 20),
                _Section(title: 'Cuenta', children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Datos personales'),
                    subtitle: Text([
                      if (user.boleta != null) 'Boleta ${user.boleta}',
                      if (user.phone != null) user.phone!,
                    ].join(' · ').ifEmpty('Agrega tu boleta y teléfono')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EditProfileView()),
                    ),
                  ),
                  if (!user.isGoogle)
                    ListTile(
                      leading: const Icon(Icons.password_rounded),
                      title: const Text('Cambiar contraseña'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChangePasswordView()),
                      ),
                    )
                  else
                    const ListTile(
                      leading: Icon(Icons.verified_user_outlined),
                      title: Text('Cuenta vinculada con Google'),
                    ),
                ]),
                _Section(title: 'Preferencias', children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Notificaciones'),
                    subtitle: const Text('Coincidencias y recordatorios'),
                    value: user.notificationsEnabled,
                    onChanged: (v) => _run(context, profile.setNotifications(v)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Modo oscuro'),
                    value: user.darkMode,
                    onChanged: (v) => _run(context, profile.setDarkMode(v)),
                  ),
                ]),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          Card(child: Column(children: children)),
        ],
      ),
    );
  }
}
