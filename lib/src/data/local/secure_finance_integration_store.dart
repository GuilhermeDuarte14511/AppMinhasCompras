import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../../application/finance_integration.dart';
import '../../core/utils/id_utils.dart';

class SecureFinanceIntegrationStore implements FinanceIntegrationStore {
  SecureFinanceIntegrationStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _tokenKey = 'finance_integration_token_v1';
  static const _pendingKey = 'finance_integration_pending_purchases_v1';

  static const _journalKey = 'finance_integration_purchase_sync_v1';
  static const _connectionKey = 'finance_integration_connection_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> writeToken(String value) async {
    // Invalidate the old binding before replacing credentials: never replay
    // a previous connection's purchase into a newly linked household.
    await _storage.write(key: _connectionKey, value: uniqueId());
    await _storage.write(key: _tokenKey, value: value);
  }

  @override
  Future<String> readConnectionId() async {
    final existing = await _storage.read(key: _connectionKey);
    if (existing != null) return existing;
    final generated = uniqueId();
    await _storage.write(key: _connectionKey, value: generated);
    return generated;
  }

  @override
  Future<List<FinancePurchaseSync>> readPurchaseSync() async {
    final encoded = await _storage.read(key: _journalKey);
    if (encoded == null) return [];
    // Fail closed on corruption; never silently discard accounting receipts.
    final values = jsonDecode(encoded) as List;
    return values
        .map(
          (value) => FinancePurchaseSync.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> writePurchaseSync(List<FinancePurchaseSync> purchases) =>
      _storage.write(
        key: _journalKey,
        value: jsonEncode(purchases.map((r) => r.toJson()).toList()),
      );

  @override
  Future<List<FinancePurchaseRequest>> readPendingPurchases() async {
    final encoded = await _storage.read(key: _pendingKey);
    if (encoded == null || encoded.isEmpty) return const [];
    final decoded = jsonDecode(encoded) as List;
    return decoded
        .map(
          (item) => FinancePurchaseRequest.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> writePendingPurchases(List<FinancePurchaseRequest> purchases) {
    if (purchases.isEmpty) return _storage.delete(key: _pendingKey);
    return _storage.write(
      key: _pendingKey,
      value: jsonEncode(
        purchases.map((purchase) => purchase.toJson()).toList(growable: false),
      ),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    // Keep the journal and pending requests for review in purchase history.
  }
}
