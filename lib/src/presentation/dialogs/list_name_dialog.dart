import 'package:flutter/material.dart';
import '../../domain/models_and_utils.dart';
import '../../data/finance_integration_dependencies.dart';
import '../../application/finance_integration.dart';
import '../../core/utils/format_utils.dart';
import 'budget_editor_dialog.dart';

import '../theme/editorial_workspace_theme.dart';
import '../utils/app_modal.dart';

class ListSetupResult {
  const ListSetupResult({
    required this.name,
    this.budget,
    this.paymentBalances = const [],
  });
  final String name;
  final double? budget;
  final List<PaymentBalance> paymentBalances;
}

Future<ListSetupResult?> showListSetupDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialValue = '',
  double? initialBudget,
  List<PaymentBalance> initialPaymentBalances = const [],
  FinanceIntegrationRepository? financeRepository,
}) => showAppDialog<ListSetupResult>(
  context: context,
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _ListNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
      configureFunding: true,
      initialBudget: initialBudget,
      initialPaymentBalances: initialPaymentBalances,
      financeRepository: financeRepository,
    ),
  ),
);

Future<String?> showListNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialValue = '',
}) => showAppDialog<String>(
  context: context,
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _ListNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  ),
);

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialValue,
    this.configureFunding = false,
    this.initialBudget,
    this.initialPaymentBalances = const [],
    this.financeRepository,
  });

  final String title;
  final String confirmLabel;
  final String initialValue;
  final bool configureFunding;
  final double? initialBudget;
  final List<PaymentBalance> initialPaymentBalances;
  final FinanceIntegrationRepository? financeRepository;

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialValue);
  late double? _budget = widget.initialBudget;
  late List<PaymentBalance> _balances = List.of(widget.initialPaymentBalances);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      widget.configureFunding
          ? ListSetupResult(
              name: _name.text.trim(),
              budget: _budget,
              paymentBalances: List.unmodifiable(_balances),
            )
          : _name.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
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
                        padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    widget.title,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fechar',
                              constraints: const BoxConstraints(
                                minHeight: 48,
                                minWidth: 48,
                              ),
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: colors.outlineVariant),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'NOME DA LISTA *',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: .5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const Key('list_name_field'),
                              controller: _name,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Nome da lista',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                hintText: 'Ex.: Compras da semana',
                                filled: true,
                                fillColor: colors.surfaceContainerLowest,
                                border: border,
                                enabledBorder: border,
                                focusedBorder: border.copyWith(
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                errorMaxLines: 3,
                              ),
                              style: theme.textTheme.bodyLarge,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Digite um nome para a lista.'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (widget.configureFunding) ...[
                              const SizedBox(height: 16),
                              if (_budget != null)
                                Text('Orçamento: ${formatCurrency(_budget!)}'),
                              for (final balance in _balances)
                                Text(
                                  '${balance.name} · ${formatCurrency(balance.value)}',
                                ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await showBudgetEditorDialog(
                                    context,
                                    initialValue: _budget,
                                    initialPaymentBalances: _balances,
                                    financeRepository:
                                        widget.financeRepository ??
                                        createFinanceIntegrationRepository(),
                                  );
                                  if (!mounted || result == null) return;
                                  setState(() {
                                    _budget = result.clear
                                        ? null
                                        : result.value;
                                    _balances =
                                        result.paymentBalances ?? _balances;
                                  });
                                },
                                icon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                label: Text(
                                  _budget == null
                                      ? 'Definir orçamento e cartões'
                                      : 'Editar orçamento e cartões',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: buttonShape,
                        textStyle: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: _submit,
                      child: Text(
                        widget.confirmLabel,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: buttonShape,
                        textStyle: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
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
