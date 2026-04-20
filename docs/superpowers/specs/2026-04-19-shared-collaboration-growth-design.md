# Shared Collaboration Growth Design (PM + Mobile Architecture)

## Problem statement
The app already has strong shopping-specific depth (budgeting, history, barcode, reminders), but shared-list collaboration still has enough friction and trust gaps that households may not adopt it as their primary shared shopping workflow. The next product goal is to increase weekly active shared-list households.

## Business objective and constraints
1. **Primary KPI:** weekly active shared-list households.
2. **Team assumption:** small team (1–2 engineers) for the next quarter.
3. **Platform focus:** Android first, then Web/iOS.
4. **Permissions model (v1):** owner + members.

## Scope lock (this spec cycle)
This spec is intentionally scoped to **Phase 1 only** for execution planning. Phases 2 and 3 remain directional and are not part of the immediate implementation plan.

### Phase 1 in-scope
1. Shared home card collaboration cues.
2. Invite/join funnel hardening.
3. Presence + optimistic item toggles + sync/pending indicators.
4. Basic recent activity events feed.
5. **Phase-1 queue model:** ephemeral in-memory + lightweight pending badge only (no persisted replay queue yet).
6. Owner controls for shared-list visibility: archive/hide in home surface (no role changes).

### Non-goals (for this planning cycle)
1. Full conflict center UI and merge workflow.
2. Role expansion beyond owner/member.
3. Collaboration reliability scoring system.
4. Advanced timeline filters and long-term analytics dashboards.
5. Persisted offline mutation replay engine.

## Product strategy
Use a **reliability-first collaboration strategy** before broad feature expansion:
1. Make shared lists easy to join and immediately useful.
2. Make collaboration feel trustworthy (clear freshness, authorship, sync state).
3. Improve offline confidence and conflict handling enough to prevent silent data loss confusion.
4. Delay advanced roles/social features until the collaboration core is stable and retained.

## Gaps vs top collaboration apps (AnyList, Keep-class expectations)
1. **Lower collaboration confidence:** limited visibility into who changed what/when.
2. **Higher onboarding friction:** shared-list join and first successful collaborative edit can be slower than expected.
3. **Weaker realtime feedback:** fewer cues for presence/editing/sync reliability.
4. **Offline ambiguity:** users can be unsure whether edits are synced, pending, or conflicting.

## High-impact functional improvements

## A) Shared lists experience (creation, sync, permissions, visibility)
### Quick wins
1. Shared home card with:
   - last editor identity
   - last update freshness ("updated 2m ago")
   - sync/pending badge
2. Invite and join funnel hardening:
   - deep-link join
   - deterministic error states (invalid/expired/disabled)
   - clear success handoff to list screen
3. Owner controls:
   - archive/hide old shared lists from primary home surface
   - keep owner/member permissions simple

### Complex improvements
1. Shared-list visibility preferences (pin/mute/archive) with household-specific ranking.
2. Role expansion only if KPI plateaus after owner/member stabilization.

## B) Realtime updates and collaboration
### Quick wins
1. Presence indicator ("2 people editing now").
2. Optimistic item toggle and immediate UI feedback.
3. Lightweight recent activity chips (e.g., "Ana marked Milk as purchased").

### Complex improvements
1. Full activity timeline per shared list.
2. Event attribution with filtered views (by member/date/change type).

## C) Offline-first and conflict resolution
### Quick wins
1. Explicit local queue status ("queued", "syncing", "synced").
2. Retry affordance for failed pending actions.

### Complex improvements
1. Persistent mutation queue (`opId`, `entityId`, `baseVersion`, `patch`, `clientTs`).
2. Pragmatic conflict policy:
   - `isPurchased`: last-write-wins + audit event
   - `quantity/unitPrice`: merge prompt if `baseVersion` diverges
   - `name/category`: owner-preferred fallback when both changed concurrently
3. Conflict center UI for unresolved merges.

## D) UX friction reducers
1. Reduce tap count in shared flows (join, add item, mark purchased).
2. Keep sync confidence visible but subtle (banner/chip states, not noisy modals).
3. Add first-run shared collaboration coach marks only for users entering shared mode.

## Retention feature recommendations
1. **Household routines:** recurring template list and smart refill suggestions.
2. **Trust + memory:** activity timeline and change attribution.
3. **Reliability nudges:** pending-sync reminders and recovery prompts.
4. **Shared value:** monthly household savings/consistency insights from budget + history.

## Architecture design (Flutter + Firebase)

## Module boundaries and interfaces (explicit contracts)
1. **SharedListsReadModel (data):**
   - Responsibility: stream/fetch shared lists and item snapshots.
   - Input: `uid`, `listId`.
   - Output: immutable `SharedShoppingListSummary` + `SharedShoppingItem`.
2. **InviteJoinCoordinator (application/presentation boundary):**
   - Responsibility: invite deep-link parse, preview load, auth-gated join confirm.
   - Input: invite payload (`code`, optional source metadata), auth state.
   - Output: deterministic states (`preview_ready`, `invalid`, `expired`, `disabled`, `joined`).
3. **CollaborationSyncCoordinator (application):**
   - Responsibility: bind listeners, optimistic local state, sync status badges.
   - Input: active shared list context + connectivity/auth signals.
   - Output: UI-facing collaboration state model (`isLive`, `isPending`, `lastEditor`, `lastUpdatedAt`).
   - Phase-1 note: `isPending` reflects ephemeral pending operations only; persistent queue arrives in Phase 2.
4. **ActivityEventWriter (data/service):**
   - Responsibility: write lightweight activity events for key user actions.
   - Input: domain action + actor uid + entity metadata.
   - Output: append-only event doc in `events` subcollection.
5. **ActivityEventsReadModel (data):**
   - Responsibility: read and paginate recent activity for home/shared list cards.
   - Input: `listId`, `limit`, `cursor`.
   - Output: ordered events (`createdAt desc`) with bounded page size (default 20, max 50).
6. **PresenceStateProvider (service):**
   - Responsibility: compute realtime collaborator presence state for a list.
   - Input: member heartbeat/activity signals.
   - Output: `activeMembersCount`, `lastPresenceAt`, `isStale`.
   - Contract: presence is considered stale after 90 seconds without activity.

Interface rule: each module is independently testable and does not directly mutate another module's private state.

## Data model direction
1. Keep normalized structure:
   - `shared_lists/{listId}`
   - `shared_lists/{listId}/items/{itemId}`
   - `shared_lists/{listId}/events/{eventId}` (new for activity/audit)
2. Canonical membership and owner fields in shared list root.
3. Use server timestamps for ordering and cross-device consistency.

## Realtime pipeline
1. Firestore snapshot listeners scoped to visible shared lists.
2. UI update throttling/debounce to avoid repaint churn.
3. Dedicated sync coordinator (separate from large page widgets) to manage:
   - listener lifecycle
   - phase-1 ephemeral pending state updates
   - phase-2 queue flush and conflict signal emission (out of current execution scope)

## Offline and conflict processing
1. **Phase 1 (in scope):**
   - use ephemeral pending operations state for immediate UX clarity.
   - show deterministic pending/synced/failure badges.
2. **Phase 2+ (out of current execution scope):**
   - persist mutation queue locally (Android-first).
   - replay queue in order when network/auth is healthy.
   - detect conflicts via base-version mismatch.
   - emit conflict items and resolution UI.

### Required edge-case handling (phase 1-safe behavior)
1. **Member removed while offline:** queued writes are rejected with `not_member_or_removed`; app clears optimistic badge and shows rejoin prompt.
2. **List archived/deleted while offline:** queued writes are dropped with explicit “list unavailable” state; user can duplicate locally.
3. **Same user editing on multiple devices:** server timestamp wins for non-critical fields; app shows “updated elsewhere” refresh hint.
4. **Invite accepted on another account/device first:** join flow resolves to deterministic “already member” or “invalid/expired” outcome.

### Firestore security/index checklist (phase 1)
1. Add rules for `shared_lists/{listId}/events/{eventId}`:
   - read/write allowed only for list members.
   - writes require actor uid in payload matching `request.auth.uid`.
2. Ensure index support for activity feed query:
   - collection: `events`
   - order: `createdAt desc`
   - optional filter by `actorUid` only if product requires it in phase 1.
3. Keep membership checks consistent with canonical owner/member fields in rules and app model.

## Phase 1 deliverables contract (strict)
1. Shared home cards show:
   - last editor
   - freshness timestamp
   - pending/synced state badge
2. Invite/join flow returns deterministic terminal states:
   - invalid
   - expired
   - disabled
   - already_member
   - joined
3. Presence behavior:
   - source of truth: last activity heartbeat event per member
   - stale timeout: 90 seconds
   - reconnect: recalculate presence on listener reconnect and render latest count
4. Owner can archive/hide shared lists from home without deleting remote data.
5. Recent activity feed renders top 20 events ordered by `createdAt desc`.

## Events schema (phase 1 minimal)
Collection: `shared_lists/{listId}/events/{eventId}`

Required fields:
1. `eventType` (enum): `item_added`, `item_updated`, `item_purchased_toggled`, `invite_joined`, `list_archived`, `list_unarchived`
2. `actorUid` (string)
3. `entityType` (string): `item` or `list`
4. `entityId` (string)
5. `summary` (string, localized-ready display text)
6. `createdAt` (server timestamp)
7. `schemaVersion` (int, initial `1`)

Retention:
1. Keep latest 500 events per list (rolling cap via background cleanup task/maintenance job).

## Firebase service usage
1. Firestore for primary collaborative data and realtime listeners.
2. Firebase Auth for household identity and permission gates.
3. Cloud Functions only for heavier asynchronous concerns (aggregation/notifications), not core CRUD path.

## Error and resilience model
Represent explicit states in UX and logs:
1. `permission_denied`
2. `invite_invalid_or_expired`
3. `not_member_or_removed`
4. `offline_pending`
5. `conflict_requires_resolution`

## Prioritized roadmap

## Phase 1 (4–8 weeks, quick wins)
1. Shared home card improvements.
2. Invite/join funnel hardening.
3. Presence + optimistic toggle + sync badges.
4. Basic events feed for recent changes.

### Phase 1 acceptance criteria
1. Invite join completion rate improves by at least **+15%** vs baseline.
2. Time-to-first-shared-edit drops by at least **20%**.
3. Shared home section exposes last update freshness and actor for all visible shared lists.
4. Offline pending actions always show an explicit queue/sync state (no silent ambiguity).

## Phase 2 (8–12 weeks, medium complexity)
1. Local mutation queue and replay worker.
2. Conflict detector + merge prompt UX.
3. Shared list visibility controls (archive/mute/pin).

## Phase 3 (12+ weeks, strategic depth)
1. Collaboration reliability diagnostics.
2. Richer activity/audit browsing.
3. Re-evaluate role model expansion based on retention and usage data.

## Measurement plan
Track collaboration funnel events:
1. `invite_opened`
2. `invite_preview_loaded`
3. `join_confirmed`
4. `join_success`
5. `first_shared_edit`
6. `shared_list_active_weekly`

### Event ownership and schema
1. **Owner:** mobile client instrumentation team (same feature squad).
2. **Schema (minimum):**
   - `event_name`
   - `user_uid`
   - `household_key` (hashed)
   - `list_id`
   - `platform`
   - `client_ts`
   - `app_version`
   - optional `error_code`
3. **Validation rule:** events without `household_key` or `list_id` (where applicable) are discarded from KPI dashboards.

Primary KPI:
1. Weekly active shared-list households.

Secondary indicators:
1. Join completion rate.
2. Time-to-first-shared-edit.
3. Conflict resolution completion rate.
4. Shared-list week-over-week retention.

### Baseline and reporting cadence
1. Baseline window: previous 28 days before Phase 1 rollout.
2. Review cadence: weekly KPI check + biweekly product/engineering review.
3. Rollout guardrail: if join-success error rate exceeds baseline by >10% for 3 consecutive days, pause rollout and investigate.
