import type { LuaKey } from "../core/lua.js";
import type { Health } from "../server/app.js";
import type { Manifest } from "../server/bundle.js";
import type { Candidate } from "../server/geocoding.js";
import type { ProfileListing, ProfileWithPath } from "../server/profiles.js";
import type { SettingsState } from "../server/settings-file.js";

/** A non-2xx answer from the studio server: its `error` text and HTTP status. */
export class ApiError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

/** A profile's settings file as `GET /api/profiles/:id/settings` and each `PUT` of a key answer it. */
export interface Settings {
  path: string;
  exists: boolean;
  state: SettingsState;
  reason?: string;
  schema_version: number | null;
  /** Every schema key's value: the stored one when valid, else the default. */
  values: Record<string, unknown>;
  invalid: { key: string }[];
  unknown: { key: LuaKey; text: string }[];
}

async function requestJson<T>(url: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(url, init);
  if (!res.ok) {
    let message = `${url} answered ${res.status}`;
    try {
      const body: unknown = await res.json();
      if (typeof body === "object" && body !== null && "error" in body && typeof body.error === "string") {
        message = body.error;
      }
    } catch {
      // A body that is not JSON keeps the status message.
    }
    throw new ApiError(res.status, message);
  }
  return (await res.json()) as T;
}

export function fetchProfiles(signal?: AbortSignal): Promise<ProfileListing> {
  return requestJson("/api/profiles", { signal });
}

/**
 * The profile with this id. An id that cannot be one URL path segment (empty, `.` or `..`, which the
 * URL parser resolves to another path whatever their encoding) names no profile and is not requested.
 */
export async function fetchProfile(id: string, signal?: AbortSignal): Promise<ProfileWithPath> {
  return requestJson(profileUrl(id), { signal });
}

function profileUrl(id: string): string {
  return `/api/profiles/${idSegment(id)}`;
}

function idSegment(id: string): string {
  if (id === "" || id === "." || id === "..") throw new ApiError(404, `no profile "${id}"`);
  return encodeURIComponent(id);
}

/** The settings file of the profile with this id. */
export async function fetchSettings(id: string, signal?: AbortSignal): Promise<Settings> {
  return requestJson(`${profileUrl(id)}/settings`, { signal });
}

/** Writes one key of the profile's settings file and answers the file as read after. */
export async function putSetting(id: string, key: string, value: unknown): Promise<Settings> {
  return requestJson(`${profileUrl(id)}/settings/${encodeURIComponent(key)}`, {
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ value }),
  });
}

/**
 * The fit check's answer: how many rows the home leaves out for the profile's current layout and for
 * the proposed one, or why that couldn't be checked.
 */
export type FitAnswer = { checked: true; current: number; proposed: number } | { checked: false; reason: string };

/** Asks how the proposed rows of the rows key `key` fit on the profile's screen against its current ones. */
export async function checkFit(id: string, rows: unknown, key: string, signal?: AbortSignal): Promise<FitAnswer> {
  return requestJson(`${profileUrl(id)}/layout-fit`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ rows, key }),
    signal,
  });
}

/** A render that gave no image: the HTTP status (0 when the server can't be reached), its error and log lines. */
export class PreviewError extends Error {
  readonly status: number;
  readonly error: string;
  readonly log: string[];

  constructor(status: number, error: string, log: string[] = []) {
    super(error);
    this.name = "PreviewError";
    this.status = status;
    this.error = error;
    this.log = log;
  }
}

/** The profile's home rendered by the emulator in one look, day or night, as a PNG. */
export async function fetchPreview(
  id: string,
  frame: { look: string; night: boolean },
  signal?: AbortSignal,
): Promise<Blob> {
  const url = `${profileUrl(id)}/preview`;
  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(frame),
      signal,
    });
  } catch (err) {
    throw new PreviewError(0, err instanceof Error ? err.message : String(err));
  }
  if (res.ok) return res.blob();
  let error = `${url} answered ${res.status}`;
  let log: string[] = [];
  try {
    const body: unknown = await res.json();
    if (typeof body === "object" && body !== null) {
      if ("error" in body && typeof body.error === "string") error = body.error;
      if ("log" in body && Array.isArray(body.log))
        log = body.log.filter((line): line is string => typeof line === "string");
    }
  } catch {
    // A body that is not JSON keeps the status message.
  }
  throw new PreviewError(res.status, error, log);
}

/** The address and port the studio is bound to, and its LAN addresses when it serves the LAN. */
export function fetchHealth(signal?: AbortSignal): Promise<Health> {
  return requestJson("/api/health", { signal });
}

/** The manifest of the profile's bundle as the Kindle would pull it now. */
export async function fetchManifest(id: string, signal?: AbortSignal): Promise<Manifest> {
  return requestJson(`/api/push/${idSegment(id)}/manifest`, { signal });
}

/** The places Open-Meteo offers for query, asked through the studio's server. */
export async function searchPlaces(query: string): Promise<Candidate[]> {
  const { candidates } = await requestJson<{ candidates: Candidate[] }>(`/api/geocode?q=${encodeURIComponent(query)}`);
  return candidates;
}
