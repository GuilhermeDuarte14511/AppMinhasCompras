import 'sync_operation.dart';

/// Persistence port for a user-scoped sync outbox.
///
/// Implementations must preserve list order and replace the complete stored
/// snapshot atomically in [save].
abstract interface class SyncOutboxStorage {
  Future<List<SyncOperation>> load({required String userId});

  Future<void> save({
    required String userId,
    required List<SyncOperation> operations,
  });

  Future<void> clear({required String userId});
}
