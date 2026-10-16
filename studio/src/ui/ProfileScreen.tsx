import { useEffect, useRef, useState } from "react";
import type { Key } from "../schema";
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

function without(record: Readonly<Record<string, string>>, key: string): Record<string, string> {
  const rest = { ...record };
  delete rest[key];
  return rest;
}

/** One profile's screen, for the profile with this id, with its settings; mount it keyed by the id. */
export function ProfileScreen({ id, view = "form" }: { id: string; view?: ProfileView }) {
  const [state, setState] = useState<State>({ status: "loading" });
  const [pending, setPending] = useState<ReadonlySet<string>>(() => new Set());
  const [errors, setErrors] = useState<Readonly<Record<string, string>>>({});
  const writes = useRef<Promise<unknown>>(Promise.resolve());

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

  /**
   * One PUT, sent once every earlier write and its refetch has settled, so answers land in order; its
   * answer becomes the settings shown. A failure puts its line beside the key and reads the file again.
   * The key stays in flight until then; resolves true once written, false when refused.
   */
  function write(entry: Key, value: unknown): Promise<boolean> {
    setPending((keys) => new Set(keys).add(entry.id));
    setErrors((all) => without(all, entry.id));
    const written = writes.current.then(async () => {
      try {
        showSettings(await putSetting(id, entry.id, value));
        return true;
      } catch (err) {
        const reason = err instanceof Error ? err.message : String(err);
        setErrors((all) => ({ ...all, [entry.id]: `Couldn't save ${entry.label}: ${reason}.` }));
        await fetchSettings(id).then(showSettings, () => undefined);
        return false;
      } finally {
        setPending((keys) => {
          const next = new Set(keys);
          next.delete(entry.id);
          return next;
        });
      }
    });
    writes.current = written.catch(() => undefined);
    return written;
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
              <SettingsForm
                profileId={id}
                settings={state.settings}
                pending={pending}
                errors={errors}
                onWrite={write}
              />
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
