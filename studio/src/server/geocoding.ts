/**
 * The device's place search (kopanda.koplugin/location_search.lua), run by the studio's server: the
 * Open-Meteo geocoding URL for a typed query and the candidates read from its answer. Held to the
 * plugin's rules by the shared corpus spec/fixtures/studio/geocoding_cases.lua.
 */

/** A place the search offers: `name` as stored, `shown` as the chooser's button reads. */
export interface Candidate {
  name: string;
  latitude: number;
  longitude: number;
  shown: string;
}

/** How long a search may take, request and body: the device's total timeout (weather.lua:76). */
export const SEARCH_TIMEOUT_MS = 10_000;

const BASE = "https://geocoding-api.open-meteo.com/v1/search?name=";
const TAIL = "&count=10&language=en&format=json";

/**
 * s without leading and trailing whitespace as KOReader's util.trim (frontend/util.lua:52-55):
 * Lua's %s, the ASCII set, so a no-break space stays where String.prototype.trim would drop it.
 */
export function trim(s: string): string {
  return s.replace(/^[ \t\n\v\f\r]+|[ \t\n\v\f\r]+$/g, "");
}

function unreserved(byte: number): boolean {
  return (
    (byte >= 0x30 && byte <= 0x39) || // 0-9
    (byte >= 0x41 && byte <= 0x5a) || // A-Z
    (byte >= 0x61 && byte <= 0x7a) || // a-z
    byte === 0x2d || // -
    byte === 0x2e || // .
    byte === 0x5f || // _
    byte === 0x7e // ~
  );
}

/**
 * s encoded as KOReader's util.urlEncode (frontend/util.lua:1443-1455): a newline becomes CR LF,
 * then every UTF-8 byte outside A-Z a-z 0-9 - . _ ~ is %XX in upper case. encodeURIComponent
 * differs: it leaves ! ' ( ) * as they are.
 */
export function urlEncode(s: string): string {
  let out = "";
  for (const byte of new TextEncoder().encode(s.replace(/\n/g, "\r\n"))) {
    out += unreserved(byte) ? String.fromCharCode(byte) : `%${byte.toString(16).toUpperCase().padStart(2, "0")}`;
  }
  return out;
}

/**
 * The geocoding URL for query, trimmed and encoded (LocationSearch.url). Exactly five digits is a
 * US ZIP code, so it is limited to the US.
 */
export function geocodeUrl(query: string): string {
  const q = trim(query);
  let url = BASE + urlEncode(q) + TAIL;
  if (/^[0-9]{5}$/.test(q)) url += "&countryCode=US";
  return url;
}

function text(value: unknown): value is string {
  return typeof value === "string" && value !== "";
}

/**
 * The candidates in a geocoding response, in the order returned (LocationSearch.parse): name is
 * "<name>, <admin1>" when admin1 is non-empty and not the name, else "<name>, <country>" when the
 * country is non-empty, else the name; shown adds ", <country>" unless it is already the last part.
 * A result without a non-empty name or with a coordinate that isn't a number is skipped, as is a
 * string or a list; no list of results is none. Null for a body that isn't JSON, holds a number too
 * big for a double (rapidjson refuses it) or isn't an object or a list, and for a result that is a
 * number, a boolean or null, which the device's parse raises on.
 */
export function parseGeocoding(body: string): Candidate[] | null {
  let data: unknown;
  try {
    // A number too big for a double is Infinity here; rapidjson refuses the whole body for it.
    data = JSON.parse(body, (_key, value: unknown) => {
      if (typeof value === "number" && !Number.isFinite(value)) throw new RangeError("number too big");
      return value;
    });
  } catch {
    return null;
  }
  if (typeof data !== "object" || data === null) return null;
  const results = (data as { results?: unknown }).results;
  if (!Array.isArray(results)) return [];
  const candidates: Candidate[] = [];
  for (const result of results as unknown[]) {
    if (typeof result === "string") continue;
    if (typeof result !== "object" || result === null) return null;
    const { name, latitude, longitude, admin1, country } = result as Record<string, unknown>;
    if (!text(name) || typeof latitude !== "number" || typeof longitude !== "number") continue;
    let stored = name;
    if (text(admin1) && admin1 !== name) {
      stored = `${name}, ${admin1}`;
    } else if (text(country)) {
      stored = `${name}, ${country}`;
    }
    const lastPart = stored.slice(stored.lastIndexOf(",") + 1).replace(/^[ \t\n\v\f\r]+/, "");
    const shown = text(country) && country !== lastPart ? `${stored}, ${country}` : stored;
    candidates.push({ name: stored, latitude, longitude, shown });
  }
  return candidates;
}

/** Why a search failed: the route answers it as 502. */
export class SearchError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "SearchError";
  }
}

/**
 * The candidates for query from Open-Meteo through fetchImpl. Throws a SearchError when the request
 * fails, answers a status other than 200 (as the device's Weather.get, weather.lua:89-91), its body
 * is unreadable, or the whole of it takes longer than timeoutMs.
 */
export async function searchPlaces(
  query: string,
  fetchImpl: typeof fetch = fetch,
  timeoutMs: number = SEARCH_TIMEOUT_MS,
): Promise<Candidate[]> {
  const signal = AbortSignal.timeout(timeoutMs);
  // A fetch that ignores the signal still loses the race.
  const timedOut = new Promise<never>((_, reject) => {
    signal.addEventListener("abort", () => {
      reject(new SearchError(`Open-Meteo didn't answer within ${timeoutMs / 1000} s`));
    });
  });
  const attempt = (async () => {
    let res: Response;
    let body: string;
    try {
      res = await fetchImpl(geocodeUrl(query), { signal });
      body = await res.text();
    } catch (err) {
      throw new SearchError(`couldn't reach Open-Meteo: ${err instanceof Error ? err.message : String(err)}`, {
        cause: err,
      });
    }
    if (res.status !== 200) throw new SearchError(`Open-Meteo answered HTTP ${res.status}`);
    const candidates = parseGeocoding(body);
    if (candidates === null) throw new SearchError("Open-Meteo's answer is unreadable");
    return candidates;
  })();
  return Promise.race([attempt, timedOut]);
}
