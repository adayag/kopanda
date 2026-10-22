import { describe, expect, it } from "vitest";
import fs from "node:fs";
import { fromJson, parse, toJson } from "../../src/core/lua.js";
import {
  addColumn,
  addRow,
  caption,
  changeWidget,
  entry,
  entryFor,
  label,
  move,
  removeColumn,
  removeRow,
  reset,
  setShare,
  shareText,
  unused,
} from "../../src/core/rows-edit.js";
import { validate } from "../../src/core/validators.js";

// The corpus spec/unit/studio_rows_edit_spec.lua holds the plugin's RowsEdit to, read with the
// studio's own reader.
const corpusUrl = new URL("../../../spec/fixtures/studio/rows_edit_cases.lua", import.meta.url);

interface Case {
  op: string;
  args: unknown[];
  result?: unknown;
  refused?: string | true;
}

function readCorpus(): Case[] {
  const result = parse(fs.readFileSync(corpusUrl));
  if (!result.ok) throw new Error(`rows_edit_cases.lua is unreadable: ${result.error}`);
  const cases = toJson(result.value);
  if (!Array.isArray(cases)) throw new Error("rows_edit_cases.lua returns no list");
  return cases as Case[];
}

// The plugin's names for the port's functions; the row operations answer { rows } or { refused }.
const EDITS: Record<string, (...args: never[]) => unknown> = {
  move,
  add_row: addRow,
  add_column: addColumn,
  change_widget: changeWidget,
  set_share: setShare,
  remove_column: removeColumn,
  remove_row: removeRow,
  reset,
};
const QUERIES: Record<string, (...args: never[]) => unknown> = {
  unused,
  label,
  share_text: shareText,
  caption,
};

const cases = readCorpus();

/** Every object and array inside value, value included. */
function objects(value: unknown, into = new Set<object>()): Set<object> {
  if (typeof value === "object" && value !== null) {
    into.add(value);
    for (const item of Object.values(value)) objects(item, into);
  }
  return into;
}

describe("the row operations on the shared corpus", () => {
  it("covers every operation", () => {
    const covered = new Set(cases.map((c) => c.op));

    expect([...Object.keys(EDITS), ...Object.keys(QUERIES)].filter((op) => !covered.has(op))).toEqual([]);
  });

  cases.forEach((c, i) => {
    it(`case ${i + 1}: ${c.op}`, () => {
      const op = EDITS[c.op] ?? QUERIES[c.op];
      if (!op) throw new Error(`no operation ${c.op}`);
      const before = structuredClone(c.args);

      const out = op(...(c.args as never[]));

      expect(c.args, "the input changed").toEqual(before);
      if (c.refused !== undefined) {
        expect(out).toEqual({ refused: c.refused === true ? null : c.refused });
      } else if (c.op in EDITS) {
        expect(out).toEqual({ rows: c.result });
        const rows = (out as { rows: unknown }).rows;
        expect(validate(entry, fromJson(rows)), "the validator refuses the result").toBe(true);
        const inputs = objects(c.args);
        expect([...objects(rows)].filter((o) => inputs.has(o)), "the result shares a table with its input").toEqual(
          [],
        );
      } else {
        expect(out).toEqual(c.result);
      }
    });
  });
});

describe("reset", () => {
  it("answers a fresh copy each time, never the schema's own default", () => {
    const first = reset();
    if (!("rows" in first)) throw new Error("reset refused");
    first.rows[0]![0]!.share = 3;

    expect(reset()).toEqual({ rows: entry.default });
    expect(entry.default[0]![0]!.share).toBe(1);
  });
});

describe("entryFor", () => {
  it("answers each rows key's schema entry, layout.rows's being entry", () => {
    expect(entryFor("layout.rows")).toBe(entry);
    const page2 = entryFor("layout.rows_2");

    expect(page2.id).toBe("layout.rows_2");
    expect(page2.label).toBe("Page 2");
    expect(page2.default).toHaveLength(4);
  });

  it.each(["look", "layout.rows_3"])("throws for %s, which is no rows key", (id) => {
    expect(() => entryFor(id)).toThrow(id);
  });
});

describe("reset and unused for another rows key", () => {
  const page2 = entryFor("layout.rows_2");

  it("resets to that key's default, a fresh copy", () => {
    const first = reset(page2);
    if (!("rows" in first)) throw new Error("reset refused");
    first.rows[0]![0]!.share = 3;

    expect(reset(page2)).toEqual({ rows: page2.default });
    expect(page2.default).not.toEqual(entry.default);
  });

  it("lists that key's widgets not on the page", () => {
    const narrow = { ...page2, widgets: ["date", "heatmap", "records"] };

    expect(unused([[{ widget: "heatmap", share: 1 }]], narrow)).toEqual(["date", "records"]);
  });
});
