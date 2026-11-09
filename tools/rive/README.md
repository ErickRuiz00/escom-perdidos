# Adaptación del globo Rive

```powershell
node tools/rive/retarget_globe.cjs
```

El script produce `assets/animations/particle_globe.riv` a partir de la copia
original verificada en `assets/animations/source/particle_globe.original.riv`.
No requiere paquetes npm ni conexión a Rive Editor.

Lee el formato binario de Rive 7 con su tabla de tipos, conserva exactamente los
assets y bytecode Luau originales y reemplaza los siete artboards gráficos.
Se mantienen sus nombres y orden para respetar las referencias del script.
El relleno verde se convierte en transparente y el radio pasa de 130 a 162.

Los siete iconos nuevos se construyen con trazados, rectángulos, elipses y
rellenos vectoriales. No se superponen imágenes para ocultar los ojos.
`ParticleGlobe` controla `changeIcon` mediante Data Binding: valores 1 a 7.
Los selectores permiten elegir lápiz, cuaderno y laptop; tocar el globo recorre
también mochila, audífonos, llaves y botella. El script original maneja el giro.

Se verifica la integridad del original, lectura completa, generación determinista,
ocho artboards, siete referencias de iconos, script sin cambios y ausencia del
relleno verde. La comprobación en el runtime de Android sigue siendo necesaria
después de cualquier nueva modificación de los objetos exportados.

Especificación y propiedades consultadas en el código oficial de Rive:

- https://github.com/rive-app/rive-runtime/blob/main/include/rive/runtime_header.hpp
- https://github.com/rive-app/rive-runtime/tree/main/include/rive/generated
- https://github.com/rive-app/help-center/blob/master/runtimes/advanced_topics/format.md

Autor y licencia del archivo de origen: ver `assets/animations/ATTRIBUTION.md`.
