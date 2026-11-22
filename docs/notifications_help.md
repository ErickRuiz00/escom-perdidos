# Fase 5: notificaciones internas, preferencias y ayuda

Implementada en `feature/notifications-help`, desde `main` después de integrar
la Fase 4 probada manualmente por el usuario. **No fusionar la Fase 5 todavía.**
No se ejecutó la aplicación ni se utilizaron dispositivos o emuladores.
No se consultó ni modificó el esquema Supabase remoto.

## Aplicación manual de SQL

1. Confirmar que están aplicadas las migraciones de perfiles y Fases 3 y 4.
2. Revisar y ejecutar una sola vez como propietario
   [`202611210002_notifications_help.sql`](../supabase/migrations/202611210002_notifications_help.sql).
   Es aditiva y transaccional. Si existen objetos con esos nombres, inspeccionar
   antes de continuar. No cambia Auth, Storage ni las RPC de recuperación.
3. Revisar [`verify_notifications.sql`](../supabase/verify_notifications.sql).
   Su primera sección inspecciona RLS, permisos, funciones y Realtime.
   En el bloque A/B/C, reemplazar los tres UUID por cuentas confirmadas
   diferentes y ejecutar el bloque completo. Usa `authenticated`, genera
   datos sintéticos y termina en `ROLLBACK`. Ante un error o interrupción,
   ejecutar `ROLLBACK` antes de continuar.
4. Verificar que `supabase_realtime` incluya `notifications` y
   `notification_preferences`. La migración las incorpora si la publicación
   existe; no crea ni altera el esquema interno `realtime`.
5. Ejecutar las pruebas manuales de la aplicación desde esta rama.

## Datos, preferencias y privacidad

`notifications` conserva destinatario, tipo, textos generales, fechas de
creación/lectura y referencias a publicación, solicitud y conversación.
Solo el destinatario tiene SELECT mediante RLS. El cliente no tiene
INSERT/UPDATE/DELETE; marcar lectura usa una RPC ligada a `auth.uid()` y
`p_actor`, con fechas del servidor. Marcar todo utiliza un límite temporal
para conservar sin leer eventos posteriores a lo consultado.

Los avisos se producen mediante triggers de operaciones ya autorizadas:

| Origen verificado | Destinatario / destino |
| --- | --- |
| Solicitud creada | Encontrador / solicitud privada |
| Aceptación, rechazo, cancelación, cierre o acuerdo actualizado | Otro participante / solicitud |
| Primera confirmación de entrega o recepción | Otro participante / solicitud |
| Ambas confirmaciones | Ambos participantes / solicitud resuelta |
| Mensaje nuevo | Otro participante / chat; si está cerrado, solicitud |
| Edición relevante del hallazgo | Solicitantes activos / publicación |
| Retiro, Prefectura o devolución en otra solicitud | Participantes afectados / publicación visible o solicitud conservada |

Los textos no incluyen mensajes, evidencia, nombres, contactos ni títulos de
objetos. Los enlaces vuelven a consultar mediante RLS; conservar el UUID no
concede acceso. Si desaparece una solicitud, se informa que el destino no está
disponible. No se expone contenido previo con `REPLICA IDENTITY FULL`.

La clave única `(recipient_id,event_key)` evita duplicar avisos por reintentos
de solicitudes, acciones y mensajes. Una edición que no cambia contenido no
genera otro aviso. Ediciones diferentes confirmadas sí son eventos distintos.
La migración inicia los avisos a partir de su aplicación; no reconstruye
notificaciones de eventos anteriores de Fase 4.

`notification_preferences` guarda las cuatro categorías y la versión de la
guía vista/omitida. Cada cuenta solo consulta sus preferencias y las cambia
por RPC. Completar u omitir la guía conserva las categorías y viceversa.
Sin fila, se aplican preferencias activadas por defecto.

Silenciar una categoría se aplica a **eventos futuros**: su aviso se registra
con `alert_enabled=false`, permanece en el historial y no aumenta el contador.
Los avisos anteriores conservan la preferencia vigente cuando se generaron.
Marcar como leído también funciona para avisos silenciados. El contador usa
COUNT exacto en el servidor, sin limitarse a la primera página del historial.
Coincidencias guarda una preferencia futura: no se inventó un motor remoto ni
se anuncian coincidencias disponibles.

## Realtime y sesión

Se reutilizan Auth y Postgres Changes con filtros de destinatario/cuenta y RLS.
Los eventos invalidan consultas; sus payloads no se agregan directamente al
estado. Se actualiza al iniciar sesión, al reconectar y al volver a primer plano,
con respaldo periódico de 30 segundos y actualización manual.
El historial pagina por `(created_at,id)`, 50 filas por consulta; al reconectar
se rellena el intervalo hasta la página más antigua cargada, incluso con más
de 50 eventos nuevos. Se vuelven a consultar lecturas de otros dispositivos.
Al cerrar sesión se eliminan datos, contadores, preferencias y suscripciones;
se descartan respuestas y callbacks de sesiones anteriores.

Solo son avisos **dentro de la aplicación**. No se añaden Firebase, FCM,
proveedores push, email, tareas en segundo plano ni permisos del sistema.
El servicio local heredado de fases anteriores no recibe eventos Supabase
ni se usa para simular recepción con la aplicación cerrada.

## Tutorial y ayuda

Inicio invita a consultar una guía de cinco secciones. «Ahora no», «Omitir» y
«Terminar» guardan que ya se consultó. Se puede abrir nuevamente desde Perfil
o Centro de ayuda. La guía recorre Inicio, Explorar, Publicar, Chats y Perfil
sobre las pantallas reales: oscurece el fondo, resalta el botón correspondiente
y lo señala con una flecha y una leyenda. Cambia de sección al avanzar, sin
preguntas ni evaluaciones. Incluye progreso, anterior/siguiente y omisión;
adapta el foco a la barra inferior o lateral, ambos temas y texto grande.
Impide activar acciones del fondo por accidente y se cierra al cambiar de
cuenta. Se puede salir aunque falle guardar su estado en Supabase.

El ajuste visual se verificó con **177 pruebas Flutter aprobadas**, análisis sin
incidencias y `git diff --check`. Incluye pruebas del foco en las cinco secciones,
texto al 200 %, temas claro/oscuro, rotación, áreas del sistema, omisión sin red
y reapertura desde Perfil/Ayuda. Reutiliza `tutorial_version=1`: no necesita otra
migración ni vuelve a invitar a quienes ya completaron u omitieron la guía.
Esas cuentas pueden repetirla con «Ver tutorial».

Las FAQ explican publicaciones, Mis hallazgos, recuperación, propiedad, chats,
devoluciones, Prefectura, avisos y seguridad. El enlace para reportar abuso
abre las solicitudes existentes; se utiliza la acción «Reportar abuso»,
su formulario y RPC originales.
No se crea otro sistema de reportes. No se inventan horarios, direcciones,
procedimientos oficiales, atención automática ni garantías de moderación.

## Verificación y pruebas manuales pendientes

Pruebas locales: repositorio con SDK real y HTTP controlado, ViewModel,
widgets/navegación, y PostgreSQL local con PGlite, roles y Auth mínimo simulado.
No acreditan WebSocket real, instalación remota ni concurrencia de conexiones
PostgreSQL independientes.

```powershell
$flutter32 = '.\.dart_tool\flutter-3.32.8\bin\flutter.bat'
& $flutter32 pub get
& $flutter32 analyze --no-pub
& $flutter32 test --no-pub --concurrency=1
npm.cmd --prefix tools/sql-security test
git diff --check
```

Resultados locales del 21 de noviembre de 2026 con Flutter 3.32.8 / Dart 3.8.1:

| Comprobación | Resultado |
| --- | --- |
| `flutter pub get` | Correcto; sin cambios en dependencias versionadas. |
| `flutter analyze --no-pub` | Sin incidencias. |
| `flutter test --no-pub --concurrency=1` | 174 pruebas aprobadas, incluidas las regresiones de Fases 1–4. |
| `npm test` en `tools/sql-security` | 75 comprobaciones aprobadas: 36 de Fase 3, 21 de Fase 4 y 18 de Fase 5. |
| `git diff --check` | Correcto. |
| App, dispositivo/emulador y migración remota | No ejecutados; pruebas manuales pendientes. |

Se conservó sin incluir en commits la personalización local de UUID en
`verify_recovery.sql`. El verificador local sustituye esos valores por fixtures
en memoria, sin modificar el archivo ni conectarse a Supabase.

Pruebas manuales después de aplicar SQL:

- A publica; B solicita; A recibe un aviso y abre la solicitud. C no consulta
  avisos ni preferencias de A/B. Reintentar acciones sin duplicados.
- A acepta/rechaza y B cancela en solicitudes separadas. Comprobar avisos,
  contador, lectura individual y lectura global; reabrir y conservar lecturas.
- Intercambiar mensajes, abrir el chat desde la campana y cerrar la solicitud:
  el aviso antiguo debe abrir la solicitud. Confirmar ambas devoluciones.
- Editar, retirar y declarar Prefectura con solicitudes activas; comprobar
  destino a hallazgo visible o solicitud y conservación del historial.
- Silenciar cada categoría y generar nuevos eventos: historial sí, contador
  no. Cambiar preferencias y sesión; comprobar que no aparecen datos ajenos.
- Cortar/restablecer red y dejar más de 50 avisos nuevos; recuperar todos sin
  duplicados. Probar reanudación y lectura desde otra sesión de la misma cuenta.
- Omitir y repetir la guía, recorrer las cinco secciones y terminarla; revisar ayuda y
  acceso a Reportar abuso en ambos temas y con fuente grande.
- Con app cerrada no se espera push. Abrirla y recuperar los eventos guardados.

## Pendientes para Fase 6 (no implementados)

- Eliminar «Programar encuentro»; coordinar exclusivamente por chat.
- Eliminar «Bloquear usuario», conservando «Reportar abuso».

La Fase 5 conserva ambas funciones tal como estaban en Fase 4.

Referencias de implementación:
[Postgres Changes y RLS](https://supabase.com/docs/guides/realtime/postgres-changes),
[políticas de acceso](https://supabase.com/docs/guides/database/postgres/row-level-security).
