import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sign_out_policy.dart';

void main() {
  test('signs out immediately when no local changes are pending', () {
    final action = resolveSignOutAction(
      hasPendingChanges: false,
      isSyncing: false,
      hasNetworkConnection: true,
    );

    expect(action, SignOutAction.signOutImmediately);
  });

  test('syncs before signing out when online changes are pending', () {
    final action = resolveSignOutAction(
      hasPendingChanges: true,
      isSyncing: false,
      hasNetworkConnection: true,
    );

    expect(action, SignOutAction.syncThenSignOut);
  });

  test('waits for an active sync before signing out', () {
    final action = resolveSignOutAction(
      hasPendingChanges: false,
      isSyncing: true,
      hasNetworkConnection: true,
    );

    expect(action, SignOutAction.syncThenSignOut);
  });

  test('requires explicit discard confirmation when offline', () {
    final action = resolveSignOutAction(
      hasPendingChanges: true,
      isSyncing: false,
      hasNetworkConnection: false,
    );

    expect(action, SignOutAction.confirmDiscardOfflineChanges);
  });
}
