import { useState } from "react";
import { add, count, maxEntries, type Entry } from "../../core/entries-edit";
import { schema, type Key } from "../../schema";
import type { Settings } from "../api";
import { profileHref } from "../ProfileList";
import { AddEntry } from "./AddEntry";
import { EntryRow } from "./EntryRow";

type LauncherKey = Extract<Key, { type: "launcher" }>;
type Folder = Extract<Entry, { kind: "folder" }>;

const launcher = schema.keys.find((key): key is LauncherKey => key.type === "launcher")!;

export interface LauncherEditorProps {
  /** The open profile's id, for Done. */
  profileId: string;
  /** The profile's settings file as the API answered it; the launcher is its launcher.entries. */
  settings: Settings;
  /** The keys whose writes are in flight; while launcher.entries' is, every control is disabled. */
  pending: ReadonlySet<string>;
  /** The failure line of each key's last write. */
  errors: Readonly<Record<string, string>>;
  /** Writes one key; resolves true once written, false when refused. */
  onWrite: (entry: Key, value: unknown) => Promise<boolean>;
}

/**
 * The launcher editor (kopanda.koplugin/launcher_manage.lua's screen): the top level headed "N of 6
 * on the home screen" over "Launcher", or one folder's list headed "Folder · N" over its label, a row
 * per entry and the add flows. Every change is one write of launcher.entries, whose answer the editor
 * shows; a read-only or unreadable file disables every control.
 */
export function LauncherEditor({ profileId, settings, pending, errors, onWrite }: LauncherEditorProps) {
  const [folder, setFolder] = useState<number | null>(null);
  const entries = (settings.values[launcher.id] ?? launcher.default) as Entry[];
  const disabled = settings.state !== "writable" || pending.has(launcher.id);
  const at = folder === null ? undefined : entries[folder - 1];
  const open: Folder | null = at?.kind === "folder" ? at : null;
  const list = open ? open.entries : entries;
  const error = errors[launcher.id];

  async function apply(next: Entry[] | null, folderRemoved = false): Promise<boolean> {
    if (next === null) return false;
    const written = await onWrite(launcher, next);
    if (written && folderRemoved) setFolder(null);
    return written;
  }

  return (
    <div className="launcher-editor">
      {settings.state === "read_only" && (
        <p className="error">
          This settings file is from schema version {settings.schema_version}, newer than this studio's{" "}
          {schema.version}, so it is shown and not written.
        </p>
      )}
      {settings.state === "unreadable" && (
        <p className="error">The studio can't read this settings file: {settings.reason}</p>
      )}
      <header className="editor-head">
        <div>
          <p className="editor-aside">
            {open ? `Folder · ${open.entries.length}` : `${count(entries)} of ${maxEntries} on the home screen`}
          </p>
          <h2>{open ? open.label : "Launcher"}</h2>
        </div>
        {open ? (
          <button type="button" className="editor-link" onClick={() => setFolder(null)}>
            Done
          </button>
        ) : (
          <a className="editor-link" href={profileHref(profileId)}>
            Done
          </a>
        )}
      </header>
      {settings.invalid.some(({ key }) => key === launcher.id) && (
        <p className="note">The stored value isn't allowed, so this shows the default.</p>
      )}
      {error !== undefined && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
      <ol className="entries" aria-label="Entries">
        {list.map((entry, i) => (
          <EntryRow
            // A change to the entry at a slot remounts its row, closing any panel opened on the entry before.
            key={`${open ? folder : 0}:${i}:${JSON.stringify(entry)}`}
            entries={entries}
            pos={open ? [folder!, i + 1] : [i + 1]}
            length={list.length}
            disabled={disabled}
            apply={apply}
            onOpen={() => setFolder(i + 1)}
          />
        ))}
      </ol>
      <AddEntry
        key={open ? folder : 0}
        inFolder={open !== null}
        disabled={disabled}
        onAdd={(entry) => apply(add(entries, entry, open ? folder! : undefined))}
      />
    </div>
  );
}
