import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/escom.dart';
import '../../core/theme/app_status_colors.dart';
import '../../data/models/user.dart';
import '../../features/splash/presentation/animated_circuit_logo.dart';
import 'remote_report_image.dart';

/// Breakpoint a partir del cual se usa el diseño para tablet (RNF1 - adaptativo).
const double kWideLayout = 700;

/// Limita el ancho del contenido en pantallas grandes para que no se estire.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = 560,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Foto del reporte o un ícono de la categoría si no tiene foto.
///
/// `cacheWidth` decodifica la imagen al tamaño en que se muestra, lo que reduce
/// mucho el uso de RAM en listas largas (RNF2 - Eficiencia de recursos).
class ReportImage extends StatelessWidget {
  const ReportImage({
    super.key,
    required this.path,
    required this.category,
    this.decodeWidth = 400,
    this.iconSize = 40,
    this.storagePath,
  });

  final String? path;
  final ItemCategory category;
  final int decodeWidth;
  final double iconSize;
  final String? storagePath;

  @override
  Widget build(BuildContext context) {
    final placeholder = _CategoryPlaceholder(
      category: category,
      size: iconSize,
    );
    if (path == null && storagePath != null) {
      return RemoteReportImage(
        storagePath: storagePath!,
        placeholder: placeholder,
      );
    }
    if (path == null) return placeholder;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      cacheWidth: (decodeWidth * ratio).round(),
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
        opacity: sync || frame != null ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );
  }
}

class _CategoryPlaceholder extends StatelessWidget {
  const _CategoryPlaceholder({required this.category, required this.size});

  final ItemCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(category.icon, size: size, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 24});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final size = (radius * 2 * ratio).round();
    ImageProvider? image;
    if (user.avatarPath != null) {
      image = ResizeImage(FileImage(File(user.avatarPath!)), width: size);
    } else if (user.avatarUrl != null) {
      image = ResizeImage(NetworkImage(user.avatarUrl!), width: size);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(
        user.initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Etiqueta de color "Perdido" / "Encontrado".
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type, this.dense = false});

  final ReportType type;
  final bool dense;

  @override
  Widget build(BuildContext context) => StatusBadge(
    state: type == ReportType.lost
        ? ItemVisualState.lost
        : ItemVisualState.found,
    dense: dense,
  );
}

/// Estilos de los cuatro estados, sin modificar el ciclo de vida del reporte.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.state,
    this.label,
    this.dense = false,
  });

  final ItemVisualState state;
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = AppStatusColors.of(context).forState(state);
    final (title, icon) = switch (state) {
      ItemVisualState.lost => ('Perdido', Icons.search_rounded),
      ItemVisualState.seen => ('Visto', Icons.visibility_outlined),
      ItemVisualState.found => ('Encontrado', Icons.volunteer_activism_rounded),
      ItemVisualState.delivered => ('Entregado', Icons.task_alt_rounded),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.foreground.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 16, color: colors.foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label ?? title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
                fontSize: dense ? 11 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de ubicación institucional, también legible en superficies oscuras.
class LocationTag extends StatelessWidget {
  const LocationTag({super.key, required this.location, this.dense = false});

  final String location;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place_outlined,
            size: dense ? 12 : 16,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSecondaryContainer,
                fontSize: dense ? 11 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Diálogo de confirmación previo a acciones destructivas (RF2).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Eliminar',
  bool destructive = true,
}) async {
  final colors = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Center(child: BrandDialogLogo()),
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  minimumSize: const Size(0, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class BrandDialogLogo extends StatelessWidget {
  const BrandDialogLogo({super.key});
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 650),
      builder: (_, value, _) => AnimatedCircuitLogo(
        progress: AlwaysStoppedAnimation(value),
        size: 76,
      ),
    );
  }
}

/// Hoja inferior para elegir entre cámara y galería. Devuelve `true` si es cámara.
Future<bool?> pickPhotoSource(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: error ? TextStyle(color: colors.onError) : null,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? colors.error : null,
      ),
    );
}
