import { useEffect, useState } from "react";
import type { ProfileWithPath } from "../server/profiles.js";
import { ApiError, fetchProfile } from "./api";
import { screenFacts } from "./ProfileList";

type State =
  | { status: "loading" }
  | { status: "loaded"; profile: ProfileWithPath }
  | { status: "missing" }
  | { status: "failed"; message: string };

/** One profile's screen, for the profile with this id; mount it keyed by the id. */
export function ProfileScreen({ id }: { id: string }) {
  const [state, setState] = useState<State>({ status: "loading" });

  useEffect(() => {
    const controller = new AbortController();
    fetchProfile(id, controller.signal)
      .then(
        (profile): State => ({ status: "loaded", profile }),
        (err: unknown): State =>
          err instanceof ApiError && err.status === 404
            ? { status: "missing" }
            : { status: "failed", message: err instanceof Error ? err.message : String(err) },
      )
      .then((next) => {
        if (!controller.signal.aborted) setState(next);
      });
    return () => controller.abort();
  }, [id]);

  return (
    <section className="screen">
      <nav>
        <a href="#/">Profiles</a>
      </nav>
      {state.status === "loading" && (
        <p role="status" className="note">
          Loading profile
        </p>
      )}
      {state.status === "missing" && <h1>No profile {id}</h1>}
      {state.status === "failed" && (
        <p role="alert" className="error">
          {state.message}
        </p>
      )}
      {state.status === "loaded" && <Profile profile={state.profile} />}
    </section>
  );
}

function Profile({ profile }: { profile: ProfileWithPath }) {
  return (
    <>
      <h1>{profile.name}</h1>
      <dl className="facts">
        <dt>Device</dt>
        <dd>{profile.device}</dd>
        <dt>Screen</dt>
        <dd>{screenFacts(profile)}</dd>
        <dt>Settings file</dt>
        <dd>
          <code>{profile.settings_path}</code>
        </dd>
      </dl>
      {!profile.has_settings && <p className="note">All settings at their defaults</p>}
      <section className="settings" aria-label="Settings" />
    </>
  );
}
