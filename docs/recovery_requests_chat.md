# Fase 4: recuperación y comunicación privada

Actualización del 21 de noviembre de 2026: el usuario confirmó las pruebas
manuales de las funcionalidades principales y autorizó la integración. La rama
se fusionó a `main` en `dfed181` y se subió a GitHub antes de iniciar Fase 5.
El contenido siguiente conserva el registro original de implementación y sus
límites de verificación; no acredita pruebas remotas adicionales.

Implementación en `feature/recovery-requests-chat`, creada desde `main`
`ed626f8`. No integrar esta rama hasta la revisión manual del usuario. No se
ejecutó la app en el teléfono ni en un emulador, ni se aplicó SQL remoto.

## Modelo y reglas

Se reutilizan Auth, perfiles privados, `found_items`, sus estados `active`,
`withdrawn`, `returned`, el bucket privado y los componentes/temas existentes.
La etiqueta existente «Devolución confirmada» representa el hallazgo resuelto. No se añade
otro estado equivalente ni se publica información de perfiles en el chat.

Tablas nuevas:

| Tabla | Datos y acceso |
| --- | --- |
| `recovery_requests` | Solicitante, encontrador, hallazgo, título público al solicitar, características privadas, estado, versión, acuerdo y confirmaciones. Solo participantes. |
| `recovery_conversations` | Una por solicitud aceptada. Sus participantes pueden consultar su apertura/cierre. |
| `recovery_messages` | UUID, conversación, remitente derivado de Auth, texto y fecha del servidor. Lectura/envío solo mientras la solicitud esté aceptada y el hallazgo activo con custodia estudiante, sin bloqueo. |
| `recovery_events` | Historial de acciones; solo los participantes de su solicitud. |
| `recovery_blocks` | Relación de bloqueo; solo quien bloqueó puede consultarla/deshacerla. |
| `recovery_abuse_reports` | Motivo privado; solo quien reportó puede consultar su registro desde el cliente. La revisión administrativa queda pendiente de un proceso de moderación del proyecto. |

`pending` → `accepted` / `rejected` (solo encontrador); `pending` o `accepted`
→ `cancelled` (solo solicitante, antes de cualquier confirmación).
Una conversación aceptada puede cerrarse sin devolución antes de confirmar.
Los estados terminales no se reactivan. Aceptar una solicitud permite aclarar
características, **no acredita propiedad**. Varias solicitudes/conversaciones
del mismo hallazgo son independientes; B nunca consulta las de C.

Una solicitud activa por pareja solicitante/hallazgo se protege mediante un
índice único parcial y bloqueo de la fila del hallazgo. Hay máximo tres intentos
por pareja, 24 horas entre intentos y diez solicitudes nuevas por solicitante
en 24 horas; un advisory lock serializa ese último límite. La evidencia acepta
20–1200 caracteres. Los mensajes aceptan 1–2000 y se limita a uno cada dos
segundos por remitente y conversación. Un reintento con el mismo UUID/contenido
no crea otra solicitud, conversación ni mensaje.

El punto de encuentro se selecciona entre las zonas existentes de ESCOM y el
horario debe ser futuro, dentro de 30 días. Se recomienda un lugar público y
acordarlo por chat. Guardar un acuerdo no confirma la entrega. No se inventan
direcciones, horarios ni procedimientos oficiales.

La devolución necesita dos acciones explícitas con diálogo: «Confirmar que
entregué» del encontrador y «Confirmar que recibí» del solicitante. La primera
no resuelve el hallazgo. Al registrar ambas, la misma transacción marca la
solicitud `closed/returned`, cambia `found_items.status` a `returned`, cierra
el chat y cierra las demás solicitudes activas con motivo `item_returned`.
El historial se conserva. Una vez que alguien confirma, no se permite cancelar,
cerrar voluntariamente ni cambiar el acuerdo; bloquear o retirar el hallazgo
sigue cerrando la comunicación sin certificar una devolución.

Retirar la publicación o declarar Prefectura cierra todas sus solicitudes y
conversaciones mediante un trigger. Prefectura nunca admite solicitudes nuevas,
chats ni confirmaciones digitales de recepción. Se conservan las indicaciones
presenciales y la advertencia de entrega declarada de Fase 3.

## Seguridad y aislamiento

Todas las tablas privadas tienen RLS. Se revocan INSERT/UPDATE/DELETE directos
del cliente: las cinco RPC públicas realizan las escrituras, validan actor,
participación, disponibilidad y transiciones. Usan `SECURITY DEFINER` con
`search_path=''` y nombres de tabla cualificados. No se exponen funciones
genéricas de administración ni claves privilegiadas al cliente.

El parámetro `p_actor` vincula cada operación con su sesión de origen y debe
coincidir con `auth.uid()`. No autoriza por sí mismo: cada RPC verifica además
su rol dentro de la solicitud. Impide que un formulario de A se envíe como B
si el SDK cambia de sesión antes de transmitirlo. El servidor fija remitente,
encontrador, fechas y versiones. Las versiones obsoletas se rechazan (`40001`).

El orden de bloqueo es hallazgo → solicitud; los bloqueos entre usuarios toman
hallazgos ordenados. Esto serializa aceptación, mensajes, cierre, cambio de
custodia y resolución de solicitudes competidoras. La suite local prueba
estados obsoletos y efectos transaccionales; **no simula conexiones PostgreSQL
concurrentes independientes**. Esa comprobación sigue pendiente en staging.

Flutter descarta respuestas tardías mediante una revisión de sesión; al cerrar
sesión/cambiar de cuenta limpia listas, mensajes, pendientes, borradores y
suscripciones. No almacena evidencia ni conversaciones en SQLite. El contenido
privado no se incorpora a `Report`, consultas públicas ni comentarios.
Los participantes se muestran por su papel («Encontrador», «Solicitante», «Tú»),
sin divulgar automáticamente nombre, boleta, correo, teléfono o avatar.

Bloquear cierra solicitudes/conversaciones entre ambos usuarios e impide nuevas
solicitudes y mensajes en ambos sentidos. Desbloquear no reabre el historial.
Reportar registra el motivo para seguimiento administrativo; **no existe aún
una consola de moderación, atención automática ni garantía de respuesta**.

## Realtime, avisos y reconexión

La migración añade solicitudes, conversaciones y mensajes a `supabase_realtime`
si esa publicación existe. Debe comprobarse en el proyecto desplegado. RLS
autoriza SELECT de INSERT/UPDATE; no se utiliza `REPLICA IDENTITY FULL` y el
cliente no tiene DELETE. No modificar la publicación global para habilitar
datos antiguos completos ni conceder acceso público a estas tablas.

Los eventos invalidan consultas y se vuelve a leer mediante RLS; su payload
no se incorpora directamente al estado. Al reconectar se actualizan solicitudes
y mensajes. Hay recarga periódica de respaldo: 20 segundos para bandejas y
10 para el chat abierto, además de actualización manual y al volver a primer
plano. Esta recarga funciona aunque Realtime no esté configurado. Las
suscripciones se eliminan al salir/cambiar de cuenta.

El chat carga páginas de 50 con cursor `(created_at,id)`, permite consultar
mensajes anteriores y recorre todas las páginas nuevas desde el último mensaje
consultado tras una desconexión. El cursor no avanza por un mensaje enviado
localmente hasta volver a consultarlo, evitando saltarse mensajes recibidos
mientras no había conexión. Los UUID deduplican mensajes y se conservan al
reintentar una respuesta perdida. Los pendientes no sobreviven al cierre de
sesión o de la pantalla; el servidor conserva los mensajes confirmados.

El encontrador ve la cuenta de solicitudes pendientes en la campana de Inicio
y su bandeja en Chats/Notificaciones. Son avisos dentro de la aplicación, sin
push, email ni contador de «no leídos» inventado. La evidencia solo aparece
en el detalle privado de la solicitud.

## Coincidencias: dependencia real

Existe `ReportRepository.findMatches` en SQLite para registros heredados.
El catálogo compartido solo publica objetos encontrados. Por ello no se mezclan
registros locales con usuarios/solicitudes de Supabase ni se inventa una tabla
remota de objetos perdidos. `RecoveryMatchService` prepara un origen futuro
de publicaciones perdidas compartidas: categoría, zona y fecha, sugerencias
descartables por sesión, sin inferir propiedad. No se anuncia coincidencia
disponible en la UI mientras falte ese origen. Cuando exista, sus sugerencias
deben abrir los detalles y el mismo formulario privado de recuperación.

## Aplicación manual y verificación remota

1. Comprobar que las dos migraciones de Fase 3 y perfiles estén aplicadas. El
   usuario lo confirmó; esta revisión no inspeccionó su esquema remoto.
2. Revisar íntegra
   [`202611210001_recovery_requests_chat.sql`](../supabase/migrations/202611210001_recovery_requests_chat.sql).
   Aplicarla una sola vez como propietario en SQL Editor. Es aditiva y
   transaccional; si existen objetos con esos nombres, detenerse e inspeccionar.
   No modifica Auth, perfiles ni permisos del bucket de Fase 3.
3. Revisar [`verify_recovery.sql`](../supabase/verify_recovery.sql). La primera
   parte inspecciona RLS, permisos, RPC y publicación. En la segunda reemplazar
   los tres UUID por A/B/C confirmados y ejecutar el bloque completo: usa roles
   `authenticated`, crea datos sintéticos y termina con ROLLBACK. Ante un error
   ejecutar ROLLBACK antes de seguir. No interpretar consultas como postgres
   como prueba de RLS.
4. Verificar que Realtime incluya las tres tablas y que no haya políticas
   adicionales que amplíen accesos. No cambiar el bucket a público.
5. Después de estos pasos, realizar la prueba manual en la app desde esta rama.
   No se inició ni se inspeccionó el teléfono durante la implementación.

Prueba manual A/B/C (pendiente; no declarada aprobada):

- A publica un hallazgo con custodia Alumno. B abre «Creo que es mío», describe
  características privadas y confirma. A recibe el aviso. C envía otra
  solicitud; A ve ambas, B/C solo la propia. Probar doble envío/reintento.
- A acepta B. Únicamente A/B abren ese chat e intercambian mensajes. C no debe
  poder leerlos ni enviar mediante API. A puede aceptar C y abrir otro chat
  independiente; no se comparte evidencia entre conversaciones.
- Cortar/restablecer red y probar reconexión, envío pendiente/reintento y
  navegación por mensajes anteriores. Probar varias páginas nuevas y ausencia
  de duplicados. Cerrar sesión con un envío pendiente y entrar como C: no debe
  aparecer ningún mensaje/borrador/evidencia de B.
- A/B registran punto y hora en ESCOM. Una confirmación mantiene el hallazgo
  activo; la segunda muestra «Devolución confirmada» y cierra las demás solicitudes. No se
  admiten solicitudes o mensajes nuevos. Revisar el historial de cada cuenta.
- Repetir retiro y entrega declarada a Prefectura con solicitudes activas:
  todas se cierran, no hay chat con Prefectura ni confirmación digital en su
  nombre. Probar publicación propia, retirada y ya devuelta.
- Probar rechazo, cancelación, bloqueo/desbloqueo, reporte privado, límites y
  versiones obsoletas desde dos sesiones. Ejecutar también la carrera de dos
  devoluciones sobre el mismo hallazgo desde conexiones separadas: una sola
  debe resolver y las otras conservar su historial cerrado.

## Comprobaciones locales

```powershell
$flutter32 = '.\.dart_tool\flutter-3.32.8\bin\flutter.bat'
& $flutter32 pub get
& $flutter32 analyze --no-pub
& $flutter32 test --no-pub --concurrency=1
git diff --check
npm.cmd --prefix tools/sql-security test
```

Las pruebas Dart usan el SDK real con HTTP controlado y widgets. Las SQL
ejecutan migraciones y el flujo A/B/C en PGlite con Auth mínimo simulado; no
verifican Storage HTTP, WebSocket, despliegue ni sesiones de usuarios reales.
Resultados ejecutados el 21 de noviembre de 2026 con Flutter 3.32.8 / Dart 3.8.1:

| Comprobación | Resultado |
| --- | --- |
| `flutter pub get` | Correcto, sin cambios de dependencias versionadas. |
| `flutter analyze --no-pub` | Sin incidencias. |
| `flutter test --no-pub --concurrency=1` | **142 pruebas aprobadas**. |
| `npm test` en `tools/sql-security` | **57 comprobaciones PostgreSQL aprobadas: 36 de Fase 3 y 21 de Fase 4**. |
| `git diff --check` y diff preparado | Correctos. |
| Inspección de secretos en archivos preparados | Sin claves privilegiadas, JWT de servicio, claves privadas ni contraseñas de conexión detectados. Configuración local excluida. |
| SQL remoto, HTTP/Realt​ime real y concurrencia de conexiones independientes | **Pendientes; no ejecutados**. |
| Teléfono/emulador | **No utilizado**. |

Las regresiones cubren además limpieza de evidencia/borradores al cambiar cuenta,
respuestas tardías, reintentos de mensajes con el mismo UUID, recuperación de
120 mensajes tras desconexión, cancelación de suscripciones y estados de error
o no disponibilidad con texto al 200 % en ambos temas. `main` permanece en
`ed626f8`; no se fusiona la Fase 4.

Referencias de diseño:
[funciones SQL seguras](https://supabase.com/docs/guides/database/functions),
[Postgres Changes y RLS](https://supabase.com/docs/guides/realtime/postgres-changes),
[suscripciones Flutter](https://supabase.com/docs/reference/dart/subscribe).
