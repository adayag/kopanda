import { afterEach, describe, expect, it, vi } from "vitest";
import type express from "express";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import type { AddressInfo, Socket } from "node:net";
import os from "node:os";
import path from "node:path";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { createPreviewQueue, DEFAULT_PREVIEW, type PreviewQueue } from "../../src/server/preview.js";

const FAKE = path.resolve(import.meta.dirname, "../fixtures/fake-preview");

const colorsoft = { name: "Colorsoft", device: "Kindle Colorsoft SE", width: 1264, height: 1680, dpi: 300, color: true };
const paperwhite = { name: "Paperwhite", device: "Kindle Paperwhite", width: 1072, height: 1448, dpi: 300, color: false };

interface Run {
  event: "start" | "end";
  args: string[];
  at: number;
}

const cleanups: (() => void)[] = [];
afterEach(() => {
  vi.unstubAllEnvs();
  for (const cleanup of cleanups.splice(0)) cleanup();
});

/**
 * A profiles directory holding "colorsoft", "paperwhite" and an invalid "broken"; an app whose preview
 * command is the fake in `mode`; and the directory the fake records to.
 */
function setup(mode: string, options: { timeoutMs?: number; queue?: PreviewQueue; delayMs?: number } = {}) {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-preview-route-")));
  cleanups.push(() => fs.rmSync(dir, { recursive: true, force: true }));
  for (const [id, profile] of Object.entries({ colorsoft, paperwhite, broken: { name: "Broken" } })) {
    fs.mkdirSync(path.join(dir, id));
    fs.writeFileSync(path.join(dir, id, "profile.json"), JSON.stringify(profile));
  }
  const record = path.join(dir, "record");
  fs.mkdirSync(record);
  vi.stubEnv("KOPANDA_FAKE_PREVIEW_DIR", record);
  vi.stubEnv("KOPANDA_FAKE_PREVIEW_MODE", mode);
  vi.stubEnv("KOPANDA_FAKE_PREVIEW_DELAY_MS", String(options.delayMs ?? 0));
  const app = createApp(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: dir }), {
    preview: { command: FAKE, timeoutMs: options.timeoutMs, queue: options.queue },
  });
  const runs = (): Run[] => {
    const file = path.join(record, "runs");
    if (!fs.existsSync(file)) return [];
    return fs
      .readFileSync(file, "utf8")
      .split("\n")
      .filter((line) => line !== "")
      .map((line) => JSON.parse(line) as Run);
  };
  const settingsFile = (id: string) => path.join(dir, id, "settings", "kopanda", "settings.lua");
  return { app, record, runs, settingsFile };
}

function preview(app: express.Express, id: string, body?: object) {
  const req = request(app).post(`/api/profiles/${id}/preview`);
  return body === undefined ? req : req.send(body);
}

describe("POST /api/profiles/:id/preview", () => {
  it("runs the command for a Colorsoft profile with no settings file and answers its PNG", async () => {
    const { app, record, runs } = setup("png");

    const res = await preview(app, "colorsoft", { look: "diner", night: false });

    expect(res.status).toBe(200);
    expect(res.headers["content-type"]).toBe("image/png");
    expect(res.headers["cache-control"]).toBe("no-store");
    expect(Buffer.compare(res.body as Buffer, fs.readFileSync(path.join(record, "out.png")))).toBe(0);
    const [start] = runs();
    const png = start!.args[6]!;
    expect(start!.args).toEqual(["1264", "1680", "300", "color", "diner", "day", png]);
    expect(path.isAbsolute(png)).toBe(true);
    expect(fs.existsSync(path.dirname(png))).toBe(false);
  });

  it("passes the settings file's absolute path last when the profile has one", async () => {
    const { app, runs, settingsFile } = setup("png");
    fs.mkdirSync(path.dirname(settingsFile("colorsoft")), { recursive: true });
    fs.writeFileSync(settingsFile("colorsoft"), 'return { ["look"] = "editorial" }\n');

    const res = await preview(app, "colorsoft", { look: "editorial", night: false });

    expect(res.status).toBe(200);
    const args = runs()[0]!.args;
    expect(args.slice(0, 6)).toEqual(["1264", "1680", "300", "color", "editorial", "day"]);
    expect(args[7]).toBe(settingsFile("colorsoft"));
    expect(args).toHaveLength(8);
  });

  it("passes grey for a greyscale profile and night when night is on", async () => {
    const { app, runs } = setup("png");

    const res = await preview(app, "paperwhite", { look: "diner", night: true });

    expect(res.status).toBe(200);
    expect(runs()[0]!.args.slice(0, 6)).toEqual(["1072", "1448", "300", "grey", "diner", "night"]);
  });

  it("answers 400 for a look outside the schema's choices, a night that isn't a boolean, or no body", async () => {
    const { app, runs } = setup("png");

    for (const body of [{ look: "classic", night: false }, { look: "classic" }, { look: "diner", night: "yes" }, { night: true }]) {
      const res = await preview(app, "colorsoft", body);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expect(res.body.error).toEqual(expect.any(String));
    }
    const res = await preview(app, "colorsoft");
    expect(res.status).toBe(400);
    expect(runs()).toEqual([]);
  });

  it("answers 404 for an unknown or invalid profile", async () => {
    const { app, runs } = setup("png");

    for (const id of ["nope", "broken"]) {
      const res = await preview(app, id, { look: "diner", night: false });
      expect(res.status, id).toBe(404);
      expect(res.body.error).toEqual(expect.any(String));
    }
    expect(runs()).toEqual([]);
  });

  it("answers 502 with stderr's first line and the last 40 of the rest when the render fails", async () => {
    const { app, runs } = setup("fail");

    const res = await preview(app, "colorsoft", { look: "diner", night: false });

    expect(res.status).toBe(502);
    expect(res.body).toEqual({
      error: "line 1",
      log: Array.from({ length: 40 }, (_, i) => `line ${i + 6}`),
    });
    expect(fs.existsSync(path.dirname(runs()[0]!.args[6]!))).toBe(false);
  });

  it("answers 503 when the script refuses to run", async () => {
    const { app } = setup("refuse");

    const res = await preview(app, "colorsoft", { look: "diner", night: false });

    expect(res.status).toBe(503);
    expect(res.body).toEqual({ error: "bin/preview: no luajit at /nonexistent/luajit", log: [] });
  });

  it("answers 502 naming the parse when stdout isn't the script's JSON", async () => {
    const { app } = setup("junk");

    const res = await preview(app, "colorsoft", { look: "diner", night: false });

    expect(res.status).toBe(502);
    expect(res.body.error).toMatch(/JSON/);
  });

  it("answers 502 when the command can't be started", async () => {
    const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-preview-route-")));
    cleanups.push(() => fs.rmSync(dir, { recursive: true, force: true }));
    fs.mkdirSync(path.join(dir, "colorsoft"));
    fs.writeFileSync(path.join(dir, "colorsoft", "profile.json"), JSON.stringify(colorsoft));
    const app = createApp(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: dir }), {
      preview: { command: path.join(dir, "absent") },
    });

    const res = await preview(app, "colorsoft", { look: "diner", night: false });

    expect(res.status).toBe(502);
    expect(res.body.error).toContain("absent");
  });

  it("kills the whole process group past the time limit and answers 502", async () => {
    const { app, record, runs } = setup("sleep", { timeoutMs: 300 });
    const started = Date.now();

    const res = await preview(app, "colorsoft", { look: "diner", night: false });

    expect(res.status).toBe(502);
    expect(res.body).toEqual({ error: "No render within 0.3 s", log: [] });
    expect(Date.now() - started).toBeLessThan(5000);
    const child = Number(fs.readFileSync(path.join(record, "child-pid"), "utf8"));
    await vi.waitFor(() => expect(() => process.kill(child, 0)).toThrow(), { timeout: 2000 });
    expect(fs.existsSync(path.dirname(runs()[0]!.args[6]!))).toBe(false);
  });

  it("runs one render at a time, and never runs a queued request whose client has gone", async () => {
    const queue = createPreviewQueue();
    const signals: AbortSignal[] = [];
    let release!: () => void;
    const held = new Promise<void>((resolve) => (release = resolve));
    // The first render waits for the test, so the others queue behind it whatever the machine's load.
    const counted: PreviewQueue = {
      run: (job, signal) => {
        signals.push(signal!);
        return queue.run(signals.length === 1 ? () => held.then(job) : job, signal);
      },
    };
    const { app, runs } = setup("png", { delayMs: 200, queue: counted });
    const server = app.listen(0, "127.0.0.1");
    cleanups.push(() => server.close());
    await new Promise((resolve) => server.once("listening", resolve));
    const url = `http://127.0.0.1:${(server.address() as AddressInfo).port}/api/profiles/colorsoft/preview`;
    const send = (look: string, night: boolean, signal?: AbortSignal) =>
      fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ look, night }),
        signal,
      });

    // Each request is sent once the one before it has reached the queue, so they arrive in this order.
    const first = send("diner", false);
    await vi.waitFor(() => expect(signals).toHaveLength(1));
    const second = send("editorial", false);
    await vi.waitFor(() => expect(signals).toHaveLength(2));
    const leaving = new AbortController();
    const third = send("diner", true, leaving.signal).catch((err: unknown) => err);
    await vi.waitFor(() => expect(signals).toHaveLength(3));
    leaving.abort();
    await vi.waitFor(() => expect(signals[2]!.aborted).toBe(true));
    release();

    expect((await first).status).toBe(200);
    expect((await second).status).toBe(200);
    expect(await third).toBeInstanceOf(Error);
    // A job queued now runs only after every job still in the queue has ended.
    await queue.run(async () => undefined);
    const records = runs();
    const starts = records.filter((r) => r.event === "start");
    const ends = records.filter((r) => r.event === "end");
    expect(starts.map((r) => r.args.slice(4, 6))).toEqual([
      ["diner", "day"],
      ["editorial", "day"],
    ]);
    expect(starts[1]!.at).toBeGreaterThanOrEqual(ends[0]!.at);
    expect(ends[0]!.args).toEqual(starts[0]!.args);
  });

  it("never runs a request whose client has gone while its profile was read", async () => {
    const queue = createPreviewQueue();
    const signals: AbortSignal[] = [];
    const counted: PreviewQueue = {
      run: (job, signal) => {
        signals.push(signal!);
        return queue.run(job, signal);
      },
    };
    const { app, record, runs } = setup("png", { queue: counted });
    // The profile's file is a pipe, so its read waits until the test writes it.
    const profileFile = path.join(path.dirname(record), "colorsoft", "profile.json");
    fs.rmSync(profileFile);
    execFileSync("mkfifo", [profileFile]);
    const server = app.listen(0, "127.0.0.1");
    cleanups.push(() => server.close());
    await new Promise((resolve) => server.once("listening", resolve));
    const closed = new Promise((resolve) => server.once("connection", (socket: Socket) => socket.once("close", resolve)));
    const leaving = new AbortController();
    const sent = fetch(`http://127.0.0.1:${(server.address() as AddressInfo).port}/api/profiles/colorsoft/preview`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ look: "diner", night: false }),
      signal: leaving.signal,
    }).catch((err: unknown) => err);

    // Opening the pipe to write waits until the server has opened it to read.
    const writer = await fs.promises.open(profileFile, "w");
    leaving.abort();
    expect(await sent).toBeInstanceOf(Error);
    await closed;
    await writer.writeFile(JSON.stringify(colorsoft));
    await writer.close();

    await vi.waitFor(() => expect(signals).toHaveLength(1));
    expect(signals[0]!.aborted).toBe(true);
    await queue.run(async () => undefined);
    expect(runs()).toEqual([]);
  });
});

describe("createPreviewQueue", () => {
  function deferred() {
    let resolve!: (value: string) => void;
    const promise = new Promise<string>((res) => (resolve = res));
    return { promise, resolve };
  }

  it("runs jobs one at a time in arrival order", async () => {
    const queue = createPreviewQueue();
    const order: string[] = [];
    const a = deferred();
    const b = deferred();
    const first = queue.run(() => (order.push("a"), a.promise));
    const second = queue.run(() => (order.push("b"), b.promise));
    const third = queue.run(async () => (order.push("c"), "c"));

    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(order).toEqual(["a"]);
    a.resolve("a");
    expect(await first).toBe("a");
    await vi.waitFor(() => expect(order).toEqual(["a", "b"]));
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(order).toEqual(["a", "b"]);
    b.resolve("b");
    expect(await second).toBe("b");
    expect(await third).toBe("c");
    expect(order).toEqual(["a", "b", "c"]);
  });

  it("moves on after a job that fails", async () => {
    const queue = createPreviewQueue();
    const failing = queue.run(() => Promise.reject(new Error("boom")));
    const next = queue.run(async () => "next");

    await expect(failing).rejects.toThrow("boom");
    expect(await next).toBe("next");
  });

  it("drops a waiting job whose signal aborts, rejecting it at once, and lets a started one finish", async () => {
    const queue = createPreviewQueue();
    const a = deferred();
    const started = new AbortController();
    const waiting = new AbortController();
    const job = vi.fn(async () => "never");
    const first = queue.run(() => a.promise, started.signal);
    const second = queue.run(job, waiting.signal);

    waiting.abort();
    started.abort();
    await expect(second).rejects.toThrow();
    a.resolve("a");
    expect(await first).toBe("a");
    expect(await queue.run(async () => "after")).toBe("after");
    expect(job).not.toHaveBeenCalled();
  });

  it("never starts a job whose signal has already aborted", async () => {
    const queue = createPreviewQueue();
    const job = vi.fn(async () => "never");

    await expect(queue.run(job, AbortSignal.abort())).rejects.toThrow();
    expect(job).not.toHaveBeenCalled();
  });
});

describe("the default command", () => {
  it("is the repo's bin/preview, on disk", () => {
    expect(DEFAULT_PREVIEW).toBe(path.resolve(import.meta.dirname, "../../../bin/preview"));
    expect(fs.statSync(DEFAULT_PREVIEW).isFile()).toBe(true);
  });
});
