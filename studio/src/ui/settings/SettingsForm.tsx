import { useId, type ComponentType } from "react";
import { schema as studioSchema, type Key, type Schema } from "../../schema";
import type { Settings } from "../api";
import { profileHref } from "../ProfileList";
import { BooleanControl } from "./controls/BooleanControl";
import { ChoiceControl } from "./controls/ChoiceControl";
import type { ControlProps } from "./controls/Field";
import { LauncherControl } from "./controls/LauncherControl";
import { LocationControl } from "./controls/LocationControl";
import { PathControl } from "./controls/PathControl";
import { RowsControl } from "./controls/RowsControl";

const CONTROLS: { [T in Key["type"]]: ComponentType<ControlProps<Extract<Key, { type: T }>>> } = {
  choice: ChoiceControl,
  boolean: BooleanControl,
  path: PathControl,
  location: LocationControl,
  rows: RowsControl,
  launcher: LauncherControl,
};

/** The control for a key's type; undefined for a type the table lacks, which only a test's schema has. */
function controlFor(type: string): ComponentType<ControlProps<Key>> | undefined {
  return (CONTROLS as Partial<Record<string, ComponentType<ControlProps<Key>>>>)[type];
}

/** The schema's keys in runs of one group, in order. */
function groups(keys: readonly Key[]): { id: string; keys: Key[] }[] {
  const runs: { id: string; keys: Key[] }[] = [];
  for (const entry of keys) {
    const last = runs.at(-1);
    if (last?.id === entry.group) last.keys.push(entry);
    else runs.push({ id: entry.group, keys: [entry] });
  }
  return runs;
}

function capitalised(id: string): string {
  return id.charAt(0).toUpperCase() + id.slice(1);
}

export interface SettingsFormProps {
  /** The schema the form is generated from; a test hands its own. */
  schema?: Schema;
  /** The open profile's id, for the editor routes. */
  profileId: string;
  /** The profile's settings file as the API answered it. */
  settings: Settings;
  /** The keys whose writes are in flight; their controls are disabled. */
  pending: ReadonlySet<string>;
  /** The failure line of each key's last write, beside its control. */
  errors: Readonly<Record<string, string>>;
  /** Writes one key; resolves true once written, false when refused. */
  onWrite: (entry: Key, value: unknown) => Promise<boolean>;
}

/**
 * One control per schema key, in schema order under its group's heading, with the file's reports: a
 * read-only or unreadable file above the form, refused stored values beside their controls, keys
 * outside the schema after it. A key's control is disabled while its write is pending.
 */
export function SettingsForm({
  schema = studioSchema,
  profileId,
  settings,
  pending,
  errors,
  onWrite,
}: SettingsFormProps) {
  const unknownId = useId();
  const writable = settings.state === "writable";
  const invalid = new Set(settings.invalid.map(({ key }) => key));
  const href = profileHref(profileId);

  function control(entry: Key) {
    const Control = controlFor(entry.type);
    if (Control === undefined) {
      return (
        <p key={entry.id} className="note">
          No control for {entry.type} ({entry.id}).
        </p>
      );
    }
    const error = errors[entry.id];
    const notes = (
      <>
        {invalid.has(entry.id) && <p className="note">The stored value isn't allowed, so this shows the default.</p>}
        {error !== undefined && (
          <p role="alert" className="error">
            {error}
          </p>
        )}
      </>
    );
    return (
      <Control
        key={entry.id}
        entry={entry}
        value={entry.id in settings.values ? settings.values[entry.id] : entry.default}
        disabled={!writable || pending.has(entry.id)}
        write={(value) => onWrite(entry, value)}
        profileHref={href}
        notes={notes}
      />
    );
  }

  return (
    <div className="settings-form">
      {settings.state === "read_only" && (
        <p className="error">
          This settings file is from schema version {settings.schema_version}, newer than this studio's{" "}
          {schema.version}, so it is shown and not written.
        </p>
      )}
      {settings.state === "unreadable" && (
        <p className="error">The studio can't read this settings file: {settings.reason}</p>
      )}
      {groups(schema.keys).map((group) => (
        <section key={group.id} className="setting-group">
          <h2>{capitalised(group.id)}</h2>
          {group.keys.map(control)}
        </section>
      ))}
      {settings.unknown.length > 0 && (
        <section className="setting-group" aria-labelledby={unknownId}>
          <h2 id={unknownId}>Not in the schema</h2>
          <p className="note">Kept as they are when the studio writes.</p>
          <dl className="unknown">
            {settings.unknown.map(({ key, text }) => (
              <div key={`${typeof key}:${key}`}>
                <dt>
                  <code>{key}</code>
                </dt>
                <dd>
                  <pre>{text}</pre>
                </dd>
              </div>
            ))}
          </dl>
        </section>
      )}
    </div>
  );
}
