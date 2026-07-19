import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test from "node:test";

import {
  CosmosConfigurationError,
  CosmosUpstreamError,
  InvalidGtinError,
  createCosmosLookupHandler,
  fetchCosmosProduct,
  hasValidGtinCheckDigit,
  mapCosmosProduct,
} from "./cosmos";
import {RateLimitExceededError} from "./rate_limit";

const VALID_GTIN = "7894900011517";

void test("validates GTIN length, digits, and check digit", () => {
  assert.equal(hasValidGtinCheckDigit(VALID_GTIN), true);
  assert.equal(hasValidGtinCheckDigit("7894900011518"), false);
  assert.equal(hasValidGtinCheckDigit("123"), false);
});

void test("maps only the public product fields required by the app", () => {
  const product = mapCosmosProduct(VALID_GTIN, {
    description: " Café torrado ",
    name: "Café Premium",
    brand: {name: "Marca Exemplo"},
    gpc: {description: "Bebidas"},
    avg_price: "19,90",
    ignored_private_field: "must not be returned",
  });
  const fixture = JSON.parse(
    readFileSync(
      resolve(process.cwd(), "../test/fixtures/cosmos_lookup_response.json"),
      "utf8",
    ),
  ) as unknown;

  assert.deepEqual({product}, fixture);
  assert.equal("ignored_private_field" in product, false);
});

void test("bounds upstream text and price values", () => {
  const product = mapCosmosProduct(VALID_GTIN, {
    name: "x".repeat(300),
    category: "Categoria desconhecida",
    avg_price: 1_000_001,
    max_price: 42.5,
  });

  assert.equal(product.name?.length, 160);
  assert.equal(product.categoryKey, null);
  assert.equal(product.unitPrice, 42.5);
});

void test("uses brand as a safe name fallback", () => {
  const product = mapCosmosProduct(VALID_GTIN, {
    brand: {name: "Marca sem descrição"},
  });

  assert.equal(product.name, "Marca sem descrição");
});

void test("handler validates before rate limiting or calling Cosmos", async () => {
  let beforeLookupCalls = 0;
  let fetchCalls = 0;
  const handler = createCosmosLookupHandler({
    getToken: () => "test-secret",
    beforeLookup: () => {
      beforeLookupCalls += 1;
      return Promise.resolve();
    },
    fetchImpl: () => {
      fetchCalls += 1;
      return Promise.resolve(Response.json({}));
    },
  });

  await assert.rejects(
    handler({gtin: "7894900011518"}),
    InvalidGtinError,
  );
  assert.equal(beforeLookupCalls, 0);
  assert.equal(fetchCalls, 0);
});

void test("handler checks configuration before consuming user quota", async () => {
  let beforeLookupCalls = 0;
  const handler = createCosmosLookupHandler({
    getToken: () => " ",
    beforeLookup: () => {
      beforeLookupCalls += 1;
      return Promise.resolve();
    },
  });

  await assert.rejects(
    handler({gtin: VALID_GTIN}),
    CosmosConfigurationError,
  );
  assert.equal(beforeLookupCalls, 0);
});

void test("cache hit bypasses token, quota, upstream, and cache write", async () => {
  let tokenReads = 0;
  let quotaCalls = 0;
  let fetchCalls = 0;
  let cacheWrites = 0;
  const cachedProduct = {
    gtin: VALID_GTIN,
    name: "Produto em cache",
    categoryKey: "grocery",
    unitPrice: 9.9,
  };
  const handler = createCosmosLookupHandler({
    getToken: () => {
      tokenReads += 1;
      return "test-secret";
    },
    readCache: () =>
      Promise.resolve({hit: true, product: cachedProduct}),
    beforeLookup: () => {
      quotaCalls += 1;
      return Promise.resolve();
    },
    fetchImpl: () => {
      fetchCalls += 1;
      return Promise.resolve(Response.json({}));
    },
    writeCache: () => {
      cacheWrites += 1;
      return Promise.resolve();
    },
  });

  const result = await handler({gtin: VALID_GTIN});

  assert.deepEqual(result, {product: cachedProduct});
  assert.equal(tokenReads, 0);
  assert.equal(quotaCalls, 0);
  assert.equal(fetchCalls, 0);
  assert.equal(cacheWrites, 0);
});

void test("negative cache hit also bypasses quota and upstream", async () => {
  let quotaCalls = 0;
  let upstreamCalls = 0;
  const handler = createCosmosLookupHandler({
    getToken: () => "test-secret",
    readCache: () => Promise.resolve({hit: true, product: null}),
    beforeLookup: () => {
      quotaCalls += 1;
      return Promise.resolve();
    },
    fetchImpl: () => {
      upstreamCalls += 1;
      return Promise.resolve(Response.json({}));
    },
  });

  assert.deepEqual(
    await handler({gtin: VALID_GTIN}),
    {product: null},
  );
  assert.equal(quotaCalls, 0);
  assert.equal(upstreamCalls, 0);
});

void test("cache miss reserves quota before upstream and then caches", async () => {
  const events: string[] = [];
  const handler = createCosmosLookupHandler({
    readCache: () => {
      events.push("cache-read");
      return Promise.resolve({hit: false, product: null});
    },
    getToken: () => {
      events.push("token");
      return "test-secret";
    },
    beforeLookup: () => {
      events.push("quota");
      return Promise.resolve();
    },
    fetchImpl: () => {
      events.push("upstream");
      return Promise.resolve(Response.json({description: "Arroz"}));
    },
    writeCache: () => {
      events.push("cache-write");
      return Promise.resolve();
    },
  });

  await handler({gtin: VALID_GTIN});

  assert.deepEqual(events, [
    "cache-read",
    "token",
    "quota",
    "upstream",
    "cache-write",
  ]);
});

void test("concurrent quota rejection prevents excess upstream calls", async () => {
  let reservations = 0;
  let upstreamCalls = 0;
  const handler = createCosmosLookupHandler({
    getToken: () => "test-secret",
    beforeLookup: async () => {
      await Promise.resolve();
      if (reservations >= 2) {
        throw new RateLimitExceededError(60, "global");
      }
      reservations += 1;
    },
    fetchImpl: () => {
      upstreamCalls += 1;
      return Promise.resolve(Response.json({description: "Arroz"}));
    },
  });

  const results = await Promise.allSettled(
    Array.from({length: 5}, () => handler({gtin: VALID_GTIN})),
  );

  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    2,
  );
  assert.equal(
    results.filter((result) => result.status === "rejected").length,
    3,
  );
  assert.equal(upstreamCalls, 2);
});

void test("handler injects the token only into the upstream header", async () => {
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  const handler = createCosmosLookupHandler({
    getToken: () => "test-secret",
    fetchImpl: (input, init) => {
      capturedUrl =
        typeof input === "string"
          ? input
          : input instanceof URL
            ? input.href
            : input.url;
      capturedInit = init;
      return Promise.resolve(
        Response.json({
          description: "Arroz",
          brand: {name: "Marca"},
          avg_price: 8.5,
        }),
      );
    },
  });

  const result = await handler({gtin: VALID_GTIN});

  assert.equal(
    capturedUrl,
    `https://api.cosmos.bluesoft.com.br/gtins/${VALID_GTIN}.json`,
  );
  assert.equal(
    new Headers(capturedInit?.headers).get("X-Cosmos-Token"),
    "test-secret",
  );
  assert.equal(JSON.stringify(result).includes("test-secret"), false);
  assert.equal(result.product?.name, "Arroz");
});

void test("does not expose an upstream response body on failure", async () => {
  const upstreamBody = "sensitive-upstream-details";
  const handler = createCosmosLookupHandler({
    getToken: () => "test-secret",
    fetchImpl: () =>
      Promise.resolve(new Response(upstreamBody, {status: 500})),
  });

  await assert.rejects(
    handler({gtin: VALID_GTIN}),
    (error: unknown) => {
      assert.ok(error instanceof CosmosUpstreamError);
      assert.equal(error.message.includes(upstreamBody), false);
      return true;
    },
  );
});

void test("maps Cosmos not-found and rate-limit responses", async () => {
  const notFound = await fetchCosmosProduct({
    gtin: VALID_GTIN,
    token: "test-secret",
    fetchImpl: () => Promise.resolve(new Response(null, {status: 404})),
  });
  assert.equal(notFound, null);

  await assert.rejects(
    fetchCosmosProduct({
      gtin: VALID_GTIN,
      token: "test-secret",
      fetchImpl: () => Promise.resolve(new Response(null, {status: 429})),
    }),
    (error: unknown) =>
      error instanceof CosmosUpstreamError &&
      error.reason === "rate-limited",
  );
});

void test("rejects invalid JSON without exposing its body", async () => {
  const invalidBody = "private-invalid-body";
  await assert.rejects(
    fetchCosmosProduct({
      gtin: VALID_GTIN,
      token: "test-secret",
      fetchImpl: () =>
        Promise.resolve(
          new Response(invalidBody, {
            status: 200,
            headers: {"Content-Type": "application/json"},
          }),
        ),
    }),
    (error: unknown) => {
      assert.ok(error instanceof CosmosUpstreamError);
      assert.equal(error.reason, "invalid-response");
      assert.equal(error.message.includes(invalidBody), false);
      return true;
    },
  );
});

void test("aborts a slow upstream request at the configured timeout", async () => {
  await assert.rejects(
    fetchCosmosProduct({
      gtin: VALID_GTIN,
      token: "test-secret",
      timeoutMs: 1,
      fetchImpl: (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            reject(new DOMException("aborted", "AbortError"));
          });
        }),
    }),
    (error: unknown) =>
      error instanceof CosmosUpstreamError && error.reason === "timeout",
  );
});
