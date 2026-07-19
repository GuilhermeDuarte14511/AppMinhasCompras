const COSMOS_API_BASE_URL = "https://api.cosmos.bluesoft.com.br";
const DEFAULT_TIMEOUT_MS = 6_000;
const VALID_GTIN_LENGTHS = new Set([8, 12, 13, 14]);
const MAX_PRODUCT_NAME_LENGTH = 160;
const MAX_UNIT_PRICE = 1_000_000;

export interface CosmosProduct {
  readonly gtin: string;
  readonly name: string | null;
  readonly categoryKey: string | null;
  readonly unitPrice: number | null;
}

export interface CosmosLookupResponse {
  readonly product: CosmosProduct | null;
}

export interface CosmosCacheLookup {
  readonly hit: boolean;
  readonly product: CosmosProduct | null;
}

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export class InvalidGtinError extends Error {
  constructor() {
    super("Invalid GTIN.");
    this.name = "InvalidGtinError";
  }
}

export class CosmosConfigurationError extends Error {
  constructor() {
    super("Cosmos integration is not configured.");
    this.name = "CosmosConfigurationError";
  }
}

export class CosmosUpstreamError extends Error {
  constructor(
    readonly reason:
      | "invalid-response"
      | "rate-limited"
      | "timeout"
      | "unavailable",
  ) {
    super(`Cosmos upstream failure: ${reason}.`);
    this.name = "CosmosUpstreamError";
  }
}

export interface CosmosLookupDependencies {
  readonly getToken: () => string;
  readonly fetchImpl?: FetchLike;
  readonly timeoutMs?: number;
  readonly readCache?: (gtin: string) => Promise<CosmosCacheLookup>;
  readonly writeCache?: (
    gtin: string,
    product: CosmosProduct | null,
  ) => Promise<void>;
  readonly beforeLookup?: (gtin: string) => Promise<void>;
}

export function createCosmosLookupHandler(
  dependencies: CosmosLookupDependencies,
): (data: unknown) => Promise<CosmosLookupResponse> {
  return async (data: unknown): Promise<CosmosLookupResponse> => {
    const gtin = parseCosmosLookupRequest(data);
    const cached = await dependencies.readCache?.(gtin);
    if (cached?.hit === true) {
      return {product: cached.product};
    }

    const token = dependencies.getToken().trim();
    if (token.length === 0) {
      throw new CosmosConfigurationError();
    }
    await dependencies.beforeLookup?.(gtin);

    const product = await fetchCosmosProduct({
      gtin,
      token,
      fetchImpl: dependencies.fetchImpl,
      timeoutMs: dependencies.timeoutMs,
    });
    await dependencies.writeCache?.(gtin, product);
    return {product};
  };
}

export function parseCosmosLookupRequest(data: unknown): string {
  if (!isRecord(data)) {
    throw new InvalidGtinError();
  }

  const keys = Object.keys(data);
  if (keys.length !== 1 || keys[0] !== "gtin" || typeof data.gtin !== "string") {
    throw new InvalidGtinError();
  }

  const gtin = data.gtin;
  if (
    gtin !== gtin.trim() ||
    !/^\d+$/.test(gtin) ||
    !VALID_GTIN_LENGTHS.has(gtin.length) ||
    !hasValidGtinCheckDigit(gtin)
  ) {
    throw new InvalidGtinError();
  }

  return gtin;
}

export function hasValidGtinCheckDigit(gtin: string): boolean {
  if (!VALID_GTIN_LENGTHS.has(gtin.length) || !/^\d+$/.test(gtin)) {
    return false;
  }

  const checkDigit = Number(gtin.at(-1));
  let sum = 0;
  let multiplier = 3;

  for (let index = gtin.length - 2; index >= 0; index -= 1) {
    sum += Number(gtin[index]) * multiplier;
    multiplier = multiplier === 3 ? 1 : 3;
  }

  return (10 - (sum % 10)) % 10 === checkDigit;
}

interface FetchCosmosProductOptions {
  readonly gtin: string;
  readonly token: string;
  readonly fetchImpl?: FetchLike;
  readonly timeoutMs?: number;
}

export async function fetchCosmosProduct({
  gtin,
  token,
  fetchImpl = fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
}: FetchCosmosProductOptions): Promise<CosmosProduct | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => {
    controller.abort();
  }, timeoutMs);

  try {
    const response = await fetchImpl(
      `${COSMOS_API_BASE_URL}/gtins/${gtin}.json`,
      {
        method: "GET",
        headers: {
          Accept: "application/json",
          "User-Agent": "Lista-Compras-Cosmos-Proxy",
          "X-Cosmos-Token": token,
        },
        signal: controller.signal,
      },
    );

    if (response.status === 404) {
      return null;
    }
    if (response.status === 429) {
      throw new CosmosUpstreamError("rate-limited");
    }
    if (!response.ok) {
      throw new CosmosUpstreamError("unavailable");
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      throw new CosmosUpstreamError("invalid-response");
    }

    if (!isRecord(payload)) {
      throw new CosmosUpstreamError("invalid-response");
    }
    return mapCosmosProduct(gtin, payload);
  } catch (error: unknown) {
    if (error instanceof CosmosUpstreamError) {
      throw error;
    }
    if (
      controller.signal.aborted ||
      (error instanceof Error &&
        (error.name === "AbortError" || error.name === "TimeoutError"))
    ) {
      throw new CosmosUpstreamError("timeout");
    }
    throw new CosmosUpstreamError("unavailable");
  } finally {
    clearTimeout(timeout);
  }
}

export function mapCosmosProduct(
  gtin: string,
  payload: Readonly<Record<string, unknown>>,
): CosmosProduct {
  const brand =
    readString(payload.brand, MAX_PRODUCT_NAME_LENGTH) ??
    readNestedString(payload.brand, ["name", "description"]);
  const name =
    readString(payload.name, MAX_PRODUCT_NAME_LENGTH) ??
    readString(payload.description, MAX_PRODUCT_NAME_LENGTH) ??
    brand;
  const category =
    readString(payload.category, MAX_PRODUCT_NAME_LENGTH) ??
    readNestedString(payload.category, ["description", "name"]) ??
    readNestedString(payload.gpc, ["description", "name"]) ??
    readNestedString(payload.ncm, ["description", "name"]);
  const unitPrice =
    readPositiveNumber(payload.avg_price) ??
    readPositiveNumber(payload.avgPrice) ??
    readPositiveNumber(payload.max_price) ??
    readPositiveNumber(payload.price);

  return {
    gtin,
    name,
    categoryKey: classifyCategory(category),
    unitPrice,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readString(
  value: unknown,
  maxLength = MAX_PRODUCT_NAME_LENGTH,
): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length === 0) {
    return null;
  }
  return normalized.slice(0, maxLength);
}

function readNestedString(
  value: unknown,
  keys: readonly string[],
): string | null {
  if (!isRecord(value)) {
    return null;
  }
  for (const key of keys) {
    const candidate = readString(value[key]);
    if (candidate !== null) {
      return candidate;
    }
  }
  return null;
}

function readPositiveNumber(value: unknown): number | null {
  const parsed =
    typeof value === "number"
      ? value
      : typeof value === "string" && value.trim().length > 0
        ? Number(value.replace(",", "."))
        : Number.NaN;
  return Number.isFinite(parsed) && parsed > 0 && parsed <= MAX_UNIT_PRICE ?
    parsed :
    null;
}

export function classifyCategory(value: string | null): string | null {
  if (value === null) {
    return null;
  }
  const normalized = value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase();
  const rules: ReadonlyArray<readonly [string, readonly string[]]> = [
    ["baby", ["bebe", "infantil"]],
    ["pet", ["pet", "animal"]],
    ["personal_care", ["higiene", "cosmetico", "cuidados pessoais"]],
    ["cleaning", ["limpeza", "detergente", "desinfetante"]],
    ["beverages", ["bebida", "refrigerante", "suco", "agua mineral"]],
    ["dairy", ["laticinio", "leite", "queijo", "iogurte"]],
    ["eggs", ["ovo"]],
    ["seafood", ["peixe", "pescado", "frutos do mar"]],
    ["meat", ["carne", "bovino", "suino", "aves"]],
    ["produce", ["hortifruti", "fruta", "verdura", "legume"]],
    ["bakery", ["padaria", "panificacao", "pao"]],
    ["grains_pasta", ["grao", "cereal", "massa", "arroz", "feijao"]],
    ["frozen", ["congelado"]],
    ["snacks", ["snack", "salgadinho"]],
    ["sweets", ["doce", "sobremesa", "chocolate"]],
    ["condiments", ["condimento", "tempero", "molho"]],
    ["grocery", ["mercearia"]],
  ];
  for (const [key, keywords] of rules) {
    if (keywords.some((keyword) => normalized.includes(keyword))) {
      return key;
    }
  }
  return null;
}
