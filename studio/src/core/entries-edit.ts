// A port of the plugin's EntriesEdit (kopanda.koplugin/entries_edit.lua): the launcher's list
// operations on a launcher.entries value, each pure, working on a deep copy and returning it, the
// input left unchanged. spec/fixtures/studio/entries_edit_cases.lua holds both sides to the same
// results. setLabel and setIcon are the studio's own (decision S3); the device edits neither.
import { schema, type Key } from "../schema.js";

type LauncherKey = Extract<Key, { type: "launcher" }>;

/** A launcher entry, of one of the kinds kopanda.koplugin/settings.lua:84-91 lists. */
export type Entry = LauncherKey["default"][number];
/** A folder's entry: any kind but a folder, since folders don't nest. */
export type FolderEntry = Exclude<Entry, { kind: "folder" }>;

/**
 * A position, 1-based as on the device: [i] at the top level, or [f, i] inside the folder at
 * top-level index f.
 */
export type Pos = readonly [number] | readonly [number, number];

const launcher = schema.keys.find((key): key is LauncherKey => key.type === "launcher");
if (!launcher) throw new Error("the schema has no launcher key");

/** The most the top level holds (schema.lua's max_entries). */
export const maxEntries = launcher.max_entries;

/** The copy of entries and, in it, the list pos names and the entry's 0-based index there. */
function locate(entries: readonly Entry[], pos: Pos): { copy: Entry[]; list: Entry[]; at: number } {
  const copy = structuredClone(entries) as Entry[];
  if (pos.length === 1) return { copy, list: copy, at: pos[0] - 1 };
  const folder = copy[pos[0] - 1];
  if (folder?.kind !== "folder") throw new Error(`no folder at ${pos[0]}`);
  return { copy, list: folder.entries, at: pos[1] - 1 };
}

/** entries with the entry at pos moved by delta within its list; null when that passes an end. */
export function move(entries: readonly Entry[], pos: Pos, delta: number): Entry[] | null {
  const { copy, list, at } = locate(entries, pos);
  const to = at + delta;
  if (to < 0 || to >= list.length) return null;
  const [entry] = list.splice(at, 1);
  list.splice(to, 0, entry!);
  return copy;
}

/**
 * entries without the entry at pos, a folder with its entries, and whether a folder went with it: a
 * folder holds one entry or more, so removing its only entry removes the folder.
 */
export function remove(entries: readonly Entry[], pos: Pos): { entries: Entry[]; folderRemoved: boolean } {
  const { copy, list, at } = locate(entries, pos);
  list.splice(at, 1);
  if (pos.length === 2 && list.length === 0) {
    copy.splice(pos[0] - 1, 1);
    return { entries: copy, folderRemoved: true };
  }
  return { entries: copy, folderRemoved: false };
}

/**
 * entries with entry added (decision D3): into the folder at top-level index f, at its end; else at
 * the end of a top level under maxEntries; else at the end of the first top-level folder; else the
 * last entry and the new one become a folder labelled More in its place. Folders don't nest, so a
 * folder entry is never added: null.
 */
export function add(entries: readonly Entry[], entry: Entry, f?: number): Entry[] | null {
  if (entry.kind === "folder") return null;
  const copy = structuredClone(entries) as Entry[];
  const added = structuredClone(entry);
  if (f !== undefined) {
    const folder = copy[f - 1];
    if (folder?.kind !== "folder") throw new Error(`no folder at ${f}`);
    folder.entries.push(added);
    return copy;
  }
  if (copy.length < maxEntries) {
    copy.push(added);
    return copy;
  }
  const first = copy.find((e) => e.kind === "folder");
  if (first) {
    first.entries.push(added);
    return copy;
  }
  const last = copy[maxEntries - 1] as FolderEntry;
  copy[maxEntries - 1] = { kind: "folder", label: "More", entries: [last, added] };
  return copy;
}

/** The top level's length. */
export function count(entries: readonly Entry[]): number {
  return entries.length;
}

/** The entry's kind line, "<kind> · <detail>"; a folder's is "Folder · N entries ›". */
export function kindLine(entry: Entry): string {
  switch (entry.kind) {
    case "kopanda":
      return `KoPanda · ${entry.target}`;
    case "koreader":
      return `KOReader · ${entry.target}`;
    case "plugin":
      return `Plugin · ${entry.plugin}`;
    case "action":
      return `Action · ${entry.action}`;
    case "directory":
      return `Folder on disk · ${entry.path}`;
    case "folder": {
      const n = entry.entries.length;
      return n === 1 ? `Folder · ${n} entry ›` : `Folder · ${n} entries ›`;
    }
  }
}

/** Whether the entry has a label of its own: plugin, action, directory and folder entries do. */
export function hasLabel(entry: Entry): entry is Extract<Entry, { label: string }> {
  return entry.kind !== "kopanda" && entry.kind !== "koreader";
}

/** Whether the entry's icon is its own: plugin and action entries; the others draw a fixed one. */
export function hasIcon(entry: Entry): entry is Extract<Entry, { icon: string }> {
  return entry.kind === "plugin" || entry.kind === "action";
}

/**
 * label without the leading and trailing whitespace Lua's %s matches (space, \t, \n, \v, \f, \r),
 * as KOReader's util.trim (frontend/util.lua:52-55) leaves it.
 */
export function trim(label: string): string {
  return label.replace(/^[ \t\n\v\f\r]+|[ \t\n\v\f\r]+$/g, "");
}

/**
 * entries with the label of the entry at pos replaced by label trimmed, as the device stores a
 * label it is given (kopanda.koplugin/entry_picker.lua's ask_label); null for an entry with no
 * label, or a label empty after trimming.
 */
export function setLabel(entries: readonly Entry[], pos: Pos, label: string): Entry[] | null {
  const trimmed = trim(label);
  const { copy, list, at } = locate(entries, pos);
  const entry = list[at]!;
  if (trimmed === "" || !hasLabel(entry)) return null;
  entry.label = trimmed;
  return copy;
}

/** entries with the icon of the action or plugin entry at pos replaced; null for any other kind. */
export function setIcon(entries: readonly Entry[], pos: Pos, icon: string): Entry[] | null {
  const { copy, list, at } = locate(entries, pos);
  const entry = list[at]!;
  if (!hasIcon(entry)) return null;
  entry.icon = icon;
  return copy;
}
