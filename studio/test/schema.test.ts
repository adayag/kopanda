import { describe, expect, it } from "vitest";
import fs from "node:fs";
import { z } from "zod";
import { Schema, schema } from "../src/schema.js";

function readCheckedIn(): { keys: { id: string; type: string }[] } {
  return JSON.parse(fs.readFileSync(new URL("../src/schema.json", import.meta.url), "utf8"));
}

describe("the schema type", () => {
  it("accepts the checked-in schema.json", () => {
    const result = Schema.safeParse(readCheckedIn());

    expect(result.error).toBeUndefined();
  });

  it("rejects a key of a type the studio does not declare, naming the key's index", () => {
    const copy = readCheckedIn();
    const index = copy.keys.findIndex((key) => key.id === "stats.show");
    copy.keys[index]!.type = "slider";

    const result = Schema.safeParse(copy);

    expect(result.success).toBe(false);
    expect(z.prettifyError(result.error!)).toContain(`keys[${index}]`);
  });
});

describe("schema", () => {
  it("is the checked-in schema.json, nothing dropped", () => {
    expect(schema).toEqual(readCheckedIn());
  });
});
