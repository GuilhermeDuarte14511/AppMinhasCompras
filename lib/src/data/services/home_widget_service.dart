import 'dart:async';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../application/ports.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';
import '../../domain/pantry.dart';

class NoopShoppingHomeWidgetService implements ShoppingHomeWidgetService {
  const NoopShoppingHomeWidgetService();

  @override
  Future<void> updateSnapshot({
    required List<ShoppingListModel> lists,
    required List<PantryItem> pantryItems,
  }) async {}
}

class AndroidShoppingHomeWidgetService implements ShoppingHomeWidgetService {
  const AndroidShoppingHomeWidgetService();

  static const String _summaryProviderClass =
      'com.example.lista_compras_material.ShoppingSummaryWidgetProvider';
  static const String _focusProviderClass =
      'com.example.lista_compras_material.ShoppingFocusListWidgetProvider';

  static const String _kTotalLists = 'widget_total_lists';
  static const String _kPendingItems = 'widget_pending_items';
  static const String _kTotalValue = 'widget_total_value';
  static const String _kUpdatedAt = 'widget_updated_at';
  static const String _kPantryAttentionCount = 'widget_pantry_attention_count';
  static const String _kPantryPreview = 'widget_pantry_preview';

  static const String _kFocusTitle = 'widget_focus_title';
  static const String _kFocusListId = 'widget_focus_list_id';
  static const String _kFocusDetails = 'widget_focus_details';
  static const String _kFocusPendingPreview = 'widget_focus_pending_preview';
  static const String _kFocusTotal = 'widget_focus_total';
  static const String _kFocusBudget = 'widget_focus_budget';
  static const Duration _minimumUpdateInterval = Duration(milliseconds: 700);

  static Future<void> _writeQueue = Future<void>.value();
  static String? _lastPayloadSignature;
  static DateTime? _lastUpdateAt;

  @override
  Future<void> updateSnapshot({
    required List<ShoppingListModel> lists,
    required List<PantryItem> pantryItems,
  }) {
    final snapshot = List<ShoppingListModel>.unmodifiable(
      List<ShoppingListModel>.from(lists),
    );
    final pantrySnapshot = List<PantryItem>.unmodifiable(
      pantryItems.map((item) => item.copyWith()),
    );
    _writeQueue = _writeQueue
        .catchError((_) {})
        .then((_) => _performUpdate(snapshot, pantrySnapshot));
    return _writeQueue;
  }

  Future<void> _performUpdate(
    List<ShoppingListModel> lists,
    List<PantryItem> pantryItems,
  ) async {
    try {
      final totalLists = lists.length;
      final pendingItems = lists.fold<int>(
        0,
        (sum, list) =>
            sum +
            list.items
                .where((item) => !item.isPurchased)
                .fold<int>(0, (acc, item) => acc + item.quantity),
      );
      final totalValue = lists.fold<double>(
        0,
        (sum, list) => sum + list.totalValue,
      );
      final pantryAttention = pantryItems
          .where((item) => item.needsRestock)
          .toList(growable: false);
      final pantryAttentionCount = pantryAttention.length;
      final pantryPreview = pantryAttention.isEmpty
          ? 'Despensa: tudo em ordem'
          : 'Despensa: ${pantryAttention.take(2).map((item) => item.name.trim()).join(' • ')}';

      final focus = _selectFocusList(lists);
      final focusTitle = focus?.name ?? 'Nenhuma lista criada';
      final focusListId = focus?.id ?? '';
      final focusDetails = focus == null
          ? 'Crie uma lista para aparecer aqui.'
          : '${focus.totalItems} itens - ${focus.purchasedItemsCount} comprados';
      final focusPendingPreview = focus == null
          ? 'Toque no microfone para começar uma lista.'
          : _formatPendingPreview(focus);
      final focusTotal = focus == null
          ? formatCurrency(0)
          : 'Total: ${formatCurrency(focus.totalValue)}';
      final focusBudget = focus == null
          ? 'Orçamento: não definido'
          : _formatBudgetLine(focus);

      final totalValueLabel = formatCurrency(totalValue);
      final updatedAtLabel = formatDateTime(DateTime.now());
      final payloadSignature = [
        totalLists,
        pendingItems,
        totalValueLabel,
        focusTitle,
        focusListId,
        focusDetails,
        focusPendingPreview,
        focusTotal,
        focusBudget,
        pantryAttentionCount,
        pantryPreview,
      ].join('|');

      if (_lastPayloadSignature == payloadSignature &&
          _lastUpdateAt != null &&
          DateTime.now().difference(_lastUpdateAt!) < _minimumUpdateInterval) {
        return;
      }

      final now = DateTime.now();
      if (_lastUpdateAt != null) {
        final elapsed = now.difference(_lastUpdateAt!);
        if (elapsed < _minimumUpdateInterval) {
          await Future<void>.delayed(_minimumUpdateInterval - elapsed);
        }
      }

      await HomeWidget.saveWidgetData<int>(_kTotalLists, totalLists);
      await HomeWidget.saveWidgetData<int>(_kPendingItems, pendingItems);
      await HomeWidget.saveWidgetData<String>(_kTotalValue, totalValueLabel);
      await HomeWidget.saveWidgetData<String>(_kUpdatedAt, updatedAtLabel);
      await HomeWidget.saveWidgetData<int>(
        _kPantryAttentionCount,
        pantryAttentionCount,
      );
      await HomeWidget.saveWidgetData<String>(_kPantryPreview, pantryPreview);
      await HomeWidget.saveWidgetData<String>(_kFocusTitle, focusTitle);
      await HomeWidget.saveWidgetData<String>(_kFocusListId, focusListId);
      await HomeWidget.saveWidgetData<String>(_kFocusDetails, focusDetails);
      await HomeWidget.saveWidgetData<String>(
        _kFocusPendingPreview,
        focusPendingPreview,
      );
      await HomeWidget.saveWidgetData<String>(_kFocusTotal, focusTotal);
      await HomeWidget.saveWidgetData<String>(_kFocusBudget, focusBudget);

      await HomeWidget.updateWidget(
        qualifiedAndroidName: _summaryProviderClass,
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: _focusProviderClass);
      _lastPayloadSignature = payloadSignature;
      _lastUpdateAt = DateTime.now();
    } on MissingPluginException {
      // Non-Android platforms and tests.
    } on PlatformException {
      // Best-effort update. Never block app flow on widget channel failure.
    } catch (_) {
      // Widget updates are best-effort and should never break app flow.
    }
  }

  ShoppingListModel? _selectFocusList(List<ShoppingListModel> lists) {
    if (lists.isEmpty) {
      return null;
    }

    final openLists = lists.where((list) => !list.isClosed).toList();
    final candidates = openLists.isEmpty ? lists : openLists;
    final withReminder = candidates
        .where((list) => list.reminder != null)
        .toList();
    if (withReminder.isNotEmpty) {
      withReminder.sort(
        (a, b) => a.reminder!.scheduledAt.compareTo(b.reminder!.scheduledAt),
      );
      return withReminder.first;
    }

    final sorted = [...candidates]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.first;
  }

  String _formatPendingPreview(ShoppingListModel list) {
    final pending = list.items
        .where((item) => !item.isPurchased)
        .take(3)
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (pending.isEmpty) {
      return 'Todos os itens foram marcados.';
    }
    return pending.join(' • ');
  }

  String _formatBudgetLine(ShoppingListModel list) {
    if (!list.hasBudget) {
      return 'Orçamento: não definido';
    }
    if (list.isOverBudget) {
      return 'Acima do orçamento: ${formatCurrency(list.overBudgetAmount)}';
    }
    return 'Saldo do orçamento: ${formatCurrency(list.budgetRemaining)}';
  }
}
