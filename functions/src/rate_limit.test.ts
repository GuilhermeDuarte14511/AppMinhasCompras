import assert from "node:assert/strict";
import test from "node:test";

import {type Firestore} from "firebase-admin/firestore";

import {
  DEFAULT_GLOBAL_DAILY_QUOTA,
  RateLimitConfigurationError,
  RateLimitExceededError,
  consumeDailyRateLimit,
  consumeRateLimit,
  enforceCosmosRateLimits,
  evaluateCosmosRateLimits,
  rateLimitDocumentIdForUid,
  resolveDailyQuota,
} from "./rate_limit";

void test("uses an opaque SHA-256 document id instead of the Firebase UID", () => {
  const uid = "firebase-user-id";
  const documentId = rateLimitDocumentIdForUid(uid);

  assert.match(documentId, /^[a-f0-9]{64}$/);
  assert.equal(documentId.includes(uid), false);
});

void test("starts a new rate-limit window", () => {
  const result = consumeRateLimit(null, 1_000, 60_000, 30);

  assert.deepEqual(result, {
    allowed: true,
    nextState: {windowStartedAtMs: 1_000, count: 1},
    retryAfterSeconds: 0,
  });
});

void test("increments an active window up to the limit", () => {
  const result = consumeRateLimit(
    {windowStartedAtMs: 1_000, count: 29},
    30_000,
    60_000,
    30,
  );

  assert.equal(result.allowed, true);
  assert.equal(result.nextState.count, 30);
});

void test("rejects requests over the limit with a retry interval", () => {
  const state = {windowStartedAtMs: 1_000, count: 30};
  const result = consumeRateLimit(state, 31_500, 60_000, 30);

  assert.equal(result.allowed, false);
  assert.equal(result.nextState, state);
  assert.equal(result.retryAfterSeconds, 30);
});

void test("resets an expired window", () => {
  const result = consumeRateLimit(
    {windowStartedAtMs: 1_000, count: 30},
    61_000,
    60_000,
    30,
  );

  assert.equal(result.allowed, true);
  assert.deepEqual(result.nextState, {
    windowStartedAtMs: 61_000,
    count: 1,
  });
});

void test("defaults the global budget to 25 upstream calls per UTC day", () => {
  assert.equal(DEFAULT_GLOBAL_DAILY_QUOTA, 25);

  const now = Date.UTC(2026, 6, 19, 12);
  const lastAllowed = consumeDailyRateLimit(
    {utcDay: "2026-07-19", count: 24},
    now,
  );
  const rejected = consumeDailyRateLimit(
    lastAllowed.nextState,
    now,
  );

  assert.equal(lastAllowed.allowed, true);
  assert.equal(lastAllowed.nextState.count, 25);
  assert.equal(rejected.allowed, false);
  assert.equal(rejected.retryAfterSeconds, 12 * 60 * 60);
});

void test("resets the global counter at the next UTC day", () => {
  const result = consumeDailyRateLimit(
    {utcDay: "2026-07-19", count: 25},
    Date.UTC(2026, 6, 20),
  );

  assert.deepEqual(result, {
    allowed: true,
    nextState: {utcDay: "2026-07-20", count: 1},
    retryAfterSeconds: 0,
  });
});

void test("denies both counter writes when either atomic limit is exceeded", () => {
  const now = Date.UTC(2026, 6, 19, 12);
  const globalDenied = evaluateCosmosRateLimits(
    {windowStartedAtMs: now, count: 2},
    {utcDay: "2026-07-19", count: 25},
    now,
    25,
  );
  const userDenied = evaluateCosmosRateLimits(
    {windowStartedAtMs: now, count: 30},
    {utcDay: "2026-07-19", count: 5},
    now,
    25,
  );

  assert.equal(globalDenied.allowed, false);
  assert.equal(globalDenied.deniedScope, "global");
  assert.equal(userDenied.allowed, false);
  assert.equal(userDenied.deniedScope, "user");
});

void test("fails closed for unsafe daily quota configuration", () => {
  assert.equal(resolveDailyQuota(25), 25);
  assert.throws(() => resolveDailyQuota(0), RateLimitConfigurationError);
  assert.throws(() => resolveDailyQuota(10_001), RateLimitConfigurationError);
  assert.throws(() => resolveDailyQuota(1.5), RateLimitConfigurationError);
});

void test("serializes concurrent global quota reservations transactionally", async () => {
  const firestore = new InMemoryFirestore();
  const now = Date.UTC(2026, 6, 19, 12);

  const results = await Promise.allSettled(
    Array.from({length: 5}, (_, index) =>
      enforceCosmosRateLimits(
        firestore as unknown as Firestore,
        `user-${index}`,
        2,
        now,
      ),
    ),
  );

  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    2,
  );
  const rejected = results.filter(
    (result): result is PromiseRejectedResult =>
      result.status === "rejected",
  );
  assert.equal(rejected.length, 3);
  assert.equal(
    rejected.every(
      (result) =>
        result.reason instanceof RateLimitExceededError &&
        result.reason.scope === "global",
    ),
    true,
  );
  assert.equal(
    firestore.read("internal_rate_limits/cosmos_global_daily")?.count,
    2,
  );
});

interface InMemoryDocumentReference {
  readonly path: string;
}

class InMemoryFirestore {
  private readonly documents = new Map<string, Readonly<Record<string, unknown>>>();
  private transactionTail: Promise<void> = Promise.resolve();

  collection(name: string): {
    doc: (id: string) => InMemoryDocumentReference;
  } {
    return {
      doc: (id: string): InMemoryDocumentReference => ({
        path: `${name}/${id}`,
      }),
    };
  }

  runTransaction<T>(
    operation: (transaction: InMemoryTransaction) => Promise<T>,
  ): Promise<T> {
    const result = this.transactionTail.then(() =>
      operation(new InMemoryTransaction(this.documents)),
    );
    this.transactionTail = result.then(
      () => undefined,
      () => undefined,
    );
    return result;
  }

  read(path: string): Readonly<Record<string, unknown>> | undefined {
    return this.documents.get(path);
  }
}

class InMemoryTransaction {
  constructor(
    private readonly documents: Map<
      string,
      Readonly<Record<string, unknown>>
    >,
  ) {}

  get(reference: InMemoryDocumentReference): Promise<{
    data: () => Readonly<Record<string, unknown>> | undefined;
  }> {
    return Promise.resolve({
      data: () => this.documents.get(reference.path),
    });
  }

  set(
    reference: InMemoryDocumentReference,
    data: Readonly<Record<string, unknown>>,
  ): void {
    this.documents.set(reference.path, data);
  }
}
