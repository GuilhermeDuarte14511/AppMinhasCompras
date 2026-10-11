import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../application/finance_integration.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';
import '../payment_source_picker_sheet.dart';
import '../theme/editorial_workspace_theme.dart';
import '../utils/app_modal.dart';
import 'widgets/brl_currency_input_formatter.dart';

Future<PaymentBalancesEditorResult?> showPaymentBalancesEditorDialog(
  BuildContext context, {
  List<PaymentBalance> initialValues = const <PaymentBalance>[],
  FinanceIntegrationRepository? financeRepository,
}) => showAppDialog<PaymentBalancesEditorResult>(
  context: context,
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _BalancesDialog(
      initialValues: initialValues,
      repository: financeRepository,
    ),
  ),
);

class _BalancesDialog extends StatefulWidget {
  const _BalancesDialog({required this.initialValues, this.repository});
  final List<PaymentBalance> initialValues;
  final FinanceIntegrationRepository? repository;
  @override
  State<_BalancesDialog> createState() => _BalancesDialogState();
}

class _BalancesDialogState extends State<_BalancesDialog> {
  late final List<PaymentBalance> _working = widget.initialValues
      .map((entry) => entry.copyWith())
      .toList();
  Future<void> _add() async {
    if (widget.repository != null) {
      final selection = await showPaymentSourcePickerSheet(
        context,
        repository: widget.repository!,
      );
      if (!mounted || selection == null) return;
      if (!selection.addManually && selection.balance != null) {
        setState(() => _working.add(selection.balance!));
        return;
      }
    }
    if (!mounted) return;
    final value = await _showPaymentBalanceEntryDialog(context);
    if (mounted && value != null) setState(() => _working.add(value));
  }

  Future<void> _edit(int index) async {
    final value = await _showPaymentBalanceEntryDialog(
      context,
      initialValue: _working[index],
    );
    if (mounted && value != null) setState(() => _working[index] = value);
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _working.length) return;
    setState(() => _working.insert(to, _working.removeAt(from)));
  }

  void _save() => Navigator.pop(
    context,
    PaymentBalancesEditorResult(
      value: List<PaymentBalance>.unmodifiable(_working),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 22),
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Saldos de pagamento',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: Text(
                              'Defina a ordem de desconto dos saldos para acompanhar o pagamento da lista.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Prioridade de desconto',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Use as setas para ordenar.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          if (_working.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'Nenhum saldo configurado ainda.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          else
                            for (
                              var index = 0;
                              index < _working.length;
                              index++
                            )
                              _entry(index, theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: shape,
                    ),
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Novo saldo'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: shape,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: shape,
                          ),
                          onPressed: _save,
                          child: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                  if (_working.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: colors.error,
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        const PaymentBalancesEditorResult(clear: true),
                      ),
                      child: const Text('Limpar saldos'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(int index, ThemeData theme) {
    final entry = _working[index];
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${index + 1}ª prioridade',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Text(entry.type.label, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    formatCurrency(entry.value),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _action(
                        'Mover para cima',
                        Icons.keyboard_arrow_up,
                        index == 0 ? null : () => _move(index, index - 1),
                      ),
                      _action(
                        'Mover para baixo',
                        Icons.keyboard_arrow_down,
                        index == _working.length - 1
                            ? null
                            : () => _move(index, index + 1),
                      ),
                      _action(
                        'Editar',
                        Icons.edit_outlined,
                        () => _edit(index),
                      ),
                      _action(
                        'Remover',
                        Icons.delete_outline,
                        () => setState(() => _working.removeAt(index)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _action(String label, IconData icon, VoidCallback? action) =>
      IconButton(
        tooltip: label,
        onPressed: action,
        icon: Icon(icon, size: 20),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      );
}

Future<PaymentBalance?> _showPaymentBalanceEntryDialog(
  BuildContext context, {
  PaymentBalance? initialValue,
}) => showAppDialog<PaymentBalance>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .45),
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _BalanceEntryDialog(initialValue: initialValue),
  ),
);

class _BalanceEntryDialog extends StatefulWidget {
  const _BalanceEntryDialog({this.initialValue});
  final PaymentBalance? initialValue;
  @override
  State<_BalanceEntryDialog> createState() => _BalanceEntryDialogState();
}

class _BalanceEntryDialogState extends State<_BalanceEntryDialog> {
  final formKey = GlobalKey<FormState>();
  final formatter = BrlCurrencyInputFormatter();
  late final nameController = TextEditingController(
    text: widget.initialValue?.name ?? '',
  );
  late final amountController = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : formatter.formatValue(widget.initialValue!.value),
  );
  late var selectedType = widget.initialValue?.type ?? PaymentBalanceType.card;
  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (formKey.currentState?.validate() != true) return;
    final amount = BrlCurrencyInputFormatter.tryParse(amountController.text);
    if (amount == null || !amount.isFinite || amount <= 0) return;
    Navigator.pop(
      context,
      PaymentBalance(
        id: widget.initialValue?.id ?? uniqueId(),
        name: nameController.text.trim(),
        type: selectedType,
        amount: amount,
        financeSourceId: widget.initialValue?.financeSourceId,
        financeSourceKind: widget.initialValue?.financeSourceKind,
      ),
    );
  }

  String _typeLabel(PaymentBalanceType type) => switch (type) {
    PaymentBalanceType.card => 'Cartão de crédito',
    PaymentBalanceType.debit => 'Débito / Conta corrente',
    PaymentBalanceType.foodVoucher => 'Vale alimentação (VA)',
    PaymentBalanceType.mealVoucher => 'Vale refeição (VR)',
    PaymentBalanceType.pix => 'Pix',
    PaymentBalanceType.voucher => 'Voucher',
    PaymentBalanceType.cash => 'Dinheiro',
    PaymentBalanceType.other => 'Outro saldo',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final borderColor = dark ? colors.outlineVariant : const Color(0xFFD9DCD3);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: borderColor),
    );
    InputDecoration decoration({String? hint}) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
      errorMaxLines: 2,
    );
    Widget field(String label, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(label: label, child: child),
      ],
    );
    final actionShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: dark ? colors.surface : const Color(0xFFF7F5EF),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 358),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            widget.initialValue == null
                                ? 'Novo saldo'
                                : 'Editar saldo',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 24),
                        field(
                          'Nome',
                          TextFormField(
                            key: const Key('balance_entry_name'),
                            controller: nameController,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                            ),
                            decoration: decoration(hint: 'Ex.: VR Alimentação'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Informe um nome.'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        field(
                          'Tipo',
                          DropdownButtonFormField<PaymentBalanceType>(
                            key: const Key('balance_entry_type'),
                            initialValue: selectedType,
                            isExpanded: true,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                            ),
                            decoration: decoration(),
                            items: PaymentBalanceType.values
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(_typeLabel(type)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedType = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        field(
                          'Saldo disponível',
                          TextFormField(
                            key: const Key('balance_entry_amount'),
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _save(),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              formatter,
                            ],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            decoration: decoration(hint: 'R\$ 0,00'),
                            validator: (value) {
                              final parsed = BrlCurrencyInputFormatter.tryParse(
                                value ?? '',
                              );
                              return parsed == null ||
                                      !parsed.isFinite ||
                                      parsed <= 0
                                  ? 'Informe um saldo válido.'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Valor inicial para controle de compras',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      foregroundColor: colors.onSurface,
                      shape: actionShape,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      backgroundColor: const Color(0xFF365943),
                      foregroundColor: Colors.white,
                      shape: actionShape,
                    ),
                    onPressed: _save,
                    child: const Text('Salvar'),
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
