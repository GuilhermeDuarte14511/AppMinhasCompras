import {
  type Firestore,
  Timestamp,
} from "firebase-admin/firestore";

import {
  type CosmosCacheLookup,
  type CosmosProduct,
} from "./cosmos";

export const PRODUCT_CACHE_TTL_MS = 24 * 60 * 60 * 1_000;
export const NOT_FOUND_CACHE_TTL_MS = 6 * 60 * 60 * 1_000;

const CACHE_COLLECTION = "internal_cosmos_cache";
const CACHE_SCHEMA_VERSION = 1;
const VALID_CATEGORY_KEYS = new Set([
  "baby",
  "bakery",
  "beverages",
  "cleaning",
  "condiments",
  "dairy",
  "eggs",
  "frozen",
  "grains_pasta",
  "grocery",
  "meat",
  "personal_care",
  "pet",
  "produce",
  "seafood",
  "snacks",
  "sweets",
]);

export async function readCosmosProductCache(
  firestore: Firestore,
  gtin: string,
  nowMs = Date.now(),
): Promise<CosmosCacheLookup> {
  const snapshot = await firestore.collection(CACHE_COLLECTION).doc(gtin).get();
  return parseCosmosCacheEntry(snapshot.data(), gtin, nowMs);
}

export async function writeCosmosProductCache(
  firestore: Firestore,
  gtin: string,
  product: CosmosProduct | null,
  nowMs = Date.now(),
): Promise<void> {
  const ttlMs =
    product === null ? NOT_FOUND_CACHE_TTL_MS : PRODUCT_CACHE_TTL_MS;
  await firestore.collection(CACHE_COLLECTION).doc(gtin).set({
    schemaVersion: CACHE_SCHEMA_VERSION,
    found: product !== null,
    product,
    updatedAt: Timestamp.fromMillis(nowMs),
    expiresAt: Timestamp.fromMillis(nowMs + ttlMs),
  });
}

export function parseCosmosCacheEntry(
  data: unknown,
  expectedGtin: string,
  nowMs: number,
): CosmosCacheLookup {
  if (!isRecord(data) || data.schemaVersion !== CACHE_SCHEMA_VERSION) {
    return cacheMiss();
  }
  if (!(data.expiresAt instanceof Timestamp) || data.expiresAt.toMillis() <= nowMs) {
    return cacheMiss();
  }
  if (data.found === false && data.product === null) {
    return {hit: true, product: null};
  }
  if (data.found !== true || !isRecord(data.product)) {
    return cacheMiss();
  }

  const product = parseCachedProduct(data.product, expectedGtin);
  return product === null ? cacheMiss() : {hit: true, product};
}

function parseCachedProduct(
  data: Readonly<Record<string, unknown>>,
  expectedGtin: string,
): CosmosProduct | null {
  if (data.gtin !== expectedGtin) {
    return null;
  }
  const name = readNullableString(data.name);
  const categoryKey = readCategoryKey(data.categoryKey);
  const unitPrice = readUnitPrice(data.unitPrice);

  if (
    (data.name !== null && name === null) ||
    (data.categoryKey !== null && categoryKey === null) ||
    (data.unitPrice !== null && unitPrice === null)
  ) {
    return null;
  }

  return {
    gtin: expectedGtin,
    name,
    categoryKey,
    unitPrice,
  };
}

function cacheMiss(): CosmosCacheLookup {
  return {hit: false, product: null};
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readNullableString(value: unknown): string | null {
  if (value === null) {
    return null;
  }
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 && normalized.length <= 160 ? normalized : null;
}

function readCategoryKey(value: unknown): string | null {
  if (value === null) {
    return null;
  }
  return typeof value === "string" && VALID_CATEGORY_KEYS.has(value) ?
    value :
    null;
}

function readUnitPrice(value: unknown): number | null {
  if (value === null) {
    return null;
  }
  return typeof value === "number" &&
    Number.isFinite(value) &&
    value > 0 &&
    value <= 1_000_000 ?
    value :
    null;
}
