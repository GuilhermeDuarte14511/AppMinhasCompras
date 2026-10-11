import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/models_and_utils.dart';

/// Serializes local writes so a slow save cannot overwrite a newer cart.
class MarketShoppingSession extends ChangeNotifier {
  MarketShoppingSession({
    required ShoppingListModel initialList,
    required this.onSave,
  }) : _list = initialList.deepCopy();

  final Future<void> Function(ShoppingListModel) onSave;
  ShoppingListModel _list;
  Future<void> _saveTail = Future.value();
  int _revision = 0;
  int _savedRevision = 0;
  Object? _saveError;
  bool _disposed = false;

  ShoppingListModel get list => _list;
  bool get hasUnsavedChanges => _savedRevision != _revision;
  bool get isSaving => hasUnsavedChanges && _saveError == null;
  Object? get saveError => _saveError;

  void updateItem(ShoppingItem item) {
    if (_list.isClosed) return;
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) return;
    final items = [..._list.items];
    items[index] = item;
    _change(_list.copyWith(items: items));
  }

  void updateBalances(List<PaymentBalance> balances) {
    if (_list.isClosed) return;
    final total = balances.fold<double>(0, (sum, item) => sum + item.value);
    final budget = balances.isEmpty
        ? _list.budget
        : _list.budget == null
        ? total
        : max<double>(0, _list.budget! + total - _list.paymentBalancesTotal);
    _change(_list.copyWith(paymentBalances: balances, budget: budget));
  }

  void _change(ShoppingListModel list) {
    _list = list.copyWith(updatedAt: DateTime.now());
    _revision++;
    _enqueueSave();
  }

  void retrySave() {
    if (hasUnsavedChanges && !isSaving) _enqueueSave();
  }

  void _enqueueSave() {
    final snapshot = _list.deepCopy();
    final revision = _revision;
    _saveError = null;
    _saveTail = _saveTail.then((_) async {
      try {
        await onSave(snapshot);
        _savedRevision = revision;
        if (revision == _revision) _saveError = null;
      } catch (error) {
        if (revision == _revision) _saveError = error;
      }
      if (!_disposed) notifyListeners();
    });
    if (!_disposed) notifyListeners();
  }

  Future<bool> flush() async {
    await _saveTail;
    return !hasUnsavedChanges;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
