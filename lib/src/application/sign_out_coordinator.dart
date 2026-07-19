import 'sign_out_policy.dart';

enum SignOutDecision { cancel, syncAndSignOut, discardAndSignOut }

enum SignOutFailureStep { synchronize, signOut }

class SignOutFailure implements Exception {
  const SignOutFailure({required this.step, required this.cause});

  final SignOutFailureStep step;
  final Object cause;
}

class SignOutCoordinator {
  const SignOutCoordinator();

  Future<bool> execute({
    required SignOutAction action,
    required Future<SignOutDecision> Function(SignOutAction action)
    requestDecision,
    required Future<void> Function()? synchronize,
    required Future<void> Function({required bool discardPendingChanges})
    signOut,
  }) async {
    final decision = action == SignOutAction.signOutImmediately
        ? SignOutDecision.discardAndSignOut
        : await requestDecision(action);

    if (decision == SignOutDecision.cancel) {
      return false;
    }

    if (decision == SignOutDecision.syncAndSignOut) {
      final sync = synchronize;
      if (sync == null) {
        throw SignOutFailure(
          step: SignOutFailureStep.synchronize,
          cause: StateError('Sincronização indisponível.'),
        );
      }
      try {
        await sync();
      } catch (error) {
        throw SignOutFailure(
          step: SignOutFailureStep.synchronize,
          cause: error,
        );
      }
    }

    try {
      await signOut(
        discardPendingChanges:
            action != SignOutAction.signOutImmediately &&
            decision == SignOutDecision.discardAndSignOut,
      );
    } catch (error) {
      throw SignOutFailure(step: SignOutFailureStep.signOut, cause: error);
    }
    return true;
  }
}
