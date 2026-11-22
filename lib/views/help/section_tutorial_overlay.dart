import 'dart:math' as math;
import 'package:flutter/material.dart';

const _sections = [
  (
    Icons.home_rounded,
    'Inicio',
    'Aquí tienes un vistazo de los hallazgos. Usa la búsqueda para explorar y la campana para consultar tus notificaciones.',
  ),
  (
    Icons.search_rounded,
    'Explorar',
    'Busca por nombre, categoría o zona. Abre un hallazgo y toca «Creo que es mío» para enviar características privadas. Si está en Prefectura, consulta presencialmente.',
  ),
  (
    Icons.add_box_rounded,
    'Publicar',
    '¿Encontraste algo? Toca «Preparar hallazgo» para añadir descripción, foto, zona y quién lo resguarda. Evita mostrar datos personales.',
  ),
  (
    Icons.chat_bubble_rounded,
    'Chats',
    'Revisa las solicitudes recibidas y enviadas. Al aceptar se abre un chat privado. Coordina la entrega y confirma la devolución: se necesitan ambas confirmaciones.',
  ),
  (
    Icons.person_rounded,
    'Perfil',
    'En «Mis hallazgos» puedes revisar y editar tus publicaciones. Aquí también están tus preferencias, el centro de ayuda y el acceso para repetir esta guía.',
  ),
];

/// Capa modal sobre la navegación real: deja libre solo la sección señalada.
class SectionTutorialOverlay extends StatelessWidget {
  const SectionTutorialOverlay({
    super.key,
    required this.step,
    required this.target,
    required this.wide,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });
  final int step;
  final Rect? target;
  final bool wide;
  final VoidCallback onNext, onPrevious, onSkip;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    return BlockSemantics(
      child: FocusScope(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final padding = MediaQuery.paddingOf(context);
            final rect =
                target ??
                Rect.fromLTWH(
                  16,
                  size.height - padding.bottom - 80,
                  size.width / 5,
                  72,
                );
            final cardLeft = wide ? math.max(16.0, rect.right + 48) : 16.0;
            final cardBottom = wide
                ? padding.bottom + 16
                : math.max(padding.bottom + 16, size.height - rect.top + 48);
            final maxHeight = math.max(
              80.0,
              size.height - padding.top - 16 - cardBottom,
            );
            final cardWidth = math.min(
              460.0,
              math.max(0.0, size.width - cardLeft - 16),
            );
            final cardX = wide ? cardLeft : (size.width - cardWidth) / 2;
            final (icon, title, description) = _sections[step];
            return Stack(
              key: const Key('section-tutorial-overlay'),
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: TweenAnimationBuilder<Rect?>(
                      tween: RectTween(begin: rect, end: rect),
                      duration: duration,
                      builder: (_, highlight, __) =>
                          CustomPaint(painter: _SpotlightPainter(highlight!)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const Key('tutorial-arrow'),
                      painter: _ArrowPainter(
                        start: wide
                            ? Offset(
                                cardX - 6,
                                (size.height + padding.top - padding.bottom) /
                                    2,
                              )
                            : Offset(
                                rect.center.dx.clamp(
                                  cardX + 24,
                                  cardX + cardWidth - 24,
                                ),
                                rect.top - 42,
                              ),
                        end: wide
                            ? Offset(rect.right + 8, rect.center.dy)
                            : Offset(rect.center.dx, rect.top - 8),
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: Semantics(
                    button: true,
                    label:
                        'Sección $title. ${step == 4 ? 'Terminar guía' : 'Continuar recorrido'}',
                    child: GestureDetector(
                      key: const Key('tutorial-spotlight'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onNext,
                    ),
                  ),
                ),
                Positioned(
                  left: cardX,
                  width: cardWidth,
                  top: wide ? padding.top + 16 : null,
                  bottom: cardBottom,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 16,
                        borderRadius: BorderRadius.circular(28),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          key: ValueKey('tutorial-card-$step'),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'TU RECORRIDO\n${step + 1} de 5',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Omitir tutorial',
                                    onPressed: onSkip,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                header: true,
                                child: Text(
                                  title,
                                  key: const Key('tutorial-section-title'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(description),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  for (var i = 0; i < 5; i++)
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration: duration,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: i <= step
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: onSkip,
                                    child: const Text('Omitir'),
                                  ),
                                  if (step > 0)
                                    TextButton(
                                      onPressed: onPrevious,
                                      child: const Text('Anterior'),
                                    ),
                                  FilledButton(
                                    onPressed: onNext,
                                    child: Text(
                                      step == 4 ? 'Terminar' : 'Siguiente',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.target);
  final Rect target;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(target, const Radius.circular(18));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.76),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.start, required this.end});
  final Offset start, end;
  @override
  void paint(Canvas canvas, Size size) {
    final bend = Offset(start.dx, end.dy);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(bend.dx, bend.dy, end.dx, end.dy);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
    final tangent = end - (bend == end ? start : bend);
    final angle = math.atan2(tangent.dy, tangent.dx);
    final head = Path()
      ..moveTo(
        end.dx - 9 * math.cos(angle - 0.55),
        end.dy - 9 * math.sin(angle - 0.55),
      )
      ..lineTo(end.dx, end.dy)
      ..lineTo(
        end.dx - 9 * math.cos(angle + 0.55),
        end.dy - 9 * math.sin(angle + 0.55),
      );
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}
