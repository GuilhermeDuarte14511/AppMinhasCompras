import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

class SharedShoppingListSummary {
  const SharedShoppingListSummary({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.createdAt,
    required this.updatedAt,
    this.budget,
    this.reminder,
    this.paymentBalances = const <PaymentBalance>[],
    this.isClosed = false,
    this.closedAt,
    this.inviteCode,
    this.sourceLocalListId,
  });

  factory SharedShoppingListSummary.fromFirestoreDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final members = <String>{};
    final rawMembers = data['memberUids'];
    if (rawMembers is List) {
      for (final raw in rawMembers) {
        if (raw is String && raw.trim().isNotEmpty) {
          members.add(raw.trim());
        }
      }
    }
    final ownerUid = (data['ownerUid'] as String?)?.trim() ?? '';
    if (ownerUid.isNotEmpty) {
      members.add(ownerUid);
    }
    return SharedShoppingListSummary(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? (data['id'] as String).trim()
          : doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Lista compartilhada',
      ownerUid: ownerUid,
      memberUids: List.unmodifiable(members),
      createdAt:
          SharedListsRepository._readDate(data['createdAt']) ?? DateTime.now(),
      updatedAt:
          SharedListsRepository._readDate(data['updatedAt']) ?? DateTime.now(),
      budget: (data['budget'] as num?)?.toDouble(),
      reminder: _parseReminder(data['reminder']),
      paymentBalances: SharedListsRepository._parsePaymentBalances(
        data['paymentBalances'],
      ),
      isClosed: (data['isClosed'] as bool?) ?? false,
      closedAt: SharedListsRepository._readDate(data['closedAt']),
      inviteCode: SharedListsRepository._cleanNullable(
        data['inviteCode'] as String?,
      ),
      sourceLocalListId: SharedListsRepository._cleanNullable(
        data['sourceLocalListId'] as String?,
      ),
    );
  }

  final String id;
  final String name;
  final String ownerUid;
  final List<String> memberUids;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? budget;
  final ShoppingReminderConfig? reminder;
  final List<PaymentBalance> paymentBalances;
  final bool isClosed;
  final DateTime? closedAt;
  final String? inviteCode;
  final String? sourceLocalListId;

  bool isOwner(String uid) => ownerUid == uid;
  int get memberCount => memberUids.toSet().length;
  bool get hasBudget => budget != null && (budget ?? 0) > 0;
  bool get hasPaymentBalances =>
      paymentBalances.any((entry) => entry.value > 0);
  double get paymentBalancesTotal =>
      paymentBalances.fold<double>(0, (sum, entry) => sum + entry.value);

  Map<String, dynamic> toCreatePayload({
    required String ownerUid,
    required String inviteCode,
    String? sourceLocalListId,
  }) {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'ownerUid': ownerUid,
      'memberUids': <String>[ownerUid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'budget': budget,
      'reminder': reminder?.toJson(),
      'paymentBalances': paymentBalances
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'isClosed': isClosed,
      'closedAt': closedAt?.toIso8601String(),
      'inviteCode': inviteCode,
      'sourceLocalListId': SharedListsRepository._cleanNullable(
        sourceLocalListId,
      ),
    };
  }

  SharedShoppingListSummary copyWith({
    String? id,
    String? name,
    String? ownerUid,
    List<String>? memberUids,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? budget,
    ShoppingReminderConfig? reminder,
    List<PaymentBalance>? paymentBalances,
    bool? isClosed,
    DateTime? closedAt,
    String? inviteCode,
    String? sourceLocalListId,
    bool clearInviteCode = false,
    bool clearSourceLocalListId = false,
  }) {
    return SharedShoppingListSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUid: ownerUid ?? this.ownerUid,
      memberUids: memberUids ?? this.memberUids,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      budget: budget ?? this.budget,
      reminder: reminder ?? this.reminder,
      paymentBalances: paymentBalances ?? this.paymentBalances,
      isClosed: isClosed ?? this.isClosed,
      closedAt: closedAt ?? this.closedAt,
      inviteCode: clearInviteCode ? null : inviteCode ?? this.inviteCode,
      sourceLocalListId: clearSourceLocalListId
          ? null
          : sourceLocalListId ?? this.sourceLocalListId,
    );
  }

  static ShoppingReminderConfig? _parseReminder(dynamic raw) {
    if (raw is Map) {
      return ShoppingReminderConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

class SharedShoppingItem {
  const SharedShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.isPurchased,
    required this.updatedBy,
    required this.updatedAt,
    required this.createdAt,
    this.category = ShoppingCategory.other,
    this.barcode,
  });

  factory SharedShoppingItem.fromFirestoreDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawQuantity = data['quantity'];
    final rawUnitPrice = data['unitPrice'];
    return SharedShoppingItem(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? (data['id'] as String).trim()
          : doc.id,
      name: (data['name'] as String?)?.trim() ?? '',
      quantity: rawQuantity is num ? max(1, rawQuantity.toInt()) : 1,
      unitPrice: rawUnitPrice is num ? max(0, rawUnitPrice.toDouble()) : 0,
      isPurchased: (data['isPurchased'] as bool?) ?? false,
      updatedBy: (data['updatedBy'] as String?)?.trim() ?? '',
      updatedAt:
          SharedListsRepository._readDate(data['updatedAt']) ?? DateTime.now(),
      createdAt:
          SharedListsRepository._readDate(data['createdAt']) ?? DateTime.now(),
      category: ShoppingCategoryParser.fromKey(data['category'] as String?),
      barcode: sanitizeBarcode(data['barcode'] as String?),
    );
  }

  final String id;
  final String name;
  final int quantity;
  final double unitPrice;
  final bool isPurchased;
  final String updatedBy;
  final DateTime updatedAt;
  final DateTime createdAt;
  final ShoppingCategory category;
  final String? barcode;

  double get subtotal => unitPrice * quantity;

  ShoppingItem toShoppingItem() {
    return ShoppingItem(
      id: id,
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      isPurchased: isPurchased,
      category: category,
      barcode: barcode,
    );
  }

  SharedShoppingItem copyWith({
    String? id,
    String? name,
    int? quantity,
    double? unitPrice,
    bool? isPurchased,
    String? updatedBy,
    DateTime? updatedAt,
    DateTime? createdAt,
    ShoppingCategory? category,
    String? barcode,
    bool clearBarcode = false,
  }) {
    return SharedShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      isPurchased: isPurchased ?? this.isPurchased,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      barcode: clearBarcode ? null : sanitizeBarcode(barcode) ?? this.barcode,
    );
  }

  Map<String, dynamic> toFirestorePayload({required String updatedBy}) {
    return <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'quantity': max(1, quantity),
      'unitPrice': max(0, unitPrice),
      'isPurchased': isPurchased,
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': createdAt,
      'category': category.key,
      'barcode': barcode,
    };
  }

  static SharedShoppingItem fromShoppingItem(ShoppingItem item, String uid) {
    final now = DateTime.now();
    return SharedShoppingItem(
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      isPurchased: item.isPurchased,
      updatedBy: uid,
      updatedAt: now,
      createdAt: now,
      category: item.category,
      barcode: item.barcode,
    );
  }
}

class SharedListsRepository {
  SharedListsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? _buildPreferredFirestore();

  static const String _sharedListsCollection = 'shared_lists';
  static const String _listInvitesCollection = 'list_invites';
  static const String _itemsSubCollection = 'items';
  static const String _historySubCollection = 'history';
  static const String _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  static FirebaseFirestore _buildPreferredFirestore() {
    return FirebaseFirestore.instance;
  }

  void _log(String message) {
    debugPrint('[shared_lists] $message');
    developer.log(message, name: 'shared_lists');
  }

  CollectionReference<Map<String, dynamic>> get _sharedListsRef =>
      _firestore.collection(_sharedListsCollection);

  CollectionReference<Map<String, dynamic>> get _listInvitesRef =>
      _firestore.collection(_listInvitesCollection);

  DocumentReference<Map<String, dynamic>> _listRef(String listId) =>
      _sharedListsRef.doc(listId);

  CollectionReference<Map<String, dynamic>> _itemsRef(String listId) =>
      _listRef(listId).collection(_itemsSubCollection);

  CollectionReference<Map<String, dynamic>> _historyRef(String listId) =>
      _listRef(listId).collection(_historySubCollection);

  DocumentReference<Map<String, dynamic>> _inviteRef(String code) =>
      _listInvitesRef.doc(_normalizeInviteCode(code));

  Stream<List<SharedShoppingListSummary>> watchSharedLists(String uid) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return const Stream<List<SharedShoppingListSummary>>.empty();
    }
    return _sharedListsRef
        .where('memberUids', arrayContains: trimmedUid)
        .snapshots()
        .map((snapshot) {
          final lists = snapshot.docs
              .map(SharedShoppingListSummary.fromFirestoreDoc)
              .toList(growable: false);
          lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return List.unmodifiable(lists);
        });
  }

  Future<List<SharedShoppingListSummary>> fetchOwnedSharedLists(String uid) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return const <SharedShoppingListSummary>[];
    }
    final snapshot = await _sharedListsRef
        .where('ownerUid', isEqualTo: trimmedUid)
        .get();
    final lists = snapshot.docs
        .map(SharedShoppingListSummary.fromFirestoreDoc)
        .toList(growable: false);
    lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(lists);
  }

  Future<List<SharedShoppingItem>> fetchListItems(String listId) async {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) {
      return const <SharedShoppingItem>[];
    }
    final snapshot = await _itemsRef(trimmedListId).get();
    final items = snapshot.docs
        .map(SharedShoppingItem.fromFirestoreDoc)
        .toList(growable: false);
    items.sort((left, right) {
      if (left.isPurchased != right.isPurchased) {
        return left.isPurchased ? 1 : -1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return List.unmodifiable(items);
  }

  Future<void> syncLocalListToShared({
    required ShoppingListModel localList,
    required SharedShoppingListSummary sharedList,
    required String updatedBy,
  }) async {
    final trimmedUid = updatedBy.trim();
    if (trimmedUid.isEmpty) {
      return;
    }
    final listId = sharedList.id.trim();
    if (listId.isEmpty) {
      return;
    }
    await updateListMeta(
      listId: listId,
      name: localList.name,
      budget: localList.budget,
      reminder: localList.reminder,
      paymentBalances: localList.paymentBalances,
      isClosed: localList.isClosed,
      closedAt: localList.closedAt,
      clearBudget: localList.budget == null,
      clearReminder: localList.reminder == null,
      clearPaymentBalances: localList.paymentBalances.isEmpty,
      clearClosedAt: localList.closedAt == null,
    );

    final sharedItems = await fetchListItems(listId);
    final sharedById = <String, SharedShoppingItem>{
      for (final item in sharedItems) item.id: item,
    };
    final localIds = localList.items.map((item) => item.id).toSet();
    final toDelete = sharedItems
        .where((item) => !localIds.contains(item.id))
        .map((item) => item.id)
        .toList(growable: false);

    final operations = <void Function(WriteBatch)>[];
    final now = DateTime.now();
    for (final item in localList.items) {
      final existing = sharedById[item.id];
      final sharedItem = SharedShoppingItem(
        id: item.id,
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        isPurchased: item.isPurchased,
        updatedBy: trimmedUid,
        updatedAt: now,
        createdAt: existing?.createdAt ?? now,
        category: item.category,
        barcode: item.barcode,
      );
      operations.add(
        (batch) => batch.set(
          _itemsRef(listId).doc(sharedItem.id),
          sharedItem.toFirestorePayload(updatedBy: trimmedUid),
          SetOptions(merge: true),
        ),
      );
    }
    for (final itemId in toDelete) {
      operations.add((batch) => batch.delete(_itemsRef(listId).doc(itemId)));
    }

    if (operations.isEmpty) {
      return;
    }

    const maxOps = 450;
    for (var i = 0; i < operations.length; i += maxOps) {
      final batch = _firestore.batch();
      final slice = operations.skip(i).take(maxOps);
      for (final op in slice) {
        op(batch);
      }
      await batch.commit();
    }
  }

  Stream<List<SharedShoppingListSummary>> watchOwnedSharedLists(String uid) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return const Stream<List<SharedShoppingListSummary>>.empty();
    }
    return _sharedListsRef
        .where('ownerUid', isEqualTo: trimmedUid)
        .snapshots()
        .map((snapshot) {
          final lists = snapshot.docs
              .map(SharedShoppingListSummary.fromFirestoreDoc)
              .toList(growable: false);
          lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return List.unmodifiable(lists);
        });
  }

  Stream<SharedShoppingListSummary?> watchSharedList(String listId) {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) {
      return const Stream<SharedShoppingListSummary?>.empty();
    }
    return _listRef(trimmedListId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return SharedShoppingListSummary.fromFirestoreDoc(snapshot);
    });
  }

  Future<SharedShoppingListSummary?> fetchSharedList(String listId) async {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) {
      return null;
    }
    final snapshot = await _listRef(trimmedListId).get();
    if (!snapshot.exists) {
      return null;
    }
    return SharedShoppingListSummary.fromFirestoreDoc(snapshot);
  }

  Future<SharedShoppingListSummary?> findSharedListBySource({
    required String ownerUid,
    required String sourceLocalListId,
  }) async {
    final trimmedUid = ownerUid.trim();
    final trimmedSource = sourceLocalListId.trim();
    if (trimmedUid.isEmpty || trimmedSource.isEmpty) {
      return null;
    }
    final snapshot = await _sharedListsRef
        .where('ownerUid', isEqualTo: trimmedUid)
        .get();
    for (final doc in snapshot.docs) {
      final parsed = SharedShoppingListSummary.fromFirestoreDoc(doc);
      if (parsed.sourceLocalListId == trimmedSource) {
        return parsed;
      }
    }
    return null;
  }

  Stream<List<SharedShoppingItem>> watchListItems(String listId) {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) {
      return const Stream<List<SharedShoppingItem>>.empty();
    }
    return _itemsRef(trimmedListId).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(SharedShoppingItem.fromFirestoreDoc)
          .toList(growable: false);
      items.sort((left, right) {
        if (left.isPurchased != right.isPurchased) {
          return left.isPurchased ? 1 : -1;
        }
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
      return List.unmodifiable(items);
    });
  }

  Stream<List<CompletedPurchase>> watchSharedHistory(String listId) {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) {
      return const Stream<List<CompletedPurchase>>.empty();
    }
    return _historyRef(
      trimmedListId,
    ).orderBy('closedAt', descending: true).snapshots().map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => CompletedPurchase.fromJson(doc.data()))
          .toList(growable: false);
      entries.sort((a, b) => b.closedAt.compareTo(a.closedAt));
      return List.unmodifiable(entries);
    });
  }

  Future<SharedShoppingListSummary> createOrGetSharedListFromLocal({
    required ShoppingListModel localList,
    required String ownerUid,
  }) async {
    final trimmedUid = ownerUid.trim();
    if (trimmedUid.isEmpty) {
      throw StateError('ownerUid invalido');
    }
    final sourceLocalListId = localList.id.trim();
    if (sourceLocalListId.isNotEmpty) {
      final ownedSnapshot = await _sharedListsRef
          .where('ownerUid', isEqualTo: trimmedUid)
          .get();
      for (final doc in ownedSnapshot.docs) {
        final parsed = SharedShoppingListSummary.fromFirestoreDoc(doc);
        if (parsed.sourceLocalListId == sourceLocalListId) {
          return parsed;
        }
      }
    }
    return createSharedListFromLocal(localList: localList, ownerUid: ownerUid);
  }

  Future<SharedShoppingListSummary> createSharedListFromLocal({
    required ShoppingListModel localList,
    required String ownerUid,
  }) async {
    final trimmedUid = ownerUid.trim();
    if (trimmedUid.isEmpty) {
      throw StateError('ownerUid invalido');
    }

    _log(
      'createSharedListFromLocal start owner=$trimmedUid list=${localList.id}',
    );

    // Gera um código único (baseado na sua função atual)
    final generatedCode = await _generateUniqueInviteCode();

    // Cria o doc da shared_list
    final docRef = _listRef(uniqueId());
    _log('createSharedListFromLocal listId=${docRef.id} invite=$generatedCode');

    // Monta o summary (o objeto que você já usa no app)
    final summary = SharedShoppingListSummary(
      id: docRef.id,
      name: localList.name,
      ownerUid: trimmedUid,
      memberUids: <String>[trimmedUid],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      budget: localList.budget,
      reminder: localList.reminder,
      paymentBalances: localList.paymentBalances,
      isClosed: localList.isClosed,
      closedAt: localList.closedAt,
      inviteCode: generatedCode,
      sourceLocalListId: localList.id,
    );

    // ---------------------------------------------------------------------------
    // 1) PRIMEIRO: cria SOMENTE a lista compartilhada
    // Motivo: suas rules de items e invite usam exists/get em /shared_lists/{listId}
    // e em batch elas não "enxergam" o doc que ainda não foi commitado.
    // ---------------------------------------------------------------------------
    await docRef.set(
      summary.toCreatePayload(
        ownerUid: trimmedUid,
        inviteCode: generatedCode,
        sourceLocalListId: localList.id,
      ),
    );
    _log('shared_list created listId=${docRef.id}');

    // ---------------------------------------------------------------------------
    // 2) SEGUNDO: cria os ITEMS (pode ser em batch, agora a lista já existe)
    // ---------------------------------------------------------------------------
    if (localList.items.isNotEmpty) {
      final itemsBatch = _firestore.batch();

      for (final item in localList.items) {
        final sharedItem = SharedShoppingItem.fromShoppingItem(
          item,
          trimmedUid,
        );
        itemsBatch.set(
          _itemsRef(docRef.id).doc(sharedItem.id),
          sharedItem.toFirestorePayload(updatedBy: trimmedUid),
        );
      }

      await itemsBatch.commit();
      _log('shared_list items created count=${localList.items.length}');
    }

    // ---------------------------------------------------------------------------
    // 3) TERCEIRO: cria o INVITE (agora sharedListExists(listId) vai retornar true)
    // ---------------------------------------------------------------------------
    await _inviteRef(generatedCode).set(<String, dynamic>{
      'code': generatedCode,
      'listId': docRef.id,
      'ownerUid': trimmedUid,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log('list_invite created code=$generatedCode listId=${docRef.id}');

    return summary;
  }

  Future<String> generateInviteCode({
    required String listId,
    required String requesterUid,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedUid = requesterUid.trim();
    if (trimmedListId.isEmpty || trimmedUid.isEmpty) {
      throw StateError('Dados invalidos para gerar convite.');
    }
    _log('generateInviteCode start listId=$trimmedListId uid=$trimmedUid');
    final newCode = await _generateUniqueInviteCode();
    _log('generateInviteCode candidate=$newCode');
    await _firestore.runTransaction((transaction) async {
      final listSnapshot = await transaction.get(_listRef(trimmedListId));
      _log('generateInviteCode listSnapshot.exists=${listSnapshot.exists}');
      if (!listSnapshot.exists) {
        throw StateError('Lista compartilhada nao encontrada.');
      }
      final parsed = SharedShoppingListSummary.fromFirestoreDoc(listSnapshot);
      _log(
        'generateInviteCode owner=${parsed.ownerUid} invite=${parsed.inviteCode}',
      );
      if (!parsed.isOwner(trimmedUid)) {
        throw StateError('Somente o dono pode gerar codigo.');
      }
      final previousCode = parsed.inviteCode;
      if (previousCode != null && previousCode.isNotEmpty) {
        final previousInvite = await transaction.get(_inviteRef(previousCode));
        _log(
          'generateInviteCode previousInvite.exists=${previousInvite.exists}',
        );
        if (previousInvite.exists) {
          transaction.delete(_inviteRef(previousCode));
        }
      }
      transaction.update(_listRef(trimmedListId), <String, dynamic>{
        'inviteCode': newCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(_inviteRef(newCode), <String, dynamic>{
        'code': newCode,
        'listId': trimmedListId,
        'ownerUid': trimmedUid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    _log('generateInviteCode done listId=$trimmedListId newCode=$newCode');
    return newCode;
  }

  Future<void> revokeInviteCode({
    required String listId,
    required String requesterUid,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedUid = requesterUid.trim();
    if (trimmedListId.isEmpty || trimmedUid.isEmpty) {
      throw StateError('Dados invalidos para revogar convite.');
    }
    _log('revokeInviteCode start listId=$trimmedListId uid=$trimmedUid');
    await _firestore.runTransaction((transaction) async {
      final listSnapshot = await transaction.get(_listRef(trimmedListId));
      _log('revokeInviteCode listSnapshot.exists=${listSnapshot.exists}');
      if (!listSnapshot.exists) {
        return;
      }
      final parsed = SharedShoppingListSummary.fromFirestoreDoc(listSnapshot);
      _log(
        'revokeInviteCode owner=${parsed.ownerUid} invite=${parsed.inviteCode}',
      );
      if (!parsed.isOwner(trimmedUid)) {
        throw StateError('Somente o dono pode revogar codigo.');
      }
      final previousCode = parsed.inviteCode;
      if (previousCode != null && previousCode.isNotEmpty) {
        final previousInvite = await transaction.get(_inviteRef(previousCode));
        _log('revokeInviteCode previousInvite.exists=${previousInvite.exists}');
        if (previousInvite.exists) {
          transaction.delete(_inviteRef(previousCode));
        }
      }
      transaction.update(_listRef(trimmedListId), <String, dynamic>{
        'inviteCode': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    _log('revokeInviteCode done listId=$trimmedListId');
  }

  Future<void> removeMember({
    required String listId,
    required String requesterUid,
    required String memberUid,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedRequester = requesterUid.trim();
    final trimmedMember = memberUid.trim();
    if (trimmedListId.isEmpty ||
        trimmedRequester.isEmpty ||
        trimmedMember.isEmpty) {
      throw StateError('Dados inválidos para remover membro.');
    }
    if (trimmedRequester == trimmedMember) {
      throw StateError('Não é possível remover você mesmo.');
    }

    _log(
      'removeMember start listId=$trimmedListId requester=$trimmedRequester member=$trimmedMember',
    );

    await _firestore.runTransaction((transaction) async {
      final listSnapshot = await transaction.get(_listRef(trimmedListId));
      if (!listSnapshot.exists) {
        throw StateError('Lista compartilhada não encontrada.');
      }
      final parsed = SharedShoppingListSummary.fromFirestoreDoc(listSnapshot);
      if (!parsed.isOwner(trimmedRequester)) {
        throw StateError('Somente o dono pode remover membros.');
      }
      if (!parsed.memberUids.contains(trimmedMember)) {
        return;
      }
      transaction.update(_listRef(trimmedListId), <String, dynamic>{
        'memberUids': FieldValue.arrayRemove(<String>[trimmedMember]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    _log('removeMember done listId=$trimmedListId member=$trimmedMember');
  }

  Future<String> joinByCode({
    required String inviteCode,
    required String uid,
  }) async {
    final normalizedCode = _normalizeInviteCode(inviteCode);
    final trimmedUid = uid.trim();
    if (normalizedCode.isEmpty || trimmedUid.isEmpty) {
      throw StateError('Codigo ou usuario invalido.');
    }

    if (kIsWeb) {
      _log('joinByCode web mode (sem transacao) code=$normalizedCode');
      return _joinByCodeWithoutTransaction(
        inviteCode: normalizedCode,
        uid: trimmedUid,
        forceServer: true,
      );
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        final inviteSnapshot = await transaction.get(
          _inviteRef(normalizedCode),
        );
        if (!inviteSnapshot.exists) {
          throw StateError('Codigo invalido ou expirado.');
        }
        final inviteData = inviteSnapshot.data() ?? const <String, dynamic>{};
        if ((inviteData['active'] as bool?) != true) {
          throw StateError('Codigo invalido ou expirado.');
        }
        final listId = (inviteData['listId'] as String?)?.trim() ?? '';
        if (listId.isEmpty) {
          throw StateError('Convite sem lista valida.');
        }

        transaction.update(_listRef(listId), <String, dynamic>{
          'memberUids': FieldValue.arrayUnion(<String>[trimmedUid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return listId;
      });
    } catch (error, stack) {
      _log('joinByCode transaction error=$error');
      if (error is StateError) {
        rethrow;
      }
      if (error is FirebaseException &&
          error.code.toLowerCase() == 'permission-denied') {
        rethrow;
      }
      if (kIsWeb) {
        try {
          return await _joinByCodeWithoutTransaction(
            inviteCode: normalizedCode,
            uid: trimmedUid,
            forceServer: true,
          );
        } catch (fallbackError, fallbackStack) {
          _log('joinByCode fallback error=$fallbackError');
          developer.log(
            'joinByCode fallback stack',
            name: 'shared_lists',
            error: fallbackError,
            stackTrace: fallbackStack,
          );
          rethrow;
        }
      }
      developer.log(
        'joinByCode error',
        name: 'shared_lists',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<String> _joinByCodeWithoutTransaction({
    required String inviteCode,
    required String uid,
    bool forceServer = false,
  }) async {
    final inviteSnapshot = forceServer
        ? await _inviteRef(inviteCode).get(
            const GetOptions(source: Source.server),
          )
        : await _inviteRef(inviteCode).get();
    if (!inviteSnapshot.exists) {
      throw StateError('Codigo invalido ou expirado.');
    }
    final inviteData = inviteSnapshot.data() ?? const <String, dynamic>{};
    if ((inviteData['active'] as bool?) != true) {
      throw StateError('Codigo invalido ou expirado.');
    }
    final listId = (inviteData['listId'] as String?)?.trim() ?? '';
    if (listId.isEmpty) {
      throw StateError('Convite sem lista valida.');
    }
    await _listRef(listId).update(<String, dynamic>{
      'memberUids': FieldValue.arrayUnion(<String>[uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return listId;
  }

  Future<void> updateListMeta({
    required String listId,
    String? name,
    double? budget,
    ShoppingReminderConfig? reminder,
    List<PaymentBalance>? paymentBalances,
    bool? isClosed,
    DateTime? closedAt,
    bool clearBudget = false,
    bool clearReminder = false,
    bool clearPaymentBalances = false,
    bool clearClosedAt = false,
  }) async {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) {
      return;
    }
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final cleanName = _cleanNullable(name);
    if (cleanName != null) {
      updates['name'] = cleanName;
    }
    if (clearBudget) {
      updates['budget'] = null;
    } else if (budget != null) {
      updates['budget'] = budget;
    }
    if (clearReminder) {
      updates['reminder'] = null;
    } else if (reminder != null) {
      updates['reminder'] = reminder.toJson();
    }
    if (clearPaymentBalances) {
      updates['paymentBalances'] = <dynamic>[];
    } else if (paymentBalances != null) {
      updates['paymentBalances'] = paymentBalances
          .map((entry) => entry.toJson())
          .toList(growable: false);
    }
    if (isClosed != null) {
      updates['isClosed'] = isClosed;
    }
    if (clearClosedAt) {
      updates['closedAt'] = null;
    } else if (closedAt != null) {
      updates['closedAt'] = closedAt.toIso8601String();
    }
    await _listRef(trimmedListId).update(updates);
  }

  Future<CompletedPurchase> finalizeSharedList({
    required String listId,
    required String updatedBy,
    required bool markPendingAsPurchased,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedUid = updatedBy.trim();
    if (trimmedListId.isEmpty || trimmedUid.isEmpty) {
      throw StateError('Dados inválidos para finalizar lista.');
    }

    final listSnapshot = await _listRef(trimmedListId).get();
    if (!listSnapshot.exists) {
      throw StateError('Lista compartilhada não encontrada.');
    }
    final summary = SharedShoppingListSummary.fromFirestoreDoc(listSnapshot);
    if (summary.isClosed) {
      throw StateError('Lista já está fechada.');
    }

    final itemsSnapshot = await _itemsRef(trimmedListId).get();
    final sharedItems = itemsSnapshot.docs
        .map(SharedShoppingItem.fromFirestoreDoc)
        .toList(growable: false);
    final updatedItems = sharedItems
        .map((item) {
          if (!markPendingAsPurchased || item.isPurchased) {
            return item;
          }
          return item.copyWith(
            isPurchased: true,
            updatedBy: trimmedUid,
            updatedAt: DateTime.now(),
          );
        })
        .toList(growable: false);

    final shoppingItems = updatedItems
        .map((item) => item.toShoppingItem())
        .toList(growable: false);
    final listModel = ShoppingListModel(
      id: summary.id,
      name: summary.name,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      items: shoppingItems,
      budget: summary.budget,
      reminder: summary.reminder,
      paymentBalances: summary.paymentBalances,
      isClosed: true,
      closedAt: DateTime.now(),
    );

    final now = DateTime.now();
    final completed = CompletedPurchase.fromList(listModel, closedAt: now);
    final historyDocId = completed.id;

    final batch = _firestore.batch();

    if (markPendingAsPurchased) {
      for (final item in updatedItems) {
        final original = sharedItems.firstWhere((entry) => entry.id == item.id);
        if (original.isPurchased == item.isPurchased) {
          continue;
        }
        batch.update(_itemsRef(trimmedListId).doc(item.id), <String, dynamic>{
          'isPurchased': item.isPurchased,
          'updatedBy': trimmedUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.update(_listRef(trimmedListId), <String, dynamic>{
      'isClosed': true,
      'closedAt': now.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_historyRef(trimmedListId).doc(historyDocId), completed.toJson());

    await batch.commit();
    return completed;
  }

  Future<void> reopenSharedList({
    required String listId,
    required String updatedBy,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedUid = updatedBy.trim();
    if (trimmedListId.isEmpty || trimmedUid.isEmpty) {
      throw StateError('Dados inválidos para reabrir lista.');
    }
    await _listRef(trimmedListId).update(<String, dynamic>{
      'isClosed': false,
      'closedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertItem({
    required String listId,
    required SharedShoppingItem item,
    required String updatedBy,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedUid = updatedBy.trim();
    if (trimmedListId.isEmpty || trimmedUid.isEmpty) {
      return;
    }
    final payload = item.toFirestorePayload(updatedBy: trimmedUid);
    payload['createdAt'] = item.createdAt;
    await _itemsRef(
      trimmedListId,
    ).doc(item.id).set(payload, SetOptions(merge: true));
    await _listRef(
      trimmedListId,
    ).update(<String, dynamic>{'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteItem({
    required String listId,
    required String itemId,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedItemId = itemId.trim();
    if (trimmedListId.isEmpty || trimmedItemId.isEmpty) {
      return;
    }
    await _itemsRef(trimmedListId).doc(trimmedItemId).delete();
    await _listRef(
      trimmedListId,
    ).update(<String, dynamic>{'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> togglePurchased({
    required String listId,
    required String itemId,
    required bool isPurchased,
    required String updatedBy,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedItemId = itemId.trim();
    final trimmedUid = updatedBy.trim();
    if (trimmedListId.isEmpty || trimmedItemId.isEmpty || trimmedUid.isEmpty) {
      return;
    }
    await _itemsRef(trimmedListId).doc(trimmedItemId).update(<String, dynamic>{
      'isPurchased': isPurchased,
      'updatedBy': trimmedUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _listRef(
      trimmedListId,
    ).update(<String, dynamic>{'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> changeQuantity({
    required String listId,
    required String itemId,
    required int quantity,
    required String updatedBy,
  }) async {
    final trimmedListId = listId.trim();
    final trimmedItemId = itemId.trim();
    final trimmedUid = updatedBy.trim();
    if (trimmedListId.isEmpty || trimmedItemId.isEmpty || trimmedUid.isEmpty) {
      return;
    }
    await _itemsRef(trimmedListId).doc(trimmedItemId).update(<String, dynamic>{
      'quantity': max(1, quantity),
      'updatedBy': trimmedUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _listRef(
      trimmedListId,
    ).update(<String, dynamic>{'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = _randomInviteCode();
      final snapshot = await _inviteRef(candidate).get();
      if (!snapshot.exists) {
        return candidate;
      }
    }
    throw StateError('Falha ao gerar codigo de compartilhamento unico.');
  }

  String _randomInviteCode() {
    const codeLength = 8;
    final buffer = StringBuffer();
    for (var index = 0; index < codeLength; index++) {
      final charIndex = _random.nextInt(_inviteAlphabet.length);
      buffer.write(_inviteAlphabet[charIndex]);
    }
    return buffer.toString();
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate().toLocal();
    }
    if (raw is DateTime) {
      return raw.toLocal();
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }
    return null;
  }

  static List<PaymentBalance> _parsePaymentBalances(dynamic raw) {
    if (raw is! List) {
      return const <PaymentBalance>[];
    }
    final parsed = <PaymentBalance>[];
    for (final entry in raw) {
      if (entry is Map) {
        parsed.add(PaymentBalance.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return List.unmodifiable(parsed);
  }

  static String _normalizeInviteCode(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    return cleaned;
  }

  static String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
