import { afterEach, describe, expect, it } from "vitest";
import express from "express";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { isLoopback, lanGuard } from "../../src/server/lan-guard.js";

const HASH = "ab".repeat(32);

/** Answers 200 "reached" to every request that gets past the guard, which sees `peer` as the remote address. */
function guarded(peer: string): express.Express {
  const app = express();
  app.use((req, _res, next) => {
    Object.defineProperty(req.socket, "remoteAddress", { value: peer, configurable: true });
    next();
  });
  app.use(lanGuard);
  app.use((_req, res) => {
    res.send("reached");
  });
  return app;
}

const ALLOWED: [string, string][] = [
  ["GET", "/api/health"],
  ["GET", "/api/push/profiles"],
  ["GET", "/api/push/colorsoft/manifest"],
  ["GET", `/api/push/colorsoft/files/${HASH}/plugin/icons/a.svg`],
];

const REFUSED: [string, string][] = [
  ["GET", "/api/profiles"],
  ["GET", "/api/profiles/colorsoft"],
  ["GET", "/api/profiles/colorsoft/settings"],
  ["PUT", "/api/profiles/colorsoft/settings/look"],
  ["POST", "/api/profiles/colorsoft/preview"],
  ["GET", "/"],
  ["GET", "/assets/x.js"],
  ["HEAD", "/api/push/profiles"],
  ["GET", "/api/push/Colorsoft/manifest"],
  ["GET", `/api/push/colorsoft/files/${HASH}`],
  ["GET", `/api/push/colorsoft/files/${HASH.slice(2)}/plugin/main.lua`],
  ["GET", "/api/push/colorsoft/manifest/x"],
  ["POST", "/api/health"],
];

const send = (app: express.Express, method: string, url: string) =>
  request(app)[method.toLowerCase() as "get" | "post" | "put" | "head"](url);

describe("the LAN guard", () => {
  it.each(ALLOWED)("lets another machine %s %s", async (method, url) => {
    const res = await send(guarded("192.168.1.30"), method, url);

    expect(res.status).toBe(200);
    expect(res.text).toBe("reached");
  });

  it.each(REFUSED)("answers another machine's %s %s with 403 JSON", async (method, url) => {
    const res = await send(guarded("192.168.1.30"), method, url);

    expect(res.status).toBe(403);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    if (method !== "HEAD") {
      expect(res.body).toEqual({ error: "only the push routes are served to other machines" });
    }
  });

  it.each(["127.0.0.1", "127.8.9.10", "::1", "::ffff:127.0.0.1"])(
    "lets loopback peer %s through everywhere",
    async (peer) => {
      for (const [method, url] of [...ALLOWED, ...REFUSED]) {
        const res = await send(guarded(peer), method, url);
        expect(res.status, `${method} ${url}`).toBe(200);
      }
    },
  );

  it.each(["::ffff:192.168.1.30", "fe80::1", "128.0.0.1", "10.127.0.1"])("treats %s as another machine", async (peer) => {
    const res = await send(guarded(peer), "GET", "/");

    expect(res.status).toBe(403);
  });

  it("treats an unknown peer as another machine", () => {
    expect(isLoopback(undefined)).toBe(false);
  });
});

describe("the studio app's guard", () => {
  const tmpDirs: string[] = [];
  afterEach(() => {
    for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
  });

  /** The studio app over an empty profiles directory, serving a built UI, as `peer` reaches it. */
  function studio(peer: string, env: Record<string, string> = {}): express.Express {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-guard-"));
    tmpDirs.push(dir);
    fs.writeFileSync(path.join(dir, "index.html"), "<!doctype html><title>KoPanda studio</title>");
    fs.mkdirSync(path.join(dir, "profiles"));
    const config = loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: path.join(dir, "profiles"), ...env });
    const outer = express();
    outer.use((req, _res, next) => {
      Object.defineProperty(req.socket, "remoteAddress", { value: peer, configurable: true });
      next();
    });
    outer.use(createApp(config, { uiDir: dir }));
    return outer;
  }

  it("refuses another machine the UI's files and the profiles API, and serves it health and push", async () => {
    const app = studio("192.168.1.30");

    expect((await request(app).get("/")).status).toBe(403);
    expect((await request(app).get("/index.html")).status).toBe(403);
    expect((await request(app).get("/api/profiles")).status).toBe(403);
    expect((await request(app).get("/api/health")).status).toBe(200);
    expect(await request(app).get("/api/push/profiles").then((res) => [res.status, res.body] as const)).toEqual([
      200,
      { profiles: [] },
    ]);
  });

  it("serves a loopback peer the UI", async () => {
    const res = await request(studio("::ffff:127.0.0.1")).get("/");

    expect(res.status).toBe(200);
    expect(res.text).toContain("<title>KoPanda studio</title>");
  });
});

describe("GET /api/health", () => {
  it("answers the bound host and port with no addresses on a loopback host", async () => {
    const res = await request(createApp(loadConfig({ KOPANDA_STUDIO_PORT: "5000" }))).get("/api/health");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true, host: "127.0.0.1", port: 5000, addresses: [] });
  });

  it("lists this machine's non-internal IPv4 addresses on a LAN host", async () => {
    const expected = Object.values(os.networkInterfaces())
      .flatMap((infos) => infos ?? [])
      .filter((info) => info.family === "IPv4" && !info.internal)
      .map((info) => info.address);

    const res = await request(createApp(loadConfig({ KOPANDA_STUDIO_HOST: "0.0.0.0" }))).get("/api/health");

    expect(res.body).toEqual({ ok: true, host: "0.0.0.0", port: 4490, addresses: expected });
  });
});
