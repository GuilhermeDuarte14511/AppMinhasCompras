import assert from "node:assert/strict";
import test from "node:test";

import {Timestamp} from "firebase-admin/firestore";

import {parseCosmosCacheEntry} from "./cache";

const GTIN = "7894900011517";
const NOW_MS = Date.UTC(2026, 6, 19, 12);

void test("returns a positive cache hit only for a valid unexpired entry", () => {
  const result = parseCosmosCacheEntry(
    {
      schemaVersion: 1,
      found: true,
      product: {
        gtin: GTIN,
        name: "Café",
        categoryKey: "beverages",
        unitPrice: 19.9,
      },
      expiresAt: Timestamp.fromMillis(NOW_MS + 1_000),
    },
    GTIN,
    NOW_MS,
  );

  assert.deepEqual(result, {
    hit: true,
    product: {
      gtin: GTIN,
      name: "Café",
      categoryKey: "beverages",
      unitPrice: 19.9,
    },
  });
});

void test("supports negative cache hits without fabricating a product", () => {
  const result = parseCosmosCacheEntry(
    {
      schemaVersion: 1,
      found: false,
      product: null,
      expiresAt: Timestamp.fromMillis(NOW_MS + 1_000),
    },
    GTIN,
    NOW_MS,
  );

  assert.deepEqual(result, {hit: true, product: null});
});

void test("treats expired or malformed entries as misses", () => {
  const expired = parseCosmosCacheEntry(
    {
      schemaVersion: 1,
      found: true,
      product: {
        gtin: GTIN,
        name: "Café",
        categoryKey: "beverages",
        unitPrice: 19.9,
      },
      expiresAt: Timestamp.fromMillis(NOW_MS),
    },
    GTIN,
    NOW_MS,
  );
  const wrongGtin = parseCosmosCacheEntry(
    {
      schemaVersion: 1,
      found: true,
      product: {
        gtin: "96385074",
        name: "Outro produto",
        categoryKey: null,
        unitPrice: null,
      },
      expiresAt: Timestamp.fromMillis(NOW_MS + 1_000),
    },
    GTIN,
    NOW_MS,
  );

  assert.deepEqual(expired, {hit: false, product: null});
  assert.deepEqual(wrongGtin, {hit: false, product: null});
});
