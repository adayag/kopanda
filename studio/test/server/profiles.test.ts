import { afterEach, describe, expect, it, vi } from "vitest";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { ensureProfilesDir } from "../../src/server/profiles.js";
import seed from "../../src/server/default-profiles.json" with { type: "json" };

const tmpDirs: string[] = [];
afterEach(() => {
  vi.restoreAllMocks();
  for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

function tempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-profiles-"));
  tmpDirs.push(dir);
  return dir;
}

/** Every file under dir, relative to it, with its bytes. */
function snapshot(dir: string): Record<string, string> {
  const files: Record<string, string> = {};
  for (const entry of fs.readdirSync(dir, { recursive: true, withFileTypes: true })) {
    const full = path.join(entry.parentPath, entry.name);
    const rel = path.relative(dir, full);
    files[rel] = entry.isDirectory() ? "<dir>" : fs.readFileSync(full, "base64");
  }
  return files;
}

function writeProfileJson(dir: string, id: string, content: unknown): void {
  fs.mkdirSync(path.join(dir, id), { recursive: true });
  const text = typeof content === "string" ? content : JSON.stringify(content);
  fs.writeFileSync(path.join(dir, id, "profile.json"), text);
}

const kobo = {
  name: "Kobo",
  device: "Kobo Libra Colour",
  width: 1264,
  height: 1680,
  dpi: 300,
  color: true,
};

function app(profilesDir: string) {
  return createApp(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: profilesDir }));
}

describe("ensureProfilesDir", () => {
  it("creates a missing directory holding the two seed profiles and no settings", async () => {
    const dir = path.join(tempDir(), "nested", "profiles");

    await ensureProfilesDir(dir);

    expect(Object.keys(snapshot(dir)).sort()).toEqual([
      "colorsoft",
      path.join("colorsoft", "profile.json"),
      "paperwhite",
      path.join("paperwhite", "profile.json"),
    ]);
    for (const [id, profile] of Object.entries(seed)) {
      expect(JSON.parse(fs.readFileSync(path.join(dir, id, "profile.json"), "utf8"))).toEqual(profile);
    }
  });

  it("leaves an existing empty directory empty", async () => {
    const dir = tempDir();

    await ensureProfilesDir(dir);

    expect(fs.readdirSync(dir)).toEqual([]);
  });

  it("leaves a directory holding one profile byte-identical", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "kobo", `${JSON.stringify(kobo, null, 4)}\n`);
    const before = snapshot(dir);

    await ensureProfilesDir(dir);

    expect(snapshot(dir)).toEqual(before);
  });

  it("throws naming the path when it is a file", async () => {
    const file = path.join(tempDir(), "profiles");
    fs.writeFileSync(file, "");

    await expect(ensureProfilesDir(file)).rejects.toThrow(file);
  });
});

describe("GET /api/profiles", () => {
  it("answers the absolute directory and the seed profiles in id order with every field", async () => {
    const dir = path.join(tempDir(), "profiles");
    await ensureProfilesDir(dir);

    const res = await request(app(dir)).get("/api/profiles");

    expect(res.status).toBe(200);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    expect(res.body).toEqual({
      dir,
      profiles: [
        { id: "colorsoft", ...seed.colorsoft, has_settings: false },
        { id: "paperwhite", ...seed.paperwhite, has_settings: false },
      ],
    });
  });

  it("answers dir as an absolute path when configured with a relative one", async () => {
    const dir = tempDir();
    const relative = path.relative(process.cwd(), dir);
    expect(path.isAbsolute(relative)).toBe(false);

    const res = await request(app(relative)).get("/api/profiles");

    expect(res.body).toEqual({ dir, profiles: [] });
  });

  it("shows a profile written after the app starts on the next request", async () => {
    const dir = tempDir();
    const server = app(dir);
    expect((await request(server).get("/api/profiles")).body.profiles).toEqual([]);

    writeProfileJson(dir, "kobo", kobo);

    expect((await request(server).get("/api/profiles")).body.profiles).toEqual([
      { id: "kobo", ...kobo, has_settings: false },
    ]);
  });

  it("shows a hand edit to a profile on the next request", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "kobo", kobo);
    const server = app(dir);
    await request(server).get("/api/profiles");

    writeProfileJson(dir, "kobo", { ...kobo, name: "Renamed" });

    expect((await request(server).get("/api/profiles")).body.profiles[0].name).toBe("Renamed");
  });

  it("sorts by id whatever order the directory is read in", async () => {
    const dir = tempDir();
    for (const id of ["alpha", "mid-1", "zeta"]) writeProfileJson(dir, id, kobo);
    const readdir = fsp.readdir;
    vi.spyOn(fsp, "readdir").mockImplementation((async (target: string) =>
      (await readdir(target)).reverse()) as typeof fsp.readdir);

    const res = await request(app(dir)).get("/api/profiles");

    expect(res.body.profiles.map((p: { id: string }) => p.id)).toEqual(["alpha", "mid-1", "zeta"]);
  });

  it("skips a directory without profile.json, plain files and hidden entries", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "kobo", kobo);
    fs.mkdirSync(path.join(dir, "empty"));
    fs.writeFileSync(path.join(dir, "notes.txt"), "not a profile");
    fs.writeFileSync(path.join(dir, ".DS_Store"), "");
    writeProfileJson(dir, ".hidden", kobo);
    writeProfileJson(dir, ".broken", "{");

    const res = await request(app(dir)).get("/api/profiles");

    expect(res.body.profiles.map((p: { id: string }) => p.id)).toEqual(["kobo"]);
  });

  it("lists malformed JSON as id and error", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "broken", "{ not json");

    const [profile] = (await request(app(dir)).get("/api/profiles")).body.profiles;

    expect(Object.keys(profile).sort()).toEqual(["error", "id"]);
    expect(profile.id).toBe("broken");
    expect(profile.error).toMatch(/JSON/);
  });

  it("lists a zero width as id and an error naming the field", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "flat", { ...kobo, width: 0 });

    const [profile] = (await request(app(dir)).get("/api/profiles")).body.profiles;

    expect(Object.keys(profile).sort()).toEqual(["error", "id"]);
    expect(profile.id).toBe("flat");
    expect(profile.error).toMatch(/width/);
  });

  it.each([
    ["a missing name", { ...kobo, name: undefined }, /name/],
    ["an empty device", { ...kobo, device: "" }, /device/],
    ["a fractional dpi", { ...kobo, dpi: 300.5 }, /dpi/],
    ["a string color", { ...kobo, color: "yes" }, /color/],
    ["a negative height", { ...kobo, height: -1 }, /height/],
    ["an array", [kobo], /./],
  ])("lists %s as invalid with the reason", async (_label, content, reason) => {
    const dir = tempDir();
    writeProfileJson(dir, "bad", content);

    const [profile] = (await request(app(dir)).get("/api/profiles")).body.profiles;

    expect(profile).toEqual({ id: "bad", error: expect.stringMatching(reason) });
  });

  it("lists a directory whose name breaks the id pattern as invalid with the reason", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "My Kindle", kobo);

    const res = await request(app(dir)).get("/api/profiles");

    expect(res.body.profiles).toEqual([
      { id: "My Kindle", error: expect.stringContaining("^[a-z0-9-]+$") },
    ]);
  });

  it("reports has_settings once settings/kopanda/settings.lua exists", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "kobo", kobo);
    const server = app(dir);
    expect((await request(server).get("/api/profiles")).body.profiles[0].has_settings).toBe(false);

    fs.mkdirSync(path.join(dir, "kobo", "settings", "kopanda"), { recursive: true });
    expect((await request(server).get("/api/profiles")).body.profiles[0].has_settings).toBe(false);

    fs.writeFileSync(path.join(dir, "kobo", "settings", "kopanda", "settings.lua"), "return {}\n");
    expect((await request(server).get("/api/profiles")).body.profiles[0].has_settings).toBe(true);
  });
});

describe("GET /api/profiles/:id", () => {
  it("returns the profile with its absolute settings_path", async () => {
    const dir = path.join(tempDir(), "profiles");
    await ensureProfilesDir(dir);

    const res = await request(app(dir)).get("/api/profiles/colorsoft");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      id: "colorsoft",
      ...seed.colorsoft,
      has_settings: false,
      settings_path: path.join(dir, "colorsoft", "settings", "kopanda", "settings.lua"),
    });
    expect(path.isAbsolute(res.body.settings_path)).toBe(true);
    expect(res.body.settings_path).toMatch(/colorsoft\/settings\/kopanda\/settings\.lua$/);
  });

  it("is 404 with an error for an unknown id", async () => {
    const dir = path.join(tempDir(), "profiles");
    await ensureProfilesDir(dir);

    const res = await request(app(dir)).get("/api/profiles/kobo");

    expect(res.status).toBe(404);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    expect(res.body).toEqual({ error: expect.stringContaining("kobo") });
  });

  it("is 404 with the reason for an invalid profile", async () => {
    const dir = tempDir();
    writeProfileJson(dir, "flat", { ...kobo, width: 0 });

    const res = await request(app(dir)).get("/api/profiles/flat");

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: expect.stringMatching(/flat.*width/) });
  });

  it("is 404 for a hidden directory holding a valid profile", async () => {
    const dir = tempDir();
    writeProfileJson(dir, ".hidden", kobo);

    const res = await request(app(dir)).get("/api/profiles/.hidden");

    expect(res.status).toBe(404);
  });

  it.each(["..", "%2e%2e", "..%2Foutside", "%2e%2e%2Foutside", "inner%2F..%2F..%2Foutside"])(
    "never reaches outside the profiles directory for %s",
    async (id) => {
      const root = tempDir();
      const dir = path.join(root, "profiles");
      writeProfileJson(dir, "inner", kobo);
      writeProfileJson(root, "outside", kobo);
      fs.writeFileSync(path.join(root, "profile.json"), JSON.stringify(kobo));

      const res = await request(app(dir)).get(`/api/profiles/${id}`);

      expect(res.status).toBe(404);
      expect(res.body).toEqual({ error: `no profile "${decodeURIComponent(id)}"` });
    },
  );
});

describe("unknown API paths beside the profiles router", () => {
  it("answer 404 JSON with an error", async () => {
    const res = await request(app(tempDir())).get("/api/nope");

    expect(res.status).toBe(404);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    expect(res.body).toEqual({ error: "not found: GET /api/nope" });
  });
});
