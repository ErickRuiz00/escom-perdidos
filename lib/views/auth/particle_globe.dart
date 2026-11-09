import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'auth_theme.dart';

const _schoolObjects = [
  (label: 'Lápiz', icon: Icons.edit_rounded),
  (label: 'Cuaderno', icon: Icons.menu_book_rounded),
  (label: 'Laptop', icon: Icons.laptop_mac_rounded),
  (label: 'Mochila', icon: Icons.backpack_outlined),
  (label: 'Audífonos', icon: Icons.headphones_rounded),
  (label: 'Llaves', icon: Icons.key_rounded),
  (label: 'Botella', icon: Icons.water_drop_outlined),
];

/// Un solo archivo/controlador por montaje. La carga nunca bloquea el acceso.
class ParticleGlobe extends StatefulWidget {
  const ParticleGlobe({super.key});

  @override
  State<ParticleGlobe> createState() => _ParticleGlobeState();
}

class _ParticleGlobeState extends State<ParticleGlobe>
    with WidgetsBindingObserver {
  rive.File? _file;
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _viewModel;
  rive.ViewModelInstanceNumber? _iconInput;
  int _selectedObject = 2;
  Timer? _timeout;
  bool _finished = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _timeout = Timer(const Duration(seconds: 8), () {
      if (mounted && !_finished) setState(() => _finished = true);
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    rive.File? file;
    rive.RiveWidgetController? controller;
    rive.ViewModelInstance? viewModel;
    rive.ViewModelInstanceNumber? iconInput;
    try {
      // API instalada: rive 0.14.11 / rive_native 0.1.11.
      // File.asset inicializa el runtime nativo, incluido scripting Luau.
      file = await rive.File.asset(
        'assets/animations/particle_globe.riv',
        riveFactory: rive.Factory.rive,
      );
      if (!mounted || _finished) {
        file?.dispose();
        return;
      }
      if (file == null) throw StateError('No se pudo decodificar el globo.');
      controller = rive.RiveWidgetController(file);
      // El recurso publica un ViewModel: se enlaza su instancia exportada
      // sin depender de nombres internos que podrían cambiar en el editor.
      if (file.defaultArtboardViewModel(controller.artboard) != null) {
        viewModel = controller.dataBind(rive.DataBind.auto());
        iconInput = viewModel.number('changeIcon');
        // El archivo conserva su contrato: icon1…icon7, valores 1…7.
        iconInput?.value = (_selectedObject + 1).toDouble();
      }
      controller.active = _foreground && TickerMode.of(context);
      _timeout?.cancel();
      setState(() {
        _file = file;
        _controller = controller;
        _viewModel = viewModel;
        _iconInput = iconInput;
        _finished = true;
      });
    } catch (error) {
      controller?.dispose();
      iconInput?.dispose();
      viewModel?.dispose();
      file?.dispose();
      _timeout?.cancel();
      debugPrint('Interactive Particle Globe no disponible: $error');
      if (mounted) setState(() => _finished = true);
    }
  }

  void _selectObject(int index) {
    setState(() => _selectedObject = index);
    _iconInput?.value = (index + 1).toDouble();
    _controller?.scheduleRepaint();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePlayback();
  }

  void _updatePlayback() {
    final controller = _controller;
    if (controller == null) return;
    final active = _foreground && TickerMode.of(context);
    if (controller.active != active) controller.active = active;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _controller?.dispose();
    _iconInput?.dispose();
    _viewModel?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Semantics(
            image: true,
            label:
                'Globo de objetos escolares. ${_schoolObjects[_selectedObject].label}',
            hint: 'Desliza para girar. Toca para cambiar el objeto.',
            onTap: () =>
                _selectObject((_selectedObject + 1) % _schoolObjects.length),
            child: ExcludeSemantics(
              child: GestureDetector(
                key: const Key('school-object-globe'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectObject(
                  (_selectedObject + 1) % _schoolObjects.length,
                ),
                // El arrastre pertenece al globo, no al scroll de la bienvenida.
                onPanStart: (_) {},
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_controller == null)
                        GlobeFallback(itemIndex: _selectedObject)
                      else
                        rive.RiveWidget(
                          controller: _controller!,
                          fit: rive.Fit.contain,
                          // Limita el coste del render en teléfonos de alta densidad.
                          renderResolution: const rive.RenderResolution.fixed(
                            900,
                            900,
                          ),
                        ),
                      if (!_finished)
                        const Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Text(
                            'Preparando tu mundo…',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFC4B4BF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          'Desliza para girar · toca para cambiar',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (var index = 0; index < 3; index++)
              ChoiceChip(
                label: Text(_schoolObjects[index].label),
                avatar: Icon(_schoolObjects[index].icon, size: 17),
                selected: _selectedObject == index,
                showCheckmark: false,
                onSelected: (_) => _selectObject(index),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                selectedColor: const Color(0xFF573149),
                backgroundColor: const Color(0xFF241B25),
                labelStyle: TextStyle(color: colors.onSurface, fontSize: 12),
                side: BorderSide(
                  color: _selectedObject == index
                      ? AuthTheme.accent
                      : const Color(0xFF51404E),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Ilustración original, estática y sin recursos externos. También se utiliza
/// con movimiento reducido, evitando cargar el runtime en ese caso.
class GlobeFallback extends StatelessWidget {
  const GlobeFallback({super.key, this.itemIndex = 0});

  final int itemIndex;

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(painter: _GlobePainter(itemIndex)));
}

class _GlobePainter extends CustomPainter {
  const _GlobePainter(this.itemIndex);

  final int itemIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.37;
    final bounds = Rect.fromCircle(center: center, radius: radius * 1.3);
    canvas.drawCircle(
      center,
      radius * 1.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AuthTheme.accent.withValues(alpha: 0.12),
            AuthTheme.accent.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
    // Distribución de Fibonacci: puntos uniformes sobre una esfera, con
    // perspectiva y profundidad. No requiere tickers ni imágenes remotas.
    final paint = Paint();
    const count = 180;
    for (var i = 0; i < count; i++) {
      final y = 1 - 2 * i / (count - 1);
      final ring = math.sqrt(1 - y * y);
      final angle = i * math.pi * (3 - math.sqrt(5));
      final x = math.cos(angle) * ring;
      final z = math.sin(angle) * ring;
      final depth = (z + 1) / 2;
      paint.color = Color.lerp(
        const Color(0xFF71435E),
        const Color(0xFFF7DBE9),
        depth,
      )!.withValues(alpha: 0.3 + depth * 0.7);
      canvas.drawCircle(
        center + Offset(x * radius, y * radius),
        0.7 + depth * 1.5,
        paint,
      );
    }
    final glyph = _schoolObjects[itemIndex].icon;
    for (var i = 0; i < 28; i++) {
      final y = 1 - 2 * i / 27;
      final ring = math.sqrt(1 - y * y);
      final angle = i * math.pi * (3 - math.sqrt(5));
      final z = math.sin(angle) * ring;
      if (z < -0.2) continue;
      final depth = (z + 1) / 2;
      final text = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(glyph.codePoint),
          style: TextStyle(
            fontFamily: glyph.fontFamily,
            package: glyph.fontPackage,
            fontSize: 12 + depth * 12,
            color: AuthTheme.accent.withValues(alpha: 0.5 + depth * 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        center +
            Offset(math.cos(angle) * ring * radius, y * radius) -
            Offset(text.width / 2, text.height / 2),
      );
      text.dispose();
    }
    final orbit = Paint()
      ..color = AuthTheme.accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.65,
        height: radius * 0.85,
      ),
      orbit,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) =>
      itemIndex != oldDelegate.itemIndex;
}
