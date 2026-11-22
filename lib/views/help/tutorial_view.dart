import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_exception.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../../viewmodels/tutorial_viewmodel.dart';
import '../widgets/common.dart';

/// Vuelve a la navegación principal y señala los controles de la app real.
void startSectionTutorial(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  final tutorial = context.read<TutorialViewModel>();
  Navigator.of(context).popUntil((route) => route.isFirst);
  tutorial.start();
}

class TutorialInvitation extends StatelessWidget {
  const TutorialInvitation({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    if (!vm.ready || vm.preferences.tutorialVersion >= 1) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.explore_outlined),
              title: Text('Conoce Encuéntralo'),
              subtitle: Text(
                'Descubre las cinco secciones con una guía sobre la pantalla.',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => startSectionTutorial(context),
                  child: const Text('Ver tutorial'),
                ),
                TextButton(
                  onPressed: vm.saving
                      ? null
                      : () async {
                          try {
                            await vm.completeTutorial();
                          } catch (e) {
                            if (context.mounted) {
                              showSnack(
                                context,
                                userMessageFor(e),
                                error: true,
                              );
                            }
                          }
                        },
                  child: const Text('Ahora no'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
