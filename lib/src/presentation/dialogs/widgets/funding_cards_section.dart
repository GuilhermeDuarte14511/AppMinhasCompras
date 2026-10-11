import 'package:flutter/material.dart';
import '../../../application/finance_integration.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import '../payment_balances_editor_dialog.dart';

class FundingCardsSection extends StatelessWidget {
  const FundingCardsSection({
    super.key,
    required this.balances,
    required this.repository,
    required this.onChanged,
  });
  final List<PaymentBalance> balances;
  final FinanceIntegrationRepository repository;
  final ValueChanged<List<PaymentBalance>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      Text(
        'Cartões e saldos para esta compra',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      const Text(
        'Selecione um ou mais cartões do Minhas Finanças e o valor que pretende usar de cada um.',
      ),
      for (final balance in balances)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${balance.name} · ${formatCurrency(balance.value)}'),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          final result = await showPaymentBalancesEditorDialog(
            context,
            initialValues: balances,
            financeRepository: repository,
          );
          if (!context.mounted || result == null) return;
          onChanged(result.clear ? [] : result.value ?? []);
        },
        icon: const Icon(Icons.credit_card_outlined),
        label: const Text('Selecionar cartões'),
      ),
    ],
  );
}
