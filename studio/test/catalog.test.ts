import { describe, expect, it } from "vitest";
import fs from "node:fs";
import { z } from "zod";
import { Catalog, catalog } from "../src/catalog.js";

type Section = { title: string; actions: { id?: string; title: string }[] };

function readCheckedIn(): { actions: Section[] } {
  return JSON.parse(fs.readFileSync(new URL("../src/catalog.json", import.meta.url), "utf8"));
}

describe("the catalog type", () => {
  it("accepts the checked-in catalog.json", () => {
    const result = Catalog.safeParse(readCheckedIn());

    expect(result.error).toBeUndefined();
  });

  it("rejects an action missing its id, naming it", () => {
    const copy = readCheckedIn();
    const index = copy.actions[1]!.actions.findIndex((action) => action.id === "toggle_wifi");
    delete copy.actions[1]!.actions[index]!.id;

    const result = Catalog.safeParse(copy);

    expect(result.success).toBe(false);
    expect(z.prettifyError(result.error!)).toContain(`actions[1].actions[${index}].id`);
  });
});

describe("catalog", () => {
  it("is the checked-in catalog.json, nothing dropped", () => {
    expect(catalog).toEqual(readCheckedIn());
  });
});
