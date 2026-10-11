import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

enum CatalogProductAction { addToPantry, edit, updatePrice, delete }

class CatalogProductRow extends StatelessWidget {
  const CatalogProductRow({
    super.key,
    required this.product,
    required this.batchMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });
  final CatalogProduct product;
  final bool batchMode, selected;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<CatalogProductAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (batchMode)
                Checkbox(value: selected, onChanged: (_) => onTap()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.category.label} · Uso: ${product.usageCount}${product.barcode?.isNotEmpty ?? false ? ' · ${product.barcode}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          product.unitPrice == null
                              ? 'Sem preço'
                              : formatCurrency(product.unitPrice!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Atualizado em ${formatShortDate(product.updatedAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!batchMode)
                PopupMenuButton<CatalogProductAction>(
                  tooltip: 'Ações do produto',
                  onSelected: onAction,
                  icon: const Icon(Icons.more_horiz, size: 18),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: CatalogProductAction.addToPantry,
                      child: Text('Adicionar à despensa'),
                    ),
                    PopupMenuItem(
                      value: CatalogProductAction.edit,
                      child: Text('Editar produto'),
                    ),
                    PopupMenuItem(
                      value: CatalogProductAction.updatePrice,
                      child: Text('Atualizar preço'),
                    ),
                    PopupMenuItem(
                      value: CatalogProductAction.delete,
                      child: Text('Excluir produto'),
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
