# Compilación Android con memoria limitada

## Error observado

El comando de desarrollo utiliza Flutter 3.32.8 / Dart 3.8.1:

```powershell
& "$HOME\development\flutter_3.32.8\bin\flutter.bat" run -d RFCX51BSMHR --no-pub
```

El fallo original ocurría en `:gradle:compileKotlin`, al compilar las
herramientas Gradle de Flutter. Kotlin intentaba iniciar otra JVM y Windows
respondía `Could not reserve enough space for object heap` y error **1455**
(archivo de paginación insuficiente). Los archivos `hs_err_pid*.log`
confirmaban el agotamiento de memoria nativa/virtual.

## Ajustes del proyecto

En `android/gradle.properties`:

- Heap de Gradle de 1536 MB, con 128 MB iniciales, en lugar del presupuesto
  anterior de 8 GB; metaspace limitado a 512 MB.
- Un trabajador, sin ejecución paralela de proyectos.
- Kotlin se ejecuta dentro del proceso de Gradle. La propiedad con prefijo
  `systemProp.org.gradle.project` también alcanza el build incluido de
  `flutter_tools`, responsable de `:gradle:compileKotlin`.
- El proceso de Gradle termina después de cada compilación para liberar memoria.

En `android/gradlew.bat`, el lanzador utiliza 64 MB de heap, en lugar de dejar
que Java seleccione un presupuesto proporcional a la memoria del equipo. Este
límite corresponde al lanzador; el proceso de compilación tiene el presupuesto
independiente descrito arriba.
El wrapper está excluido de Git por `android/.gitignore`; este ajuste del
lanzador es local a la computadora.

**Precedencia:** `C:\Users\migue\.gradle\gradle.properties` ya contenía un heap
de 2 GB. Gradle da prioridad a ese archivo sobre las propiedades del proyecto;
por tanto, en esta computadora el heap efectivo sigue siendo de 2 GB. No se
modificó ese archivo global ni la configuración de paginación de Windows.

Antes de validar se detuvieron los daemons de Gradle 8.12 y otros procesos
Gradle antiguos iniciados por VS Code (7.5, 8.13 y 9.7.1). No se eliminaron
cachés ni se ejecutó `flutter clean`, para conservar la compilación incremental.

Si se vuelve a acumular memoria en procesos Gradle, se puede detener la versión
del proyecto, sin borrar sus cachés:

```powershell
& .\android\gradlew.bat --stop
```

Ese comando requiere que `JAVA_HOME` apunte a un JDK compatible. Flutter usa el
JDK 17 ya instalado para compilar este proyecto.

## Verificación en el dispositivo

Con autorización del usuario se ejecutó:

```powershell
& "$HOME\development\flutter_3.32.8\bin\flutter.bat" run -d RFCX51BSMHR --no-pub --no-resident
```

La opción `--no-resident` cierra la sesión de depuración tras abrir la app;
la compilación e instalación son las mismas que con el comando habitual.

- `assembleDebug`: correcto, aproximadamente 121 segundos.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Instalación en Samsung SM A356E / Android 14 / arm64: correcta, 9 segundos.
- Proceso de la app activo tras el arranque.
- Biblioteca `librive_native.so`: cargada correctamente. El globo del archivo
  `.riv` se muestra en el dispositivo; no se utilizó el respaldo estático.
- Navegación comprobada sin introducir credenciales: bienvenida → correo →
  registro → Atrás del sistema → bienvenida. La app quedó en la bienvenida.
- No se crearon usuarios, no se eliminaron datos y no se cambiaron credenciales.

El arranque registra un aviso de `flutter_secure_storage` al intentar descifrar
claves antiguas de `EncryptedSharedPreferences`, seguido del fallback interno
del plugin. La app abre y permite navegar. No se borró el almacenamiento para
silenciarlo; el acceso con una cuenta existente y la persistencia de su sesión
no formaron parte de esta prueba sin credenciales.

También se observó un aviso de versión de XML del SDK Android, sin impedir la
compilación. No se actualizaron Flutter, Java, Gradle, el SDK ni dependencias.

## Referencias

- [Propiedades y precedencia de Gradle](https://docs.gradle.org/current/userguide/build_environment.html).
- [Estrategia de ejecución del compilador Kotlin](https://kotlinlang.org/docs/compiler-execution-strategy.html).
