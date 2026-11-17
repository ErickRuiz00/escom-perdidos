# Acceso y navegación

La aplicación utiliza el tema institucional global en bienvenida, login,
registro y recuperación. No existe un tema oscuro local que reemplace la
preferencia general. Los tokens están documentados en [theme_palette.md](theme_palette.md).

Al arrancar se muestra la [splash de 2.7 segundos](splash_screen.md) en paralelo
con la restauración de sesión. Sin sesión se abre la bienvenida; con sesión
válida, HomeShell. Si la restauración tarda más, se espera en la splash.

AuthFlow conserva su Navigator con bienvenida (`/`), correo (`/login`), registro
(`/register`) y recuperación (`/forgot-password`). Login y registro se reemplazan;
Atrás vuelve a bienvenida. Recuperación se apila sobre login y vuelve a él.
Al autenticar se desmonta toda la pila de acceso. Logout crea una bienvenida
nueva, sin reproducir la splash. Cambiar de tema conserva la ruta y los campos.

La animación de objetos escolares fue eliminada por petición del usuario:
widget ParticleGlobe y respaldo, selectores, créditos, archivos Rive original
y adaptado, herramienta de adaptación y dependencias rive/rive_native. La
bienvenida mantiene solamente marca, textos y acciones de acceso. La animación
del circuito de la splash se conserva y utiliza solo Flutter.

Google sigue deshabilitado hasta configurar OAuth y backend. El acceso por
correo, registro, validación y recuperación conservan su lógica y servicios.
Los formularios permiten desplazarse con teclado y texto ampliado.
