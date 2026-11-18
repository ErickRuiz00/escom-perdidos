# Fase 2: pantalla principal y navegación

Trabajo en `feature/home-navigation`, creada desde `main` limpio después de
`git pull --ff-only`. No se hace push ni merge.

## Comportamiento

- Cinco destinos: Inicio, Explorar, Publicar, Chats y Perfil. `IndexedStack`
  conserva consulta, filtros, desplazamiento y selección de Chats. Las secciones
  ocultas suspenden sus animaciones. Atrás desde otra pestaña vuelve a Inicio.
  En pantallas anchas se reutiliza la navegación lateral Material.
- Inicio muestra el nombre del perfil autenticado, el circuito del logotipo
  existente, una entrada breve que respeta movimiento reducido, búsqueda,
  acceso al formulario de hallazgos y centro de notificaciones.
- Explorar reutiliza categorías, zonas, ordenamiento y la hoja de filtros del
  proyecto. La consulta escrita en Inicio pasa a Explorar al buscar.
- Publicar conserva el formulario y su validación, foto opcional, fecha y zona.
  Solo permite objetos encontrados. Antes de guardar informa que el registro
  queda únicamente en el dispositivo; el botón y la confirmación lo reiteran.
- Las tarjetas reutilizan la imagen con alternativa por categoría y la etiqueta
  de zona. Incluyen nombre, categoría y custodia: Alumno o Prefectura. Los registros
  antiguos sin este dato muestran «Custodia sin especificar».
- Perfil muestra nombre y correo de la sesión, edición de datos y avatar,
  Mis hallazgos, Mis búsquedas, Mis hazañas, Configuración y cierre de sesión.
  Configuración conserva modo oscuro y cambio de contraseña.
- Chats tiene Solicitudes y Conversaciones con estados preparatorios explícitos.
  Notificaciones, Mis búsquedas y Mis hazañas también indican su disponibilidad
  futura. No se simulan conversaciones, avisos, logros ni contadores de actividad.

## Separación de datos

`ReportsViewModel.communityFound` permanece vacío intencionalmente: todavía no
hay una fuente de publicaciones públicas. Inicio y Explorar usan únicamente ese
catálogo; no muestran los registros locales ni los datos de ejemplo heredados.
Tampoco se insertan muestras al iniciar la app. Se conserva `SeedData` para las
pruebas antiguas, sin borrar muestras ya existentes en dispositivos.

Mis hallazgos filtra los registros de SQLite por el UUID de la sesión y por
objetos encontrados. Guardar un hallazgo no publica, busca coincidencias, envía
notificaciones ni programa recordatorios.

SQLite se conserva y pasa de versión 1 a 2 para agregar la columna local nullable
`reports.custody`. La actualización añade la columna sin eliminar datos. Los
usuarios y reportes anteriores permanecen intactos. No se modifica ningún archivo
SQL, tabla ni política de Supabase. La autenticación, sus enlaces y la splash
animada conservan su implementación.

## Archivos

Nuevos:

- `lib/views/home/explore_view.dart`: interfaz de consulta y filtros.
- `lib/views/home/community_views.dart`: resultados públicos vacíos, Publicar,
  Chats y pantallas de funciones pendientes.
- `lib/views/widgets/local_only_notice.dart`: aviso reutilizable de guardado local.
- `test/views/home_navigation_test.dart`: navegación, formulario, aislamiento de
  muestras, cierre de sesión, accesibilidad y configuración.
- `test/data/home_reports_test.dart`: persistencia de custodia, ausencia de avisos,
  rechazo de objetos perdidos y actualización de SQLite.
- `docs/home_navigation.md`: alcance y verificación de esta fase.

Modificados:

- `lib/views/home/home_shell.dart`, `feed_view.dart` y `my_reports_view.dart`.
- `lib/views/profile/profile_view.dart`.
- `lib/views/reports/report_form_view.dart` y `report_detail_view.dart`.
- `lib/views/widgets/report_card.dart`.
- `lib/viewmodels/report_form_viewmodel.dart` y `reports_viewmodel.dart`.
- `lib/core/constants/escom.dart`, `lib/data/models/report.dart`,
  `lib/data/local/app_database.dart` y `lib/main.dart`.
- `README.md`: enlace a esta guía.

## Pendiente por diseño

Sincronización y almacenamiento remoto de hallazgos e imágenes, búsquedas
privadas persistentes, solicitudes, conversaciones, validación de entregas,
hazañas, alertas, recompensas y notificaciones push. Esta fase solo prepara
sus accesos; no cambia permisos ni promete que los registros locales sean
visibles para la comunidad.

## Verificación

Se utiliza Flutter 3.32.8 / Dart 3.8.1, la misma versión documentada en la fase 1.

```powershell
$flutter32 = '.\.dart_tool\flutter-3.32.8\bin\flutter.bat'
& $flutter32 pub get
& $flutter32 analyze
& $flutter32 test --no-pub --concurrency=1
& $flutter32 run -d R58R90LEHTT --no-pub --dart-define-from-file=config/supabase.local.json
```

Las pruebas de autenticación usan el SDK real de Supabase con HTTP controlado;
no sustituyen un login manual contra el servidor. Las de interfaz usan dobles
de repositorios y verifican pantallas de 320 × 640 y 840 × 500, ambos temas y
texto al 200 %. Las de persistencia usan SQLite real en archivos temporales
y memoria, sin tocar los datos del teléfono.

El 18 de noviembre de 2026, `flutter pub get` terminó correctamente, el análisis
final terminó sin incidencias y la suite completa final pasó: **81 pruebas**.
Se detectó y corrigió un desbordamiento en el estado vacío de Mis hallazgos al
200 % de texto; su prueba y la de Configuración también forman parte de la suite.
`git diff --check` no encontró errores de espacios. No hay cambios en Supabase,
las pantallas o repositorio de autenticación ni la implementación de la splash.

Windows agotó memoria/paginación en algunos intentos de pruebas. Se consultó el
estado de los daemons Gradle y se detuvieron los identificados como inactivos;
se preservaron los procesos ocupados y los IDE. No se cambió la configuración
global de Java ni de memoria. La compilación Android usa los mismos límites
temporales de proceso documentados en la fase 1.

### Android conectado

El mismo 18 de noviembre se compiló, instaló y abrió el APK nuevo en el Samsung
SM A022M (`R58R90LEHTT`), Android 11 / API 30, con la configuración local real.
`assembleDebug` terminó en 85.2 segundos y la instalación en 20.7 segundos.
Se revisaron visualmente Inicio, Explorar, Publicar, Chats y Mis búsquedas en el
teléfono. Inicio mostró el nombre de la cuenta real, el logo y los cinco destinos;
Explorar mostró el catálogo vacío, sin los reportes de muestra antiguos.

Una consulta de solo lectura al depurador confirmó `authenticated`, usuario
presente, sin error ni aviso de autenticación y sin operación pendiente. No se
leyeron correos, contraseñas ni tokens con el depurador. Esto comprueba la
restauración de la sesión real al abrir la versión nueva; **no se repitió un login
manual con correo y contraseña** en esta fase. Ese nuevo login queda como
comprobación manual adicional, además de las pruebas automatizadas aprobadas.

El dispositivo volvió a usar OpenGLES por su controlador Vulkan y el plugin de
almacenamiento seguro registró el mismo aviso de descifrado heredado observado
en la fase 1, antes de continuar con su alternativa de cifrado. La sesión se
restauró; no se borraron datos para resolver estos avisos. Hubo frames omitidos
durante el arranque en debug; no se ha medido rendimiento en release.

Las capturas de revisión permanecen en `.dart_tool/*-navigation-android.png`,
excluidas de Git. No se crearon publicaciones ni mensajes en el teléfono durante
la comprobación automatizada de navegación.
