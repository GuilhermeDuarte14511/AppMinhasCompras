# Deep-link invite/join flow design (v1)

## Problem statement
The shared-list invite/join journey currently has avoidable friction. The goal is to raise **join completion rate** by making link-based entry fast, clear, and resilient while staying within the current Firebase/Firestore architecture.

## Scope
### In scope
1. Deep-link-first invite opening flow.
2. Invite preview before join mutation.
3. Login gating only at confirm step, with post-login resume.
4. Idempotent join orchestration using existing repositories/services.
5. Clear handling of invalid/expired/disabled/already-member states.
6. Test coverage for parsing, resume logic, and end-to-end join funnel.

### Out of scope (v1)
1. New backend services outside existing Firebase/Firestore stack.
2. Major schema redesign.
3. Role/permission expansion beyond current membership model.
4. Collaboration feed/history UI redesign.

## Current-context alignment
The repo already contains shared-list sync/join flows and Firestore rules for `shared_lists` and invite documents. This design extends existing patterns (presentation -> application use-case -> data repository) without introducing a new service boundary.

## Proposed architecture
## 1. Invite Link Resolver (presentation)
Responsibilities:
1. Parse deep links and extract invite payload (`inviteCode`, optional `listId`, source metadata).
2. Validate format and route to invite preview state.
3. Request lightweight invite preview data for user confirmation.

Outputs:
1. `InvitePreviewReady` (preview loaded).
2. `InviteInvalid` / `InviteExpired` / `InviteDisabled`.
3. `InviteNeedsAuth` (if action requires login).

## 2. Join Gate + resume coordinator (presentation/application boundary)
Responsibilities:
1. If user is unauthenticated, persist pending invite context locally.
2. Redirect to auth flow.
3. On auth success, detect pending invite and resume at confirmation.

Storage:
1. Small local payload (e.g., SharedPreferences-backed pending invite record).
2. Cleared on successful join or terminal failure.

## 3. Join Confirmation screen (presentation)
Responsibilities:
1. Show list identity (name/owner/member count if available).
2. Show current signed-in account.
3. Require explicit user confirm before join mutation.

## 4. Join Orchestrator use case (application)
Responsibilities:
1. Validate invite and membership eligibility.
2. Execute idempotent join mutation.
3. Trigger local mirror/sync update.
4. Map technical errors to domain/user-facing states.

Contract sketch:
```dart
Future<JoinInviteResult> joinByDeepLink(JoinInviteCommand command)
```

Result states:
1. `joined`
2. `alreadyMember`
3. `inviteInvalid`
4. `inviteExpired`
5. `inviteDisabled`
6. `authRequired`
7. `temporaryFailure`

## Data flow
1. User opens deep link.
2. Resolver parses payload and requests invite preview.
3. If unauthenticated, pending invite is persisted and auth is launched.
4. After login, app resumes pending invite automatically.
5. User confirms join.
6. Join Orchestrator validates + executes idempotent join.
7. On success, app routes to shared list and clears pending invite.
8. On recoverable failure, app keeps pending invite for retry.
9. On terminal failure (invalid/expired/disabled), app clears pending invite and displays explicit state.

## Error handling and safety
1. **Invalid/expired/disabled invite:** explicit terminal state and recovery CTA (e.g., request new invite).
2. **Already member:** treat as success and route directly to shared list.
3. **Wrong-account protection:** confirmation screen always shows signed-in account and target list before mutation.
4. **Offline behavior:** preview may be shown from cache; join action blocks with retry guidance when offline.
5. **Idempotency:** repeated deep-link opens must not duplicate membership or local mirror records.

## Testing strategy
## Unit tests
1. Deep-link parsing and payload validation.
2. Pending invite persistence/resume lifecycle.
3. JoinOrchestrator result mapping by backend outcome.

## Integration tests
1. Link open -> auth redirect -> resume -> confirm -> joined.
2. Already-member path routes directly to list.
3. Invalid/expired/disabled invite terminal handling.

## Regression tests
1. Reopening same link repeatedly remains idempotent.
2. Offline interruption followed by online retry works without stale state.
3. Pending invite is cleared on terminal failures and successful join.

## Success criteria
Primary KPI:
1. Higher invite-link join completion rate across funnel stages:
   - link opened
   - preview loaded
   - confirm tapped
   - join succeeded

Secondary indicators:
1. Reduced drop-off between preview and confirm.
2. Lower rate of join failures caused by invalid flow state.

## Incremental rollout plan
1. Implement resolver + preview state behind current shared-list entry points.
2. Add auth-resume pending invite flow.
3. Add confirmation and orchestrator idempotency hardening.
4. Enable telemetry funnel checkpoints.
5. Evaluate KPI change and decide v2 scope (permissions/history enhancements).
