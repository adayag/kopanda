import type { ProfileListing, ProfileWithPath } from "../server/profiles.js";

/** A non-2xx answer from the studio server: its `error` text and HTTP status. */
export class ApiError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function getJson<T>(url: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(url, { signal });
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
  return getJson("/api/profiles", signal);
}

/**
 * The profile with this id. An id that cannot be one URL path segment (empty, `.` or `..`, which the
 * URL parser resolves to another path whatever their encoding) names no profile and is not requested.
 */
export async function fetchProfile(id: string, signal?: AbortSignal): Promise<ProfileWithPath> {
  if (id === "" || id === "." || id === "..") throw new ApiError(404, `no profile "${id}"`);
  return getJson(`/api/profiles/${encodeURIComponent(id)}`, signal);
}
