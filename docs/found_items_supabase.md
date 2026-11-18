# Fase 3: publicaciones de hallazgos con Supabase

El código utiliza Supabase como fuente compartida. **La activación remota y la
prueba entre dos dispositivos requieren revisar y aplicar manualmente los SQL de
esta fase.** No se ejecutaron migraciones, cambios de Storage ni SQL de prueba en
el proyecto remoto desde este trabajo. No se cambió Supabase Auth.

## Git

La fase 2 no estaba integrada: se revisó, pasó sus 81 pruebas y análisis, y se
guardó en `f5d0e42`. Se integró por avance rápido y se subió únicamente `main` a
GitHub. No se eliminaron ramas. La fase 3 se respalda en su propia rama,
`feature/found-items-supabase`, sin integrarla con `main`.

## SQL que debes revisar y aplicar

1. Confirma que la migración de perfiles de la fase 1 ya está aplicada. No la
   vuelvas a ejecutar.
2. Revisa y ejecuta completo, en SQL Editor,
   [`202611180001_create_found_items.sql`](../supabase/migrations/202611180001_create_found_items.sql).
   Crea `public.found_items`, restricciones, índices, RLS, permisos por columna y
   el trigger que protege las transiciones. No altera `profiles` ni Auth.
3. Revisa y ejecuta completo
   [`202611180002_found_item_photos.sql`](../supabase/migrations/202611180002_found_item_photos.sql).
   Crea el bucket privado y sus políticas. No lo crees también desde Dashboard:
   el SQL ya lo crea con la configuración necesaria.
4. Si algún objeto ya existe, estas migraciones fallan y revierten su transacción.
   Inspecciona la estructura antes de reintentar; no hay borrados automáticos ni
   `DROP ... CASCADE`.
5. Revisa [`verify_found_items.sql`](../supabase/verify_found_items.sql). La primera
   parte inspecciona estructura, permisos, políticas y bucket. Para la segunda,
   sustituye `REEMPLAZA_UUID_A` y `REEMPLAZA_UUID_B` por UUID distintos de cuentas
   existentes en Auth. Cambia temporalmente de rol e identidad, ejecuta
   comprobaciones y hace `ROLLBACK`. Si se interrumpe, ejecuta `ROLLBACK` antes
   de seguir. No uses el SQL Editor como postgres para inferir que RLS funciona:
   ese rol omite las políticas.

## Datos y permisos

La tabla contiene UUID, autor, título, categoría, descripción, fecha del hallazgo,
zona, custodia, ruta de foto opcional, estado y fechas de auditoría. Todas las
filas son de objetos encontrados; no hay publicaciones públicas de búsquedas.
Se validan longitudes, categorías, zonas, fechas y rutas de fotos en la BD y
antes del envío en Flutter.

| Operación | Permiso |
| --- | --- |
| Consultar catálogo | Solo authenticated; únicamente `active` en la consulta del catálogo. |
| Consultar Mis hallazgos | Solo la cuenta autora; incluye sus estados no públicos. |
| Crear | Autor igual a `auth.uid()` por RLS. El cliente envía el UUID de la sesión que abrió el formulario, evitando atribuirlo a otra cuenta si cambia la sesión durante el envío. |
| Editar | Solo autor y publicación activa; únicamente columnas autorizadas. |
| Retirar | Autor cambia `active` a `withdrawn`; desaparece del catálogo general. |
| Borrar físicamente | El alumno no tiene DELETE. |
| Cambiar autoría, UUID o fechas de auditoría | Sin privilegios del cliente; trigger protege identidad y fija `updated_at`. |
| Confirmar devolución o reactivar estados terminales | No permitido al cliente. `returned` queda reservado para un flujo futuro del servidor. |

La custodia es independiente del estado. Alumno → Prefectura registra una
declaración y termina la coordinación por parte del alumno; la publicación
permanece activa. No equivale a recepción verificada ni devolución confirmada.
El cliente no puede revertir esa declaración a Alumno. No se implementan códigos
ni un endpoint para confirmar devoluciones.

El catálogo no consulta ni combina `profiles`: no expone boletas, correos,
teléfonos, nombres privados o avatares de autores. Conserva el saludo y Perfil
usando la autenticación existente. El formulario advierte que la descripción
tampoco debe incluir información personal.

## Storage

- Bucket: `found-item-photos`, **privado**.
- Límite por archivo: **3 MiB** (`3145728` bytes).
- MIME permitidos: `image/jpeg`, `image/png`, `image/webp`.
- Ruta: `UUID_USUARIO/UUID_PUBLICACION/UUID_CONTENIDO.ext`.
- El selector existente redimensiona a 1280 × 1280 y solicita calidad 75. Antes
  de subir se comprueban tamaño, firma del formato y decodificación raster;
  se rechazan imágenes mayores de 16 megapíxeles. No se admiten SVG ni GIF.
- El límite y MIME también quedan configurados en el bucket. La comprobación
  de bytes y decodificación es del cliente; las políticas no realizan análisis
  antivirus ni inspección binaria de archivos enviados por clientes ajenos.
- Se permite subir a una carpeta propia antes de insertar la publicación. Solo
  el autor puede leer esos archivos provisionales. Otros usuarios autenticados
  acceden únicamente al `photo_path` vinculado a una publicación activa.
- No se permite UPDATE de objetos. Un reemplazo usa otra ruta; después de
  confirmar el cambio en la fila se intenta borrar el objeto anterior. La
  política impide borrar una foto que siga vinculada a una publicación.
- Las restricciones de este bucket también bloquean políticas permisivas
  amplias preexistentes de Storage, sin restringir otros buckets. La suite SQL
  prueba expresamente ese escenario.
- Se generan URLs firmadas de **120 segundos**, solo en memoria. Se renuevan
  mientras la imagen está visible, al volver a primer plano o al reintentar.
  Una URL ya emitida puede funcionar hasta caducar después de retirar el objeto:
  no equivale a revocación inmediata. No se guardan URLs firmadas en SQLite.
- La app avisa que deben cubrirse nombre, rostro, boleta, códigos y otros datos
  antes de fotografiar documentos. No promete borrarlos automáticamente.
- Flutter utiliza exclusivamente el cliente público configurado y la sesión
  autenticada. No utiliza `service_role` ni secret keys.

El límite global de Storage del proyecto debe permitir al menos 3 MiB; compruébalo
en Dashboard. No necesitas volver público el bucket ni configurar Auth de nuevo.

Si falla una escritura y se puede comprobar que el archivo quedó desvinculado,
se intenta limpiar. Si se pierde la conexión y no es posible comprobar si la
fila se confirmó, se conserva la foto para no borrar una publicación válida.
Pueden quedar archivos provisionales tras un cierre o fallo prolongado; su
limpieza posterior debe realizarse mediante Storage API desde un entorno de
confianza, comprobando referencias y antigüedad. No borres solamente metadatos
de `storage.objects` mediante SQL.

## Comportamiento de la app

- Inicio muestra hasta seis hallazgos recientes; Explorar permite nombre,
  términos de descripción/categoría/zona, categoría, zona, fecha inclusiva y orden.
  El repositorio recorre páginas de 200 filas y deduplica por UUID. Explorar
  muestra bloques de 30 tarjetas con «Mostrar más hallazgos». Hay actualización
  explícita; no se implementa Realtime.
- Un servicio no disponible muestra error y reintento, no un falso catálogo
  vacío ni datos de ejemplo. Nunca se usa SQLite como alternativa del catálogo.
- El formulario valida datos, deshabilita envíos duplicados y conserva un UUID
  estable al reintentar. Ante una respuesta perdida, se consulta ese UUID antes
  de confirmar éxito o limpiar archivos. Las ediciones usan `updated_at` para
  rechazar cambios basados en una versión antigua.
- Solo después de una respuesta confirmada aparece «Hallazgo publicado» o
  «Cambios guardados». La confirmación ofrece abrir el detalle.
- El circuito del logo aparece animado en la confirmación de publicación y en
  los diálogos compartidos: cierre de sesión, retiro y declaración de Prefectura.
  Respeta movimiento reducido; no se introdujeron emojis.
- El detalle muestra datos, foto/categoría y custodia. Una publicación ajena
  resguardada por Alumno muestra «Creo que es mío» deshabilitado y explica que
  las solicitudes aún no están disponibles. Con Prefectura indica que se trata
  de una declaración y que debes acudir personalmente.
- Mis hallazgos incluye activas, retiradas y devoluciones confirmadas futuras.
  Solo ofrece editar/retirar publicaciones activas propias. No hay «resolver»
  libremente ni «reactivar» estados terminales.
- Una respuesta de una sesión anterior no repuebla datos ni URLs de otra cuenta.
  Las animaciones Hero de pestañas ocultas se suspenden para evitar conflictos
  si una tarjeta aparece tanto en Inicio como en Explorar.
- Se conservan SQLite y sus registros heredados, la splash, login, registro,
  navegación y temas. No se importan automáticamente publicaciones locales.

## Prueba manual con dos cuentas

Después de aplicar los SQL, utiliza dos cuentas confirmadas A/B, preferiblemente
en dos dispositivos o instalaciones independientes:

1. A publica un hallazgo sin foto y custodia Alumno. Comprueba la confirmación
   con logo y abre su detalle. A debe verlo también en Mis hallazgos.
2. B inicia sesión y pulsa «Actualizar hallazgos». Debe ver la misma publicación
   en Inicio/Explorar. Busca por nombre y filtra por categoría, zona y fecha.
   En el detalle B no debe ver acciones de editar o retirar.
3. A añade una foto válida. B actualiza y comprueba que aparece. En Storage,
   verifica la carpeta de A y de la publicación, sin enlaces públicos.
4. Intenta seleccionar SVG/GIF o una foto final mayor de 3 MiB; la app debe
   rechazarla. Comprueba también los límites del bucket desde un cliente API.
5. A cambia la custodia a Prefectura y confirma su declaración. A/B deben ver
   el aviso de recepción no verificada; el estado sigue activo. No debe
   aparecer una devolución confirmada ni un modo de revertir a Alumno.
6. A retira la publicación y confirma con el logo. B actualiza: debe desaparecer.
   A la conserva en Retirada, sin editar ni reactivar. Una URL firmada anterior
   puede durar los segundos restantes de su vigencia.
7. Ejecuta el script SQL de verificación con los UUID A/B: modificar una fila
   ajena debe afectar cero filas; cambiar autoría, confirmar devolución o hacer
   DELETE debe fallar. La prueba termina con rollback.
8. Desde clientes autenticados, comprueba que B no pueda subir, reemplazar o
   eliminar fotos en la carpeta de A; tampoco debe ver un archivo provisional
   no vinculado. Sin autenticación no debe poder consultar el catálogo ni fotos.
9. Prueba pérdida de red al publicar y reintento con el mismo formulario. No debe
   anunciar éxito sin confirmación ni duplicar una publicación confirmada con
   el mismo UUID. Prueba edición simultánea desde dos sesiones de A.

## Verificación automatizada

Flutter 3.32.8 / Dart 3.8.1:

```powershell
$flutter32 = '.\.dart_tool\flutter-3.32.8\bin\flutter.bat'
& $flutter32 pub get
& $flutter32 analyze
& $flutter32 test --no-pub --concurrency=1
& $flutter32 run -d R58R90LEHTT --no-pub --dart-define-from-file=config/supabase.local.json
```

Pruebas SQL aisladas (Node, sin credenciales):

```powershell
Set-Location tools/sql-security
npm ci --ignore-scripts --no-audit --no-fund
npm test
```

El 18 de noviembre de 2026: `pub get` correcto, análisis sin incidencias,
**97 pruebas Flutter aprobadas** y **28 comprobaciones PostgreSQL locales
aprobadas**. Las pruebas del repositorio usan el SDK real con HTTP controlado;
las SQL ejecutan las migraciones y el script de verificación en PGlite, con
esquemas locales mínimos de Auth/Storage y dos identidades. No sustituyen el
Storage HTTP desplegado ni la prueba entre dos cuentas en el proyecto remoto.
La suite conserva las pruebas de autenticación y splash y cubre errores,
confirmaciones, retiro, propiedad visible y accesibilidad al 200 % en ambos temas.

### Samsung conectado

Se compiló, instaló y ejecutó en el SM A022M (`R58R90LEHTT`), Android 11 / API 30,
ARM de 32 bits. `assembleDebug` terminó en 60.0 segundos y la instalación en
17.0 segundos. No se cambió la configuración global de Java: se usaron límites
temporales de memoria y un solo worker, como en la fase 2.

En el primer arranque la splash quedó esperando la restauración de sesión:
`unknown`, restauración pendiente y sin error informado. Una consulta pública de
solo lectura desde Windows confirmó que el backend respondía; eso no verifica
la conexión del teléfono. Tras un reinicio de Flutter, sin borrar datos ni cerrar
la cuenta, el proceso confirmó `authenticated`, usuario presente, restauración
terminada y sin error. No se estableció la causa exacta de la espera inicial ni
se modificó Auth para atribuirle una solución no comprobada.

Se revisaron Inicio y Perfil, y se abrió el diálogo real de cierre de sesión:
el circuito del logo aparece sobre el título. Se canceló el diálogo y se
comprobó que la sesión seguía autenticada. La captura permanece en
`.dart_tool/phase3-logo-confirmation-android.png`, fuera de Git.

Inicio mostró «El servicio de hallazgos todavía no está disponible», con
reintento, compatible con las migraciones pendientes. No se sustituyó ese error
por un falso catálogo vacío. No se publicó ningún objeto en el proyecto remoto,
no se probó Storage remoto ni se repitió un login manual con contraseña. La
prueba completa de A publicando y B consultando requiere aplicar los SQL y seguir
el procedimiento manual anterior. No se midió rendimiento en release.

## Archivos principales

Nuevos: `lib/data/repositories/found_items_repository.dart`,
`lib/data/models/publication_photo.dart`, `lib/views/widgets/remote_report_image.dart`,
`lib/views/widgets/publication_notice.dart`, las dos migraciones SQL,
`supabase/verify_found_items.sql`, `test/data/found_items_repository_test.dart`,
`tools/sql-security/{package.json,package-lock.json,verify.mjs}` y esta guía.

Adaptados: `lib/app.dart`, `lib/core/constants/escom.dart`, modelos `report.dart`
y `report_filter.dart`, ambos ViewModels de reportes, pantallas de Inicio,
Explorar, Publicar, Mis hallazgos, Perfil, formulario y detalle; widgets comunes,
tarjetas y hoja de filtros; pruebas de navegación y compatibilidad SQLite,
`.gitignore` y `README.md`. `local_only_notice.dart` se sustituye por el aviso
de publicación. No se cambia el repositorio ni la configuración de Auth.

Pendiente: revisión/aplicación manual del SQL, comprobación real entre dos
cuentas/dispositivos, mantenimiento de provisionales, y las futuras funciones de
solicitudes, chats, códigos, devolución verificada, alertas, push y recompensas.

Referencias primarias consultadas para el diseño:
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[permisos por columna](https://supabase.com/docs/guides/database/postgres/column-level-security),
[buckets privados](https://supabase.com/docs/guides/storage/buckets/fundamentals),
[control de acceso de Storage](https://supabase.com/docs/guides/storage/security/access-control),
[límites de archivos](https://supabase.com/docs/guides/storage/uploads/file-limits).
