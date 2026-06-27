# Central De Sincronizacao E Diagnostico Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a practical sync and diagnostics page that shows current cloud/local/shared-list state, lets the user force synchronization, and copies a support report.

**Architecture:** Keep sync orchestration in `ShoppingListApp`, pass an immutable diagnostics snapshot down to options/dashboard, and render a focused diagnostics page in presentation. Shared-list diagnostics are read from the existing repository stream/fetch APIs and no new Firestore schema is required.

**Tech Stack:** Flutter, Dart, Firebase Auth/Firestore, existing `ShoppingListsStore`, existing app route/toast/theme helpers, widget/unit tests.

---

### Task 1: Diagnostics Model And Report Formatting

**Files:**
- Create: `lib/src/application/sync_diagnostics.dart`
- Test: `test/application/sync_diagnostics_test.dart`

- [ ] **Step 1: Write failing tests**

Run: `flutter test test/application/sync_diagnostics_test.dart`
Expected: fail because `SyncDiagnosticsSnapshot` does not exist.

- [ ] **Step 2: Implement immutable model**

Add `SyncDiagnosticsSnapshot`, `SharedListDiagnosticEntry`, `SyncDiagnosticStatus`, status title helpers, and `buildSupportReport()`.

- [ ] **Step 3: Run tests**

Run: `flutter test test/application/sync_diagnostics_test.dart`
Expected: pass.

### Task 2: Options Entry And Diagnostics Page

**Files:**
- Create: `lib/src/presentation/sync_diagnostics_page.dart`
- Modify: `lib/src/presentation/account_pages.dart`
- Modify: `lib/src/presentation/dashboard_page.dart`
- Test: `test/presentation/sync_diagnostics_page_test.dart`

- [ ] **Step 1: Write failing widget test**

Run: `flutter test test/presentation/sync_diagnostics_page_test.dart`
Expected: fail because the diagnostics page is missing.

- [ ] **Step 2: Implement page**

Render status, counts, settings, shared-list diagnostics, sync-now button, and copy-report button.

- [ ] **Step 3: Link from Options**

Pass snapshot/callbacks from dashboard into options and add a `Sincronizacao e diagnostico` list tile.

- [ ] **Step 4: Run widget test**

Run: `flutter test test/presentation/sync_diagnostics_page_test.dart`
Expected: pass.

### Task 3: App Integration And Manual Sync

**Files:**
- Modify: `lib/src/app/shopping_list_app.dart`
- Modify: `lib/src/presentation/dashboard_page.dart`

- [ ] **Step 1: Build diagnostics snapshot in app**

Use current sync flags, user info, counts, preferences, project id, and last shared-list error.

- [ ] **Step 2: Add manual sync action**

Cancel pending debounce, refresh connectivity, pull if needed, mirror owned shared lists, then push current snapshot.

- [ ] **Step 3: Track last sync error**

Record readable pull/push/shared errors for the diagnostics page.

### Task 4: Verification

**Files:**
- All modified files

- [ ] **Step 1: Format**

Run: `dart format <changed files>`
Expected: exit 0.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 3: Tests**

Run focused diagnostics tests and existing sync/store tests.
Expected: all pass.
