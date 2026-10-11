import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models_and_utils.dart';
import '../../application/finance_integration.dart';
import '../../data/finance_integration_dependencies.dart';
import '../theme/editorial_workspace_theme.dart';
import '../utils/app_modal.dart';
import 'widgets/brl_currency_input_formatter.dart';
import 'widgets/funding_cards_section.dart';

Future<BudgetEditorResult?> showBudgetEditorDialog(
  BuildContext context, {
  double? initialValue,
  List<PaymentBalance> initialPaymentBalances = const [],
  FinanceIntegrationRepository? financeRepository,
}) => showAppDialog<BudgetEditorResult>(
  context: context,
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _BudgetEditorDialog(
      initialValue: initialValue,
      initialPaymentBalances: initialPaymentBalances,
      financeRepository: financeRepository,
    ),
  ),
);

class _BudgetEditorDialog extends StatefulWidget {
  const _BudgetEditorDialog({
    this.initialValue,
    required this.initialPaymentBalances,
    this.financeRepository,
  });
  final double? initialValue;
  final List<PaymentBalance> initialPaymentBalances;
  final FinanceIntegrationRepository? financeRepository;

  @override
  State<_BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<_BudgetEditorDialog> {
  late final _repository =
      widget.financeRepository ?? createFinanceIntegrationRepository();
  late List<PaymentBalance> _balances = List.of(widget.initialPaymentBalances);
  final _formKey = GlobalKey<FormState>();
  final _formatter = BrlCurrencyInputFormatter();
  late final _controller = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : _formatter.formatValue(widget.initialValue!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      BudgetEditorResult(
        value: BrlCurrencyInputFormatter.tryParse(_controller.text),
        paymentBalances: List.unmodifiable(_balances),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final buttonShape = RoundedRectangleBorder(
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
        constraints: const BoxConstraints(maxWidth: 390),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 8, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Orçamento da lista',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fechar',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 22),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Orçamento da lista',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const Key('budget_field'),
                              controller: _controller,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _formatter,
                              ],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              decoration: InputDecoration(
                                labelText: 'Orçamento da lista',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                hintText: 'R\$ 0,00',
                                filled: true,
                                fillColor: colors.surfaceContainerLowest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 2,
                                  ),
                                ),
                                errorMaxLines: 3,
                                contentPadding: const EdgeInsets.all(14),
                              ),
                              validator: (raw) {
                                final value =
                                    BrlCurrencyInputFormatter.tryParse(
                                      raw ?? '',
                                    );
                                return value == null ||
                                        !value.isFinite ||
                                        value <= 0
                                    ? 'Informe um valor válido.'
                                    : null;
                              },
                              onFieldSubmitted: (_) => _save(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Teto estimado para acompanhamento durante as compras.',
                              style: theme.textTheme.bodySmall,
                            ),
                            FundingCardsSection(
                              balances: _balances,
                              repository: _repository,
                              onChanged: (values) {
                                final oldTotal = _balances.fold<double>(
                                  0,
                                  (sum, item) => sum + item.value,
                                );
                                final current =
                                    BrlCurrencyInputFormatter.tryParse(
                                      _controller.text,
                                    );
                                setState(() {
                                  _balances = values;
                                  final total = values.fold<double>(
                                    0,
                                    (sum, item) => sum + item.value,
                                  );
                                  if (current == null ||
                                      (current - oldTotal).abs() < .005) {
                                    _controller.text = total > 0
                                        ? _formatter.formatValue(total)
                                        : '';
                                  }
                                });
                              },
                            ),
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
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: buttonShape,
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Salvar'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: buttonShape,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    if (widget.initialValue != null) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: colors.error,
                          shape: buttonShape,
                        ),
                        onPressed: () => Navigator.pop(
                          context,
                          const BudgetEditorResult(clear: true),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remover limite'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
