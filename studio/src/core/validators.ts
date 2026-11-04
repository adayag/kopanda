// A port of the plugin's Settings.validators and their helpers (kopanda.koplugin/settings.lua:
// 16-156) over the reader's value model, so a list, a keyed table and a sparse table are judged as
// Lua judges them. spec/fixtures/studio/validator_cases.lua holds both sides to the same verdicts.
import type { Key } from "../schema.js";
import { get, listLength, LuaTable, type LuaValue } from "./lua.js";

type EntryOf<T extends Key["type"]> = Extract<Key, { type: T }>;
type LauncherEntry = EntryOf<"launcher">;

/** Whether t is a table whose keys are exactly names. */
function hasExactly(t: LuaTable, names: readonly string[]): boolean {
  return t.fields.size === names.length && names.every((name) => t.fields.has(name));
}

function isName(v: LuaValue | undefined): v is string {
  return typeof v === "string" && v !== "";
}

// The fields of each kind of launcher entry, kind first; every one but a folder's entries is a
// non-empty string.
const ENTRY_FIELDS = new Map<string, readonly string[]>([
  ["kopanda", ["kind", "target"]],
  ["koreader", ["kind", "target"]],
  ["plugin", ["kind", "plugin", "action", "label", "icon"]],
  ["action", ["kind", "action", "label", "icon"]],
  ["directory", ["kind", "path", "label"]],
  ["folder", ["kind", "label", "entries"]],
]);

/** Whether e is a launcher entry; a folder only when not inFolder, so folders don't nest. */
function isEntry(entry: LauncherEntry, e: LuaValue | undefined, inFolder: boolean): boolean {
  if (!(e instanceof LuaTable)) return false;
  const kind = get(e, "kind");
  if (typeof kind !== "string") return false;
  const fields = ENTRY_FIELDS.get(kind);
  if (!fields || (kind === "folder" && inFolder) || !hasExactly(e, fields)) return false;
  for (const field of fields.slice(1)) {
    if (field !== "entries" && !isName(get(e, field))) return false;
  }
  if (kind === "kopanda" || kind === "koreader") {
    return entry.targets[kind].includes(get(e, "target") as string);
  }
  if (kind === "directory") {
    const path = get(e, "path") as string;
    return path.startsWith("/") && path.length > 1;
  }
  if (kind === "folder") {
    const entries = get(e, "entries");
    const count = listLength(entries);
    if (!count) return false;
    for (let i = 1; i <= count; i++) {
      if (!isEntry(entry, get(entries as LuaTable, i), true)) return false;
    }
  }
  return true;
}

function inRange(v: LuaValue | undefined, low: number, high: number): boolean {
  return typeof v === "number" && v >= low && v <= high;
}

/** One validator per schema type: whether value is allowed for entry. None throws. */
export const validators: { [T in Key["type"]]: (entry: EntryOf<T>, value: LuaValue) => boolean } = {
  boolean: (_entry, value) => typeof value === "boolean",

  choice: (entry, value) => entry.choices.some((choice) => choice.value === value),

  // Exactly { name, latitude, longitude }: a non-empty name, a latitude from -90 to 90 and a
  // longitude from -180 to 180.
  location: (_entry, value) =>
    value instanceof LuaTable &&
    value.fields.size === 3 &&
    isName(get(value, "name")) &&
    inRange(get(value, "latitude"), -90, 90) &&
    inRange(get(value, "longitude"), -180, 180),

  // A list of 0 to max_entries launcher entries, each exactly the fields of its kind.
  launcher: (entry, value) => {
    const count = listLength(value);
    if (count === undefined || count > entry.max_entries) return false;
    for (let i = 1; i <= count; i++) {
      if (!isEntry(entry, get(value as LuaTable, i), false)) return false;
    }
    return true;
  },

  // false, or an absolute path: a string starting with / and longer than /.
  path: (_entry, value) => value === false || (typeof value === "string" && value.startsWith("/") && value.length > 1),
};

/** Whether value is allowed for the schema key entry, by its type's validator. */
export function validate(entry: Key, value: LuaValue): boolean {
  const validator = validators[entry.type] as (entry: Key, value: LuaValue) => boolean;
  return validator(entry, value);
}
