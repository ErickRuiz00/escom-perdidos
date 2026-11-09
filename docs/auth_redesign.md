# Bienvenida y autenticación

## Alcance

Implementación en `feature/login-redesign`, sobre Flutter **3.32.8** y Dart
**3.8.1**. El tema se limita al acceso. No se modifican los repositorios,
servicios, ViewModels, esquema de SQLite, publicaciones, reportes ni perfil.
Se conservan los cambios de dependencias presentes al comenzar la tarea.
El recurso Rive se adaptó posteriormente a objetos escolares a petición del usuario.

## Navegación

- `AuthStatus.unknown`: splash mientras se restaura y valida el token local.
- Sin sesión: `AuthFlow` contiene un Navigator con bienvenida (`/`), correo
  (`/login`), registro (`/register`) y recuperación (`/forgot-password`).
- Login y registro se reemplazan entre sí; Atrás vuelve a la bienvenida.
  Recuperación se apila sobre login y regresa a él al finalizar.
- Al autenticar, `AuthGate` desmonta toda la pila de acceso y muestra
  `HomeShell`. No quedan formularios detrás de la pantalla principal.
- Al cerrar sesión, se crea una pila nueva con la bienvenida.
- Google permanece explícitamente deshabilitado. El servicio existente se
  conserva, pero no se activa desde estas pantallas hasta configurar y validar
  OAuth y el backend.

## Rive

Se inspeccionó el código de las versiones instaladas: `rive 0.14.11` y
`rive_native 0.1.11`. Se utiliza `File.asset`, `Factory.rive`,
`RiveWidgetController`, `DataBind.auto()` cuando existe ViewModel exportado y
`RiveWidget`, con artboard y máquina de estados predeterminados.
No se utiliza la API anterior `RiveAnimation.asset`.

El changelog de Rive indica soporte de scripting desde 0.14.1; la versión
instalada incluye correcciones posteriores de Luau. La ficha del globo indica
que utiliza scripting y ViewModel. Esto permite intentar su reproducción sin
actualizar dependencias, pero no demuestra que todos los scripts del archivo
se ejecuten correctamente en un dispositivo concreto.

La carga es asíncrona y local. Durante ella se dibuja un globo estático original;
un error de lectura, decodificación o creación del controlador conserva ese
respaldo. Una espera superior a ocho segundos también lo conserva. Si una
carga finaliza después del timeout o del desmontaje, se libera el archivo.
Los botones funcionan independientemente del estado de carga.

Se libera controlador, instancia de ViewModel, archivo y temporizador. Se
pausa la animación al ocultar la ruta o pasar la app a segundo plano. Un
`RepaintBoundary` aísla el render; su textura se limita a 900 × 900 píxeles.
Con movimiento reducido se utiliza directamente el globo estático y no se
carga Rive. Los formularios se desplazan con teclado y texto ampliado.

Las pruebas de widgets verifican el respaldo sin requerir DLL de Rive ni una
compilación Android; no validan el renderizador nativo ni los scripts. En una
verificación posterior autorizada por el usuario se compiló, instaló y abrió
la app en un Samsung SM A356E con Android 14: la biblioteca nativa y el globo
cargaron correctamente. Véase `docs/android_build.md` para los resultados y
los ajustes de memoria necesarios.

## Referencias y licencia

- [Prima Booking, Alex Bender / FANCY](https://dribbble.com/shots/27029457-Prima-Booking-onboarding-mobile-app-design-3D-animation): se localizó la ficha original y su paleta. No se pudo reproducir su video desde este entorno. El resultado es una interpretación de su composición y protagonismo de la animación, no una reproducción exacta.
- [Interactive Particle Globe, sm_motion](https://www.rive.app/marketplace/26161-48888-interactive-particle-globe/): su ficha publica licencia CC BY 4.0. Crédito visible en bienvenida y atribución con enlace a origen y licencia en `assets/animations/ATTRIBUTION.md`. El `.riv` adaptado conserva el script e incorpora fondo transparente e iconos escolares vectoriales; el original se conserva en `assets/animations/source/`.
- [Changelog de Rive](https://pub.dev/packages/rive/versions/0.14.11/changelog).

## Validación

```powershell
& 'C:\Users\migue\development\flutter_3.32.8\bin\flutter.bat' analyze
& 'C:\Users\migue\development\flutter_3.32.8\bin\flutter.bat' test
```

La suite agrega pruebas de restauración, descarte de la pila al autenticar,
logout, errores y validación de login, confirmación en registro, recuperación,
Atrás del sistema, pantalla de 320 × 640, texto al 200 %, teclado y asset ausente.

Resultado de la validación: **analyze sin incidencias; 33 pruebas aprobadas**
(26 existentes y 7 nuevas). No fue necesario ejecutar `pub get`: la configuración
local de paquetes ya resolvía las versiones solicitadas. No se actualizaron
dependencias ni el SDK.

## Comprobación posterior en el celular

Cuando se pruebe en Android: revisar reproducción e interacción real del globo,
pausa/reanudación, fluidez y consumo de memoria; comprobar teclado, TalkBack,
movimiento reducido, Atrás, login/registro/logout y restauración tras reiniciar.
Validar también la entrega del código de recuperación por notificación local
con los permisos de Android. No se realizó compilación Android ni se requieren
credenciales de Google para probar el acceso por correo.

La indicación anterior corresponde a la entrega inicial. Posteriormente se
autorizó la compilación y se verificaron arranque, globo nativo y navegación
básica en el celular; aún faltan las comprobaciones de accesibilidad, rendimiento
y autenticación con credenciales reales descritas arriba.
