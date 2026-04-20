# Shared Collaboration Growth Design (PM + Mobile Architecture)

## Problem statement
The app already has strong shopping-specific depth (budgeting, history, barcode, reminders), but shared-list collaboration still has enough friction and trust gaps that households may not adopt it as their primary shared shopping workflow. The next product goal is to increase weekly active shared-list households.

## Business objective and constraints
1. **Primary KPI:** weekly active shared-list households.
2. **Team assumption:** small team (1–2 engineers) for the next quarter.
3. **Platform focus:** Android first, then Web/iOS.
4. **Permissions model (v1):** owner + members.

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
   - queue flush
   - conflict signal emission

## Offline and conflict processing
1. Persist mutation queue locally (Android-first implementation).
2. Replay queue in order when network/auth is healthy.
3. Detect conflict at write time using base-version mismatch.
4. Emit user-facing conflict items with explicit resolution options.

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

Primary KPI:
1. Weekly active shared-list households.

Secondary indicators:
1. Join completion rate.
2. Time-to-first-shared-edit.
3. Conflict resolution completion rate.
4. Shared-list week-over-week retention.
