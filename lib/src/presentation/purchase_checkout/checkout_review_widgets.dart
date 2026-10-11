import 'package:flutter/material.dart';

export 'checkout_amount_section.dart' show CheckoutTotalsSection;
export 'checkout_items_section.dart' show CheckoutItemsSection;
import '../theme/app_tokens.dart';

class CheckoutHeader extends StatelessWidget {
  const CheckoutHeader({
    super.key,
    required this.listName,
    required this.onClose,
  });

  final String listName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fechamento de compra',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
                ),
                Text('Conferir compra', style: theme.textTheme.bodySmall),
                Text(
                  listName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fechar conferência',
            onPressed: onClose,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

class CheckoutFooter extends StatelessWidget {
  const CheckoutFooter({
    super.key,
    required this.canClose,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool canClose;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: canClose ? onConfirm : null,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirmar fechamento'),
          ),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class CheckoutSectionTitle extends StatelessWidget {
  const CheckoutSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Divider(
          height: 12,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: AppTokens.spaceXs),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class CheckoutFinanceImpact extends StatelessWidget {
  const CheckoutFinanceImpact({
    super.key,
    required this.sourceKinds,
    required this.enabled,
  });

  final Iterable<String> sourceKinds;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const Text('Nenhum lançamento será enviado ao Minhas Finanças.');
    }
    final kinds = sourceKinds.toSet();
    final onlyBenefits =
        kinds.isNotEmpty &&
        kinds.every((kind) => kind == 'foodVoucher' || kind == 'mealVoucher');
    final hasBenefits = kinds.any(
      (kind) => kind == 'foodVoucher' || kind == 'mealVoucher',
    );
    final message = kinds.isEmpty
        ? 'Conclua a divisão para conferir o impacto de cada pagamento.'
        : onlyBenefits
        ? 'VA e VR atualizam apenas o saldo do benefício. Não reduzem o saldo previsto do mês.'
        : hasBenefits
        ? 'VA e VR não reduzem o saldo previsto. A parte em crédito ou débito entra na previsão do mês.'
        : 'Crédito e débito entram no saldo previsto do mês.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.account_balance_wallet_outlined, size: 18),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(child: Text(message)),
      ],
    );
  }
}
