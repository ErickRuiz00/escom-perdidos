# Identidad institucional de color

Implementación en `feature/login-redesign`, sin cambios en SQLite, repositorios
ni reglas de negocio. No se agregaron dependencias; se retiraron `rive`,
`rive_native` y sus dependencias exclusivas mediante `flutter pub get --offline`.

## Organización

- `lib/core/theme/app_colors.dart`: ColorScheme explícitos claros y oscuros con
  los colores solicitados. Azul ESCOM es Primary, guinda IPN es Secondary y
  cian radar es Tertiary. Define también fondos, superficies y bordes.
- `lib/core/theme/app_status_colors.dart`: ThemeExtension con pares de texto y
  fondo para Perdido, Visto, Encontrado y Entregado; interpola al cambiar de tema.
- `lib/core/theme/app_theme.dart`: construye AppTheme.light()/dark() y configura
  botones, FAB, navegación inferior/lateral, tarjetas, inputs, SearchBar, chips,
  segmentados, SnackBar, diálogos, hojas inferiores, divisores, iconos, progreso
  e indicadores de notificación. Las barras del sistema siguen el modo activo.
- `lib/app.dart`: registra ambos temas. Sin sesión sigue el sistema; con sesión
  conserva el interruptor Modo oscuro y la preferencia existente en Perfil.

## Pantallas y componentes

Bienvenida, login, registro, recuperación, splash, feed, mis reportes, detalle,
formulario, filtros y perfil consumen el mismo tema. Se eliminó AuthTheme y la
paleta fija de acceso. Los campos utilizan Surface Variant, Outline en reposo
y Primary al enfocar. El botón principal y FAB usan Primary/On Primary; las
acciones OutlinedButton usan el acento Secondary. Chips activos y navegación
usan Primary Container. Los placeholders de fotos usan Surface Variant.

`StatusBadge` y `TypeBadge` usan los pares semánticos completos, sin tintes
calculados a partir de porcentajes. Las tarjetas resueltas conservan contraste.
`LocationTag` y los chips de lugar usan Secondary Container/On Secondary
Container. La tarjeta de clima usa Primary Container/On Primary Container.

El modelo existente contiene tipos Perdido/Encontrado y estados Activo/Resuelto.
Se mantienen esos valores y etiquetas. Resuelto utiliza el estilo gris de
finalización; no se etiqueta falsamente como Entregado. Los estilos y el widget
para Visto/Entregado quedan disponibles sin inventar nuevos cambios de estado
ni modificar datos existentes.

## Splash y bienvenida

La splash conserva duración, circuito y navegación. Su contenedor ocupa todo
el ancho disponible desde el primer frame, evitando el desplazamiento a la
izquierda observado en el teléfono. El circuito usa Primary Container,
Tertiary y el verde semántico de Encontrado. Cambia de paleta con el tema.
El SVG reutilizable conserva la geometría y adopta los colores claros; el
painter utiliza los tokens activos para ambos modos.

La bienvenida ya no contiene globo, animación escolar, respaldo estático,
selectores de objetos ni créditos de Rive. Se eliminaron sus recursos,
herramientas y dependencia nativa. No se agregaron ilustraciones sustitutas.

## Archivos y verificación

Además del sistema de tema se actualizaron `lib/app.dart`, los componentes de
`lib/features/splash/presentation/`, `lib/views/auth/`, `feed_view.dart`, detalle
y formulario de reportes, y los widgets `common`, `report_card`, `filter_sheet`
y `weather_card`. `pubspec.yaml` y `pubspec.lock` reflejan la retirada de Rive.

`test/views/palette_test.dart` comprueba contraste de texto y estados en ambos
modos, centrado de logo/textos/barra durante la splash en 320/360/412 px y
render de tarjetas con ubicación y texto al 200 %. Las pruebas de acceso
comprueban el cambio de tema conservando ruta y texto, ausencia de animación
y los flujos existentes de sesión/login/registro/recuperación.

Resultado local: **51 pruebas aprobadas**, `flutter analyze --no-pub` sin
incidencias y `git diff --check` sin errores. Las pruebas de contraste verifican
una relación mínima de 4.5:1 para los pares de texto comprobados.

## Prueba Android

La versión se compiló, instaló y abrió en **SM A022M / R58R90LEHTT / Android 11
(API 30), armeabi-v7a**. Compilación: 86.5 s; instalación: 32.8 s. El proceso
permaneció activo y Android confirmó que la actividad estaba visible y dibujada.
La captura local comprobó los colores claros en un formulario de acceso; los
registros consultados no mostraron excepciones de Flutter ni RenderFlex.
El modo oscuro se comprobó mediante widgets; su revisión visual en el teléfono
queda disponible en Perfil → Modo oscuro o, sin sesión, con el modo del sistema.

El APK debug ocupa **88.6 MiB** y la inspección de su ZIP confirmó **cero archivos
o bibliotecas de Rive**. Se utilizaron las opciones temporales de memoria y
Jetifier documentadas en [android_build.md](android_build.md), sin cambiar la
configuración global de Windows, Java o Gradle ni modificar credenciales/datos
de prueba desde las herramientas.
