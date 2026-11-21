import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_exception.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../widgets/common.dart';

const _steps = [
  (
    Icons.search_rounded,
    'Explora y publica',
    'Busca por categoría y zona en Explorar. Si encontraste algo, usa Publicar y evita mostrar datos personales en la foto o descripción.',
    'Encontré un objeto. ¿Dónde empiezo?',
    'Publicar',
    'Mis búsquedas',
  ),
  (
    Icons.inventory_2_outlined,
    'Tus hallazgos, en un lugar',
    'Desde Perfil → Mis hallazgos puedes revisar tus publicaciones, corregir sus datos o retirarlas cuando corresponda.',
    '¿Dónde reviso lo que publiqué?',
    'Mis hallazgos',
    'Mis hazañas',
  ),
  (
    Icons.front_hand_outlined,
    'Creo que es mío',
    'En un hallazgo bajo custodia de un estudiante, toca «Creo que es mío» y describe características privadas. Solo tú y el encontrador pueden ver esa información.',
    '¿Qué información ayuda a verificar propiedad?',
    'Características privadas',
    'Datos bancarios',
  ),
  (
    Icons.chat_bubble_outline_rounded,
    'Solicitudes y chat',
    'Consulta las solicitudes recibidas y enviadas en Chats. Aceptar una solicitud abre un chat privado; la aceptación no demuestra propiedad. Acuerden los detalles de entrega por chat.',
    '¿Aceptar la solicitud confirma propiedad?',
    'Todavía hay que verificar',
    'Sí, automáticamente',
  ),
  (
    Icons.task_alt_rounded,
    'Confirma la devolución',
    'Después de la entrega real, el encontrador confirma que entregó y el solicitante que recibió. Solo ambas confirmaciones resuelven el hallazgo.',
    '¿Cuándo se confirma la devolución?',
    'Cuando ambas personas confirman',
    'Al enviar el primer mensaje',
  ),
  (
    Icons.account_balance_outlined,
    'Cuando está en Prefectura',
    'La publicación muestra una entrega declarada a Prefectura. Consulta presencialmente con el personal y lleva información para identificar el objeto. No hay chat ni confirmación digital en nombre de Prefectura. Verifica allí los horarios y procedimientos vigentes.',
    '¿Cómo consulto un objeto en Prefectura?',
    'De forma presencial',
    'En un chat con Prefectura',
  ),
];

class TutorialView extends StatefulWidget {
  const TutorialView({super.key});
  @override
  State<TutorialView> createState() => _TutorialViewState();
}

class _TutorialViewState extends State<TutorialView> {
  int _index = 0;
  bool? _correct;
  bool _saving = false;
  late final int _session;
  @override
  void initState() {
    super.initState();
    _session = context.read<NotificationsViewModel>().sessionRevision;
  }

  Future<void> _finish({bool omit = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final vm = context.read<NotificationsViewModel>();
      vm.assertSession(_session);
      await vm.completeTutorial();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          omit
              ? 'Puedes salir de la guía. No pudimos guardar que ya la consultaste.'
              : userMessageFor(e),
          error: true,
        );
        if (omit) Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _move(int index) {
    setState(() {
      _index = index;
      _correct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final (icon, title, description, question, right, wrong) = _steps[_index];
    final theme = Theme.of(context), colors = theme.colorScheme;
    final active =
        context.watch<NotificationsViewModel>().sessionRevision == _session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guía de Encuéntralo'),
        actions: [
          TextButton(
            onPressed: _saving || !active ? null : () => _finish(omit: true),
            child: const Text('Omitir'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: ValueKey(_index),
          padding: const EdgeInsets.all(24),
          children: [
            ConstrainedContent(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paso ${_index + 1} de ${_steps.length}',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (_index + 1) / _steps.length),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      icon,
                      size: 80,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(description),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(question, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          for (final correct
                              in _index.isEven ? [true, false] : [false, true])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton(
                                onPressed: active
                                    ? () => setState(() => _correct = correct)
                                    : null,
                                child: Text(correct ? right : wrong),
                              ),
                            ),
                          if (_correct != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _correct!
                                    ? 'Así es. Ya puedes continuar.'
                                    : 'Vuelve a leer la explicación y prueba otra opción.',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!active)
                    const Text('La sesión cambió. Abre la guía nuevamente.'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (_index > 0)
                        TextButton(
                          onPressed: _saving || !active
                              ? null
                              : () => _move(_index - 1),
                          child: const Text('Anterior'),
                        ),
                      FilledButton(
                        onPressed: _saving || !active
                            ? null
                            : () => _index == _steps.length - 1
                                  ? _finish()
                                  : _move(_index + 1),
                        child: Text(
                          _saving
                              ? 'Guardando…'
                              : _index == _steps.length - 1
                              ? 'Terminar'
                              : 'Siguiente',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Puedes volver a consultar esta guía desde Perfil o Centro de ayuda.',
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
                'Una guía breve para publicar, recuperar y devolver objetos.',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TutorialView(),
                    ),
                  ),
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
