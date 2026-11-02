// Material 3 surfaces provide distinct light and pitch-black appearances.
import 'package:flutter/material.dart';

const pink = Color(0xFFF067AD);
const purple = Color(0xFF8757F3);
const installGradient = LinearGradient(
  colors: [pink, purple],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData installerTheme(bool dark) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: purple,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        surface: dark ? Colors.black : const Color(0xFFFAF9FD),
        surfaceContainerLowest: dark ? Colors.black : Colors.white,
        surfaceContainerLow: dark
            ? const Color(0xFF101014)
            : const Color(0xFFF2EFF9),
        surfaceContainer: dark
            ? const Color(0xFF17171C)
            : const Color(0xFFEEEBF6),
        outlineVariant: dark
            ? const Color(0xFF2A2932)
            : const Color(0xFFE6E1EF),
        primary: dark ? const Color(0xFFC4ACFF) : const Color(0xFF7542DB),
        onSurface: dark ? const Color(0xFFF5F2FA) : const Color(0xFF24212D),
        onSurfaceVariant: dark
            ? const Color(0xFFA7A2B2)
            : const Color(0xFF777180),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Manrope',
    brightness: dark ? Brightness.dark : Brightness.light,
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -1.8,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: scheme.onSurfaceVariant,
      ),
      bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: scheme.onSurface),
      labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
  );
}
