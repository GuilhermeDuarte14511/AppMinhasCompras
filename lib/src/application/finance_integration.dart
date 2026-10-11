class FinanceIntegrationConnection {
  const FinanceIntegrationConnection({
    required this.id,
    required this.householdId,
    required this.householdName,
    required this.ownerName,
    required this.permissions,
  });

  final String id;
  final String householdId;
  final String householdName;
  final String ownerName;
  final List<String> permissions;
}

class FinanceCardInvoice {
  const FinanceCardInvoice({
    required this.id,
    required this.totalCents,
    required this.dueOn,
  });

  final String id;
  final int totalCents;
  final DateTime dueOn;
}

class FinanceCard {
  const FinanceCard({
    required this.id,
    required this.name,
    required this.lastDigits,
    required this.closingDay,
    required this.dueDay,
    required this.limitCents,
    required this.usedCents,
    required this.availableCents,
    required this.colorHex,
    this.holderName,
    this.currentInvoice,
  });

  final String id;
  final String name;
  final String? holderName;
  final String lastDigits;
  final int closingDay;
  final int dueDay;
  final int limitCents;
  final int usedCents;
  final int availableCents;
  final String colorHex;
  final FinanceCardInvoice? currentInvoice;

  FinancePaymentSource toPaymentSource() => FinancePaymentSource(
    id: id,
    kind: FinancePaymentSourceKind.credit,
    name: name,
    lastDigits: lastDigits,
    availableCents: availableCents,
    colorHex: colorHex,
    limitCents: limitCents,
    usedCents: usedCents,
    closingDay: closingDay,
    dueDay: dueDay,
  );
}

enum FinancePaymentSourceKind {
  credit('credit', 'Crédito'),
  debit('debit', 'Débito'),
  foodVoucher('foodVoucher', 'VA'),
  mealVoucher('mealVoucher', 'VR');

  const FinancePaymentSourceKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FinancePaymentSourceKind fromWireValue(String value) =>
      values.where((kind) => kind.wireValue == value).firstOrNull ??
      (throw FormatException('Tipo de pagamento inválido: $value'));
}

class FinancePaymentSource {
  const FinancePaymentSource({
    required this.id,
    required this.kind,
    required this.name,
    required this.availableCents,
    required this.colorHex,
    this.lastDigits,
    this.limitCents,
    this.usedCents,
    this.closingDay,
    this.dueDay,
  });

  final String id;
  final FinancePaymentSourceKind kind;
  final String name;
  final String? lastDigits;
  final int availableCents;
  final String colorHex;
  final int? limitCents;
  final int? usedCents;
  final int? closingDay;
  final int? dueDay;
}

class FinancePaymentSourceRequest {
  const FinancePaymentSourceRequest({
    required this.externalRequestId,
    required this.kind,
    required this.name,
    required this.availableCents,
    this.lastDigits,
    this.closingDay,
    this.dueDay,
    this.colorHex = '#0D7B9A',
  });

  final String externalRequestId;
  final FinancePaymentSourceKind kind;
  final String name;
  final int availableCents;
  final String? lastDigits;
  final int? closingDay;
  final int? dueDay;
  final String colorHex;

  Map<String, dynamic> toJson() => {
    'externalRequestId': externalRequestId,
    'kind': kind.wireValue,
    'name': name.trim(),
    'availableCents': availableCents,
    'lastDigits': lastDigits,
    'closingDay': closingDay,
    'dueDay': dueDay,
    'colorHex': colorHex,
  };
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorHex,
  });

  final String id;
  final String name;
  final String iconKey;
  final String colorHex;
}

class FinanceWorkspace {
  const FinanceWorkspace({
    required this.householdId,
    required this.householdName,
    required this.cards,
    required this.categories,
    required this.asOf,
    this.paymentSources = const [],
  });

  final String householdId;
  final String householdName;
  final List<FinanceCard> cards;
  final List<FinancePaymentSource> paymentSources;
  final List<FinanceCategory> categories;
  final DateTime asOf;

  List<FinancePaymentSource> get availablePaymentSources =>
      paymentSources.isNotEmpty
      ? paymentSources
      : cards.map((card) => card.toPaymentSource()).toList(growable: false);
}

class FinancePurchaseRequest {
  const FinancePurchaseRequest({
    required this.externalPurchaseId,
    required this.cardId,
    required this.description,
    required this.amountCents,
    required this.purchasedOn,
    this.paymentSourceKind = FinancePaymentSourceKind.credit,
    this.categoryId,
    this.scope = 'family',
    this.countsInBudget = true,
    this.notes,
  });

  factory FinancePurchaseRequest.fromJson(Map<String, dynamic> json) {
    return FinancePurchaseRequest(
      externalPurchaseId: json['externalPurchaseId'] as String,
      cardId: json['cardId'] as String,
      paymentSourceKind: FinancePaymentSourceKind.fromWireValue(
        json['paymentSourceKind'] as String? ?? 'credit',
      ),
      categoryId: json['categoryId'] as String?,
      description: json['description'] as String,
      amountCents: (json['amountCents'] as num).toInt(),
      purchasedOn: DateTime.parse(json['purchasedOn'] as String),
      scope: json['scope'] as String? ?? 'family',
      countsInBudget: json['countsInBudget'] as bool? ?? true,
      notes: json['notes'] as String?,
    );
  }

  final String externalPurchaseId;
  final String cardId;
  final String? categoryId;
  final String description;
  final int amountCents;
  final DateTime purchasedOn;
  final FinancePaymentSourceKind paymentSourceKind;
  final String scope;
  final bool countsInBudget;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'externalPurchaseId': externalPurchaseId,
    'cardId': cardId,
    'paymentSourceId': cardId,
    'paymentSourceKind': paymentSourceKind.wireValue,
    'categoryId': categoryId,
    'description': description,
    'amountCents': amountCents,
    'purchasedOn': _dateOnly(purchasedOn),
    'scope': scope,
    'countsInBudget': countsInBudget,
    'notes': notes,
  };

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class FinancePurchaseSubmission {
  const FinancePurchaseSubmission({
    required this.queued,
    this.created = false,
    this.financialEntryId,
    this.cardChargeId,
    this.invoiceId,
    this.accountMovementId,
  });

  final bool queued;
  final bool created;
  final String? financialEntryId;
  final String? cardChargeId;
  final String? invoiceId;
  final String? accountMovementId;
}

abstract interface class FinanceIntegrationStore {
  Future<String?> readToken();

  Future<void> writeToken(String value);

  Future<List<FinancePurchaseRequest>> readPendingPurchases();

  Future<void> writePendingPurchases(List<FinancePurchaseRequest> purchases);

  Future<String> readConnectionId();
  Future<List<FinancePurchaseSync>> readPurchaseSync();
  Future<void> writePurchaseSync(List<FinancePurchaseSync> purchases);
  Future<void> clear();
}

abstract interface class FinanceIntegrationRepository {
  Future<bool> isConnected();

  Future<FinanceIntegrationConnection> connect(String code);

  Future<void> disconnect();

  Future<FinanceWorkspace> loadWorkspace();

  Future<FinancePaymentSource> createPaymentSource(
    FinancePaymentSourceRequest request,
  );

  Future<FinancePurchaseSubmission> submitPurchase(
    FinancePurchaseRequest purchase,
  );

  Future<String> connectionId();
  Future<void> submitPurchasePlan(List<FinancePurchaseSync> plan);
  Future<List<FinancePurchaseSync>> purchaseSyncHistory();
  Future<void> retryPurchase(String purchaseId);
  Future<int> pendingPurchaseCount();

  Future<int> retryPendingPurchases();
}

class FinanceIntegrationException implements Exception {
  const FinanceIntegrationException(
    this.message, {
    required this.retryable,
    this.code,
  });

  final String message;
  final bool retryable;
  final String? code;

  @override
  String toString() => message;
}

enum FinanceSyncStatus { pending, synced, attention }

/// Durable, device-local receipt. The request is immutable after staging.
class FinancePurchaseSync {
  const FinancePurchaseSync({
    required this.purchaseId,
    required this.sourceName,
    required this.request,
    this.connectionId = '',
    this.status = FinanceSyncStatus.pending,
    this.message,
    this.financialEntryId,
    this.accountMovementId,
    this.cardChargeId,
    this.invoiceId,
    this.created = false,
  });

  final String purchaseId;
  final String sourceName;
  final FinancePurchaseRequest request;
  final String connectionId;
  final FinanceSyncStatus status;
  final String? message;
  final String? financialEntryId;
  final String? accountMovementId;
  final String? cardChargeId;
  final String? invoiceId;
  final bool created;

  FinancePurchaseSync copyWith({
    String? connectionId,
    FinanceSyncStatus? status,
    String? message,
    String? financialEntryId,
    FinancePurchaseSubmission? receipt,
  }) => FinancePurchaseSync(
    purchaseId: purchaseId,
    sourceName: sourceName,
    request: request,
    connectionId: connectionId ?? this.connectionId,
    status: status ?? this.status,
    message: message,
    financialEntryId:
        receipt?.financialEntryId ?? financialEntryId ?? this.financialEntryId,
    accountMovementId: receipt?.accountMovementId ?? accountMovementId,
    cardChargeId: receipt?.cardChargeId ?? cardChargeId,
    invoiceId: receipt?.invoiceId ?? invoiceId,
    created: receipt?.created ?? created,
  );

  Map<String, dynamic> toJson() => {
    'purchaseId': purchaseId,
    'sourceName': sourceName,
    'request': request.toJson(),
    'connectionId': connectionId,
    'status': status.name,
    'message': message,
    'financialEntryId': financialEntryId,
    'accountMovementId': accountMovementId,
    'cardChargeId': cardChargeId,
    'invoiceId': invoiceId,
    'created': created,
  };

  factory FinancePurchaseSync.fromJson(Map<String, dynamic> json) =>
      FinancePurchaseSync(
        purchaseId: json['purchaseId'] as String,
        sourceName: json['sourceName'] as String,
        request: FinancePurchaseRequest.fromJson(
          Map<String, dynamic>.from(json['request'] as Map),
        ),
        connectionId: json['connectionId'] as String,
        status: FinanceSyncStatus.values.byName(json['status'] as String),
        message: json['message'] as String?,
        financialEntryId: json['financialEntryId'] as String?,
        accountMovementId: json['accountMovementId'] as String?,
        cardChargeId: json['cardChargeId'] as String?,
        invoiceId: json['invoiceId'] as String?,
        created: json['created'] as bool? ?? false,
      );
}
