import 'package:flutter/material.dart';

import '../../domain/models_and_utils.dart';
import '../theme/editorial_workspace_theme.dart';
import '../utils/app_modal.dart';

Future<bool?> showDeleteItemDialog(
  BuildContext context, {
  required ShoppingItem item,
}) => showAppDialog<bool>(
  context: context,
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _DeleteItemDialog(item: item),
  ),
);

class _DeleteItemDialog extends StatelessWidget {
  const _DeleteItemDialog({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final destructive = dark
        ? const Color(0xFFF4B0A4)
        : const Color(0xFFA44438);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? colors.outlineVariant : const Color(0xFFE6E2D8),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                namesRoute: true,
                header: true,
                child: Text(
                  'Excluir item?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    letterSpacing: -.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Deseja remover ‘${item.name}’ da lista?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.6,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: buttonShape,
                      textStyle: const TextStyle(
                        fontFamily: 'MercadoPublicSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: destructive,
                      foregroundColor: dark
                          ? const Color(0xFF39120C)
                          : Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: buttonShape,
                      textStyle: const TextStyle(
                        fontFamily: 'MercadoPublicSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Excluir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
