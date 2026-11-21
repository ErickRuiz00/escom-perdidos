import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../home/community_views.dart';
import '../home/my_reports_view.dart';
import '../widgets/common.dart';
import 'change_password_view.dart';
import 'edit_profile_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.onNewReport});
  final VoidCallback onNewReport;

  Future<void> _changeAvatar(BuildContext context) async {
    final fromCamera = await pickPhotoSource(context);
    if (fromCamera == null || !context.mounted) return;
    final error = await context.read<ProfileViewModel>().changeAvatar(
      fromCamera: fromCamera,
    );
    if (error != null && context.mounted) {
      showSnack(context, error, error: true);
    }
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
    final auth = context.read<AuthViewModel>();
    final success = await auth.logout();
    if (!success && context.mounted) {
      showSnack(
        context,
        auth.error ?? 'No se pudo cerrar la sesión.',
        error: true,
      );
    }
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const PageStorageKey('profile-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            ConstrainedContent(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            UserAvatar(user: user, radius: 46),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: IconButton.filled(
                                tooltip: 'Cambiar foto',
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 18,
                                ),
                                onPressed: () => _changeAvatar(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _open(context, const EditProfileView()),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar perfil'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Mi actividad',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        _ProfileLink(
                          icon: Icons.inventory_2_outlined,
                          title: 'Mis hallazgos',
                          subtitle: 'Tus publicaciones en la comunidad',
                          onTap: () => _open(
                            context,
                            MyReportsView(onNewReport: onNewReport),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _ProfileLink(
                          icon: Icons.manage_search_rounded,
                          title: 'Mis búsquedas',
                          subtitle: 'Tu espacio personal de búsqueda',
                          onTap: () => _open(
                            context,
                            const PendingActivityView(
                              title: 'Mis búsquedas',
                              icon: Icons.manage_search_rounded,
                              heading: 'Lo que buscas tiene su lugar',
                              message:
                                  'Más adelante podrás organizar tus búsquedas privadas aquí. Por ahora puedes consultar los hallazgos en Explorar.',
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _ProfileLink(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Mis hazañas',
                          subtitle: 'Tu contribución a la comunidad',
                          onTap: () => _open(
                            context,
                            const PendingActivityView(
                              title: 'Mis hazañas',
                              icon: Icons.workspace_premium_outlined,
                              heading: 'Cada devolución cuenta',
                              message:
                                  'Este espacio reunirá tus aportaciones a la comunidad cuando esté disponible. Aún no hay hazañas registradas.',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: _ProfileLink(
                      icon: Icons.settings_outlined,
                      title: 'Configuración',
                      subtitle: 'Apariencia y seguridad',
                      onTap: () => _open(context, const SettingsView()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});
  Future<void> _theme(BuildContext context, bool dark) async {
    final error = await context.read<ProfileViewModel>().setDarkMode(dark);
    if (error != null && context.mounted) {
      showSnack(context, error, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    if (user == null) return const SizedBox.shrink();
    final saving = context.watch<ProfileViewModel>().saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConstrainedContent(
              maxWidth: 640,
              child: Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Modo oscuro'),
                      value: user.darkMode,
                      onChanged: saving
                          ? null
                          : (value) => _theme(context, value),
                    ),
                    const Divider(height: 1),
                    if (!user.isGoogle)
                      _ProfileLink(
                        icon: Icons.password_rounded,
                        title: 'Cambiar contraseña',
                        subtitle: 'Protege el acceso a tu cuenta',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChangePasswordView(),
                          ),
                        ),
                      )
                    else
                      const ListTile(
                        leading: Icon(Icons.verified_user_outlined),
                        title: Text('Cuenta vinculada con Google'),
                      ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.notifications_none_rounded),
                      title: Text('Notificaciones'),
                      subtitle: Text('Disponibles en una próxima fase'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
