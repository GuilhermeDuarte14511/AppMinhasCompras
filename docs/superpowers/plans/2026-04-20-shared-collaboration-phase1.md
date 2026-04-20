# Shared Collaboration Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver Phase 1 collaboration reliability improvements (shared home card cues, deterministic invite/join outcomes, presence + pending sync indicators, recent activity feed, owner archive/hide visibility) to increase weekly active shared-list households.

**Architecture:** Keep existing `SharedListsRepository` as the source of truth for shared-list data and add focused collaborators: a lightweight collaboration state coordinator, event read/write mappers, and local visibility preference storage. Keep UI changes isolated to shared-home and shared-editor entry points while preserving current list editing flow. Implement Phase 1 only (no persisted offline replay queue, no role expansion, no conflict center).

**Tech Stack:** Flutter, Dart, Firebase Auth, Cloud Firestore, SharedPreferences, flutter_test.

---

## Scope check
This plan is intentionally Phase-1 only from `docs/superpowers/specs/2026-04-19-shared-collaboration-growth-design.md`.  
It excludes Phase 2+ work (persisted mutation queue, conflict center, role expansion, advanced analytics).

## File structure map

### Create
- `lib/src/application/shared_collaboration_state.dart`  
  Immutable UI state contracts for shared-home card cues (`isLive`, `isPending`, `lastEditor`, `lastUpdatedAt`, `activeMembersCount`).
- `lib/src/application/shared_collaboration_coordinator.dart`  
  Listener orchestration and mapping from repository/auth/connectivity into `SharedCollaborationState`.
- `lib/src/data/local/shared_visibility_prefs_storage.dart`  
  Persist owner visibility preferences (archive/hide for shared lists on home).
- `lib/src/data/remote/shared_activity_models.dart`  
  Phase-1 event model and serialization helpers for `shared_lists/{listId}/events/{eventId}`.
- `lib/src/data/remote/shared_activity_repository.dart`  
  Focused Firestore access for activity append/read (`events` subcollection).
- `lib/src/data/remote/shared_presence_repository.dart`  
  Presence heartbeat read helpers + stale-window calculations.
- `lib/src/presentation/widgets/shared_home_card_section.dart`  
  Focused shared-home cards UI (freshness, actor, pending badge, archive/hide actions).
- `lib/src/presentation/widgets/shared_activity_feed.dart`  
  Shared list activity feed UI component (top 20 ordered events).
- `test/firestore_rules/shared_events_rules_check.md`  
  Replaced by executable Firestore rules test suite below.
- `test/firestore_rules/package.json`  
  Isolated rules-test dependencies (`@firebase/rules-unit-testing`, `firebase`).
- `test/firestore_rules/shared_events.rules.test.js`  
  Executable emulator tests for member/non-member access and actorUid enforcement.
- `test/presentation/invite_join_handoff_test.dart`  
  Deep-link preview and success handoff assertions for shared invite flow.
- `test/application/shared_collaboration_coordinator_test.dart`
- `test/data/local/shared_visibility_prefs_storage_test.dart`
- `test/data/remote/shared_activity_models_test.dart`
- `test/presentation/shared_home_visibility_test.dart`
- `test/presentation/shared_activity_feed_test.dart`

### Modify
- `lib/src/data/remote/shared_lists_repository.dart`  
  Keep as orchestrator only; delegate activity/presence concerns to focused repositories and preserve existing public API.
- `lib/src/presentation/pages.dart`  
  Replace in-file shared-home rendering with widget integration and archive/hide filter wiring.
- `lib/src/presentation/shared_lists_pages.dart`  
  Wire `SharedActivityFeed` and presence/pending chips without adding complex logic inline.
- `lib/src/app/shopping_list_app.dart`  
  Wire collaboration coordinator lifecycle and visibility prefs storage.
- `firestore.rules`  
  Add `events` subcollection rules (member-scoped read/write; `actorUid == request.auth.uid`).
- `firestore.indexes.json`  
  Add required index for `events` ordering by `createdAt desc` (and optional actor filter only if used).

### Existing references
- `docs/superpowers/specs/2026-04-19-shared-collaboration-growth-design.md`
- `docs/superpowers/plans/2026-04-19-invite-join-flow.md` (reuse invite contracts and avoid duplicate flow logic)

---

## Chunk 1: Phase-1 collaboration reliability delivery

### Task 1: Add collaboration state contracts + coordinator

**Files:**
- Create: `lib/src/application/shared_collaboration_state.dart`
- Create: `lib/src/application/shared_collaboration_coordinator.dart`
- Test: `test/application/shared_collaboration_coordinator_test.dart`

- [ ] **Step 1: Write the failing coordinator tests (@superpowers:test-driven-development)**

```dart
test('emits pending state when local optimistic mutation exists', () async {
  final coordinator = buildCoordinatorWithFakes(pendingOps: 1, activeMembers: 2);
  final state = await coordinator.currentStateForList('list-1');
  expect(state.isPending, isTrue);
  expect(state.activeMembersCount, 2);
});

test('marks presence stale after timeout window', () async {
  final coordinator = buildCoordinatorWithFakes(
    lastPresenceAt: DateTime.now().subtract(const Duration(seconds: 91)),
  );
  final state = await coordinator.currentStateForList('list-1');
  expect(state.isLive, isFalse);
});

test('recalculates active presence on listener reconnect', () async {
  final coordinator = buildCoordinatorWithFakes(activeMembers: 0);
  await coordinator.onListenerReconnected('list-1');
  expect((await coordinator.currentStateForList('list-1')).activeMembersCount, 2);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/application/shared_collaboration_coordinator_test.dart`  
Expected: FAIL because coordinator/state files do not exist yet.

- [ ] **Step 3: Implement minimal contracts and coordinator**

```dart
class SharedCollaborationState {
  const SharedCollaborationState({
    required this.isLive,
    required this.isPending,
    required this.activeMembersCount,
    required this.lastUpdatedAt,
    this.lastEditor,
  });
  final bool isLive;
  final bool isPending;
  final int activeMembersCount;
  final DateTime? lastUpdatedAt;
  final String? lastEditor;
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/application/shared_collaboration_coordinator_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/application/shared_collaboration_state.dart lib/src/application/shared_collaboration_coordinator.dart test/application/shared_collaboration_coordinator_test.dart
git commit -m "feat: add shared collaboration state coordinator"
```

### Task 2: Add owner archive/hide shared-home visibility storage

**Files:**
- Create: `lib/src/data/local/shared_visibility_prefs_storage.dart`
- Create: `lib/src/presentation/widgets/shared_home_card_section.dart`
- Modify: `lib/src/presentation/pages.dart`
- Test: `test/data/local/shared_visibility_prefs_storage_test.dart`
- Test: `test/presentation/shared_home_visibility_test.dart`

- [ ] **Step 1: Write failing tests for archive/hide behavior**

```dart
test('hidden list ids are not rendered on shared home section', () {
  final visible = filterSharedListsForHome(
    all: [list('a'), list('b')],
    hiddenIds: {'b'},
  );
  expect(visible.map((e) => e.id), ['a']);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/data/local/shared_visibility_prefs_storage_test.dart test/presentation/shared_home_visibility_test.dart`  
Expected: FAIL because storage/filter APIs do not exist.

- [ ] **Step 3: Implement minimal storage + home filter integration**

```dart
abstract class SharedVisibilityPrefsStorage {
  Future<Set<String>> loadHiddenSharedListIds(String ownerUid);
  Future<void> saveHiddenSharedListIds(String ownerUid, Set<String> ids);
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/data/local/shared_visibility_prefs_storage_test.dart test/presentation/shared_home_visibility_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/local/shared_visibility_prefs_storage.dart lib/src/presentation/widgets/shared_home_card_section.dart lib/src/presentation/pages.dart test/data/local/shared_visibility_prefs_storage_test.dart test/presentation/shared_home_visibility_test.dart
git commit -m "feat: add shared home archive hide preferences"
```

### Task 3: Add phase-1 activity event schema + repository read/write APIs

**Files:**
- Create: `lib/src/data/remote/shared_activity_models.dart`
- Create: `lib/src/data/remote/shared_activity_repository.dart`
- Create: `lib/src/data/remote/shared_presence_repository.dart`
- Modify: `lib/src/data/remote/shared_lists_repository.dart`
- Create: `lib/src/presentation/widgets/shared_activity_feed.dart`
- Test: `test/data/remote/shared_activity_models_test.dart`
- Test: `test/presentation/shared_activity_feed_test.dart`

- [ ] **Step 1: Write failing tests for event serialization and ordering**

```dart
test('serializes required phase-1 event fields', () {
  final event = SharedActivityEvent.itemPurchasedToggled(
    listId: 'l1',
    itemId: 'i1',
    actorUid: 'u1',
    summary: 'Ana marcou Leite como comprado',
  );
  expect(event.toJson().keys, containsAll([
    'eventType', 'actorUid', 'entityType', 'entityId', 'summary', 'createdAt', 'schemaVersion',
  ]));
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/data/remote/shared_activity_models_test.dart test/presentation/shared_activity_feed_test.dart`  
Expected: FAIL because event model/repository methods are missing.

- [ ] **Step 3: Implement minimal event model + repo APIs**

```dart
Future<void> appendActivityEvent({
  required String listId,
  required String actorUid,
  required SharedActivityEvent event,
});

Stream<List<SharedActivityEvent>> watchRecentActivity({
  required String listId,
  int limit = 20,
});
```

```text
Implementation constraints:
- enforce `watchRecentActivity` default limit 20 and max limit 50
- enforce rolling retention cap of 500 events per list (delete oldest after append)
- keep UI feed access in shared_activity_feed.dart (no feed rendering logic in pages.dart)
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/data/remote/shared_activity_models_test.dart test/presentation/shared_activity_feed_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/remote/shared_activity_models.dart lib/src/data/remote/shared_activity_repository.dart lib/src/data/remote/shared_presence_repository.dart lib/src/data/remote/shared_lists_repository.dart lib/src/presentation/widgets/shared_activity_feed.dart test/data/remote/shared_activity_models_test.dart test/presentation/shared_activity_feed_test.dart
git commit -m "feat: add shared activity events feed contracts"
```

### Task 4: Enforce deterministic invite/join terminal outcomes in repository and UI mapping

**Files:**
- Modify: `lib/src/data/remote/shared_lists_repository.dart`
- Modify: `lib/src/presentation/shared_lists_pages.dart`
- Test: `test/shared_lists_visibility_test.dart`
- Test: `test/presentation/shared_home_visibility_test.dart` (add invite-state rendering assertions)
- Test: `test/presentation/invite_join_handoff_test.dart`

- [ ] **Step 1: Write failing tests for terminal states**

```dart
test('join by code maps already-member deterministically', () async {
  final result = await repository.joinSharedListByCode(inviteCode: 'A1B2C3', uid: 'u1');
  expect(result.state.name, 'already_member');
});

test('join by code maps invalid deterministically', () async { /* ... */ });
test('join by code maps expired deterministically', () async { /* ... */ });
test('join by code maps disabled deterministically', () async { /* ... */ });
test('join by code maps joined deterministically', () async { /* ... */ });

testWidgets('deep link preview loads and joined handoff opens shared list', (tester) async {
  await tester.pumpWidget(buildInviteEntryWithCode('A1B2C3'));
  expect(find.textContaining('Prévia da lista'), findsOneWidget);
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
  expect(find.byType(SharedListEditorPage), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/shared_lists_visibility_test.dart test/presentation/shared_home_visibility_test.dart`  
Expected: FAIL because `alreadyMember` terminal mapping is incomplete in current phase-1 UI path.

- [ ] **Step 3: Implement minimal deterministic mapping**

```dart
enum SharedJoinTerminalState { invalid, expired, disabled, already_member, joined }
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/shared_lists_visibility_test.dart test/presentation/shared_home_visibility_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/remote/shared_lists_repository.dart lib/src/presentation/shared_lists_pages.dart test/shared_lists_visibility_test.dart test/presentation/shared_home_visibility_test.dart test/presentation/invite_join_handoff_test.dart
git commit -m "fix: enforce deterministic shared invite join outcomes"
```

### Task 5: Update Firestore rules + indexes for activity feed security and queryability

**Files:**
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json`

- [ ] **Step 1: Write failing executable Firestore rules tests**

```dart
// test/data/remote/shared_activity_models_test.dart
test('rejects event payload when actorUid is empty', () {
  expect(
    () => SharedActivityEvent.itemUpdated(
      listId: 'l1',
      itemId: 'i1',
      actorUid: '',
      summary: 'invalid',
    ),
    throwsArgumentError,
  );
});
```

```js
// test/firestore_rules/shared_events.rules.test.js
it('denies non-member read', async () => { /* expect PERMISSION_DENIED */ });
it('denies member create when actorUid mismatches auth uid', async () => { /* expect PERMISSION_DENIED */ });
it('allows member create/read when actorUid matches auth uid', async () => { /* expect success */ });
```

- [ ] **Step 2: Run baseline validation commands**

Run:
1. `npm install --prefix test/firestore_rules`
2. `firebase emulators:exec --only firestore "npm test --prefix test/firestore_rules"`
Expected: FAIL before rules updates.

- [ ] **Step 3: Implement minimal rules/index changes**

```rules
match /shared_lists/{listId}/events/{eventId} {
  allow read: if isSharedListMember(listId);
  allow create: if isSharedListMember(listId)
    && request.resource.data.actorUid == request.auth.uid;
  allow update, delete: if false;
}
```

- [ ] **Step 4: Run repository + widget tests impacted by shared flow**

Run:
1. `flutter test test/data/remote/shared_activity_models_test.dart test/shared_lists_visibility_test.dart test/presentation/shared_activity_feed_test.dart`
2. `firebase emulators:exec --only firestore "npm test --prefix test/firestore_rules"`

Expected:
1. Flutter tests PASS.
2. Rules tests PASS with explicit coverage for non-member read deny, mismatched actorUid deny, and valid member read/write allow.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firestore.indexes.json test/firestore_rules/package.json test/firestore_rules/shared_events.rules.test.js test/presentation/shared_activity_feed_test.dart
git commit -m "chore: secure shared activity events rules and indexes"
```

### Task 6: Integrate home/editor UI cues and finalize phase-1 acceptance checks

**Files:**
- Modify: `lib/src/presentation/pages.dart`
- Modify: `lib/src/presentation/shared_lists_pages.dart`
- Modify: `lib/src/presentation/widgets/shared_home_card_section.dart`
- Modify: `lib/src/presentation/widgets/shared_activity_feed.dart`
- Modify: `lib/src/app/shopping_list_app.dart`
- Test: `test/presentation/shared_home_visibility_test.dart`
- Test: `test/presentation/shared_activity_feed_test.dart`

- [ ] **Step 1: Write failing widget tests for cue rendering**

```dart
testWidgets('shared card shows last editor and freshness', (tester) async {
  await tester.pumpWidget(buildHomeWithSharedCard(
    lastEditor: 'Ana',
    lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
  ));
  expect(find.textContaining('Ana'), findsOneWidget);
  expect(find.textContaining('2 min'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/presentation/shared_home_visibility_test.dart test/presentation/shared_activity_feed_test.dart`  
Expected: FAIL because cues/presence badge/feed widgets are not fully wired.

- [ ] **Step 3: Implement minimal UI wiring**

```text
1) In shared_home_card_section.dart, implement shared-home card renderer:
   - actor label ("Última edição: <nome|uid>")
   - freshness label derived from updatedAt
   - pending/synced chip from SharedCollaborationState.isPending
2) In shared_activity_feed.dart, implement activity feed widget:
   - subscribe to watchRecentActivity(listId, limit: 20)
   - render list ordered by createdAt desc
3) In shared_lists_pages.dart, integrate shared_activity_feed and presence chip:
   - show "<N> editando agora" when activeMembersCount > 0
   - fallback to "Sem atividade ao vivo" when stale
4) In pages.dart, replace old inline shared-home UI with SharedHomeCardSection.
```

- [ ] **Step 4: Run full verification for this phase**

Run: `flutter test && flutter analyze`  
Expected: Test suite passes and analyzer output contains no new warnings/errors introduced by this phase.

- [ ] **Step 5: Commit**

```bash
git add lib/src/presentation/pages.dart lib/src/presentation/shared_lists_pages.dart lib/src/presentation/widgets/shared_home_card_section.dart lib/src/presentation/widgets/shared_activity_feed.dart lib/src/app/shopping_list_app.dart test/presentation/shared_home_visibility_test.dart test/presentation/shared_activity_feed_test.dart
git commit -m "feat: ship shared collaboration phase 1 home and activity cues"
```

### Task 7: Cover required edge cases from phase-1 spec

**Files:**
- Modify: `lib/src/application/shared_collaboration_coordinator.dart`
- Modify: `lib/src/data/remote/shared_lists_repository.dart`
- Test: `test/application/shared_collaboration_coordinator_test.dart`
- Test: `test/presentation/shared_home_visibility_test.dart`

- [ ] **Step 1: Write failing edge-case tests**

```dart
test('maps removed-member write failure to not_member_or_removed state', () async {
  final state = await coordinator.mapWriteError('permission-denied', reason: 'removed');
  expect(state.errorCode, 'not_member_or_removed');
});

test('shows list unavailable state when archived/deleted before sync completes', () async {
  final state = await coordinator.mapWriteError('not-found');
  expect(state.errorCode, 'list_unavailable');
});

test('shows updated elsewhere hint for same user multi-device divergence', () async {
  final state = await coordinator.resolveExternalUpdateDetected('list-1');
  expect(state.showUpdatedElsewhereHint, isTrue);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/application/shared_collaboration_coordinator_test.dart test/presentation/shared_home_visibility_test.dart`  
Expected: FAIL because edge-case mapping and UI hints are not implemented yet.

- [ ] **Step 3: Implement minimal edge-case mapping and hints**

```text
- translate repository/auth errors into explicit UI error codes:
  not_member_or_removed, list_unavailable, offline_pending
- set updated-elsewhere flag when same-user remote update timestamp overtakes local optimistic mutation
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/application/shared_collaboration_coordinator_test.dart test/presentation/shared_home_visibility_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/application/shared_collaboration_coordinator.dart lib/src/data/remote/shared_lists_repository.dart test/application/shared_collaboration_coordinator_test.dart test/presentation/shared_home_visibility_test.dart
git commit -m "test: cover shared phase 1 edge-case mappings"
```

