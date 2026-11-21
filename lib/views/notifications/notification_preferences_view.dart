import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/app_notification.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../widgets/common.dart';

class NotificationPreferencesView extends StatelessWidget {
  const NotificationPreferencesView({super.key});
  Future<void> _save(
    BuildContext context,
    NotificationPreferences preferences,
  ) async {
    try {
      await context.read<NotificationsViewModel>().savePreferences(preferences);
      if (context.mounted) showSnack(context, 'Preferencias guardadas');
    } catch (e) {
      if (context.mounted) showSnack(context, userMessageFor(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>(), p = vm.preferences;
    final enabled = vm.ready && !vm.saving && !vm.loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias de avisos')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConstrainedContent(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Elige qué eventos aparecen como avisos sin leer. Los eventos siguen disponibles en tu historial aunque los silencies. Los cambios se aplican a eventos futuros.',
                  ),
                  const SizedBox(height: 16),
                  if (vm.loading || vm.saving) const LinearProgressIndicator(),
                  if (vm.error != null) Text(vm.error!),
                  if (!vm.ready)
                    TextButton(
                      onPressed: vm.loading ? null : vm.load,
                      child: const Text('Reintentar'),
                    ),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Solicitudes de recuperación'),
                          value: p.requests,
                          onChanged: enabled
                              ? (v) => _save(context, p.copyWith(requests: v))
                              : null,
                        ),
                        SwitchListTile(
                          title: const Text('Mensajes privados'),
                          value: p.messages,
                          onChanged: enabled
                              ? (v) => _save(context, p.copyWith(messages: v))
                              : null,
                        ),
                        SwitchListTile(
                          title: const Text('Cambios de estado y devoluciones'),
                          value: p.status,
                          onChanged: enabled
                              ? (v) => _save(context, p.copyWith(status: v))
                              : null,
                        ),
                        SwitchListTile(
                          title: const Text('Coincidencias'),
                          subtitle: const Text(
                            'Se aplicará cuando las coincidencias estén disponibles.',
                          ),
                          value: p.matches,
                          onChanged: enabled
                              ? (v) => _save(context, p.copyWith(matches: v))
                              : null,
                        ),
                      ],
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
