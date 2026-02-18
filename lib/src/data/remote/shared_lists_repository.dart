import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

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
      inviteCode:
          SharedListsRepository._cleanNullable(data['inviteCode'] as String?),
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
  final String? inviteCode;
  final String? sourceLocalListId;

  bool isOwner(String uid) => ownerUid == uid;
  int get memberCount => memberUids.toSet().length;

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
      inviteCode: clearInviteCode ? null : inviteCode ?? this.inviteCode,
      sourceLocalListId: clearSourceLocalListId
          ? null
          : sourceLocalListId ?? this.sourceLocalListId,
    );
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
  static const int _maxMembersPerList = 30;
  static const String _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  static FirebaseFirestore _buildPreferredFirestore() {
    // Usa sempre o banco (default) em todas as plataformas.
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> get _sharedListsRef =>
      _firestore.collection(_sharedListsCollection);

  CollectionReference<Map<String, dynamic>> get _listInvitesRef =>
      _firestore.collection(_listInvitesCollection);

  DocumentReference<Map<String, dynamic>> _listRef(String listId) =>
      _sharedListsRef.doc(listId);

  CollectionReference<Map<String, dynamic>> _itemsRef(String listId) =>
      _listRef(listId).collection(_itemsSubCollection);

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

  Stream<List<SharedShoppingListSummary>> watchOwnedSharedLists(String uid) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return const Stream<List<SharedShoppingListSummary>>.empty();
    }
    return _sharedListsRef.where('ownerUid', isEqualTo: trimmedUid).snapshots().map((
      snapshot,
    ) {
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
    final generatedCode = await _generateUniqueInviteCode();
    final docRef = _listRef(uniqueId());
    final summary = SharedShoppingListSummary(
      id: docRef.id,
      name: localList.name,
      ownerUid: trimmedUid,
      memberUids: <String>[trimmedUid],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      inviteCode: generatedCode,
      sourceLocalListId: localList.id,
    );

    final batch = _firestore.batch();
    batch.set(
      docRef,
      summary.toCreatePayload(
        ownerUid: trimmedUid,
        inviteCode: generatedCode,
        sourceLocalListId: localList.id,
      ),
    );
    for (final item in localList.items) {
      final sharedItem = SharedShoppingItem.fromShoppingItem(item, trimmedUid);
      batch.set(
        _itemsRef(docRef.id).doc(sharedItem.id),
        sharedItem.toFirestorePayload(updatedBy: trimmedUid),
      );
    }
    batch.set(
      _inviteRef(generatedCode),
      <String, dynamic>{
        'code': generatedCode,
        'listId': docRef.id,
        'ownerUid': trimmedUid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
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
    final newCode = await _generateUniqueInviteCode();
    await _firestore.runTransaction((transaction) async {
      final listSnapshot = await transaction.get(_listRef(trimmedListId));
      if (!listSnapshot.exists) {
        throw StateError('Lista compartilhada nao encontrada.');
      }
      final parsed = SharedShoppingListSummary.fromFirestoreDoc(listSnapshot);
      if (!parsed.isOwner(trimmedUid)) {
        throw StateError('Somente o dono pode gerar codigo.');
      }
      final previousCode = parsed.inviteCode;
      if (previousCode != null && previousCode.isNotEmpty) {
        transaction.delete(_inviteRef(previousCode));
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
    await _firestore.runTransaction((transaction) async {
      final listSnapshot = await transaction.get(_listRef(trimmedListId));
      if (!listSnapshot.exists) {
        return;
      }
      final parsed = SharedShoppingListSummary.fromFirestoreDoc(listSnapshot);
      if (!parsed.isOwner(trimmedUid)) {
        throw StateError('Somente o dono pode revogar codigo.');
      }
      final previousCode = parsed.inviteCode;
      if (previousCode != null && previousCode.isNotEmpty) {
        transaction.delete(_inviteRef(previousCode));
      }
      transaction.update(_listRef(trimmedListId), <String, dynamic>{
        'inviteCode': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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

    return _firestore.runTransaction((transaction) async {
      final inviteSnapshot = await transaction.get(_inviteRef(normalizedCode));
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

      final listSnapshot = await transaction.get(_listRef(listId));
      if (!listSnapshot.exists) {
        throw StateError('Lista compartilhada nao encontrada.');
      }
      final parsed = SharedShoppingListSummary.fromFirestoreDoc(listSnapshot);
      final members = parsed.memberUids.toSet();
      if (members.length >= _maxMembersPerList && !members.contains(trimmedUid)) {
        throw StateError('Limite de participantes atingido.');
      }
      transaction.update(_listRef(listId), <String, dynamic>{
        'memberUids': FieldValue.arrayUnion(<String>[trimmedUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return listId;
    });
  }

  Future<void> updateListMeta({
    required String listId,
    String? name,
  }) async {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) {
      return;
    }
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    final cleanName = _cleanNullable(name);
    if (cleanName != null) {
      updates['name'] = cleanName;
    }
    await _listRef(trimmedListId).update(updates);
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
    await _itemsRef(trimmedListId).doc(item.id).set(payload, SetOptions(merge: true));
    await _listRef(trimmedListId).update(<String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    await _listRef(trimmedListId).update(<String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    await _listRef(trimmedListId).update(<String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    await _listRef(trimmedListId).update(<String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  static String _normalizeInviteCode(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
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
