import 'dart:math';

import 'package:flutter/material.dart';

import '../application/finance_integration.dart';
import '../application/purchase_checkout_review.dart';
import '../domain/models_and_utils.dart';
import 'dialogs/widgets/brl_currency_input_formatter.dart';
import 'purchase_checkout/checkout_finance_section.dart';
import 'purchase_checkout/checkout_item_editor_dialog.dart';
import 'purchase_checkout/checkout_review_widgets.dart';
import 'theme/editorial_workspace_theme.dart';
import 'utils/app_modal.dart';

Future<PurchaseCheckoutResult?> showPurchaseCheckoutDialog(
  BuildContext context, {
  required ShoppingListModel list,
  FinanceWorkspace? financeWorkspace,
  String? financeLoadError,
}) {
  return showAppDialog<PurchaseCheckoutResult>(
    context: context,
    builder: (_) => PurchaseCheckoutDialog(
      list: list,
      financeWorkspace: financeWorkspace,
      financeLoadError: financeLoadError,
    ),
  );
}

class PurchaseCheckoutDialog extends StatefulWidget {
  const PurchaseCheckoutDialog({
    super.key,
    required this.list,
    this.financeWorkspace,
    this.financeLoadError,
  });

  final ShoppingListModel list;
  final FinanceWorkspace? financeWorkspace;
  final String? financeLoadError;

  @override
  State<PurchaseCheckoutDialog> createState() => _PurchaseCheckoutDialogState();
}

class _PurchaseCheckoutDialogState extends State<PurchaseCheckoutDialog> {
  late List<ShoppingItem> _items;
  final _receiptController = TextEditingController();
  final _receiptFormatter = BrlCurrencyInputFormatter();
  bool _changeFinalTotal = false;
  bool _includePending = false;
  bool _splitPayments = false;
  List<FinancePaymentAllocation>? _splitAllocations;
  late bool _sendToFinance;
  FinancePaymentSource? _selectedSource;
  String? _selectedCategoryId;

  List<FinancePaymentSource> get _sources =>
      widget.financeWorkspace?.availablePaymentSources ?? const [];

  int? get _receiptTotalCents {
    if (_receiptController.text.trim().isEmpty) return null;
    final value = BrlCurrencyInputFormatter.tryParse(_receiptController.text);
    if (value == null || !value.isFinite || value <= 0) return null;
    final cents = value * 100;
    return cents.isFinite ? cents.round() : null;
  }

  PurchaseCheckoutReview get _review => PurchaseCheckoutReview.calculate(
    items: _items,
    includePending: _includePending,
    receiptTotalCents: _changeFinalTotal ? _receiptTotalCents : null,
  );

  @override
  void initState() {
    super.initState();
    _items = widget.list.items
        .map((item) => item.copyWith())
        .toList(growable: false);
    final linkedSourceId = widget.list.paymentBalances
        .where((balance) => balance.financeSourceId != null)
        .firstOrNull
        ?.financeSourceId;
    _selectedSource =
        _sources.where((source) => source.id == linkedSourceId).firstOrNull ??
        _sources.firstOrNull;
    _sendToFinance = _sources.isNotEmpty;
    _selectedCategoryId = widget.financeWorkspace?.categories.firstOrNull?.id;
  }

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  bool get _selectedSourceHasFunds =>
      _selectedSource != null &&
      _selectedSource!.availableCents >= _review.finalTotalCents;

  bool get _paymentIsValid {
    if (!_sendToFinance) return true;
    if (_splitPayments) {
      return _splitAllocations != null &&
          _splitAllocations!.fold<int>(
                0,
                (sum, allocation) => sum + allocation.amountCents,
              ) ==
              _review.finalTotalCents;
    }
    return _selectedSourceHasFunds;
  }

  Future<void> _editItem(ShoppingItem item) async {
    final corrected = await showCheckoutItemEditor(context, item: item);
    if (!mounted || corrected == null) return;
    setState(() {
      _items = _items
          .map((entry) => entry.id == corrected.id ? corrected : entry)
          .toList(growable: false);
      _splitAllocations = null;
    });
  }

  void _confirm() {
    final source = _selectedSource;
    final allocations = !_sendToFinance
        ? const <FinancePaymentAllocation>[]
        : _splitPayments
        ? _splitAllocations!
        : <FinancePaymentAllocation>[
            FinancePaymentAllocation(
              sourceId: source!.id,
              sourceKind: source.kind.wireValue,
              sourceName: source.name,
              amountCents: _review.finalTotalCents,
            ),
          ];
    Navigator.pop(
      context,
      PurchaseCheckoutResult(
        markPendingAsPurchased: _includePending,
        reviewedItems: _items,
        finalTotalCents: _changeFinalTotal ? _review.finalTotalCents : null,
        sendToFinance: _sendToFinance,
        financeAllocations: allocations,
        financeCardId:
            _sendToFinance && source?.kind == FinancePaymentSourceKind.credit
            ? source?.id
            : null,
        financePaymentSourceId: _sendToFinance ? source?.id : null,
        financePaymentSourceKind: _sendToFinance
            ? source?.kind.wireValue
            : null,
        financeCategoryId: _sendToFinance ? _selectedCategoryId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final review = _review;
    final canClose =
        review.canFinalize &&
        (!_changeFinalTotal || _receiptTotalCents != null) &&
        _paymentIsValid;
    final editorial = editorialWorkspaceTheme(Theme.of(context));
    return Theme(
      data: editorial.copyWith(
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : editorial.colorScheme.outline,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? editorial.colorScheme.primary
                : editorial.colorScheme.outlineVariant.withValues(alpha: .3),
          ),
          trackOutlineColor: WidgetStatePropertyAll(
            editorial.colorScheme.outlineVariant,
          ),
        ),
        cardTheme: CardThemeData(
          color: editorial.colorScheme.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: editorial.colorScheme.outlineVariant),
          ),
        ),
        listTileTheme: ListTileThemeData(
          titleTextStyle: editorial.textTheme.bodySmall?.copyWith(
            color: editorial.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          subtitleTextStyle: editorial.textTheme.bodySmall?.copyWith(
            fontSize: 11,
          ),
        ),
        inputDecorationTheme: editorial.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: editorial.colorScheme.surfaceContainerLowest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: editorial.colorScheme.outlineVariant),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
      child: Dialog(
        backgroundColor: editorial.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: EdgeInsets.all(size.width < 600 ? 0 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: min(size.height * 0.96, 820),
          ),
          child: Column(
            children: [
              CheckoutHeader(
                listName: widget.list.name,
                onClose: () => Navigator.pop(context),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckoutTotalsSection(
                        review: review,
                        receiptController: _receiptController,
                        receiptFormatter: _receiptFormatter,
                        changeFinalTotal: _changeFinalTotal,
                        onChangeFinalTotal: (value) => setState(() {
                          _changeFinalTotal = value;
                          _splitAllocations = null;
                        }),
                        onReceiptChanged: (_) => setState(() {
                          _splitAllocations = null;
                        }),
                      ),
                      const SizedBox(height: 24),
                      CheckoutItemsSection(
                        items: _items,
                        review: review,
                        onEdit: _editItem,
                        pendingControl: _items.any((item) => !item.isPurchased)
                            ? SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _includePending,
                                onChanged: (value) => setState(() {
                                  _includePending = value;
                                  _splitAllocations = null;
                                }),
                                title: const Text('Incluir itens pendentes'),
                                subtitle: Text(
                                  _items
                                              .where(
                                                (item) => !item.isPurchased,
                                              )
                                              .length ==
                                          1
                                      ? '1 item será marcado como comprado.'
                                      : '${_items.where((item) => !item.isPurchased).length} itens serão marcados como comprados.',
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 24),
                      CheckoutFinanceSection(
                        review: review,
                        workspace: widget.financeWorkspace,
                        loadError: widget.financeLoadError,
                        sources: _sources,
                        sendToFinance: _sendToFinance,
                        splitPayments: _splitPayments,
                        selectedSource: _selectedSource,
                        selectedSourceHasFunds: _selectedSourceHasFunds,
                        selectedCategoryId: _selectedCategoryId,
                        splitAllocations: _splitAllocations,
                        onSendChanged: (value) =>
                            setState(() => _sendToFinance = value),
                        onSplitChanged: (value) => setState(() {
                          _splitPayments = value;
                          _splitAllocations = null;
                        }),
                        onSourceChanged: (id) => setState(() {
                          _selectedSource = _sources
                              .where((source) => source.id == id)
                              .firstOrNull;
                        }),
                        onCategoryChanged: (value) =>
                            setState(() => _selectedCategoryId = value),
                        onAllocationsChanged: (value) =>
                            setState(() => _splitAllocations = value),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              CheckoutFooter(
                canClose: canClose,
                onCancel: () => Navigator.pop(context),
                onConfirm: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
