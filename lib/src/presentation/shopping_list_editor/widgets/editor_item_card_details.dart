import 'package:flutter/material.dart';

import '../../../domain/models_and_utils.dart';
import '../../theme/app_tokens.dart';

class EditorItemCardDetails extends StatelessWidget {
  const EditorItemCardDetails({
    super.key,
    required this.item,
    required this.readOnly,
    required this.onIncrement,
    required this.onDecrement,
  });

  final ShoppingItem item;
  final bool readOnly;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barcode = item.barcode?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 14),
        Row(
          children: [
            Text(
              'Quantidade',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _QuantityStepper(
              quantity: item.quantity,
              enabled: !readOnly,
              onIncrement: onIncrement,
              onDecrement: onDecrement,
            ),
          ],
        ),
        if (barcode.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  barcode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final bool enabled;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir quantidade',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: enabled && quantity > 1 ? onDecrement : null,
            icon: const Icon(Icons.remove_rounded, size: 20),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar quantidade',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: enabled ? onIncrement : null,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
