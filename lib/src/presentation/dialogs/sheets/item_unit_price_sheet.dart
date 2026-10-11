import 'package:flutter/material.dart';

import '../../utils/app_modal.dart';
import '../../theme/editorial_workspace_theme.dart';
import '../widgets/brl_currency_input_formatter.dart';

Future<double?> showItemUnitPriceSheet(
  BuildContext context, {
  required String name,
  required double unitPrice,
}) => showAppModalBottomSheet<double>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: editorialWorkspaceTheme(
    Theme.of(context),
  ).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
  ),
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _ItemUnitPriceSheet(name: name, unitPrice: unitPrice),
  ),
);

class _ItemUnitPriceSheet extends StatefulWidget {
  const _ItemUnitPriceSheet({required this.name, required this.unitPrice});
  final String name;
  final double unitPrice;

  @override
  State<_ItemUnitPriceSheet> createState() => _ItemUnitPriceSheetState();
}

class _ItemUnitPriceSheetState extends State<_ItemUnitPriceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _formatter = BrlCurrencyInputFormatter();
  late final _price = TextEditingController(
    text: _formatter.formatValue(widget.unitPrice),
  );

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, BrlCurrencyInputFormatter.tryParse(_price.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (constraints.maxHeight - inset).clamp(
              0,
              double.infinity,
            ),
          ),
          child: SafeArea(
            top: false,
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Atualizar preço unitário',
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
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Nome do item',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLow,
                                    border: Border.all(
                                      color: colors.outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Preço unitário',
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 6),
                                Semantics(
                                  label: 'Preço unitário',
                                  child: TextFormField(
                                    key: const Key('market_price_field'),
                                    controller: _price,
                                    autofocus: true,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [_formatter],
                                    decoration: InputDecoration(
                                      labelText: 'Preço unitário',
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
                                      hintText: '0,00',
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                    ),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    validator: (raw) {
                                      final value =
                                          BrlCurrencyInputFormatter.tryParse(
                                            raw ?? '',
                                          );
                                      return value == null ||
                                              !value.isFinite ||
                                              value <= 0
                                          ? 'Informe um preço maior que zero.'
                                          : null;
                                    },
                                    onFieldSubmitted: (_) => _submit(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Valor de uma unidade do produto para calcular o subtotal.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _submit,
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('Atualizar preço'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
        ),
      ),
    );
  }
}
