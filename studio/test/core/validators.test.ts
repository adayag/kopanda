import { describe, expect, it } from "vitest";
import fs from "node:fs";
import { get, LuaTable, parse } from "../../src/core/lua.js";
import { validate } from "../../src/core/validators.js";
import { schema } from "../../src/schema.js";

// The corpus spec/unit/studio_validators_spec.lua holds the plugin's validators to, read with the
// studio's own reader.
const corpusUrl = new URL("../../../spec/fixtures/studio/validator_cases.lua", import.meta.url);

function readCorpus() {
  const result = parse(fs.readFileSync(corpusUrl));
  if (!result.ok) throw new Error(`validator_cases.lua is unreadable: ${result.error}`);
  if (!(result.value instanceof LuaTable)) throw new Error("validator_cases.lua returns no table");
  return [...result.value.fields.values()].map((item) => {
    if (!(item instanceof LuaTable)) throw new Error("a case is not a table");
    const value = get(item, "value");
    if (value === undefined) throw new Error("a case has no value");
    return {
      key: String(get(item, "key")),
      value,
      valid: get(item, "valid") === true,
      why: String(get(item, "why")),
    };
  });
}

const cases = readCorpus();

describe("validate on the shared corpus", () => {
  it("covers every schema key", () => {
    const covered = new Set(cases.map((c) => c.key));

    expect(schema.keys.map((key) => key.id).filter((id) => !covered.has(id))).toEqual([]);
  });

  cases.forEach((c, i) => {
    it(`case ${i + 1}: ${c.key}, ${c.why}`, () => {
      const entry = schema.keys.find((key) => key.id === c.key);
      if (!entry) throw new Error(`no schema key ${c.key}`);

      expect(validate(entry, c.value), `${c.key}, ${c.why}`).toBe(c.valid);
    });
  });
});

describe("schema.version", () => {
  it("is 1", () => {
    expect(
      schema.version,
      "the studio reads only files at the schema's version: port migrations.lua's steps before raising it",
    ).toBe(1);
  });
});
