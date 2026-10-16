import { afterEach, describe, expect, it, vi } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { checkFit, DEFAULT_LAYOUT_FIT } from "../../src/server/layout-fit.js";

const fixtures = path.resolve(import.meta.dirname, "../fixtures/layout-fit");

const tmpDirs: string[] = [];
afterEach(() => {
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
    const started = Date.now();

    const result = await check("slow.sh", 200);

    expect(result).toEqual({ checked: false, reason: "bin/layout-fit gave no answer within 200 ms" });
    expect(Date.now() - started).toBeLessThan(3000);
    const sleeper = Number(fs.readFileSync(path.join(dir, "sleep-pid"), "utf8"));
    await vi.waitFor(() => expect(() => process.kill(sleeper, 0)).toThrow(), { timeout: 2000 });
  });

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
