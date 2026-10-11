import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models_and_utils.dart';
import '../dialogs/widgets/brl_currency_input_formatter.dart';
import '../theme/editorial_workspace_theme.dart';
import '../utils/app_modal.dart';

Future<ShoppingItem?> showCheckoutItemEditor(
  BuildContext context, {
  required ShoppingItem item,
}) => showAppDialog<ShoppingItem>(
  context: context,
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _CheckoutItemEditor(item: item),
  ),
);

class _CheckoutItemEditor extends StatefulWidget {
  const _CheckoutItemEditor({required this.item});
  final ShoppingItem item;

  @override
  State<_CheckoutItemEditor> createState() => _CheckoutItemEditorState();
}

class _CheckoutItemEditorState extends State<_CheckoutItemEditor> {
  final _formKey = GlobalKey<FormState>();
  final _formatter = BrlCurrencyInputFormatter();
  late final _quantityController = TextEditingController(
    text: '${widget.item.quantity}',
  );
  late final _priceController = TextEditingController(
    text: _formatter.formatValue(widget.item.unitPrice),
  );
  late bool _purchased = widget.item.isPurchased;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _apply() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      widget.item.copyWith(
        quantity: int.parse(_quantityController.text),
        unitPrice: BrlCurrencyInputFormatter.tryParse(_priceController.text),
        isPurchased: _purchased,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      errorMaxLines: 3,
    );
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Corrigir ${widget.item.name}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                ),
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
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Quantidade', style: labelStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('checkout_item_quantity'),
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: decoration('Quantidade'),
                        validator: (value) {
                          final quantity = int.tryParse(value ?? '');
                          return quantity == null || quantity < 1
                              ? 'Informe uma quantidade válida.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Valor unitário', style: labelStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('checkout_item_price'),
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _formatter,
                        ],
                        decoration: decoration('Valor unitário'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        onFieldSubmitted: (_) => _apply(),
                        validator: (value) {
                          final price = BrlCurrencyInputFormatter.tryParse(
                            value ?? '',
                          );
                          return price == null || !price.isFinite || price <= 0
                              ? 'Informe um valor maior que zero.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        visualDensity: VisualDensity.compact,
                        value: _purchased,
                        onChanged: (value) =>
                            setState(() => _purchased = value ?? false),
                        title: Text(
                          'Item comprado',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cancel = TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: shape,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    );
                    final apply = FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: shape,
                      ),
                      onPressed: _apply,
                      child: const Text('Aplicar correção'),
                    );
                    if (constraints.maxWidth < 245 ||
                        MediaQuery.textScalerOf(context).scale(14) > 18) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [apply, const SizedBox(height: 4), cancel],
                      );
                    }
                    return Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [cancel, apply],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
