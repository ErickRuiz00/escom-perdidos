# Apertura de Encuéntralo ESCOM

Implementada en `feature/login-redesign`. La primera pantalla de Flutter muestra
el circuito con forma de E, el nombre de la app, el subtítulo institucional,
una barra decorativa y el pie de comunidad. Ahora utiliza los colores claros
u oscuros del [tema institucional](theme_palette.md).

## Archivos

- `assets/logo/encuentralo_escom_logo.svg`: geometría del SVG proporcionado con
  la nueva paleta clara, reutilizable y registrado en `pubspec.yaml`.
- `lib/features/splash/presentation/splash_screen.dart`: composición responsive,
  accesibilidad y controlador de apertura de 2700 ms.
- `lib/features/splash/presentation/animated_circuit_logo.dart`: representación
  vectorial nativa de la geometría del SVG, colores del tema y señal animada.
- `lib/features/splash/presentation/splash_progress_bar.dart`: barra decorativa.
- `lib/views/splash_view.dart`: entrada compatible con la estructura existente.
- `lib/views/auth/auth_flow.dart`: espera de la apertura y de la restauración de
  sesión antes de mostrar el destino que corresponde.
- `test/views/auth_flow_test.dart`: siete pruebas nuevas de apertura y ajuste de
  la espera inicial en las pruebas existentes de autenticación.

## Animación y dependencias

No se agregaron dependencias. Se utilizan `AnimationController`, intervalos,
`FadeTransition`, `ScaleTransition` y `CustomPainter`. El SVG se conserva como
asset; la splash dibuja sus vectores directamente con Canvas para animar los
tramos y nodos individualmente sin necesitar un renderizador SVG adicional.
Si cambia el diseño del SVG, actualizar también la geometría del painter.

El logo aparece con fade y escala durante los primeros 432 ms. La señal recorre
el circuito entre los 270 y 1863 ms: tramo superior, ramal central y tramo
inferior. Los nodos se iluminan al paso y el nodo verde final emite un pulso.
Después aparecen el título y subtítulo y se llena la barra. El controlador
avisa al terminar los 2700 ms y se libera al desmontar la pantalla.

La barra representa la secuencia visual de apertura, no una descarga ni el
avance de la validación de sesión. Con movimiento reducido, el logo y los
textos aparecen completos y estáticos, conservando la espera de apertura.
Se respeta SafeArea y el escalado de texto; en alturas pequeñas el contenido
se puede desplazar sin desbordarse.
El contenedor ocupa todo el ancho disponible desde el primer frame, corrigiendo
el desplazamiento a la izquierda observado en el SM A022M.

## Navegación

`main.dart` conserva su inicialización. `MaterialApp.home` sigue siendo
`AuthGate`; no se agregan rutas ni se apila la splash en el Navigator.

La restauración de sesión transcurre en paralelo con la presentación. Si termina
antes, se espera a completar la splash. Si tarda más, se conserva la pantalla
estática hasta conocer el estado de sesión, sin mostrar formularios o contenido
privado prematuramente. Por ello, una restauración lenta puede prolongar la
apertura más allá de 2.7 segundos.

Sin sesión se muestra la bienvenida existente, desde donde se abre el login.
Con sesión válida se muestra `HomeShell`. La splash no reaparece al cerrar
sesión y Atrás no permite regresar a ella. Se conservan login, registro,
recuperación y descarte de la pila de autenticación.

## Verificación local

Con el SDK actualmente resuelto por `.dart_tool/package_config.json`
(Flutter 3.47.2 / Dart 3.13.2):

```powershell
& 'C:\Users\migue\flutter\bin\flutter.bat' test --no-pub --concurrency=1
& 'C:\Users\migue\flutter\bin\flutter.bat' analyze --no-pub lib\features\splash lib\views\splash_view.dart lib\views\auth\auth_flow.dart test\views\auth_flow_test.dart
```

Las pruebas cubren duración, restauración rápida y lenta, sesión válida, logout
sin repetir la splash, orden del circuito y barra, pantalla de 320 × 480,
texto al 200 %, movimiento reducido y liberación del controlador. También se
verifican los flujos anteriores de acceso.

Resultado actual: **51 pruebas aprobadas** y **análisis global sin incidencias**.
Incluye contraste y centrado en ambos modos, con anchos de 320/360/412 px.
Formato verificado y `git diff --check` sin errores. Se retiró el antiguo
ParticleGlobe y se actualizaron los dropdowns del formulario de reportes.
La comprobación en Android y sus ajustes de compilación se documentan en
[theme_palette.md](theme_palette.md).
