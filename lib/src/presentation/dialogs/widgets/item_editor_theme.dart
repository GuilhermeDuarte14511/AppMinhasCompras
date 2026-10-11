import 'package:flutter/material.dart';

import '../../theme/editorial_workspace_theme.dart';

ThemeData itemEditorTheme(ThemeData base) {
  final theme = editorialWorkspaceTheme(base);
  final colors = theme.colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: colors.outlineVariant),
  );
  return theme.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.primary),
      ),
      labelStyle: theme.textTheme.bodySmall,
      hintStyle: theme.textTheme.bodySmall,
      prefixIconColor: colors.onSurfaceVariant,
      suffixIconColor: colors.onSurfaceVariant,
    ),
    textTheme: theme.textTheme.copyWith(
      bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 13),
    ),
  );
}
