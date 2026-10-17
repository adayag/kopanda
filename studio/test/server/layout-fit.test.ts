import { afterEach, describe, expect, it, vi } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { setTimeout as pause } from "node:timers/promises";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { checkFit, DEFAULT_LAYOUT_FIT } from "../../src/server/layout-fit.js";
import { schema } from "../../src/schema.js";

const fixtures = path.resolve(import.meta.dirname, "../fixtures/layout-fit");

const tmpDirs: string[] = [];
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
  for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

const current = [[{ widget: "date", share: 1 }], [{ widget: "clock", share: 1 }]];
const proposed = [[{ widget: "clock", share: 1 }], [{ widget: "date", share: 1 }]];

function check(fake: string, timeoutMs?: number) {
  return checkFit({
    command: path.join(fixtures, fake),
    width: 1264,
    height: 1680,
    dpi: 300,
    settingsPath: "/profiles/colorsoft/settings/kopanda/settings.lua",
    current,
    proposed,
    timeoutMs,
  });
}

describe("checkFit", () => {
  it("runs the command for the profile's screen and settings file, both row lists on stdin", async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-fit-"));
    tmpDirs.push(dir);
    // The fake reads where to record from the environment, which checkFit passes through.
    vi.stubEnv("KOPANDA_FAKE_FIT_DIR", dir);

    const result = await check("answers.sh");

    expect(result).toEqual({ checked: true, current: 0, proposed: 1 });
    expect(fs.readFileSync(path.join(dir, "args"), "utf8")).toBe(
      "1264\n1680\n300\n/profiles/colorsoft/settings/kopanda/settings.lua\n",
    );
    expect(JSON.parse(fs.readFileSync(path.join(dir, "stdin"), "utf8"))).toEqual([current, proposed]);
  });

  it("answers unchecked with the refusal's first line when there is no emulator", async () => {
    expect(await check("no-emulator.sh")).toEqual({
      checked: false,
      reason: "no emulator: bin/layout-fit: no luajit at /nonexistent/luajit",
    });
  });

  it("answers unchecked with the script's own message, past KOReader's chatter, on another exit", async () => {
    expect(await check("fails.sh")).toEqual({
      checked: false,
      reason: "bin/layout-fit exited 1: bin/layout-fit: row list 2 is not a layout the plugin accepts",
    });
  });

  it("answers unchecked for output that isn't the script's answer", async () => {
    expect(await check("garbage.sh")).toEqual({
      checked: false,
      reason: "bin/layout-fit answered something unreadable: garbage",
    });
  });

  it("answers unchecked when it doesn't answer in time, the process and its children stopped", async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-fit-"));
    tmpDirs.push(dir);
    vi.stubEnv("KOPANDA_FAKE_FIT_DIR", dir);
    // The timeout is held until the fake has started its sleeper, so a loaded host can't stop the
    // script before the child exists. The wait polls on the named node:timers/promises import,
    // which Vitest's toFake list leaves real (vi.waitFor would advance the fake clock and fire the
    // timeout itself).
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    try {
      let settled = false;
      const pending = check("slow.sh", 200).then((result) => {
        settled = true;
        return result;
      });
      const pidFile = path.join(dir, "sleep-pid");
      const deadline = Date.now() + 10000;
      while (!/^\d+\n$/.test(fs.existsSync(pidFile) ? fs.readFileSync(pidFile, "utf8") : "")) {
        if (Date.now() > deadline) throw new Error("slow.sh never started its sleeper");
        await pause(20);
      }
      const sleeper = Number(fs.readFileSync(pidFile, "utf8"));

      // The timeout waits its whole 200 ms: one short of it the fit is still pending.
      vi.advanceTimersByTime(199);
      await Promise.resolve();
      expect(settled).toBe(false);
      vi.advanceTimersByTime(1);
      const result = await pending;

      expect(result).toEqual({ checked: false, reason: "bin/layout-fit gave no answer within 200 ms" });
      await vi.waitFor(() => expect(() => process.kill(sleeper, 0)).toThrow(), { timeout: 2000 });
    } finally {
      vi.useRealTimers();
    }
  }, 15000);

  it("answers unchecked when the command can't be started", async () => {
    const result = await check("absent.sh");

    expect(result.checked).toBe(false);
    expect(result).toHaveProperty("reason", expect.stringContaining("absent.sh"));
  });
});

describe("the default command", () => {
  it("is the repo's bin/layout-fit, on disk", () => {
    expect(DEFAULT_LAYOUT_FIT).toBe(path.resolve(import.meta.dirname, "../../../bin/layout-fit"));
    expect(fs.statSync(DEFAULT_LAYOUT_FIT).isFile()).toBe(true);
  });
});

describe("POST /api/profiles/:id/layout-fit", () => {
  const kobo = { name: "Kobo", device: "Kobo Libra Colour", width: 1264, height: 1680, dpi: 300, color: true };
  const defaultRows = schema.keys.find((key) => key.id === "layout.rows")!.default;

  /**
   * A profiles directory holding "kobo", an app whose fit command is the fake, and a directory
   * the recording fake writes its arguments and stdin to.
   */
  function setup(fake: string, timeoutMs?: number) {
    const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-fit-route-")));
    tmpDirs.push(dir);
    fs.mkdirSync(path.join(dir, "kobo"));
    fs.writeFileSync(path.join(dir, "kobo", "profile.json"), JSON.stringify(kobo));
    const record = path.join(dir, "record");
    fs.mkdirSync(record);
    vi.stubEnv("KOPANDA_FAKE_FIT_DIR", record);
    const app = createApp(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: dir }), {
      layoutFit: { command: path.join(fixtures, fake), timeoutMs },
    });
    const settingsFile = path.join(dir, "kobo", "settings", "kopanda", "settings.lua");
    return { app, record, settingsFile };
  }

  it("runs the command once for the profile's screen and settings file, the default rows as current", async () => {
    const { app, record, settingsFile } = setup("answers.sh");

    const res = await request(app).post("/api/profiles/kobo/layout-fit").send({ rows: proposed });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ checked: true, current: 0, proposed: 1 });
    expect(fs.readFileSync(path.join(record, "args"), "utf8")).toBe(`1264\n1680\n300\n${settingsFile}\n`);
    expect(JSON.parse(fs.readFileSync(path.join(record, "stdin"), "utf8"))).toEqual([defaultRows, proposed]);
  });

  it("measures the stored rows as current", async () => {
    const { app, record, settingsFile } = setup("answers.sh");
    fs.mkdirSync(path.dirname(settingsFile), { recursive: true });
    fs.writeFileSync(
      settingsFile,
      `return {
    ["layout.rows"] = {
        { { widget = "clock", share = 2 }, { widget = "date", share = 1 } },
        { { widget = "quote", share = 1 } },
    },
    ["schema_version"] = 1,
}
`,
    );

    const res = await request(app).post("/api/profiles/kobo/layout-fit").send({ rows: proposed });

    expect(res.status).toBe(200);
    expect(JSON.parse(fs.readFileSync(path.join(record, "stdin"), "utf8"))).toEqual([
      [
        [
          { widget: "clock", share: 2 },
          { widget: "date", share: 1 },
        ],
        [{ widget: "quote", share: 1 }],
      ],
      proposed,
    ]);
  });

  it("answers 400 for a body without rows, running nothing", async () => {
    const { app, record } = setup("answers.sh");

    for (const body of [{}, { row: proposed }]) {
      const res = await request(app).post("/api/profiles/kobo/layout-fit").send(body);
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/rows/);
    }
    const res = await request(app).post("/api/profiles/kobo/layout-fit");
    expect(res.status).toBe(400);
    expect(fs.existsSync(path.join(record, "args"))).toBe(false);
  });

  it("answers 404 for a profile that isn't listed, running nothing", async () => {
    const { app, record } = setup("answers.sh");

    const res = await request(app).post("/api/profiles/kindle/layout-fit").send({ rows: proposed });

    expect(res.status).toBe(404);
    expect(fs.existsSync(path.join(record, "args"))).toBe(false);
  });

  it.each([
    ["no-emulator.sh", undefined, "no emulator: bin/layout-fit: no luajit at /nonexistent/luajit"],
    ["fails.sh", undefined, "bin/layout-fit exited 1: bin/layout-fit: row list 2 is not a layout the plugin accepts"],
    ["garbage.sh", undefined, "bin/layout-fit answered something unreadable: garbage"],
    ["slow.sh", 200, "bin/layout-fit gave no answer within 200 ms"],
  ])("answers 200, unchecked with a reason, when %s can't check", async (fake, timeoutMs, reason) => {
    const { app } = setup(fake, timeoutMs);

    const res = await request(app).post("/api/profiles/kobo/layout-fit").send({ rows: proposed });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ checked: false, reason });
  });
});
