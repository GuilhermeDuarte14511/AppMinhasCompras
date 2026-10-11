import 'package:flutter/material.dart';

import 'mercado_editorial_theme.dart';

ThemeData editorialWorkspaceTheme(ThemeData base) {
  final theme = mercadoEditorialTheme(base);
  final colors = theme.colorScheme;
  return theme.copyWith(
    colorScheme: colors.copyWith(
      secondaryContainer: colors.brightness == Brightness.dark
          ? const Color(0xFF444939)
          : const Color(0xFFE0E5CF),
      onSecondaryContainer: colors.onSurface,
      primaryContainer: colors.brightness == Brightness.dark
          ? const Color(0xFF2B4E39)
          : const Color(0xFFC4ECCF),
      onPrimaryContainer: colors.onSurface,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(
          fontFamily: 'MercadoPublicSans',
          fontSize: 12,
        ),
      ),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      hintStyle: theme.textTheme.bodySmall,
      labelStyle: theme.textTheme.bodySmall,
      prefixIconColor: colors.onSurfaceVariant,
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: theme.textTheme.bodySmall,
      selectedColor: colors.brightness == Brightness.dark
          ? const Color(0xFF444939)
          : const Color(0xFFE0E5CF),
      backgroundColor: colors.surfaceContainerLow,
      side: BorderSide(color: colors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}
