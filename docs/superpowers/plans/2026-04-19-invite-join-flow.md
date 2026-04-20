# Invite/Join Deep-Link Flow Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a low-friction deep-link invite/join flow that increases join completion while preserving the current Firebase/Firestore architecture.

**Architecture:** Add a focused invite-join use case that separates parsing/preview/join orchestration from UI. Keep repository logic in `shared_lists_repository.dart`, add pending-invite resume state in app-level storage, and introduce a small dedicated presentation flow for link preview + confirm + auth resume. Minimize changes to existing list/sync behavior.

**Tech Stack:** Flutter, Dart, Firebase Auth, Cloud Firestore, SharedPreferences, flutter_test.

---

## Scope check
This plan targets one subsystem only: invite-link open -> preview -> auth gate -> confirm join -> open shared list. It does not include roles/permissions, activity feed, or major backend redesign.

## File structure map

### New files
- `lib/src/application/invite_join_contracts.dart`  
  Canonical contract types (`InvitePreview`, `InvitePreviewState`, `JoinByCodeOutcome`, use-case DTOs).
- `lib/src/application/invite_join_use_case.dart`  
  Single-purpose orchestration for invite preview + idempotent join result mapping.
- `lib/src/presentation/invite_join_page.dart`  
  Focused page/state for invite preview, confirm CTA, and terminal error states.
- `lib/src/data/local/pending_invite_storage.dart`  
  Persist/restore/clear pending invite payload for auth resume.
- `lib/src/data/remote/shared_list_invite_gateway.dart`  
  Focused invite-only Firestore gateway to avoid growing `shared_lists_repository.dart`.
- `test/application/invite_join_use_case_test.dart`  
  Unit tests for orchestration states and idempotency semantics.
- `test/data/pending_invite_storage_test.dart`  
  Unit tests for pending invite persistence lifecycle.
- `test/data/remote/shared_lists_repository_invite_test.dart`  
  Repository-level tests for invite preview and join outcome mapping.
- `test/presentation/invite_join_page_test.dart`  
  Widget tests for preview, auth-required gating, and confirm behavior.

### Existing files to modify
- `lib/src/data/remote/shared_lists_repository.dart`  
  Add invite-preview read and explicit join outcomes without breaking existing callers.
- `lib/src/app/shopping_list_app.dart`  
  Wire pending invite resume after auth and route to invite flow entry.
- `lib/src/presentation/pages.dart`  
  Reuse new invite flow from dashboard action (`_joinSharedListByCode`) instead of direct dialog-only path.
- `pubspec.yaml` (only if a deep-link package is needed beyond current platform integration).

### Existing docs/spec references
- `docs/superpowers/specs/2026-04-19-invite-join-flow-design.md`

---

## Chunk 1: Core invite domain + data contracts

### Task 0: Create canonical invite contracts

**Files:**
- Create: `lib/src/application/invite_join_contracts.dart`
- Create: `test/application/invite_join_contracts_test.dart`

- [ ] **Step 1: Write failing tests for contract defaults and enum coverage**

```dart
test('InvitePreview supports metadata-null terminal states', () {
  const preview = InvitePreview(state: InvitePreviewState.disabled);
  expect(preview.listId, isNull);
});

test('JoinByCodeOutcome includes joined/alreadyMember/invalid/expired/disabled', () {
  expect(JoinByCodeOutcome.values.length, 5);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/application/invite_join_contracts_test.dart`  
Expected: FAIL because contracts file does not exist.

- [ ] **Step 3: Implement minimal contracts**

```dart
// lib/src/application/invite_join_contracts.dart
enum InvitePreviewState { ready, invalid, expired, disabled, temporaryFailure }
enum InviteJoinState { joined, alreadyMember, invalid, expired, disabled, authRequired, temporaryFailure }
enum JoinByCodeOutcome { joined, alreadyMember, invalid, expired, disabled }

class InvitePreview {
  const InvitePreview({
    required this.state,
    this.listId,
    this.listName,
    this.ownerUid,
    this.memberCount,
  });
  final InvitePreviewState state;
  final String? listId;
  final String? listName;
  final String? ownerUid;
  final int? memberCount;
}

class InvitePreviewResult {
  const InvitePreviewResult({
    required this.state,
    this.listId,
    this.listName,
    this.ownerUid,
    this.memberCount,
  });
  final InvitePreviewState state;
  final String? listId;
  final String? listName;
  final String? ownerUid;
  final int? memberCount;
}

class InviteJoinResult {
  const InviteJoinResult({required this.state, this.listId, this.message});
  final InviteJoinState state;
  final String? listId;
  final String? message;
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/application/invite_join_contracts_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/application/invite_join_contracts.dart test/application/invite_join_contracts_test.dart
git commit -m "feat: add canonical invite join contracts"
```

### Task 1: Add failing tests for invite orchestration states

**Files:**
- Create: `test/application/invite_join_use_case_test.dart`
- Create: `lib/src/application/invite_join_use_case.dart`
- Modify: `lib/src/application/invite_join_contracts.dart` (only if tests force contract refinement)

- [ ] **Step 1: Write the failing tests (@superpowers:test-driven-development)**

```dart
test('returns preview-ready when invite exists and active', () async {
  final repo = FakeInviteRepo(previewState: FakePreviewState.ready);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.loadPreview('A1B2C3D4');
  expect(result.state, InvitePreviewState.ready);
});

test('maps preview invalid state', () async {
  final repo = FakeInviteRepo(previewState: FakePreviewState.invalid);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.loadPreview('BADCODE');
  expect(result.state, InvitePreviewState.invalid);
});

test('maps preview expired state', () async {
  final repo = FakeInviteRepo(previewState: FakePreviewState.expired);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.loadPreview('OLDCODE');
  expect(result.state, InvitePreviewState.expired);
});

test('maps preview disabled state', () async {
  final repo = FakeInviteRepo(previewState: FakePreviewState.disabled);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.loadPreview('OFFCODE');
  expect(result.state, InvitePreviewState.disabled);
});

test('maps preview exceptions to temporaryFailure', () async {
  final repo = FakeInviteRepo(throwsOnPreview: true);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.loadPreview('A1B2C3D4');
  expect(result.state, InvitePreviewState.temporaryFailure);
});

test('returns auth-required when uid is empty at join confirm', () async {
  final repo = FakeInviteRepo(joinOutcome: JoinByCodeOutcome.joined);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.confirmJoin(code: 'A1B2C3D4', uid: '');
  expect(result.state, InviteJoinState.authRequired);
});

test('maps already-member as success-open-list', () async {
  final repo = FakeInviteRepo(joinOutcome: JoinByCodeOutcome.alreadyMember);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.confirmJoin(code: 'A1B2C3D4', uid: 'u1');
  expect(result.state, InviteJoinState.alreadyMember);
});

test('maps invalid invite to invalid terminal state', () async {
  final repo = FakeInviteRepo(joinOutcome: JoinByCodeOutcome.invalid);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.confirmJoin(code: 'BADCODE', uid: 'u1');
  expect(result.state, InviteJoinState.invalid);
});

test('maps expired invite to expired terminal state', () async {
  final repo = FakeInviteRepo(joinOutcome: JoinByCodeOutcome.expired);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.confirmJoin(code: 'OLDCODE', uid: 'u1');
  expect(result.state, InviteJoinState.expired);
});

test('maps disabled invite to disabled terminal state', () async {
  final repo = FakeInviteRepo(joinOutcome: JoinByCodeOutcome.disabled);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.confirmJoin(code: 'DISABLED', uid: 'u1');
  expect(result.state, InviteJoinState.disabled);
});

test('maps backend exception to temporaryFailure', () async {
  final repo = FakeInviteRepo(throwsOnJoin: true);
  final useCase = InviteJoinUseCase(repository: repo);
  final result = await useCase.confirmJoin(code: 'A1B2C3D4', uid: 'u1');
  expect(result.state, InviteJoinState.temporaryFailure);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/application/invite_join_use_case_test.dart`  
Expected: FAIL with missing symbols/types (`InviteJoinUseCase`, result states).

- [ ] **Step 3: Write minimal implementation**

```dart
import 'invite_join_contracts.dart';

abstract class InviteJoinRepository {
  Future<InvitePreview> fetchInvitePreview({required String inviteCode});
  Future<JoinByCodeOutcome> joinByCodeWithOutcome({
    required String inviteCode,
    required String uid,
  });
}

class InviteJoinUseCase {
  InviteJoinUseCase({required InviteJoinRepository repository}) : _repository = repository;
  final InviteJoinRepository _repository;

  Future<InvitePreviewResult> loadPreview(String code) async {
    final preview = await _repository.fetchInvitePreview(inviteCode: code);
    return InvitePreviewResult(
      state: preview.state,
      listId: preview.listId,
      listName: preview.listName,
      ownerUid: preview.ownerUid,
      memberCount: preview.memberCount,
    );
  }

  Future<InviteJoinResult> confirmJoin({
    required String code,
    required String uid,
  }) async {
    if (uid.trim().isEmpty) {
      return const InviteJoinResult(state: InviteJoinState.authRequired);
    }
    try {
      final outcome = await _repository.joinByCodeWithOutcome(
        inviteCode: code,
        uid: uid,
      );
      return switch (outcome) {
        JoinByCodeOutcome.joined =>
          const InviteJoinResult(state: InviteJoinState.joined),
        JoinByCodeOutcome.alreadyMember =>
          const InviteJoinResult(state: InviteJoinState.alreadyMember),
        JoinByCodeOutcome.invalid =>
          const InviteJoinResult(state: InviteJoinState.invalid),
        JoinByCodeOutcome.expired =>
          const InviteJoinResult(state: InviteJoinState.expired),
        JoinByCodeOutcome.disabled =>
          const InviteJoinResult(state: InviteJoinState.disabled),
      };
    } catch (_) {
      return const InviteJoinResult(state: InviteJoinState.temporaryFailure);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/application/invite_join_use_case_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/application/invite_join_use_case_test.dart lib/src/application/invite_join_use_case.dart
git commit -m "feat: add invite join use-case with explicit result states"
```

### Task 2: Add repository preview + idempotent join outcomes

**Files:**
- Create: `lib/src/data/remote/shared_list_invite_gateway.dart`
- Modify: `lib/src/data/remote/shared_lists_repository.dart`
- Modify: `lib/src/application/invite_join_contracts.dart` (import only; no duplicate type declarations)
- Create: `test/data/remote/shared_lists_repository_invite_test.dart`

- [ ] **Step 1: Write failing tests for repository-facing outcomes**

```dart
test('preview returns list metadata for active invite', () async {
  final repo = createRepositoryWithInvite(code: 'A1B2C3D4', listId: 'l1');
  final preview = await repo.fetchInvitePreview(inviteCode: 'A1B2C3D4');
  expect(preview.listId, 'l1');
  expect(preview.listName, isNotEmpty);
});

test('join returns alreadyMember when uid already in memberUids', () async {
  final repo = createRepositoryWithMember(uid: 'u1');
  final outcome = await repo.joinByCodeWithOutcome(inviteCode: 'A1B2C3D4', uid: 'u1');
  expect(outcome, JoinByCodeOutcome.alreadyMember);
});

test('join returns joined for first successful membership insert', () async {
  final repo = createRepositoryWithInvite(code: 'A1B2C3D4', listId: 'l1');
  final outcome = await repo.joinByCodeWithOutcome(inviteCode: 'A1B2C3D4', uid: 'u2');
  expect(outcome, JoinByCodeOutcome.joined);
});

test('join stays alreadyMember on repeated calls (idempotent)', () async {
  final repo = createRepositoryWithInvite(code: 'A1B2C3D4', listId: 'l1');
  await repo.joinByCodeWithOutcome(inviteCode: 'A1B2C3D4', uid: 'u2');
  final second = await repo.joinByCodeWithOutcome(inviteCode: 'A1B2C3D4', uid: 'u2');
  expect(second, JoinByCodeOutcome.alreadyMember);
});

test('join returns invalid when invite document does not exist', () async {
  final repo = createRepositoryWithoutInvite();
  final outcome = await repo.joinByCodeWithOutcome(inviteCode: 'BADCODE', uid: 'u1');
  expect(outcome, JoinByCodeOutcome.invalid);
});

test('join returns expired when invite has expiration date in the past', () async {
  final repo = createRepositoryWithExpiredInvite();
  final outcome = await repo.joinByCodeWithOutcome(inviteCode: 'OLDCODE', uid: 'u1');
  expect(outcome, JoinByCodeOutcome.expired);
});

test('join returns disabled when invite active flag is false', () async {
  final repo = createRepositoryWithDisabledInvite();
  final outcome = await repo.joinByCodeWithOutcome(inviteCode: 'OFFCODE', uid: 'u1');
  expect(outcome, JoinByCodeOutcome.disabled);
});

test('preview maps disabled invite to disabled preview state', () async {
  final repo = createRepositoryWithDisabledInvite();
  final preview = await repo.fetchInvitePreview(inviteCode: 'OFFCODE');
  expect(preview.state, InvitePreviewState.disabled);
});

test('preview maps missing invite doc to invalid preview state', () async {
  final repo = createRepositoryWithoutInvite();
  final preview = await repo.fetchInvitePreview(inviteCode: 'BADCODE');
  expect(preview.state, InvitePreviewState.invalid);
});

test('preview maps expired invite to expired preview state', () async {
  final repo = createRepositoryWithExpiredInvite();
  final preview = await repo.fetchInvitePreview(inviteCode: 'OLDCODE');
  expect(preview.state, InvitePreviewState.expired);
});
```

- [ ] **Step 2: Run targeted test**

Run: `flutter test test/data/remote/shared_lists_repository_invite_test.dart --plain-name "join returns alreadyMember when uid already in memberUids"`  
Expected: FAIL with assertion mismatch or missing outcome mapping.

- [ ] **Step 3: Implement minimal repository additions**

```dart
// Canonical contracts already defined in:
// lib/src/application/invite_join_contracts.dart
// Repository must import these types; DO NOT redeclare in data layer.
Future<InvitePreview> fetchInvitePreview({required String inviteCode});
Future<JoinByCodeOutcome> joinByCodeWithOutcome({required String inviteCode, required String uid});

// Explicit acceptance behavior:
// - active + non-member => joined
// - active + already member => alreadyMember
// - missing invite doc => invalid
// - expired invite timestamp => expired
// - inactive flag => disabled
// - repeated same join call => alreadyMember (idempotent)
//
// File ownership:
// - shared_list_invite_gateway.dart: all invite doc reads + invite-state classification + join mutation primitives.
// - shared_lists_repository.dart: delegates invite operations to gateway and preserves public API for callers.
// - invite_join_contracts.dart: single source of truth for invite/join contract types.
```

- [ ] **Step 4: Run test**

Run: `flutter test test/data/remote/shared_lists_repository_invite_test.dart`  
Expected: PASS.

- [ ] **Step 4.1: Run regression compile check for existing flow**

Run: `flutter test test/widget_test.dart --plain-name "Initial menu renders expected options"`  
Expected: PASS (proves existing callers still compile and run).

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/remote/shared_list_invite_gateway.dart lib/src/data/remote/shared_lists_repository.dart test/data/remote/shared_lists_repository_invite_test.dart
git commit -m "feat: add invite gateway with explicit outcome mapping"
```

### Task 3: Add pending invite persistence for auth resume

**Files:**
- Create: `lib/src/data/local/pending_invite_storage.dart`
- Create: `test/data/pending_invite_storage_test.dart`

- [ ] **Step 1: Write failing storage tests**

```dart
test('save and load pending invite payload', () async {
  final storage = PendingInviteStorage(prefs);
  await storage.save(const PendingInvitePayload(
    inviteCode: 'A1B2C3D4',
    source: 'link',
    listIdHint: 'shared-list-1',
    createdAtIso: '2026-04-19T22:00:00.000Z',
  ));
  final loaded = await storage.load();
  expect(loaded?.inviteCode, 'A1B2C3D4');
  expect(loaded?.source, 'link');
  expect(loaded?.listIdHint, 'shared-list-1');
  expect(loaded?.createdAtIso, '2026-04-19T22:00:00.000Z');
});

test('clear removes pending invite payload', () async {
  final storage = PendingInviteStorage(prefs);
  await storage.save(const PendingInvitePayload(
    inviteCode: 'A1B2C3D4',
    source: 'link',
    createdAtIso: '2026-04-19T22:00:00.000Z',
  ));
  await storage.clear();
  expect(await storage.load(), isNull);
});

test('payload is kept after temporary failure (no clear)', () async {
  final storage = PendingInviteStorage(prefs);
  await storage.save(const PendingInvitePayload(
    inviteCode: 'A1B2C3D4',
    source: 'link',
    createdAtIso: '2026-04-19T22:00:00.000Z',
  ));
  final loaded = await storage.load();
  expect(loaded?.inviteCode, 'A1B2C3D4');
});

test('payload is removed after terminal handling (clear)', () async {
  final storage = PendingInviteStorage(prefs);
  await storage.save(const PendingInvitePayload(
    inviteCode: 'A1B2C3D4',
    source: 'link',
    createdAtIso: '2026-04-19T22:00:00.000Z',
  ));
  await storage.clear();
  expect(await storage.load(), isNull);
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/data/pending_invite_storage_test.dart`  
Expected: FAIL because storage class does not exist yet.

- [ ] **Step 3: Implement minimal storage**

```dart
class PendingInviteStorage {
  Future<void> save(PendingInvitePayload payload);
  Future<PendingInvitePayload?> load();
  Future<void> clear();
}

class PendingInvitePayload {
  const PendingInvitePayload({
    required this.inviteCode,
    required this.source,
    this.listIdHint,
    required this.createdAtIso,
  });
  final String inviteCode;
  final String source;
  final String? listIdHint;
  final String createdAtIso;
}
```

- [ ] **Step 4: Run test**

Run: `flutter test test/data/pending_invite_storage_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/local/pending_invite_storage.dart test/data/pending_invite_storage_test.dart
git commit -m "feat: add pending invite persistence storage"
```

---

## Chunk 2: UI flow, app wiring, and verification

### Task 4: Build invite preview + confirm page

**Files:**
- Create: `lib/src/presentation/invite_join_page.dart`
- Create: `test/presentation/invite_join_page_test.dart`
- Modify: `lib/src/presentation/pages.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('shows invite preview and confirm CTA', (tester) async {
  await tester.pumpWidget(buildInviteJoinPage(previewReady: true));
  expect(find.text('Entrar na lista compartilhada'), findsOneWidget);
  expect(find.text('Confirmar entrada'), findsOneWidget);
});

testWidgets('shows auth gate message when not logged', (tester) async {
  await tester.pumpWidget(buildInviteJoinPage(authRequired: true));
  expect(find.textContaining('Faça login'), findsOneWidget);
});

testWidgets('shows explicit terminal state for invalid invite', (tester) async {
  await tester.pumpWidget(buildInviteJoinPage(invalidInvite: true));
  expect(find.textContaining('Convite inválido'), findsOneWidget);
});
```

- [ ] **Step 2: Run targeted test**

Run: `flutter test test/presentation/invite_join_page_test.dart`  
Expected: FAIL (page/widgets not implemented).

- [ ] **Step 3: Implement minimal page + integration point**

```dart
class InviteJoinPage extends StatefulWidget {
  const InviteJoinPage({required this.inviteCode, required this.useCase, required this.onOpenSharedList, super.key});
}
// State machine: loading -> previewReady -> confirmInFlight -> success|terminalFailure.
```

- [ ] **Step 4: Run test**

Run: `flutter test test/presentation/invite_join_page_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/presentation/invite_join_page.dart lib/src/presentation/pages.dart test/presentation/invite_join_page_test.dart
git commit -m "feat: add invite preview and confirm join page"
```

### Task 5: Wire auth resume + dashboard join entry

**Files:**
- Modify: `lib/src/app/shopping_list_app.dart`
- Modify: `lib/src/presentation/pages.dart`
- Test: `test/presentation/invite_join_page_test.dart`

- [ ] **Step 1: Write failing test(s) for resume flow**

```dart
testWidgets('resumes pending invite after login and opens confirm step', (tester) async {
  await tester.pumpWidget(buildAppWithPendingInviteAfterAuth());
  await tester.pumpAndSettle();
  expect(find.text('Entrar na lista compartilhada'), findsOneWidget);
});
```

- [ ] **Step 2: Run targeted test**

Run: `flutter test test/presentation/invite_join_page_test.dart --plain-name "resumes pending invite after login and opens confirm step"`  
Expected: FAIL because resume wiring is missing.

- [ ] **Step 3: Implement minimal wiring**

```dart
// In auth listener after user becomes non-null:
final pending = await _pendingInviteStorage.load();
if (pending != null && mounted) {
  await Navigator.of(context).push(buildAppPageRoute(
    builder: (_) => InviteJoinPage(inviteCode: pending.inviteCode, useCase: _inviteJoinUseCase, onOpenSharedList: _openSharedListById),
  ));
}
```

- [ ] **Step 4: Run test**

Run: `flutter test test/presentation/invite_join_page_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/app/shopping_list_app.dart lib/src/presentation/pages.dart test/presentation/invite_join_page_test.dart
git commit -m "feat: resume pending invite flow after authentication"
```

### Task 6: Full verification and regression safety

**Files:**
- Modify (if needed): `test/widget_test.dart`
- Test: `test/application/invite_join_use_case_test.dart`
- Test: `test/data/pending_invite_storage_test.dart`
- Test: `test/presentation/invite_join_page_test.dart`

- [ ] **Step 1: Add/adjust regression tests for idempotency and terminal states**

```dart
test('reopening same invite does not duplicate membership', () async { /* ... */ });
```

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/application/invite_join_use_case_test.dart test/data/pending_invite_storage_test.dart test/presentation/invite_join_page_test.dart`  
Expected: PASS.

- [ ] **Step 3: Run full project verification**

Run: `flutter test && flutter analyze`  
Expected: tests pass; analyzer may still show pre-existing info-level warnings unrelated to this feature.

- [ ] **Step 4: Commit final verification-related test updates**

```bash
git add test/application/invite_join_use_case_test.dart test/data/pending_invite_storage_test.dart test/presentation/invite_join_page_test.dart test/widget_test.dart
git commit -m "test: add invite join regression coverage"
```

---

## Execution notes
1. Keep `pages.dart` edits minimal; put new invite-specific UI/state into `invite_join_page.dart` to avoid further growth in the large page file.
2. Reuse existing `SharedListsRepository` normalization helpers for invite code handling.
3. No schema rewrite in v1; if telemetry fields are added, make them optional/backward compatible.
4. Follow @superpowers:verification-before-completion before final feature handoff.
