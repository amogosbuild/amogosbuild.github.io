// Warm rose surfaces frame the supplied artwork in black and light themes.
import 'package:flutter/material.dart';

ThemeData storeTheme(bool dark) {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xffc96d73),
    brightness: dark ? Brightness.dark : Brightness.light,
    surface: dark ? const Color(0xff181314) : const Color(0xfffffaf7),
    primary: dark ? const Color(0xfff2a5a8) : const Color(0xffa63c49),
    onSurface: dark ? const Color(0xfffaf4f2) : const Color(0xff291d20),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: colors.brightness,
    colorScheme: colors,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: dark ? Colors.black : const Color(0xfffffaf7),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 28,
        color: colors.onSurface,
      ),
      titleLarge: const TextStyle(fontWeight: FontWeight.w800, fontSize: 23),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
    dividerColor: dark ? const Color(0xff3a2d30) : const Color(0xffe6d6d4),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff261d20) : const Color(0xfff5eae7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: TextStyle(
        color: colors.onInverseSurface,
        fontFamily: 'Manrope',
      ),
    ),
  );
}

Color cardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff302123)
    : const Color(0xfff4e7e3);
