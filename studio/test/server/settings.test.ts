import { afterEach, describe, expect, it, vi } from "vitest";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { schema } from "../../src/schema.js";

const tmpDirs: string[] = [];
afterEach(() => {
  vi.restoreAllMocks();
  for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

const kobo = { name: "Kobo", device: "Kobo Libra Colour", width: 1264, height: 1680, dpi: 300, color: true };

/** A profiles directory holding the profile "kobo"; its settings path, absolute, and its app. */
function setup() {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-settings-")));
  tmpDirs.push(dir);
  fs.mkdirSync(path.join(dir, "kobo"));
  fs.writeFileSync(path.join(dir, "kobo", "profile.json"), JSON.stringify(kobo));
  const settingsDir = path.join(dir, "kobo", "settings", "kopanda");
  const file = path.join(settingsDir, "settings.lua");
  const app = createApp(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: dir }));
  /** Writes the settings file with text (or bytes), making its directory first. */
  const store = (text: string | Uint8Array) => {
    fs.mkdirSync(settingsDir, { recursive: true });
    fs.writeFileSync(file, text);
  };
  return { dir, settingsDir, file, app, store };
}

const defaults = Object.fromEntries(schema.keys.map((key) => [key.id, key.default]));

function withValues(changes: Record<string, unknown>) {
  return { ...defaults, ...changes };
}

const seattle = { name: "Seattle, Washington", latitude: 47.60621, longitude: -122.33207 };

describe("GET /api/profiles/:id/settings", () => {
  it("answers every key at its default for a missing file, writable", async () => {
    const { app, file } = setup();

    const res = await request(app).get("/api/profiles/kobo/settings");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      path: file,
      exists: false,
      state: "writable",
      schema_version: 1,
      values: defaults,
      invalid: [],
      unknown: [],
    });
  });

  it("answers a valid stored value, the default for a refused one, and an unknown key as the writer writes it", async () => {
    const { app, file, store } = setup();
    store(`-- /mnt/us/koreader/settings/kopanda/settings.lua
return {
    ["look"] = "editorial",
    ["text_size"] = "huge",
    ["weather.location"] = { name = "Seattle, Washington", latitude = 47.60621, longitude = -122.33207 },
    ["studio.note"] = { 3, [10] = true, x = "y" },
    ["schema_version"] = 1,
}
`);

    const res = await request(app).get("/api/profiles/kobo/settings");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      path: file,
      exists: true,
      state: "writable",
      schema_version: 1,
      values: withValues({ look: "editorial", "weather.location": seattle }),
      invalid: [{ key: "text_size" }],
      unknown: [{ key: "studio.note", text: '{\n    [1] = 3,\n    [10] = true,\n    ["x"] = "y",\n}' }],
    });
  });

  it("reads schema_version absent or false as 1, writable", async () => {
    const { app, store } = setup();
    for (const text of ['return { look = "editorial" }', 'return { look = "editorial", schema_version = false }']) {
      store(text);

      const res = await request(app).get("/api/profiles/kobo/settings");

      expect(res.body).toMatchObject({ state: "writable", schema_version: 1, values: { look: "editorial" } });
    }
  });

  for (const version of [2, 1.5]) {
    it(`shows a file at schema_version ${version} read-only, its values read`, async () => {
      const { app, store } = setup();
      store(`return { look = "editorial", schema_version = ${version} }`);

      const res = await request(app).get("/api/profiles/kobo/settings");

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        exists: true,
        state: "read_only",
        schema_version: version,
        values: { look: "editorial" },
      });
      expect(res.body.reason).toContain(String(version));
    });
  }

  for (const version of ["0", "0.5", '"1"', "true", "{}"]) {
    it(`calls a file at schema_version ${version} unreadable, every key at its default`, async () => {
      const { app, store } = setup();
      store(`return { look = "editorial", schema_version = ${version} }`);

      const res = await request(app).get("/api/profiles/kobo/settings");

      expect(res.body).toMatchObject({
        exists: true,
        state: "unreadable",
        schema_version: null,
        values: defaults,
        invalid: [],
        unknown: [],
      });
      expect(res.body.reason).toContain("schema_version");
    });
  }

  it("calls a file holding a call unreadable, naming the line and column", async () => {
    const { app, store } = setup();
    store('return {\n    look = "editorial",\n    x = os.exit(),\n}\n');

    const res = await request(app).get("/api/profiles/kobo/settings");

    expect(res.body).toMatchObject({ exists: true, state: "unreadable", values: defaults });
    expect(res.body.reason).toMatch(/^line 3, column 9: /);
  });

  it("calls a file returning a non-table unreadable", async () => {
    const { app, store } = setup();
    store("return 5\n");

    const res = await request(app).get("/api/profiles/kobo/settings");

    expect(res.body).toMatchObject({ state: "unreadable", values: defaults });
    expect(res.body.reason).toContain("not a table");
  });

  it("calls a file with a string that isn't UTF-8 unreadable", async () => {
    const { app, store } = setup();
    store(Buffer.concat([Buffer.from('return { look = "'), Buffer.from([0xff]), Buffer.from('" }')]));

    const res = await request(app).get("/api/profiles/kobo/settings");

    expect(res.body).toMatchObject({ state: "unreadable", values: defaults });
    expect(res.body.reason).toContain("UTF-8");
  });

  it("is 404 for an unknown profile", async () => {
    const { app } = setup();

    const res = await request(app).get("/api/profiles/nope/settings");

    expect(res.status).toBe(404);
    expect(res.body.error).toContain("nope");
  });
});

describe("PUT /api/profiles/:id/settings/:key", () => {
  it("writes one key, keeping an unknown key and a refused value as they were and stamping schema_version", async () => {
    const { app, file, settingsDir, store } = setup();
    store(`-- /mnt/us/koreader/settings/kopanda/settings.lua
return {
    look = "diner",
    text_size = "huge",
    ["studio.note"] = { 3, [10] = true, x = "y" },
}
`);

    const res = await request(app).put("/api/profiles/kobo/settings/weather.location").send({ value: seattle });

    expect(res.status).toBe(200);
    expect(fs.readFileSync(file, "utf8")).toBe(`-- ${file}
return {
    ["look"] = "diner",
    ["schema_version"] = 1,
    ["studio.note"] = {
        [1] = 3,
        [10] = true,
        ["x"] = "y",
    },
    ["text_size"] = "huge",
    ["weather.location"] = {
        ["latitude"] = 47.60621,
        ["longitude"] = -122.33207,
        ["name"] = "Seattle, Washington",
    },
}
`);
    expect(res.body).toMatchObject({
      state: "writable",
      values: { "weather.location": seattle, text_size: "medium" },
      invalid: [{ key: "text_size" }],
      unknown: [{ key: "studio.note" }],
    });
    expect(fs.readdirSync(settingsDir)).toEqual(["settings.lua"]);
  });

  it("creates settings/kopanda/ for a profile with no settings, writing a list as a list", async () => {
    const { app, file, settingsDir } = setup();
    const entries = [{ kind: "kopanda", target: "library" }];

    const res = await request(app).put("/api/profiles/kobo/settings/launcher.entries").send({ value: entries });

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ exists: true, state: "writable", values: { "launcher.entries": entries } });
    expect(fs.readFileSync(file, "utf8")).toBe(`-- ${file}
return {
    ["launcher.entries"] = {
        [1] = {
            ["kind"] = "kopanda",
            ["target"] = "library",
        },
    },
    ["schema_version"] = 1,
}
`);
    expect(fs.readdirSync(settingsDir)).toEqual(["settings.lua"]);
  });

  it("answers what a following GET answers", async () => {
    const { app } = setup();

    const put = await request(app).put("/api/profiles/kobo/settings/look").send({ value: "editorial" });
    const got = await request(app).get("/api/profiles/kobo/settings");

    expect(put.body).toEqual(got.body);
  });

  it("keeps both of two PUTs started together", async () => {
    const { app } = setup();

    await Promise.all([
      request(app).put("/api/profiles/kobo/settings/look").send({ value: "editorial" }),
      request(app).put("/api/profiles/kobo/settings/stats.show").send({ value: false }),
      request(app).put("/api/profiles/kobo/settings/text_size").send({ value: "large" }),
    ]);
    const res = await request(app).get("/api/profiles/kobo/settings");

    expect(res.body.values).toMatchObject({ look: "editorial", "stats.show": false, text_size: "large" });
  });

  it("writes a value equal to the stored one, naming this file in the header in place of the device's", async () => {
    const { app, file, store } = setup();
    store('-- /mnt/us/koreader/settings/kopanda/settings.lua\nreturn { look = "diner", schema_version = 1 }\n');

    const res = await request(app).put("/api/profiles/kobo/settings/look").send({ value: "diner" });

    expect(res.status).toBe(200);
    expect(fs.readFileSync(file, "utf8")).toBe(`-- ${file}\nreturn {\n    ["look"] = "diner",\n    ["schema_version"] = 1,\n}\n`);
  });

  it("leaves a .old the device keeps as it is", async () => {
    const { app, file, store } = setup();
    store('return { look = "diner" }\n');
    fs.writeFileSync(`${file}.old`, "return { look = 'old' }\n");

    await request(app).put("/api/profiles/kobo/settings/look").send({ value: "editorial" });

    expect(fs.readFileSync(`${file}.old`, "utf8")).toBe("return { look = 'old' }\n");
  });

  const original = '-- hand\nreturn { look = "diner", text_size = "huge" }\n';

  const refusals: [string, string, string, unknown, number, RegExp][] = [
    ["a key outside the schema", original, "studio.note", "x", 404, /studio\.note/],
    ["a value the validator refuses", original, "look", "bistro", 400, /look/],
    ["null", original, "look", null, 400, /look/],
    ["a value of the wrong shape", original, "weather.location", [1, 2], 400, /weather\.location/],
    ["a read-only file", 'return { look = "diner", schema_version = 2 }\n', "look", "editorial", 409, /schema version 2/],
    ["an unreadable file", "return { look = os.exit() }\n", "look", "editorial", 409, /line 1/],
  ];

  for (const [name, text, key, value, status, error] of refusals) {
    it(`refuses ${name} with ${status}, leaving the file's bytes as they were`, async () => {
      const { app, file, settingsDir, store } = setup();
      store(text);

      const res = await request(app).put(`/api/profiles/kobo/settings/${key}`).send({ value });

      expect(res.status).toBe(status);
      expect(res.body.error).toMatch(error);
      expect(fs.readFileSync(file, "utf8")).toBe(text);
      expect(fs.readdirSync(settingsDir)).toEqual(["settings.lua"]);
    });
  }

  it("refuses a body without a value with 400, creating nothing", async () => {
    const { app, settingsDir } = setup();

    const res = await request(app).put("/api/profiles/kobo/settings/look").send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/look/);
    expect(fs.existsSync(settingsDir)).toBe(false);
  });

  it("is 404 for an unknown profile", async () => {
    const { app } = setup();

    const res = await request(app).put("/api/profiles/nope/settings/look").send({ value: "diner" });

    expect(res.status).toBe(404);
  });

  it("removes the temporary file and leaves the original when the rename fails, and the next write runs", async () => {
    const { app, file, settingsDir, store } = setup();
    store(original);
    vi.spyOn(fsp, "rename").mockRejectedValueOnce(new Error("disk full"));
    vi.spyOn(console, "error").mockImplementation(() => {});

    const res = await request(app).put("/api/profiles/kobo/settings/look").send({ value: "editorial" });

    expect(res.status).toBe(500);
    expect(fs.readFileSync(file, "utf8")).toBe(original);
    expect(fs.readdirSync(settingsDir)).toEqual(["settings.lua"]);

    const next = await request(app).put("/api/profiles/kobo/settings/look").send({ value: "editorial" });

    expect(next.status).toBe(200);
    expect(next.body.values.look).toBe("editorial");
  });
});
