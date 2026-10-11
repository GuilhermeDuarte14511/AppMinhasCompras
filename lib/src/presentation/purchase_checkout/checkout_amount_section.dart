import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/purchase_checkout_review.dart';
import '../../core/utils/format_utils.dart';
import '../dialogs/widgets/brl_currency_input_formatter.dart';

/// Displays calculated and receipt totals; checkout owns validation and state.
class CheckoutTotalsSection extends StatelessWidget {
  const CheckoutTotalsSection({
    super.key,
    required this.review,
    required this.receiptController,
    required this.receiptFormatter,
    required this.onReceiptChanged,
    required this.changeFinalTotal,
    required this.onChangeFinalTotal,
  });

  final PurchaseCheckoutReview review;
  final TextEditingController receiptController;
  final BrlCurrencyInputFormatter receiptFormatter;
  final ValueChanged<String> onReceiptChanged;
  final bool changeFinalTotal;
  final ValueChanged<bool> onChangeFinalTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final difference = review.differenceCents;
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: scheme.outline),
    );
    final helper = difference == null
        ? 'Informe um valor final maior que zero para continuar.'
        : difference == 0
        ? 'Valor final igual ao total dos itens'
        : 'Ajuste de ${formatCurrency(difference.abs() / 100)} no valor final. Os preços dos itens permanecem iguais.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'VALORES',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Total calculado', style: theme.textTheme.bodyMedium),
            ),
            Text(
              formatCurrency(review.calculatedTotalCents / 100),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alterar valor final'),
            value: changeFinalTotal,
            onChanged: onChangeFinalTotal,
          ),
        ),
        if (changeFinalTotal) ...[
          const SizedBox(height: 8),
          TextField(
            controller: receiptController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              receiptFormatter,
            ],
            onChanged: onReceiptChanged,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: 'Valor final pago',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: '0,00',
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              border: outline,
              enabledBorder: outline,
              focusedBorder: outline.copyWith(
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                helper,
                key: ValueKey(
                  difference == null
                      ? 'receipt-not-informed'
                      : difference == 0
                      ? 'receipt-matches'
                      : 'receipt-differs',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
