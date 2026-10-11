import 'dart:async';

import 'package:flutter/material.dart';

import '../application/fiscal_receipt_import.dart';
import '../domain/models_and_utils.dart';
import 'dialogs/sheets/fiscal_receipt_import_sheet.dart';
import 'dialogs/sheets/replenishment_suggestions_sheet.dart';
import 'theme/editorial_workspace_theme.dart';
import 'utils/app_modal.dart';

export 'dialogs/payment_balances_editor_dialog.dart'
    show showPaymentBalancesEditorDialog;
export 'dialogs/reminder_editor_dialog.dart' show showReminderEditorDialog;
export 'dialogs/list_name_dialog.dart'
    show showListNameDialog, showListSetupDialog, ListSetupResult;
export 'dialogs/budget_editor_dialog.dart' show showBudgetEditorDialog;
export 'dialogs/sheets/barcode_scanner_sheet.dart' show showBarcodeScannerSheet;
export 'dialogs/sheets/shopping_item_editor_sheet.dart';
export 'dialogs/sheets/voice_quick_add_sheet.dart';
export 'dialogs/sheets/template_picker_sheet.dart' show showTemplatePickerSheet;
export 'dialogs/widgets/brl_currency_input_formatter.dart';
export 'purchase_checkout_dialog.dart' show showPurchaseCheckoutDialog;
export 'purchase_checkout_completion_dialog.dart'
    show showPurchaseCompletionDialog;

Future<List<ReplenishmentSuggestion>?> showReplenishmentSuggestionsSheet(
  BuildContext context, {
  required List<ReplenishmentSuggestion> suggestions,
}) {
  final theme = editorialWorkspaceTheme(Theme.of(context));
  return showAppModalBottomSheet<List<ReplenishmentSuggestion>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (context) =>
        ReplenishmentSuggestionsSheet(suggestions: suggestions),
  );
}

Future<FiscalReceiptReviewSubmission?> showFiscalReceiptImportSheet(
  BuildContext context, {
  List<ShoppingItem> currentItems = const <ShoppingItem>[],
  List<CatalogProduct> catalogProducts = const <CatalogProduct>[],
}) {
  return showAppModalBottomSheet<FiscalReceiptReviewSubmission>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (context) => FiscalReceiptImportSheet(
      currentItems: currentItems,
      catalogProducts: catalogProducts,
    ),
  );
}
