import { randomBytes } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import {
  dump,
  fromJson,
  get,
  LuaTable,
  orderedKeys,
  parse,
  serialize,
  toJson,
  type LuaKey,
  type LuaValue,
} from "../core/lua.js";
import { validate } from "../core/validators.js";
import { schema, type Key } from "../schema.js";

// A profile's settings/kopanda/settings.lua, read and written as the plugin's Settings does
// (kopanda.koplugin/settings.lua:256-350): a stored value its validator refuses reads as the
// default, a key outside the schema is kept, a file from a newer schema is read but not written.

export type SettingsState = "writable" | "read_only" | "unreadable";

export interface SettingsRead {
  exists: boolean;
  state: SettingsState;
  /** Why the file is read-only or unreadable. */
  reason?: string;
  /** The file's schema version; null when unreadable. */
  schemaVersion: number | null;
  /** Every schema key's value as JSON, in schema order: the stored one when valid, else the default. */
  values: Record<string, unknown>;
  /** Stored values their validator refuses. */
  invalid: { key: string }[];
  /** Stored keys outside the schema, with their value as the writer writes it. */
  unknown: { key: LuaKey; text: string }[];
  /** The table the file returns; undefined when missing or unreadable. */
  stored?: LuaTable;
}

/** Why writeSetting refused, which the API answers 404, 400 and 409 for. */
export class SettingsWriteError extends Error {
  constructor(
    readonly reason: "unknown_key" | "invalid_value" | "not_writable",
    message: string,
  ) {
    super(message);
    this.name = "SettingsWriteError";
  }
}

const entries = new Map(schema.keys.map((entry) => [entry.id, entry]));

function defaults(): Record<string, unknown> {
  return Object.fromEntries(schema.keys.map((entry) => [entry.id, entry.default]));
}

function unreadable(exists: boolean, reason: string): SettingsRead {
  return { exists, state: "unreadable", reason, schemaVersion: null, values: defaults(), invalid: [], unknown: [] };
}

function errorCode(err: unknown): unknown {
  return typeof err === "object" && err !== null ? (err as { code?: unknown }).code : undefined;
}

function luaType(value: LuaValue): string {
  return value instanceof LuaTable ? "table" : typeof value;
}

/**
 * The settings file at file by the plugin's rules: missing reads every key at its default and is
 * writable; schema_version absent, false or the schema's is writable; a number above the schema's
 * is read-only; anything else, or a file outside the reader's subset or returning no table, is
 * unreadable with every key at its default.
 */
export async function readSettings(file: string): Promise<SettingsRead> {
  let bytes: Uint8Array;
  try {
    bytes = await fs.readFile(file);
  } catch (err) {
    if (errorCode(err) === "ENOENT") {
      return { exists: false, state: "writable", schemaVersion: schema.version, values: defaults(), invalid: [], unknown: [] };
    }
    return unreadable(true, `the file can't be read: ${(err as Error).message}`);
  }
  const parsed = parse(bytes);
  if (!parsed.ok) return unreadable(true, parsed.error);
  const stored = parsed.value;
  if (!(stored instanceof LuaTable)) return unreadable(true, `the file returns a ${luaType(stored)}, not a table`);

  const version = get(stored, "schema_version") ?? false;
  let state: SettingsState = "writable";
  let reason: string | undefined;
  let schemaVersion = schema.version;
  if (typeof version === "number" && version > schema.version) {
    state = "read_only";
    schemaVersion = version;
    reason = `the file is from schema version ${dump(version)}, newer than this studio's ${schema.version}`;
  } else if (version !== false && version !== schema.version) {
    return unreadable(true, `schema_version ${dump(version)} is not a version the plugin reads`);
  }

  const values = defaults();
  const invalid: { key: string }[] = [];
  for (const entry of schema.keys) {
    const value = get(stored, entry.id);
    if (value === undefined) continue;
    if (validate(entry, value)) {
      values[entry.id] = toJson(value);
    } else {
      invalid.push({ key: entry.id });
    }
  }
  const unknown: { key: LuaKey; text: string }[] = [];
  for (const key of orderedKeys(stored)) {
    if (key === "schema_version" || (typeof key === "string" && entries.has(key))) continue;
    unknown.push({ key, text: dump(stored.fields.get(key)!) });
  }
  return { exists: true, state, reason, schemaVersion, values, invalid, unknown, stored };
}

// Writes to one file, one at a time: the promise each next write waits for.
const queues = new Map<string, Promise<unknown>>();

function queued<T>(file: string, run: () => Promise<T>): Promise<T> {
  const previous = queues.get(file) ?? Promise.resolve();
  const next = previous.then(run, run);
  const settled = next.catch(() => undefined);
  queues.set(file, settled);
  void settled.then(() => {
    if (queues.get(file) === settled) queues.delete(file);
  });
  return next;
}

/** Writes text to file through a temporary file in its directory renamed over it. */
async function replaceFile(file: string, text: string): Promise<void> {
  const temporary = `${file}.tmp-${process.pid}-${randomBytes(6).toString("hex")}`;
  try {
    const handle = await fs.open(temporary, "wx");
    try {
      await handle.writeFile(text);
      await handle.sync();
    } finally {
      await handle.close();
    }
    await fs.rename(temporary, file);
  } catch (err) {
    await fs.rm(temporary, { force: true });
    throw err;
  }
}

/**
 * Stores value (JSON) under key and schema_version in the file at file, keeping every other stored
 * key as it was, and returns the file as read after. Refuses with a SettingsWriteError, writing
 * nothing, a key outside the schema, a value its validator refuses and a file that isn't writable.
 */
export async function writeSetting(file: string, key: string, value: unknown): Promise<SettingsRead> {
  const entry: Key | undefined = entries.get(key);
  if (!entry) throw new SettingsWriteError("unknown_key", `no setting named ${key}`);
  let lua: LuaValue | undefined;
  try {
    lua = fromJson(value);
  } catch {
    lua = undefined;
  }
  if (lua === undefined || !validate(entry, lua)) {
    throw new SettingsWriteError("invalid_value", `${JSON.stringify(value) ?? "no value"} is not allowed for ${key}`);
  }
  const absolute = path.resolve(file);
  return queued(absolute, async () => {
    const current = await readSettings(absolute);
    if (current.state !== "writable") {
      throw new SettingsWriteError("not_writable", `the settings file is not written: ${current.reason}`);
    }
    const data = current.stored ?? new LuaTable();
    data.fields.set(key, lua);
    data.fields.set("schema_version", schema.version);
    await fs.mkdir(path.dirname(absolute), { recursive: true });
    await replaceFile(absolute, serialize(data, absolute));
    return readSettings(absolute);
  });
}
