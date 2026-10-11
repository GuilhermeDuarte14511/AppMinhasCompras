import 'package:flutter/material.dart';

ThemeData mercadoEditorialTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final colors = base.colorScheme.copyWith(
    surface: dark ? const Color(0xFF20231E) : const Color(0xFFFBF9F3),
    surfaceContainerLow: dark
        ? const Color(0xFF30312D)
        : const Color(0xFFF5F3ED),
    surfaceContainerLowest: dark ? const Color(0xFF30312D) : Colors.white,
    onSurface: dark ? const Color(0xFFF3F1EB) : const Color(0xFF1B1C18),
    onSurfaceVariant: dark ? const Color(0xFFC4C9B4) : const Color(0xFF5B604F),
    primary: dark ? const Color(0xFFA9D0B4) : const Color(0xFF1F412D),
    outlineVariant: dark ? const Color(0xFF60685D) : const Color(0xFFC1C8C1),
  );
  final text = base.textTheme.apply(
    fontFamily: 'MercadoPublicSans',
    bodyColor: colors.onSurface,
    displayColor: colors.onSurface,
  );
  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    textTheme: text.copyWith(
      titleLarge: TextStyle(
        fontFamily: 'MercadoNewsreader',
        fontSize: 24,
        height: 1.25,
        letterSpacing: -.6,
        color: colors.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: 'MercadoNewsreader',
        fontSize: 18,
        height: 1.375,
        letterSpacing: -.25,
        color: colors.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: 'MercadoPublicSans',
        fontSize: 12,
        height: 1.5,
        letterSpacing: 0,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: 'MercadoPublicSans',
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: colors.onSurface,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'MercadoNewsreader',
        fontSize: 24,
        color: colors.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1F412D),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(
          fontFamily: 'MercadoPublicSans',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.outlineVariant),
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(
          fontFamily: 'MercadoPublicSans',
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
  );
}
