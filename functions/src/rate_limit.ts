import {createHash} from "node:crypto";

import {
  Firestore,
  Timestamp,
} from "firebase-admin/firestore";

export const RATE_LIMIT_WINDOW_MS = 60_000;
export const RATE_LIMIT_MAX_REQUESTS = 30;
export const DEFAULT_GLOBAL_DAILY_QUOTA = 25;
export const MAX_GLOBAL_DAILY_QUOTA = 10_000;

const GLOBAL_DAILY_DOCUMENT_ID = "cosmos_global_daily";

export interface RateLimitState {
  readonly windowStartedAtMs: number;
  readonly count: number;
}

export interface RateLimitDecision {
  readonly allowed: boolean;
  readonly nextState: RateLimitState;
  readonly retryAfterSeconds: number;
}

export interface DailyRateLimitState {
  readonly utcDay: string;
  readonly count: number;
}

export interface DailyRateLimitDecision {
  readonly allowed: boolean;
  readonly nextState: DailyRateLimitState;
  readonly retryAfterSeconds: number;
}

export interface CombinedRateLimitDecision {
  readonly allowed: boolean;
  readonly deniedScope: "user" | "global" | null;
  readonly retryAfterSeconds: number;
  readonly nextUserState: RateLimitState;
  readonly nextDailyState: DailyRateLimitState;
}

export class RateLimitExceededError extends Error {
  constructor(
    readonly retryAfterSeconds: number,
    readonly scope: "user" | "global" = "user",
  ) {
    super("Rate limit exceeded.");
    this.name = "RateLimitExceededError";
  }
}

export class RateLimitConfigurationError extends Error {
  constructor() {
    super("Invalid rate limit configuration.");
    this.name = "RateLimitConfigurationError";
  }
}

export function consumeRateLimit(
  state: RateLimitState | null,
  nowMs: number,
  windowMs = RATE_LIMIT_WINDOW_MS,
  maxRequests = RATE_LIMIT_MAX_REQUESTS,
): RateLimitDecision {
  const hasActiveWindow =
    state !== null &&
    state.windowStartedAtMs <= nowMs &&
    nowMs - state.windowStartedAtMs < windowMs;

  if (!hasActiveWindow) {
    return {
      allowed: true,
      nextState: {windowStartedAtMs: nowMs, count: 1},
      retryAfterSeconds: 0,
    };
  }

  if (state.count >= maxRequests) {
    const remainingMs = windowMs - (nowMs - state.windowStartedAtMs);
    return {
      allowed: false,
      nextState: state,
      retryAfterSeconds: Math.max(1, Math.ceil(remainingMs / 1_000)),
    };
  }

  return {
    allowed: true,
    nextState: {
      windowStartedAtMs: state.windowStartedAtMs,
      count: state.count + 1,
    },
    retryAfterSeconds: 0,
  };
}

export function consumeDailyRateLimit(
  state: DailyRateLimitState | null,
  nowMs: number,
  maxRequests = DEFAULT_GLOBAL_DAILY_QUOTA,
): DailyRateLimitDecision {
  const currentDay = utcDayKey(nowMs);
  if (state === null || state.utcDay !== currentDay) {
    return {
      allowed: true,
      nextState: {utcDay: currentDay, count: 1},
      retryAfterSeconds: 0,
    };
  }
  if (state.count >= maxRequests) {
    return {
      allowed: false,
      nextState: state,
      retryAfterSeconds: secondsUntilNextUtcDay(nowMs),
    };
  }
  return {
    allowed: true,
    nextState: {utcDay: currentDay, count: state.count + 1},
    retryAfterSeconds: 0,
  };
}

export function evaluateCosmosRateLimits(
  userState: RateLimitState | null,
  dailyState: DailyRateLimitState | null,
  nowMs: number,
  dailyQuota: number,
): CombinedRateLimitDecision {
  const userDecision = consumeRateLimit(userState, nowMs);
  const dailyDecision = consumeDailyRateLimit(dailyState, nowMs, dailyQuota);

  if (!userDecision.allowed) {
    return {
      allowed: false,
      deniedScope: "user",
      retryAfterSeconds: userDecision.retryAfterSeconds,
      nextUserState: userDecision.nextState,
      nextDailyState: dailyDecision.nextState,
    };
  }
  if (!dailyDecision.allowed) {
    return {
      allowed: false,
      deniedScope: "global",
      retryAfterSeconds: dailyDecision.retryAfterSeconds,
      nextUserState: userDecision.nextState,
      nextDailyState: dailyDecision.nextState,
    };
  }
  return {
    allowed: true,
    deniedScope: null,
    retryAfterSeconds: 0,
    nextUserState: userDecision.nextState,
    nextDailyState: dailyDecision.nextState,
  };
}

export async function enforceCosmosRateLimits(
  firestore: Firestore,
  uid: string,
  configuredDailyQuota: number,
  nowMs = Date.now(),
): Promise<void> {
  const dailyQuota = resolveDailyQuota(configuredDailyQuota);
  const userDocument = firestore
    .collection("internal_rate_limits")
    .doc(rateLimitDocumentIdForUid(uid));
  const globalDocument = firestore
    .collection("internal_rate_limits")
    .doc(GLOBAL_DAILY_DOCUMENT_ID);

  const decision = await firestore.runTransaction(
    async (transaction): Promise<CombinedRateLimitDecision> => {
      const userSnapshot = await transaction.get(userDocument);
      const globalSnapshot = await transaction.get(globalDocument);
      const result = evaluateCosmosRateLimits(
        readRateLimitState(userSnapshot.data()),
        readDailyRateLimitState(globalSnapshot.data()),
        nowMs,
        dailyQuota,
      );

      if (result.allowed) {
        transaction.set(userDocument, {
          windowStartedAt: Timestamp.fromMillis(
            result.nextUserState.windowStartedAtMs,
          ),
          count: result.nextUserState.count,
          updatedAt: Timestamp.fromMillis(nowMs),
          expiresAt: Timestamp.fromMillis(nowMs + RATE_LIMIT_WINDOW_MS * 2),
        });
        transaction.set(globalDocument, {
          utcDay: result.nextDailyState.utcDay,
          count: result.nextDailyState.count,
          updatedAt: Timestamp.fromMillis(nowMs),
          expiresAt: Timestamp.fromMillis(
            startOfNextUtcDayMs(nowMs) + 2 * 24 * 60 * 60 * 1_000,
          ),
        });
      }
      return result;
    },
  );

  if (!decision.allowed) {
    throw new RateLimitExceededError(
      decision.retryAfterSeconds,
      decision.deniedScope ?? "global",
    );
  }
}

export async function enforceUserRateLimit(
  firestore: Firestore,
  uid: string,
  nowMs = Date.now(),
): Promise<void> {
  const documentId = rateLimitDocumentIdForUid(uid);
  const document = firestore.collection("internal_rate_limits").doc(documentId);

  const decision = await firestore.runTransaction(
    async (transaction): Promise<RateLimitDecision> => {
      const snapshot = await transaction.get(document);
      const currentState = readRateLimitState(snapshot.data());
      const result = consumeRateLimit(currentState, nowMs);

      if (result.allowed) {
        transaction.set(document, {
          windowStartedAt: Timestamp.fromMillis(
            result.nextState.windowStartedAtMs,
          ),
          count: result.nextState.count,
          updatedAt: Timestamp.fromMillis(nowMs),
          expiresAt: Timestamp.fromMillis(nowMs + RATE_LIMIT_WINDOW_MS * 2),
        });
      }

      return result;
    },
  );

  if (!decision.allowed) {
    throw new RateLimitExceededError(decision.retryAfterSeconds);
  }
}

export function rateLimitDocumentIdForUid(uid: string): string {
  return createHash("sha256").update(uid).digest("hex");
}

export function resolveDailyQuota(value: number): number {
  if (
    !Number.isSafeInteger(value) ||
    value < 1 ||
    value > MAX_GLOBAL_DAILY_QUOTA
  ) {
    throw new RateLimitConfigurationError();
  }
  return value;
}

export function utcDayKey(nowMs: number): string {
  return new Date(nowMs).toISOString().slice(0, 10);
}

function readRateLimitState(data: unknown): RateLimitState | null {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    return null;
  }
  const record = data as Readonly<Record<string, unknown>>;
  const windowStartedAt = record.windowStartedAt;
  const count = record.count;
  if (!(windowStartedAt instanceof Timestamp) || typeof count !== "number") {
    return null;
  }
  if (!Number.isSafeInteger(count) || count < 0) {
    return null;
  }
  return {
    windowStartedAtMs: windowStartedAt.toMillis(),
    count,
  };
}

function readDailyRateLimitState(data: unknown): DailyRateLimitState | null {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    return null;
  }
  const record = data as Readonly<Record<string, unknown>>;
  const utcDay = record.utcDay;
  const count = record.count;
  if (
    typeof utcDay !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(utcDay) ||
    typeof count !== "number" ||
    !Number.isSafeInteger(count) ||
    count < 0
  ) {
    return null;
  }
  return {utcDay, count};
}

function secondsUntilNextUtcDay(nowMs: number): number {
  return Math.max(1, Math.ceil((startOfNextUtcDayMs(nowMs) - nowMs) / 1_000));
}

function startOfNextUtcDayMs(nowMs: number): number {
  const now = new Date(nowMs);
  return Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + 1,
  );
}
