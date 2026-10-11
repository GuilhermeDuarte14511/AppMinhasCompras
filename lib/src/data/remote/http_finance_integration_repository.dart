import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/finance_integration.dart';

class HttpFinanceIntegrationRepository implements FinanceIntegrationRepository {
  HttpFinanceIntegrationRepository({
    required this.baseUri,
    required FinanceIntegrationStore store,
    http.Client? client,
  }) : _store = store,
       _client = client ?? http.Client();

  final Uri baseUri;
  final FinanceIntegrationStore _store;
  final http.Client _client;

  @override
  Future<bool> isConnected() async {
    final token = await _store.readToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<FinanceIntegrationConnection> connect(String code) =>
      _serialized(() => _connect(code));

  Future<FinanceIntegrationConnection> _connect(String code) async {
    // Bind legacy pending requests to their original credentials before relinking.
    await _records();
    final response = await _send(
      () => _client.post(
        _uri('/v1/link/exchange'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'code': code.trim()}),
      ),
    );
    final body = _successBody(response);
    final token = _requiredString(body, 'token');
    final integration = _requiredMap(body, 'integration');
    await _store.writeToken(token);
    return FinanceIntegrationConnection(
      id: _requiredString(integration, 'id'),
      householdId: _requiredString(integration, 'householdId'),
      householdName: _requiredString(integration, 'householdName'),
      ownerName: _requiredString(integration, 'ownerName'),
      permissions: _stringList(integration['permissions']),
    );
  }

  @override
  Future<void> disconnect() => _serialized(_store.clear);

  @override
  Future<FinanceWorkspace> loadWorkspace() async {
    final token = await _requireToken();
    final response = await _send(
      () => _client.get(
        _uri('/v1/payment-sources'),
        headers: {'authorization': 'Bearer $token'},
      ),
    );
    final body = _successBody(response);
    final household = _requiredMap(body, 'household');
    final rawCards = _requiredList(body, 'cards');
    final rawPaymentSources = body['paymentSources'];
    final rawCategories = _requiredList(body, 'categories');
    return FinanceWorkspace(
      householdId: _requiredString(household, 'id'),
      householdName: _requiredString(household, 'name'),
      cards: rawCards.map(_parseCard).toList(growable: false),
      paymentSources: rawPaymentSources is List
          ? rawPaymentSources.map(_parsePaymentSource).toList(growable: false)
          : const [],
      categories: rawCategories.map(_parseCategory).toList(growable: false),
      asOf: DateTime.parse(_requiredString(body, 'asOf')),
    );
  }

  @override
  Future<FinancePaymentSource> createPaymentSource(
    FinancePaymentSourceRequest request,
  ) async {
    final token = await _requireToken();
    final response = await _send(
      () => _client.post(
        _uri('/v1/payment-sources'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ),
    );
    return _parsePaymentSource(
      _requiredMap(_successBody(response), 'paymentSource'),
    );
  }

  @override
  Future<String> connectionId() => _serialized(() async {
    await _requireToken();
    return _store.readConnectionId();
  });

  // Shared by repository instances: page changes must not race queue writes.
  static Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<FinancePurchaseSync>> _records() async {
    final records = [...await _store.readPurchaseSync()];
    final legacy = await _store.readPendingPurchases();
    if (legacy.isNotEmpty) {
      final binding = await _store.readConnectionId();
      for (final request in legacy) {
        if (!records.any(
          (r) => r.request.externalPurchaseId == request.externalPurchaseId,
        )) {
          records.add(
            FinancePurchaseSync(
              purchaseId: request.externalPurchaseId,
              sourceName: request.paymentSourceKind.label,
              request: request,
              connectionId: binding,
            ),
          );
        }
      }
      await _save(records);
    }
    return records;
  }

  Future<void> _save(List<FinancePurchaseSync> records) async {
    // Journal first. A crash before updating the legacy queue cannot lose a receipt.
    await _store.writePurchaseSync(records);
    await _store.writePendingPurchases(
      records
          .where((r) => r.status != FinanceSyncStatus.synced)
          .map((r) => r.request)
          .toList(growable: false),
    );
  }

  @override
  Future<List<FinancePurchaseSync>> purchaseSyncHistory() =>
      _serialized(_records);

  @override
  Future<void> submitPurchasePlan(
    List<FinancePurchaseSync> plan,
  ) => _serialized(() async {
    if (plan.isEmpty ||
        plan.length > 5 ||
        plan.any(
          (r) =>
              r.purchaseId != plan.first.purchaseId ||
              r.request.amountCents <= 0,
        ) ||
        plan.map((r) => r.request.externalPurchaseId).toSet().length !=
            plan.length) {
      throw const FinanceIntegrationException(
        'Divisão de pagamento inválida.',
        retryable: false,
      );
    }
    await _requireToken();
    final binding = await _store.readConnectionId();
    if (plan.any(
      (r) => r.connectionId.isNotEmpty && r.connectionId != binding,
    )) {
      throw const FinanceIntegrationException(
        'Este fechamento pertence à conexão original de outro aparelho ou vínculo. Confira no Finanças antes de ajustar.',
        retryable: false,
        code: 'CONNECTION_CHANGED',
      );
    }
    final records = await _records();
    final previous = records
        .where((r) => r.purchaseId == plan.first.purchaseId)
        .toList();
    if (previous.isNotEmpty) {
      if (previous.length != plan.length ||
          plan.any(
            (part) => !previous.any(
              (r) =>
                  r.connectionId == binding &&
                  jsonEncode(r.request.toJson()) ==
                      jsonEncode(part.request.toJson()),
            ),
          )) {
        throw const FinanceIntegrationException(
          'Este fechamento já tem um envio registrado. Reenvie pelo histórico sem alterar os pagamentos.',
          retryable: false,
          code: 'IMMUTABLE_PAYMENT_PLAN',
        );
      }
    } else {
      records.addAll(plan.map((r) => r.copyWith(connectionId: binding)));
      await _save(records);
    }
    await _retryRecords(
      records,
      purchaseId: plan.first.purchaseId,
      includeAttention: true,
    );
  });

  @override
  Future<FinancePurchaseSubmission> submitPurchase(
    FinancePurchaseRequest purchase,
  ) async {
    await submitPurchasePlan([
      FinancePurchaseSync(
        purchaseId: purchase.externalPurchaseId,
        sourceName: purchase.paymentSourceKind.label,
        request: purchase,
      ),
    ]);
    final record = (await purchaseSyncHistory()).firstWhere(
      (r) => r.request.externalPurchaseId == purchase.externalPurchaseId,
    );
    if (record.status == FinanceSyncStatus.attention) {
      throw FinanceIntegrationException(
        record.message ?? 'Não foi possível lançar a compra.',
        retryable: false,
      );
    }
    return FinancePurchaseSubmission(
      queued: record.status != FinanceSyncStatus.synced,
      financialEntryId: record.financialEntryId,
      accountMovementId: record.accountMovementId,
      cardChargeId: record.cardChargeId,
      invoiceId: record.invoiceId,
      created: record.created,
    );
  }

  @override
  Future<int> pendingPurchaseCount() => _serialized(
    () async => (await _records())
        .where((r) => r.status != FinanceSyncStatus.synced)
        .length,
  );

  @override
  Future<void> retryPurchase(String purchaseId) => _serialized(() async {
    await _retryRecords(
      await _records(),
      purchaseId: purchaseId,
      includeAttention: true,
    );
  });

  @override
  Future<int> retryPendingPurchases() =>
      _serialized(() async => _retryRecords(await _records()));

  Future<int> _retryRecords(
    List<FinancePurchaseSync> records, {
    String? purchaseId,
    bool includeAttention = false,
  }) async {
    final binding = await _store.readConnectionId();
    var successful = 0;
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (record.status == FinanceSyncStatus.synced ||
          (purchaseId != null && record.purchaseId != purchaseId) ||
          (!includeAttention && record.status == FinanceSyncStatus.attention)) {
        continue;
      }
      if (record.connectionId != binding) {
        records[index] = record.copyWith(
          status: FinanceSyncStatus.attention,
          message:
              'A conexão original foi alterada. Confira o lançamento no Finanças antes de qualquer ajuste.',
        );
      } else {
        try {
          final receipt = await _postPurchase(record.request);
          records[index] = record.copyWith(
            status: FinanceSyncStatus.synced,
            receipt: receipt,
          );
          successful++;
        } on FinanceIntegrationException catch (error) {
          records[index] = record.copyWith(
            status: error.retryable
                ? FinanceSyncStatus.pending
                : FinanceSyncStatus.attention,
            message: error.message,
          );
        }
      }
      // Persist each acknowledgment before attempting another payment source.
      await _save(records);
    }
    return successful;
  }

  Future<FinancePurchaseSubmission> _postPurchase(
    FinancePurchaseRequest purchase,
  ) async {
    final token = await _requireToken();
    final response = await _send(
      () => _client.post(
        _uri('/v1/purchases'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(purchase.toJson()),
      ),
    );
    final body = _successBody(response);
    if (body['financialEntryId'] is! String ||
        (body['financialEntryId'] as String).isEmpty) {
      throw const FinanceIntegrationException(
        'O Finanças não confirmou o comprovante. O envio será consultado novamente.',
        retryable: true,
        code: 'INVALID_RECEIPT',
      );
    }
    return FinancePurchaseSubmission(
      queued: false,
      created: body['created'] as bool? ?? false,
      financialEntryId: body['financialEntryId'] as String?,
      cardChargeId: body['cardChargeId'] as String?,
      invoiceId: body['invoiceId'] as String?,
      accountMovementId: body['accountMovementId'] as String?,
    );
  }

  Future<String> _requireToken() async {
    final token = await _store.readToken();
    if (token == null || token.isEmpty) {
      throw const FinanceIntegrationException(
        'Conecte o Minhas Finanças para continuar.',
        retryable: false,
        code: 'NOT_CONNECTED',
      );
    }
    return token;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 20));
    } on FinanceIntegrationException {
      rethrow;
    } catch (_) {
      throw const FinanceIntegrationException(
        'Sem conexão com o Minhas Finanças. Tentaremos novamente depois.',
        retryable: true,
        code: 'NETWORK_ERROR',
      );
    }
  }

  Map<String, dynamic> _successBody(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    Map<String, dynamic> body;
    try {
      body = _decodeBody(response.body);
    } on FormatException {
      if (isSuccess) {
        throw const FinanceIntegrationException(
          'O Minhas Finanças retornou uma resposta inválida.',
          retryable: false,
          code: 'INVALID_RESPONSE',
        );
      }
      body = <String, dynamic>{};
    }
    if (isSuccess) return body;
    final rawError = body['error'];
    final error = rawError is Map
        ? Map<String, dynamic>.from(rawError)
        : const <String, dynamic>{};
    final message =
        error['message'] as String? ??
        'Não foi possível concluir a integração financeira.';
    throw FinanceIntegrationException(
      message,
      retryable: response.statusCode == 429 || response.statusCode >= 500,
      code: error['code'] as String?,
    );
  }

  Uri _uri(String path) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final suffix = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(
      path: '$basePath$suffix',
      query: null,
      fragment: null,
    );
  }
}

FinanceCard _parseCard(dynamic value) {
  final json = _asMap(value);
  final rawInvoice = json['currentInvoice'];
  final invoice = rawInvoice is Map
      ? _parseInvoice(Map<String, dynamic>.from(rawInvoice))
      : null;
  return FinanceCard(
    id: _requiredString(json, 'id'),
    name: _requiredString(json, 'name'),
    holderName: json['holderName'] as String?,
    lastDigits: _requiredString(json, 'lastDigits'),
    closingDay: _requiredInt(json, 'closingDay'),
    dueDay: _requiredInt(json, 'dueDay'),
    limitCents: _requiredInt(json, 'limitCents'),
    usedCents: _requiredInt(json, 'usedCents'),
    availableCents: _requiredInt(json, 'availableCents'),
    colorHex: _requiredString(json, 'colorHex'),
    currentInvoice: invoice,
  );
}

FinancePaymentSource _parsePaymentSource(dynamic value) {
  final json = _asMap(value);
  return FinancePaymentSource(
    id: _requiredString(json, 'id'),
    kind: FinancePaymentSourceKind.fromWireValue(_requiredString(json, 'kind')),
    name: _requiredString(json, 'name'),
    lastDigits: json['lastDigits'] as String?,
    availableCents: _requiredInt(json, 'availableCents'),
    colorHex: _requiredString(json, 'colorHex'),
    limitCents: (json['limitCents'] as num?)?.toInt(),
    usedCents: (json['usedCents'] as num?)?.toInt(),
    closingDay: (json['closingDay'] as num?)?.toInt(),
    dueDay: (json['dueDay'] as num?)?.toInt(),
  );
}

FinanceCardInvoice _parseInvoice(Map<String, dynamic> json) {
  return FinanceCardInvoice(
    id: _requiredString(json, 'id'),
    totalCents: _requiredInt(json, 'totalCents'),
    dueOn: DateTime.parse(_requiredString(json, 'dueOn')),
  );
}

FinanceCategory _parseCategory(dynamic value) {
  final json = _asMap(value);
  return FinanceCategory(
    id: _requiredString(json, 'id'),
    name: _requiredString(json, 'name'),
    iconKey: _requiredString(json, 'iconKey'),
    colorHex: _requiredString(json, 'colorHex'),
  );
}

Map<String, dynamic> _decodeBody(String source) {
  if (source.trim().isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(source);
  return _asMap(decoded);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Resposta financeira inválida.');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  return _asMap(json[key]);
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Campo $key inválido.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Campo $key inválido.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Campo $key inválido.');
  return value.toInt();
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
