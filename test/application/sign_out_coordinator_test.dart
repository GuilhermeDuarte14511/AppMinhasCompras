import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sign_out_coordinator.dart';
import 'package:lista_compras_material/src/application/sign_out_policy.dart';

void main() {
  const coordinator = SignOutCoordinator();

  test('signs out immediately without asking for a decision', () async {
    var requestedDecision = false;
    var signedOut = false;

    final result = await coordinator.execute(
      action: SignOutAction.signOutImmediately,
      requestDecision: (_) async {
        requestedDecision = true;
        return SignOutDecision.cancel;
      },
      synchronize: null,
      signOut: ({required discardPendingChanges}) async {
        expect(discardPendingChanges, isFalse);
        signedOut = true;
      },
    );

    expect(result, isTrue);
    expect(requestedDecision, isFalse);
    expect(signedOut, isTrue);
  });

  test('synchronizes before signing out', () async {
    final steps = <String>[];

    final result = await coordinator.execute(
      action: SignOutAction.syncThenSignOut,
      requestDecision: (_) async => SignOutDecision.syncAndSignOut,
      synchronize: () async {
        steps.add('sync');
      },
      signOut: ({required discardPendingChanges}) async {
        expect(discardPendingChanges, isFalse);
        steps.add('signOut');
      },
    );

    expect(result, isTrue);
    expect(steps, ['sync', 'signOut']);
  });

  test('does not sign out when synchronization fails', () async {
    var signedOut = false;

    await expectLater(
      coordinator.execute(
        action: SignOutAction.syncThenSignOut,
        requestDecision: (_) async => SignOutDecision.syncAndSignOut,
        synchronize: () async => throw StateError('offline'),
        signOut: ({required discardPendingChanges}) async {
          signedOut = true;
        },
      ),
      throwsA(
        isA<SignOutFailure>().having(
          (failure) => failure.step,
          'step',
          SignOutFailureStep.synchronize,
        ),
      ),
    );

    expect(signedOut, isFalse);
  });

  test('cancelling keeps the session active', () async {
    var signedOut = false;

    final result = await coordinator.execute(
      action: SignOutAction.confirmDiscardOfflineChanges,
      requestDecision: (_) async => SignOutDecision.cancel,
      synchronize: null,
      signOut: ({required discardPendingChanges}) async {
        signedOut = true;
      },
    );

    expect(result, isFalse);
    expect(signedOut, isFalse);
  });

  test('marks an explicitly confirmed offline exit as discard', () async {
    bool? discardedPendingChanges;

    final result = await coordinator.execute(
      action: SignOutAction.confirmDiscardOfflineChanges,
      requestDecision: (_) async => SignOutDecision.discardAndSignOut,
      synchronize: null,
      signOut: ({required discardPendingChanges}) async {
        discardedPendingChanges = discardPendingChanges;
      },
    );

    expect(result, isTrue);
    expect(discardedPendingChanges, isTrue);
  });
}
