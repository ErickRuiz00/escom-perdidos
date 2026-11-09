import 'package:flutter/material.dart';

/// Tema exclusivo del acceso; no cambia las pantallas de la aplicación.
class AuthTheme extends StatelessWidget {
  const AuthTheme({super.key, required this.child});

  final Widget child;

  static const background = Color(0xFF170F17);
  static const accent = Color(0xFFE5B6CC);

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C1D45),
          brightness: Brightness.dark,
        ).copyWith(
          primary: accent,
          onPrimary: const Color(0xFF351526),
          surface: background,
          onSurface: const Color(0xFFF8F1F5),
          onSurfaceVariant: const Color(0xFFC4B4BF),
        );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF51404E)),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: scheme,
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF241B25),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: accent, width: 2),
          ),
          errorBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.error),
          ),
          focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.error, width: 2),
          ),
          contentPadding: const EdgeInsets.all(18),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(48, 48),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: scheme.onPrimary,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.onSurface,
            side: const BorderSide(color: Color(0xFF776070)),
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}
