import type { LuaKey } from "../core/lua.js";
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
  if (id === "" || id === "." || id === "..") throw new ApiError(404, `no profile "${id}"`);
  return `/api/profiles/${encodeURIComponent(id)}`;
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
