import 'package:flutter/material.dart';

import '../../application/finance_integration.dart';
import '../../application/purchase_checkout_review.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';
import '../finance_split_payment_editor.dart';
import '../theme/app_tokens.dart';
import 'checkout_review_widgets.dart';

class CheckoutFinanceSection extends StatelessWidget {
  const CheckoutFinanceSection({
    super.key,
    required this.review,
    required this.sources,
    required this.sendToFinance,
    required this.splitPayments,
    required this.selectedSource,
    required this.selectedSourceHasFunds,
    required this.selectedCategoryId,
    required this.splitAllocations,
    required this.onSendChanged,
    required this.onSplitChanged,
    required this.onSourceChanged,
    required this.onCategoryChanged,
    required this.onAllocationsChanged,
    this.workspace,
    this.loadError,
  });

  final PurchaseCheckoutReview review;
  final FinanceWorkspace? workspace;
  final String? loadError;
  final List<FinancePaymentSource> sources;
  final bool sendToFinance;
  final bool splitPayments;
  final FinancePaymentSource? selectedSource;
  final bool selectedSourceHasFunds;
  final String? selectedCategoryId;
  final List<FinancePaymentAllocation>? splitAllocations;
  final ValueChanged<bool> onSendChanged;
  final ValueChanged<bool> onSplitChanged;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<List<FinancePaymentAllocation>?> onAllocationsChanged;

  @override
  Widget build(BuildContext context) {
    final currentWorkspace = workspace;
    if (currentWorkspace == null) return _buildUnavailable();
    final impactKinds = splitPayments
        ? splitAllocations?.map((allocation) => allocation.sourceKind) ??
              const <String>[]
        : [selectedSource?.kind.wireValue ?? ''];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lançamento financeiro',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          key: const ValueKey('checkout_send_to_finance'),
          contentPadding: EdgeInsets.zero,
          value: sendToFinance,
          onChanged: sources.isEmpty ? null : onSendChanged,
          title: const Text('Lançar no Minhas Finanças'),
          subtitle: const Text(
            'Envia uma única vez após confirmar o fechamento.',
          ),
        ),
        const Divider(height: 1),
        if (sendToFinance && sources.isNotEmpty) ...[
          if (sources.length > 1) ...[
            _buildSplitToggle(),
            const Divider(height: 1),
          ],
          const SizedBox(height: 12),
          if (splitPayments)
            _buildSplitEditor()
          else
            _buildSourcePicker(context),
          if (currentWorkspace.categories.isNotEmpty)
            _buildCategoryPicker(context, currentWorkspace),
        ],
        const SizedBox(height: AppTokens.spaceSm),
        if (sources.isEmpty)
          const Text(
            'Nenhum meio de pagamento disponível. A compra pode ser fechada sem lançamento financeiro.',
          ),
        const SizedBox(height: AppTokens.spaceMd),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: CheckoutFinanceImpact(
            sourceKinds: impactKinds,
            enabled: sendToFinance,
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailable() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CheckoutSectionTitle(
        title: 'Lançamento financeiro',
        subtitle: 'Confira onde esta compra será registrada.',
      ),
      const SizedBox(height: AppTokens.spaceSm),
      if (loadError == null)
        const Text('O Minhas Finanças não está conectado.')
      else
        SelectableText('$loadError A compra ainda pode ser fechada.'),
    ],
  );

  Widget _buildSplitToggle() => SwitchListTile.adaptive(
    key: const ValueKey('checkout_split_payment'),
    contentPadding: EdgeInsets.zero,
    value: splitPayments,
    onChanged: onSplitChanged,
    title: const Text('Dividir pagamento'),
    subtitle: const Text('Combine VA, VR, débito ou crédito.'),
  );

  Widget _buildSplitEditor() => FinanceSplitPaymentEditor(
    key: ValueKey(review.finalTotalCents),
    sources: sources,
    totalCents: review.finalTotalCents,
    preferredSourceId: selectedSource?.id,
    onChanged: onAllocationsChanged,
  );

  Widget _buildSourcePicker(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _fieldLabel(context, 'MEIO DE PAGAMENTO'),
      const SizedBox(height: 6),
      Semantics(
        label: 'Meio de pagamento',
        child: DropdownButtonFormField<String>(
          key: const ValueKey('checkout_payment_source'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontFamily: 'MercadoPublicSans'),
          initialValue: selectedSource?.id,
          isExpanded: true,
          decoration: _fieldDecoration(context, Icons.credit_card_outlined),
          items: sources
              .map(
                (source) => DropdownMenuItem(
                  value: source.id,
                  child: Text(
                    '${source.name} (${source.kind.label})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onSourceChanged,
        ),
      ),
      if (selectedSource != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Disponível: ${formatCurrency(selectedSource!.availableCents / 100)}',
            key: const ValueKey('checkout_source_available'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selectedSourceHasFunds
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      if (!selectedSourceHasFunds)
        Padding(
          padding: const EdgeInsets.only(top: AppTokens.spaceSm),
          child: Text(
            'O valor disponível não cobre esta compra.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );

  Widget _buildCategoryPicker(
    BuildContext context,
    FinanceWorkspace currentWorkspace,
  ) => Padding(
    padding: const EdgeInsets.only(top: AppTokens.spaceMd),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(context, 'CATEGORIA'),
        const SizedBox(height: 6),
        Semantics(
          label: 'Categoria',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('checkout_finance_category'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontFamily: 'MercadoPublicSans'),
            initialValue: selectedCategoryId,
            isExpanded: true,
            hint: const Text('Sem categoria'),
            decoration: _fieldDecoration(context, Icons.shopping_bag_outlined),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Sem categoria'),
              ),
              ...currentWorkspace.categories.map(
                (category) => DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => onCategoryChanged(value == '' ? null : value),
          ),
        ),
      ],
    ),
  );

  Widget _fieldLabel(BuildContext context, String label) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );

  InputDecoration _fieldDecoration(BuildContext context, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20, color: colors.primary),
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    );
  }
}
