import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {defineInt, defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  readCosmosProductCache,
  writeCosmosProductCache,
} from "./cache";
import {
  CosmosConfigurationError,
  CosmosUpstreamError,
  InvalidGtinError,
  createCosmosLookupHandler,
} from "./cosmos";
import {
  DEFAULT_GLOBAL_DAILY_QUOTA,
  RateLimitConfigurationError,
  RateLimitExceededError,
  enforceCosmosRateLimits,
} from "./rate_limit";

initializeApp();

const firestore = getFirestore();
const cosmosApiToken = defineSecret("COSMOS_API_TOKEN");
const cosmosDailyQuota = defineInt("COSMOS_DAILY_QUOTA", {
  default: DEFAULT_GLOBAL_DAILY_QUOTA,
});

export const lookupCosmosProduct = onCall(
  {
    region: "southamerica-east1",
    timeoutSeconds: 10,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 10,
    enforceAppCheck: false,
    secrets: [cosmosApiToken],
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    const uid = request.auth.uid;
    const handler = createCosmosLookupHandler({
      getToken: () => cosmosApiToken.value(),
      readCache: async (gtin) =>
        readCosmosProductCache(firestore, gtin),
      beforeLookup: async () => {
        await enforceCosmosRateLimits(
          firestore,
          uid,
          cosmosDailyQuota.value(),
        );
      },
      writeCache: async (gtin, product) => {
        try {
          await writeCosmosProductCache(firestore, gtin, product);
        } catch {
          return;
        }
      },
    });

    try {
      return await handler(request.data);
    } catch (error: unknown) {
      if (error instanceof InvalidGtinError) {
        throw new HttpsError(
          "invalid-argument",
          "A valid GTIN-8, GTIN-12, GTIN-13, or GTIN-14 is required.",
        );
      }
      if (error instanceof RateLimitExceededError) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many product lookups. Try again later.",
          {retryAfterSeconds: error.retryAfterSeconds},
        );
      }
      if (error instanceof CosmosConfigurationError) {
        throw new HttpsError(
          "failed-precondition",
          "Product lookup is temporarily unavailable.",
        );
      }
      if (error instanceof RateLimitConfigurationError) {
        throw new HttpsError(
          "failed-precondition",
          "Product lookup is temporarily unavailable.",
        );
      }
      if (error instanceof CosmosUpstreamError) {
        const code =
          error.reason === "rate-limited" ?
            "resource-exhausted" :
            "unavailable";
        throw new HttpsError(
          code,
          "Product lookup is temporarily unavailable.",
        );
      }
      throw new HttpsError(
        "internal",
        "Product lookup could not be completed.",
      );
    }
  },
);
