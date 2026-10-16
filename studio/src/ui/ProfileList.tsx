import { useEffect, useState } from "react";
import type { Profile, ProfileListing } from "../server/profiles.js";
import { fetchProfiles } from "./api";

/** The resolution, DPI and colour of a profile's device, on one line. */
export function screenFacts(profile: Profile): string {
  const { width, height, dpi, color } = profile;
  return `${width}×${height} · ${dpi} dpi · ${color ? "colour" : "greyscale"}`;
}

/** The hash of the profile with this id: its form, or the view after it. */
export function profileHref(id: string, view?: "layout" | "launcher"): string {
  const href = `#/profiles/${encodeURIComponent(id)}`;
  return view === undefined ? href : `${href}/${view}`;
}

function openProfile(id: string): void {
  location.hash = profileHref(id);
}

type State =
  | { status: "loading" }
  | { status: "loaded"; listing: ProfileListing }
  | { status: "failed"; message: string };

/** The first screen: every profile in the profiles directory, read afresh on each mount. */
export function ProfileList() {
  const [state, setState] = useState<State>({ status: "loading" });

  useEffect(() => {
    const controller = new AbortController();
    fetchProfiles(controller.signal)
      .then(
        (listing): State => ({ status: "loaded", listing }),
        (err: unknown): State => ({
          status: "failed",
          message: err instanceof Error ? err.message : String(err),
        }),
      )
      .then((next) => {
        if (!controller.signal.aborted) setState(next);
      });
    return () => controller.abort();
  }, []);

  return (
    <section className="screen">
      <h1>Profiles</h1>
      {state.status === "loading" && (
        <p role="status" className="note">
          Loading profiles
        </p>
      )}
      {state.status === "failed" && (
        <p role="alert" className="error">
          {state.message}
        </p>
      )}
      {state.status === "loaded" && <Rows listing={state.listing} />}
    </section>
  );
}

function Rows({ listing }: { listing: ProfileListing }) {
  if (listing.profiles.length === 0) return <p className="note">No profiles in {listing.dir}</p>;
  return (
    <ul className="profile-list">
      {listing.profiles.map((profile) =>
        "error" in profile ? (
          <li key={profile.id} className="profile profile-invalid">
            <span className="profile-name">{profile.id}</span>
            <span className="error">{profile.error}</span>
          </li>
        ) : (
          <li key={profile.id}>
            <button type="button" className="profile" onClick={() => openProfile(profile.id)}>
              <span className="profile-name">{profile.name}</span>
              <span>{profile.device}</span>
              <span className="muted">{screenFacts(profile)}</span>
              <span className="muted">{profile.has_settings ? "settings file" : "defaults"}</span>
            </button>
          </li>
        ),
      )}
    </ul>
  );
}
