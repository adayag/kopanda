import { useEffect, useState } from "react";
import type { ProfileWithPath } from "../server/profiles.js";
import { ApiError, fetchProfile, fetchSettings, putSetting, type Settings } from "./api";
import { profileHref, screenFacts } from "./ProfileList";
import { SettingsForm } from "./settings/SettingsForm";

/** What the profile's screen shows under its facts: the form or one of the editors. */
export type ProfileView = "form" | "layout" | "launcher";

type State =
  | { status: "loading" }
  | { status: "loaded"; profile: ProfileWithPath; settings: Settings }
  | { status: "missing" }
  | { status: "failed"; message: string };

async function load(id: string, signal: AbortSignal): Promise<State> {
  try {
    const profile = await fetchProfile(id, signal);
    const settings = await fetchSettings(id, signal);
    return { status: "loaded", profile, settings };
  } catch (err) {
    return err instanceof ApiError && err.status === 404
      ? { status: "missing" }
      : { status: "failed", message: err instanceof Error ? err.message : String(err) };
  }
}

/** One profile's screen, for the profile with this id, with its settings; mount it keyed by the id. */
export function ProfileScreen({ id, view = "form" }: { id: string; view?: ProfileView }) {
  const [state, setState] = useState<State>({ status: "loading" });

  useEffect(() => {
    const controller = new AbortController();
    void load(id, controller.signal).then((next) => {
      if (!controller.signal.aborted) setState(next);
    });
    return () => controller.abort();
  }, [id]);

  function showSettings(settings: Settings): void {
    setState((current) => (current.status === "loaded" ? { ...current, settings } : current));
  }

  /** One PUT; its answer becomes the settings shown. A failure reads the file again, then rejects. */
  async function write(key: string, value: unknown): Promise<void> {
    try {
      showSettings(await putSetting(id, key, value));
    } catch (err) {
      fetchSettings(id).then(showSettings, () => undefined);
      throw err;
    }
  }

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
      {state.status === "loaded" && (
        <>
          <Profile profile={state.profile} settings={state.settings} />
          <section className="settings" aria-label="Settings">
            {view === "form" ? (
              <SettingsForm profileId={id} settings={state.settings} onWrite={write} />
            ) : (
              <EditorSlot id={id} title={view === "layout" ? "Layout" : "Launcher"} />
            )}
          </section>
        </>
      )}
    </section>
  );
}

function Profile({ profile, settings }: { profile: ProfileWithPath; settings: Settings }) {
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
      {!settings.exists && <p className="note">All settings at their defaults</p>}
    </>
  );
}

/** Where an editor opens: its heading and Done back to the form. */
function EditorSlot({ id, title }: { id: string; title: string }) {
  return (
    <header className="editor-head">
      <h2>{title}</h2>
      <a className="editor-link" href={profileHref(id)}>
        Done
      </a>
    </header>
  );
}
