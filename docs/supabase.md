# Supabase: autenticación y perfiles

Esta fase sustituye únicamente la autenticación local. La aplicación usa
`supabase_flutter: 2.9.1` detrás del mismo repositorio y ViewModel.

## Configuración pública local

`config/supabase.local.json` está excluido mediante `.gitignore` y no se publica.
En una copia nueva del repositorio, copia `config/supabase.example.json` a ese
nombre y completa tus valores. Edita solamente el archivo local:

```json
{
  "SUPABASE_URL": "https://TU_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_TU_CLAVE_PUBLICA"
}
```

Obtén ambos valores del proyecto **encuentralo-escom-dev** en Connect / Project
Settings → API Keys. La URL es la Project URL, no la URL del Dashboard.
Usa exclusivamente la Publishable Key `sb_publishable_…`. El argumento del SDK
2.9.1 todavía se llama `anonKey`; recibe esa clave pública.
Nunca copies Secret Keys `sb_secret_…`, `service_role` ni contraseñas de Postgres.
Los valores de `dart-define` se incorporan al binario y son públicos.

Sin configuración válida, la splash termina normalmente y el acceso muestra un
error que indica el archivo y el comando necesarios. No hay autenticación local
alternativa. Cambiar el JSON requiere detener y volver a ejecutar la aplicación.

## Supabase Dashboard: plan Free y enlaces estándar

Para proyectos Free creados desde el **3 de junio de 2026**, las plantillas del
SMTP predeterminado no se pueden editar. La implementación anterior necesitaba
agregar `{{ .Token }}` a esas plantillas y, por tanto, no era compatible con este
proyecto. Ahora el modo predeterminado usa los enlaces estándar de confirmación
y recuperación; no requiere contratar servicios ni cambiar las plantillas.

1. En **Authentication → Sign In / Providers → Email**, habilita Email,
   **Allow new users to sign up** y **Confirm email**. Mantén deshabilitado el
   acceso anónimo. No configures restricciones a dominios IPN.
2. En **Authentication → URL Configuration → Redirect URLs**, agrega exactamente:

   ```text
   mx.ipn.escom.encuentralo://auth/confirm
   mx.ipn.escom.encuentralo://auth/recovery
   ```

   La app pasa la primera URL en registro/reenvío y la segunda al solicitar
   recuperación. Conserva un Site URL válido como respaldo; estas solicitudes
   usan las URLs explícitas anteriores. No uses comodines amplios.
3. Conserva las plantillas predeterminadas **Confirm signup** y **Reset password**.
   No necesitas personalizarlas. En `config/supabase.local.json`, omite
   `SUPABASE_EMAIL_OTP_ENABLED` o déjalo en `false`.
4. Configura una contraseña mínima de 8 caracteres con letras y números.
   Supabase puede imponer reglas adicionales si las habilitas en el Dashboard.
5. Para las pruebas sin SMTP propio, usa el correo autorizado de un miembro real
   del equipo del proyecto. No concedas acceso al equipo a usuarios finales
   únicamente para enviarles correos.

### Qué ocurre al abrir un enlace

- Registro: la app muestra instrucciones para abrir el enlace, reenvío y regreso
  a login. El correo se confirma en el endpoint de Supabase antes de redirigir.
  El callback vuelve a la app en Android/iOS; el SDK consulta al servidor para
  validar el token. Después se solicita **correo y contraseña** para entrar.
  Recibir un callback por sí solo nunca abre Home ni confirma una devolución.
- Los enlaces nuevos usan PKCE: el código de redirección se intercambia con el
  verificador secreto guardado en Keystore/Keychain del celular solicitante.
  Abre el enlace en ese mismo celular. Si falta el verificador (por ejemplo,
  reinstalaste la app), pide un enlace nuevo; si el correo ya quedó confirmado,
  puedes iniciar sesión normalmente con tu contraseña.
- Si confirmas desde otro dispositivo, regresa manualmente al login del celular
  e inicia sesión con tu contraseña después de confirmar.
- Recuperación: solicita el enlace y ábrelo en el celular con la app instalada.
  El SDK valida la sesión contra Supabase y muestra **Nueva contraseña**, con
  confirmación y validación. La sesión de recuperación vive solo en memoria,
  separada de la sesión normal; nunca se persiste ni abre Home. Al guardar o
  cancelar se revoca y descarta. Tras guardar debes iniciar sesión normalmente.
- Se reciben enlaces tanto con la app abierta como al iniciarla desde el correo,
  respetando la splash. Los enlaces inválidos, vencidos o de otra operación
  muestran un error y requieren solicitar un enlace nuevo.
- Se registró el esquema móvil en Android e iOS y se desactivaron los manejadores
  automáticos de Flutter/Supabase para procesar cada enlace por una sola vía.
  Abrir enlaces externos en Windows/web no se configura en esta fase.
- No compartas enlaces ni registres sus tokens en logs. Si cierras la app durante
  la recuperación, solicita otro enlace: la sesión temporal no se restaura.
- Ningún OTP de Auth es el futuro **código de seis dígitos para confirmar la
  devolución de un objeto**. Ese mecanismo de devoluciones no se implementa,
  genera ni valida en esta fase.

### Límites del correo predeterminado

Según la documentación consultada, solo envía a direcciones autorizadas del
equipo, tiene un límite de **2 mensajes por hora** que puede cambiar y no ofrece
garantías de entrega/disponibilidad. La app admite cualquier dominio de correo;
el proveedor predeterminado impide entregar a destinatarios externos. No se ha
desactivado Confirm email ni contratado ningún servicio para eludir estos límites.

Para pruebas amplias o usuarios externos habrá que configurar SMTP propio en
el futuro. No basta cambiar la interfaz de la app ni subir de plan para asumir
que el servicio SMTP predeterminado ya permite cualquier destinatario.

Fuentes oficiales:
[restricción de plantillas desde junio de 2026](https://github.com/orgs/supabase/discussions/46599),
[límites del SMTP predeterminado](https://supabase.com/docs/guides/auth/auth-smtp),
[enlaces móviles](https://supabase.com/docs/guides/auth/native-mobile-deep-linking).

### SMTP personalizado y OTP opcionales, para después

Con SMTP propio puedes conservar los enlaces estándar sin cambios en el código.
Si posteriormente decides usar OTP de autenticación, configura **Confirm signup**
y **Reset password** para mostrar `{{ .Token }}`, usa códigos de seis dígitos y
agrega `"SUPABASE_EMAIL_OTP_ENABLED": true` al JSON local antes de recompilar.

Solo ese modo optativo muestra campos de código y usa `verifyOTP`; está
deshabilitado por defecto. Las credenciales SMTP permanecen exclusivamente en el
Dashboard. La URL y Publishable Key de la app siguen siendo las mismas.

## Migración SQL manual

No se ha conectado el repositorio a tu cuenta de Supabase ni ejecutado SQL remoto.

1. Abre **SQL Editor** en `encuentralo-escom-dev`.
2. Comprueba que no existan `public.profiles` ni los objetos `encuentralo_*` de esta
   migración. Si ya existen, revisa su esquema antes de ejecutar cualquier cambio.
3. Ejecuta completo, una sola vez,
   [`202611170001_create_profiles.sql`](../supabase/migrations/202611170001_create_profiles.sql).
   Se ejecuta en una transacción: crea la tabla, índices implícitos del UUID,
   políticas, permisos y triggers. No elimina tablas ni modifica publicaciones.
4. Ejecuta [`verify_profiles.sql`](../supabase/verify_profiles.sql).
   Espera `relrowsecurity = true`, dos políticas (SELECT/UPDATE propios), ningún
   permiso para `anon`, SELECT para `authenticated` y UPDATE únicamente de
   nombre, boleta, teléfono y preferencias. `users_without_profile` debe ser 0.
5. Crea una cuenta desde la app. En **Authentication → Users** verifica el usuario
   y su confirmación. En **Table Editor → profiles** debe existir una fila con
   exactamente el mismo UUID.

`profiles.id` referencia `auth.users.id`. El trigger crea los perfiles; el cliente
no puede insertar ni borrar filas, ni cambiar UUID o fechas. Nombre, boleta y
teléfono son privados. Correo y contraseñas permanecen en Supabase Auth.
La boleta es opcional y no acredita afiliación al IPN. No se guarda ninguna
bandera de verificación institucional que el usuario pueda modificar.
La migración también crea perfiles para usuarios que ya existan en Supabase Auth,
sin leer ni importar las credenciales locales.

### Comprobar RLS con dos cuentas

El SQL Editor como `postgres` omite RLS. Para probarla de verdad, registra dos
cuentas A/B y sustituye los UUID antes de ejecutar:

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'UUID_DE_A', true);
-- Debe devolver únicamente A.
select id, name from public.profiles;
-- Debe afectar 0 filas. La transacción se revierte al final.
update public.profiles set phone = phone
where id = 'UUID_DE_B' returning id;
rollback;
```

Repite intercambiando A/B. En una consulta separada, prueba:

```sql
begin;
set local role anon;
select * from public.profiles;
rollback;
```

Debe fallar con `permission denied`; si la ejecución se interrumpe antes del
`rollback`, ejecútalo por separado. Con el rol `authenticated`, un INSERT, DELETE
o UPDATE de `id`/`created_at` también debe ser rechazado por permisos.
Referencia: [RLS de Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Sesiones y compatibilidad con SQLite

- Supabase administra las contraseñas, tokens, renovación y cierre de la sesión
  de este dispositivo. La sesión del SDK se persiste con
  `flutter_secure_storage`, separada por proyecto. Al arrancar, se consulta el
  usuario al servidor y se carga su perfil antes de abrir Home.
- Un error de restauración deja el acceso cerrado y muestra un mensaje; no se
  inventa una sesión offline. Un perfil ausente o sin permisos tampoco abre Home.
- La pila de pantallas privadas pertenece a la sesión y desaparece al cerrarla.
  La splash animada no se modifica ni se vuelve a reproducir al cerrar sesión.
- SQLite sigue almacenando `reports`, `weather_cache`, datos de ejemplo y `users`
  para sus claves foráneas y nombres de autor. Al autenticar se guarda una copia
  mínima del perfil bajo el UUID remoto, sin contraseña, hash, sal ni token.
- La columna `email` del registro de compatibilidad usa una dirección interna
  `UUID@supabase.local.invalid`, necesaria por la unicidad del esquema local.
  El correo mostrado en la app siempre procede de Supabase Auth. Así una cuenta
  local con el mismo correo conserva su UUID y sus publicaciones; no se asume que
  pertenece a la nueva cuenta remota ni se reasignan publicaciones.
- Los hashes y cuentas locales anteriores permanecen intactos. Ya no sirven para
  entrar; esas personas deben registrarse en Supabase o recuperar su cuenta si
  ya existía allí. Los tokens locales anteriores se descartan al restaurar.
- Editar nombre, boleta, teléfono y preferencias actualiza el perfil privado en
  Supabase. Las rutas de avatares siguen siendo locales al dispositivo; no se
  suben como URLs. No se migra almacenamiento de imágenes en esta fase.
- Publicaciones, chats, mascotas y recompensas no se convierten a Supabase.

## Ejecutar en un celular

Activa depuración USB, conecta y autoriza tu Android. Desde la raíz:

En la última comprobación ADB detectó el Samsung `R58R90LEHTT` autorizado y se
ejecutó la app. Si aparece `unauthorized`, desbloquéalo y acepta **Permitir
depuración USB**. Debe aparecer como `device` antes de instalar o ejecutar.

Usa Flutter **3.32.8** para reproducir la resolución de dependencias de esta fase.
Si `flutter --version` muestra otra versión, usa una instalación de 3.32.8 o la
copia aislada preparada en este equipo:

```powershell
$flutter32 = '.\.dart_tool\flutter-3.32.8\bin\flutter.bat'
& $flutter32 --version
& $flutter32 pub get
& $flutter32 analyze
& $flutter32 test --concurrency=1
& $flutter32 devices
& $flutter32 run -d ID_DEL_CELULAR --dart-define-from-file=config/supabase.local.json
```

Si Flutter 3.32.8 ya está en tu PATH, los comandos equivalentes son:

```powershell
flutter --version
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter devices
flutter run -d ID_DEL_CELULAR --dart-define-from-file=config/supabase.local.json
```

Para construir un APK de prueba:

```powershell
flutter build apk --debug --dart-define-from-file=config/supabase.local.json
```

Prueba manualmente registro con un correo autorizado del equipo (puede ser ajeno
al IPN), intento de login antes de confirmar, enlace inválido/vencido,
confirmación, login, cierre y reapertura de
la app, edición de perfil, tema claro/oscuro, cierre de sesión, recuperación por
correo e ingreso con la nueva contraseña. La contraseña anterior debe fallar.
Con dos cuentas, comprueba que no se puedan leer ni editar perfiles ajenos.

## Estado de verificación

Las pruebas automatizadas usan el SDK real con HTTP controlado y SQLite en
memoria. No sustituyen la prueba contra `encuentralo-escom-dev`, la entrega de
correo, las políticas desplegadas ni la persistencia nativa en un teléfono.

La corrección usa Flutter **3.32.8 / Dart 3.8.1**. Los dos
DropdownButtonFormField de reportes ahora usan `value`, conservando los valores
del ViewModel y los callbacks existentes. No se cambió el diseño, la validación
ni la lógica de publicaciones.

`flutter pub get` terminó correctamente y el análisis completo quedó **sin
incidencias**. La suite completa final pasó: **71 pruebas**, ejecutadas con
`flutter test --no-pub --concurrency=1`.

Algunas ejecuciones agotaron la memoria/paginación de Windows, incluso en
secuencia. Tras liberar un daemon inactivo de Gradle 8.12, el análisis y la suite
final sí pasaron.

El **17 de noviembre de 2026** se compiló, instaló y abrió un APK nuevo en el
Samsung **SM A022M / R58R90LEHTT**, autorizado por ADB, con **Android 11 / API 30**.
Se usó exclusivamente `.dart_tool/flutter-3.32.8/bin/flutter.bat` y la configuración
local real, excluida de Git; el modo OTP sigue deshabilitado por defecto.
`flutter pub get` volvió a terminar correctamente.

El primer intento volvió a fallar por memoria nativa de Java. Después de que el
usuario liberara memoria, se consultó el estado de Gradle 8.13, 8.10.2 y 9.8.1:
los tres daemons estaban IDLE y se detuvieron sin cerrar los IDE. El margen de
memoria comprometible subió a unos 3.1 GB. El segundo intento completó
`assembleDebug` en 148.7 segundos e instaló el APK en 17.9 segundos.

Se aplicaron solo a ese proceso estos límites conservadores; no se cambió la
configuración global ni se ejecutó `flutter clean`:

```powershell
$flutter32 = '.\.dart_tool\flutter-3.32.8\bin\flutter.bat'
$env:GRADLE_OPTS = '"-Dorg.gradle.jvmargs=-Xms64m -Xmx768m -XX:MaxMetaspaceSize=384m -XX:ReservedCodeCacheSize=128m -XX:+UseSerialGC -XX:ActiveProcessorCount=2 -Dfile.encoding=UTF-8" -Dorg.gradle.workers.max=1 -Dorg.gradle.parallel=false'
& $flutter32 run -d R58R90LEHTT --dart-define-from-file=config/supabase.local.json
```

Se comprobó la pantalla de bienvenida en el teléfono y, mediante lectura del
depurador, que la instancia de `SupabaseService` tenía cliente y ningún error de
inicialización. Una consulta de solo lectura a `/auth/v1/settings` también aceptó
la configuración local y confirmó Email habilitado y confirmación obligatoria.
La respuesta desde Windows por sí sola no sustituye las pruebas de autenticación
en el teléfono.

Android avisó de un controlador Vulkan incompatible y usó OpenGLES; la interfaz
se mostró. También hubo un aviso de descifrado de datos anteriores de
EncryptedSharedPreferences; `flutter_secure_storage` continuó con su alternativa
de cifrado. No se borraron datos para resolverlo. Después del login, el usuario
quitó la app de recientes y la abrió desde su icono: confirmó que volvió a la
pantalla principal conservando la sesión.

Las tres pruebas específicas de PKCE (intercambio válido, rechazo sin verificador
y persistencia segura del verificador) también pasaron. El análisis final con
estos cambios volvió a terminar sin incidencias.

El usuario confirmó que ejecutó la migración y que `profiles` y sus columnas
aparecen en Supabase. No se volvió a ejecutar SQL remoto. Durante la prueba manual
en el Samsung confirmó que recibió el correo, confirmó su cuenta, regresó a la app
y pudo iniciar sesión hasta llegar a la pantalla principal. Estos resultados
proceden de su comprobación en el dispositivo; no se crearon cuentas ni se
introdujeron credenciales automáticamente.

La persistencia tras quitar la app de recientes y reabrir desde su icono quedó
confirmada por la prueba manual del usuario. También confirmó que cerró sesión
y volvió a iniciar sesión con la misma cuenta. Una lectura del estado del proceso
después del nuevo login confirmó `authenticated`, usuario presente, sin error y
sin operación en curso; no se extrajeron correos, contraseñas ni tokens.
El usuario también confirmó en Dashboard que la cuenta aparece confirmada en
Authentication → Users y que su UUID coincide con el `id` de la fila en
Table Editor → profiles. Quedan verificadas en el Samsung la confirmación por
correo, el retorno a la app, el login, la persistencia al reabrir, el logout y el
nuevo login, además de la creación del perfil comprobada por el usuario.
La recuperación de contraseña y el aislamiento RLS entre dos cuentas tampoco
se han probado contra el backend real.

Al cerrar la app durante estas pruebas se perdió la conexión de depuración.
`flutter attach` logró conectarse, pero falló al intentar reconectar con
`Bad state: Stream has already been listened to` dentro de `flutter_tools`.
Se recuperó el acceso de solo lectura al servicio VM del proceso actual mediante
ADB, sin reinstalar la aplicación, cambiar de Flutter ni alterar la sesión.

## Archivos de esta fase

Nuevos:

- `config/supabase.example.json` y `config/supabase.local.json` (este último ignorado).
- `lib/data/services/supabase_service.dart`: inicialización y cliente compartido.
- `lib/data/local/supabase_auth_storage.dart`: persistencia segura del SDK.
- `lib/views/auth/confirm_email_view.dart`: instrucciones y reenvío del enlace;
  código únicamente cuando se habilita el modo OTP con SMTP propio.
- `supabase/migrations/202611170001_create_profiles.sql` y
  `supabase/verify_profiles.sql`: esquema, permisos y comprobaciones manuales.
- `test/data/supabase_auth_repository_test.dart` y
  `test/data/supabase_auth_storage_test.dart`: autenticación y almacenamiento.
- `docs/supabase.md`: esta guía.

Modificados:

- `.gitignore`, `pubspec.yaml`, `pubspec.lock`, `README.md`.
- `lib/main.dart`, `lib/app.dart`, `lib/core/config/env.dart`.
- `lib/data/repositories/auth_repository.dart`, `lib/data/models/user.dart`,
  `lib/viewmodels/auth_viewmodel.dart`.
- `lib/views/auth/auth_flow.dart`, `login_view.dart`, `register_view.dart`,
  `forgot_password_view.dart`, `welcome_view.dart`.
- `lib/views/profile/profile_view.dart`: presenta fallos de cierre de sesión.
- `test/data/repositories_test.dart`, `test/views/auth_flow_test.dart`.

En esta corrección se añadieron también `lib/data/services/auth_link_service.dart`,
`lib/views/auth/reset_password_view.dart` y `test/data/auth_link_service_test.dart`.
Se modificaron el manifiesto Android y `ios/Runner/Info.plist` para los callbacks.
En `lib/views/reports/report_form_view.dart` solo se cambiaron los dos argumentos
`initialValue` por `value` para Flutter 3.32.8.

Se conservan SQLite, la lógica de reportes/clima, splash, logo y temas.
La copia de Flutter usada para comprobar 3.32.8 está bajo
`.dart_tool/flutter-3.32.8`, ignorada por Git; no cambia la instalación global.
