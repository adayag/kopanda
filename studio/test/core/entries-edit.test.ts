import { describe, expect, it } from "vitest";
import fs from "node:fs";
import {
  add,
  count,
  kindLine,
  move,
  remove,
  setIcon,
  setLabel,
  type Entry,
  type Pos,
} from "../../src/core/entries-edit.js";
import { fromJson, LuaTable, parse, toJson } from "../../src/core/lua.js";
import { validate } from "../../src/core/validators.js";
import { schema, type Key } from "../../src/schema.js";

// The corpus spec/unit/studio_entries_edit_spec.lua holds the plugin's EntriesEdit to, read with the
// studio's own reader (C12).
const corpusUrl = new URL("../../../spec/fixtures/studio/entries_edit_cases.lua", import.meta.url);

interface Case {
  op: string;
  why: string;
  args: unknown[];
  result?: unknown;
  refused: boolean;
  folder_removed?: boolean;
}

function readCorpus(): Case[] {
  const result = parse(fs.readFileSync(corpusUrl));
  if (!result.ok) throw new Error(`entries_edit_cases.lua is unreadable: ${result.error}`);
  if (!(result.value instanceof LuaTable)) throw new Error("entries_edit_cases.lua returns no table");
  const cases = toJson(result.value);
  if (!Array.isArray(cases)) throw new Error("entries_edit_cases.lua returns no list");
  return cases.map((c: Record<string, unknown>) => ({
    op: String(c.op),
    why: String(c.why),
    args: c.args as unknown[],
    result: c.result,
    refused: c.refused === true,
    folder_removed: c.folder_removed as boolean | undefined,
  }));
}

const launcher = schema.keys.find((key): key is Extract<Key, { type: "launcher" }> => key.type === "launcher")!;

function expectValid(entries: Entry[]): void {
  expect(validate(launcher, fromJson(entries)), JSON.stringify(entries)).toBe(true);
}

/** The case's operation through the port: its value, and for remove whether a folder went. */
function run(c: Case): { value: unknown; folderRemoved?: boolean } {
  const [first, second, third] = c.args;
  switch (c.op) {
    case "move":
      return { value: move(first as Entry[], second as Pos, third as number) };
    case "remove": {
      const { entries, folderRemoved } = remove(first as Entry[], second as Pos);
      return { value: entries, folderRemoved };
    }
    case "add":
      return { value: add(first as Entry[], second as Entry, third as number | undefined) };
    case "count":
      return { value: count(first as Entry[]) };
    case "kind_line":
      return { value: kindLine(first as Entry) };
    default:
      throw new Error(`no operation ${c.op}`);
  }
}

const cases = readCorpus();

describe("the entry operations on the shared corpus", () => {
  it("covers every operation", () => {
    const covered = new Set(cases.map((c) => c.op));

    expect(["move", "remove", "add", "count", "kind_line"].filter((op) => !covered.has(op))).toEqual([]);
  });

  cases.forEach((c, i) => {
    it(`case ${i + 1}: ${c.op}, ${c.why}`, () => {
      const before = structuredClone(c.args);

      const { value, folderRemoved } = run(c);

      if (c.refused) expect(value).toBeNull();
      else expect(value).toEqual(c.result);
      if (c.op === "remove") expect(folderRemoved).toBe(c.folder_removed);
      if (Array.isArray(value)) expectValid(value as Entry[]);
      expect(c.args).toEqual(before);
    });
  });
});

const PLUGIN: Entry = { kind: "plugin", plugin: "calibre", action: "search", label: "Calibre", icon: "action" };
const ACTION: Entry = { kind: "action", action: "history", label: "History", icon: "action" };
const DIRECTORY: Entry = { kind: "directory", path: "/mnt/us/books", label: "books" };
const KOPANDA: Entry = { kind: "kopanda", target: "library" };
const KOREADER: Entry = { kind: "koreader", target: "wifi" };
const FOLDER: Entry = { kind: "folder", label: "Tools", entries: [ACTION, DIRECTORY] };

/** op on a copy of entries, checked to leave entries as they were; its result. */
function unchanged<T>(entries: Entry[], op: (entries: Entry[]) => T): T {
  const before = structuredClone(entries);
  const result = op(entries);
  expect(entries).toEqual(before);
  return result;
}

describe("setLabel", () => {
  it.each([PLUGIN, ACTION, DIRECTORY, FOLDER])("changes only the label of a $kind entry", (entry) => {
    const entries = [KOPANDA, entry];

    const result = unchanged(entries, (e) => setLabel(e, [2], "Renamed"));

    expect(result).toEqual([KOPANDA, { ...entry, label: "Renamed" }]);
    expectValid(result!);
  });

  it("changes a folder's entry, keeping the label as trimmed", () => {
    const entries = [KOPANDA, FOLDER];

    const result = unchanged(entries, (e) => setLabel(e, [2, 2], "  My books  "));

    expect(result).toEqual([KOPANDA, { ...FOLDER, entries: [ACTION, { ...DIRECTORY, label: "My books" }] }]);
    expectValid(result!);
  });

  it("keeps quotes, backslashes and non-ASCII text as typed", () => {
    const label = 'Say "hi" \\ Café “quoted”';

    expect(setLabel([ACTION], [1], label)).toEqual([{ ...ACTION, label }]);
  });

  it("trims only the whitespace Lua's %s matches, as util.trim does", () => {
    expect(setLabel([ACTION], [1], " Books \v")).toEqual([{ ...ACTION, label: " Books" }]);
  });

  it.each([KOPANDA, KOREADER])("refuses a $kind entry, which has no label", (entry) => {
    expect(unchanged([entry], (e) => setLabel(e, [1], "Renamed"))).toBeNull();
  });

  it.each(["", "   ", "\t\n"])("refuses the label %j, empty after trimming", (label) => {
    expect(unchanged([ACTION], (e) => setLabel(e, [1], label))).toBeNull();
  });
});

describe("setIcon", () => {
  it.each([PLUGIN, ACTION])("changes only the icon of a $kind entry", (entry) => {
    const entries = [KOPANDA, entry];

    const result = unchanged(entries, (e) => setIcon(e, [2], "sun"));

    expect(result).toEqual([KOPANDA, { ...entry, icon: "sun" }]);
    expectValid(result!);
  });

  it("changes a folder's action entry", () => {
    const entries = [FOLDER];

    const result = unchanged(entries, (e) => setIcon(e, [1, 1], "moon"));

    expect(result).toEqual([{ ...FOLDER, entries: [{ ...ACTION, icon: "moon" }, DIRECTORY] }]);
  });

  it.each([KOPANDA, KOREADER, DIRECTORY, FOLDER])("refuses a $kind entry, whose icon is fixed", (entry) => {
    expect(unchanged([entry], (e) => setIcon(e, [1], "sun"))).toBeNull();
  });
});
