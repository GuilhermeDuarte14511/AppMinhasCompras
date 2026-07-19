enum SignOutAction {
  signOutImmediately,
  syncThenSignOut,
  confirmDiscardOfflineChanges,
}

SignOutAction resolveSignOutAction({
  required bool hasPendingChanges,
  required bool isSyncing,
  required bool hasNetworkConnection,
}) {
  final needsSync = hasPendingChanges || isSyncing;
  if (!needsSync) {
    return SignOutAction.signOutImmediately;
  }
  if (hasNetworkConnection) {
    return SignOutAction.syncThenSignOut;
  }
  return SignOutAction.confirmDiscardOfflineChanges;
}
