import { afterEach, describe, expect, it } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import type { Manifest } from "../../src/server/bundle.js";
import { loadConfig } from "../../src/server/config.js";

const tmpDirs: string[] = [];
const lockedFiles: string[] = [];
afterEach(() => {
  for (const file of lockedFiles.splice(0)) fs.chmodSync(file, 0o644);
  for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

/** Makes `file` unreadable until the test ends. */
function lock(file: string): void {
  fs.chmodSync(file, 0o000);
  lockedFiles.push(file);
}

/** Root reads a file whatever its mode, so an unreadable file cannot be staged. */
const asRoot = process.getuid?.() === 0;

function tempDir(): string {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-push-")));
  tmpDirs.push(dir);
  return dir;
}

const kobo = { name: "Kobo", device: "Kobo Libra Colour", width: 1264, height: 1680, dpi: 300, color: true };
const kindle = { name: "Kindle", device: "Kindle Colorsoft SE", width: 1264, height: 1680, dpi: 300, color: true };

/**
 * A profiles directory holding "kobo" (with a settings file), "kindle" (without) and an invalid
 * "broken", a plugin folder, and the app serving them.
 */
function setup() {
  const profiles = tempDir();
  for (const [id, profile] of [["kobo", kobo], ["kindle", kindle]] as const) {
    fs.mkdirSync(path.join(profiles, id));
    fs.writeFileSync(path.join(profiles, id, "profile.json"), JSON.stringify(profile));
  }
  fs.mkdirSync(path.join(profiles, "broken"));
  fs.writeFileSync(path.join(profiles, "broken", "profile.json"), "{");
  const settingsFile = path.join(profiles, "kobo", "settings", "kopanda", "settings.lua");
  fs.mkdirSync(path.dirname(settingsFile), { recursive: true });
  fs.writeFileSync(settingsFile, `-- ${settingsFile}\nreturn {\n    ["look"] = "diner",\n}\n`);

  const pluginDir = path.join(tempDir(), "kopanda.koplugin");
  fs.mkdirSync(path.join(pluginDir, "icons"), { recursive: true });
  fs.writeFileSync(path.join(pluginDir, "main.lua"), "return {}\n");
  fs.writeFileSync(path.join(pluginDir, "_meta.lua"), "return { name = 'kopanda' }\n");
  fs.writeFileSync(path.join(pluginDir, "icons", "a.svg"), "<svg/>");

  const app = createApp(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: profiles }), { pluginDir });
  return { profiles, settingsFile, pluginDir, app };
}

/** Collects a response body as bytes, whatever its content type. */
function bytes(res: request.Response, done: (err: Error | null, body: Buffer) => void): void {
  const chunks: Buffer[] = [];
  res.on("data", (chunk: Buffer) => chunks.push(chunk));
  res.on("end", () => done(null, Buffer.concat(chunks)));
}

async function manifestOf(app: ReturnType<typeof setup>["app"], id: string): Promise<Manifest> {
  const res = await request(app).get(`/api/push/${id}/manifest`);
  expect(res.status).toBe(200);
  return res.body as Manifest;
}

describe("GET /api/push/profiles", () => {
  it("lists each valid profile as id, name and device only, in id order", async () => {
    const { app } = setup();

    const res = await request(app).get("/api/push/profiles");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      profiles: [
        { id: "kindle", name: "Kindle", device: "Kindle Colorsoft SE" },
        { id: "kobo", name: "Kobo", device: "Kobo Libra Colour" },
      ],
    });
  });

  it("is 500 without the directory's path when the profiles directory is gone", async () => {
    const { app, profiles } = setup();
    fs.rmSync(profiles, { recursive: true, force: true });

    const res = await request(app).get("/api/push/profiles");

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: expect.any(String) as unknown });
    expect(res.body.error).not.toContain(profiles);
  });
});

describe("GET /api/push/:id/manifest", () => {
  it("answers the profile's manifest with its files in byte order", async () => {
    const { app } = setup();

    const manifest = await manifestOf(app, "kobo");

    expect(manifest.format).toBe(1);
    expect(manifest.profile).toBe("kobo");
    expect(manifest.hash).toMatch(/^[0-9a-f]{64}$/);
    expect(manifest.files.map((file) => file.path)).toEqual([
      "plugin/_meta.lua",
      "plugin/icons/a.svg",
      "plugin/main.lua",
      "settings.lua",
    ]);
  });

  it.each(["nope", "broken"])("is 404 for %s, not a valid profile", async (id) => {
    const { app } = setup();

    const res = await request(app).get(`/api/push/${id}/manifest`);

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: expect.stringContaining(id) as unknown });
  });

  it("is 500 naming the entry for a symlink in the plugin folder", async () => {
    const { app, pluginDir } = setup();
    fs.symlinkSync(path.join(pluginDir, "main.lua"), path.join(pluginDir, "icons", "link.svg"));

    const res = await request(app).get("/api/push/kobo/manifest");

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: expect.stringContaining("plugin/icons/link.svg") as unknown });
  });

  it.skipIf(asRoot)("is 500 without the profiles directory's path for an unreadable settings file", async () => {
    const { app, profiles, settingsFile } = setup();
    lock(settingsFile);

    const res = await request(app).get("/api/push/kobo/manifest");

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: expect.any(String) as unknown });
    expect(res.body.error).not.toContain(profiles);
  });

  it.skipIf(asRoot)("is 404 without the profiles directory's path for an unreadable profile.json", async () => {
    const { app, profiles } = setup();
    lock(path.join(profiles, "kobo", "profile.json"));

    const res = await request(app).get("/api/push/kobo/manifest");

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: expect.stringContaining("kobo") as unknown });
    expect(res.body.error).not.toContain(profiles);
  });

  it("is 500 without the plugin folder's path when the plugin folder is missing", async () => {
    const { profiles } = setup();
    const pluginDir = path.join(tempDir(), "missing.koplugin");
    const app = createApp(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: profiles }), { pluginDir });

    const res = await request(app).get("/api/push/kobo/manifest");

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: expect.any(String) as unknown });
    expect(res.body.error).not.toContain(pluginDir);
  });
});

describe("GET /api/push/:id/files/:hash/*path", () => {
  it("answers each listed file's bytes as application/octet-stream with no-store", async () => {
    const { app, pluginDir } = setup();
    const manifest = await manifestOf(app, "kobo");

    for (const file of manifest.files) {
      const res = await request(app)
        .get(`/api/push/kobo/files/${manifest.hash}/${file.path}`)
        .buffer(true)
        .parse(bytes);

      expect(res.status, file.path).toBe(200);
      expect(res.headers["content-type"]).toBe("application/octet-stream");
      expect(res.headers["cache-control"]).toBe("no-store");
      const body = res.body as Buffer;
      expect(body.length).toBe(file.size);
      if (file.path.startsWith("plugin/")) {
        expect(body.equals(fs.readFileSync(path.join(pluginDir, file.path.slice("plugin/".length))))).toBe(true);
      } else {
        expect(body.toString("utf8")).toBe('-- settings/kopanda/settings.lua\nreturn {\n    ["look"] = "diner",\n}\n');
      }
    }
  });

  it("serves the default settings file for a profile that has none", async () => {
    const { app } = setup();
    const manifest = await manifestOf(app, "kindle");

    const res = await request(app).get(`/api/push/kindle/files/${manifest.hash}/settings.lua`).buffer(true).parse(bytes);

    expect(res.status).toBe(200);
    expect((res.body as Buffer).toString("utf8")).toBe("-- settings/kopanda/settings.lua\nreturn {}\n");
  });

  it("is 409 with the current hash for a hash that is not the bundle's", async () => {
    const { app } = setup();
    const manifest = await manifestOf(app, "kobo");

    const res = await request(app).get(`/api/push/kobo/files/${"0".repeat(64)}/plugin/main.lua`);

    expect(res.status).toBe(409);
    expect(res.body).toEqual({ error: expect.any(String) as unknown, hash: manifest.hash });
  });

  it("is 409 once the settings file changes after the manifest was taken", async () => {
    const { app, settingsFile } = setup();
    const manifest = await manifestOf(app, "kobo");
    fs.writeFileSync(settingsFile, "return {}\n");

    const res = await request(app).get(`/api/push/kobo/files/${manifest.hash}/plugin/main.lua`);

    expect(res.status).toBe(409);
    expect(res.body.hash).toBe((await manifestOf(app, "kobo")).hash);
    expect(res.body.hash).not.toBe(manifest.hash);
  });

  it.each(["plugin/nope", "plugin/%2e%2e/x", "plugin/%2e%2e/%2e%2e/kobo/profile.json", "plugin"])(
    "is 404 for %s, not in the bundle",
    async (rel) => {
      const { app } = setup();
      const manifest = await manifestOf(app, "kobo");

      const res = await request(app).get(`/api/push/kobo/files/${manifest.hash}/${rel}`);

      expect(res.status).toBe(404);
      expect(res.body).toEqual({ error: expect.any(String) as unknown });
    },
  );

  it.each(["nope", "broken"])("is 404 for %s, not a valid profile", async (id) => {
    const { app } = setup();
    const manifest = await manifestOf(app, "kobo");

    const res = await request(app).get(`/api/push/${id}/files/${manifest.hash}/plugin/main.lua`);

    expect(res.status).toBe(404);
  });
});
