import { describe, expect, it } from "vitest";
import fs from "node:fs";
import { fromJson, get, serialize, table, toJson } from "../../src/core/lua.js";
import { validate } from "../../src/core/validators.js";
import { schema } from "../../src/schema.js";

// The round trip's data set (C1): every schema key at a valid value other than its default but
// quote.source, which has only its default; an unknown key holding a table with number and string
// keys; strings with a quote, a backslash, a newline, a tab and non-ASCII text. Its serialized form
// is spec/fixtures/studio/settings_written.lua, which spec/unit/studio_settings_file_spec.lua holds
// LuaSettings:flush and Settings.get to. KOPANDA_UPDATE_GOLDENS=1 writes the fixture instead of
// comparing against it.
const data = table([
  ["schema_version", 1],
  ["look", "editorial"],
  ["text_size", "large"],
  [
    "layout.rows",
    fromJson([
      [
        { widget: "clock", share: 2 },
        { widget: "date", share: 1 },
      ],
      [{ widget: "featured", share: 1 }],
      [{ widget: "launcher", share: 3 }],
      [
        { widget: "weather", share: 1 },
        { widget: "quote", share: 1 },
        { widget: "stats", share: 1 },
      ],
    ]),
  ],
  ["weather.location", fromJson({ name: "Seattle, Washington", latitude: 47.60621, longitude: -122.33207 })],
  ["weather.units", "celsius"],
  ["quote.source", "builtin"],
  ["stats.show", false],
  ["featured.pinned", "/mnt/us/documents/Frankenstein.epub"],
  [
    "launcher.entries",
    fromJson([
      { kind: "koreader", target: "favorites" },
      { kind: "kopanda", target: "library" },
      { kind: "plugin", plugin: "calibre", action: "search", label: "Calibre", icon: "calibre" },
      { kind: "action", action: "wifi_toggle", label: "Wi-Fi", icon: "action" },
      { kind: "directory", path: "/mnt/us/documents/Café", label: 'Say "hi" \\ back\nthen\tCafé “quoted”' },
      {
        kind: "folder",
        label: "Tools",
        entries: [
          { kind: "koreader", target: "collections" },
          { kind: "kopanda", target: "settings" },
        ],
      },
    ]),
  ],
  [
    "studio.note",
    table([
      [1, 3],
      [10, true],
      ["x", "y"],
    ]),
  ],
]);

const header = "/mnt/us/koreader/settings/kopanda/settings.lua";
const fixtureUrl = new URL("../../../spec/fixtures/studio/settings_written.lua", import.meta.url);

describe("the round trip's data set", () => {
  it("holds every schema key at a valid value, each but quote.source other than its default", () => {
    for (const entry of schema.keys) {
      const value = get(data, entry.id);
      expect(value, entry.id).toBeDefined();
      expect(validate(entry, value!), entry.id).toBe(true);
      if (entry.id === "quote.source") {
        expect(toJson(value!)).toEqual(entry.default);
      } else {
        expect(toJson(value!), entry.id).not.toEqual(entry.default);
      }
    }
  });
});

describe("spec/fixtures/studio/settings_written.lua", () => {
  it("is what serialize writes for the data set, byte for byte", () => {
    const written = serialize(data, header);
    if (process.env.KOPANDA_UPDATE_GOLDENS === "1") {
      fs.writeFileSync(fixtureUrl, written);
    }

    expect(fs.readFileSync(fixtureUrl, "utf8")).toBe(written);
  });
});
