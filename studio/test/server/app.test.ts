import { afterEach, describe, expect, it } from "vitest";
import express from "express";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { HttpError } from "../../src/server/http-error.js";

const tmpDirs: string[] = [];
afterEach(() => {
  for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

function tempUiDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-ui-"));
  tmpDirs.push(dir);
  fs.writeFileSync(path.join(dir, "index.html"), "<!doctype html><title>KoPanda studio</title>");
  return dir;
}

describe("unknown API paths", () => {
  it("answer 404 JSON with an error", async () => {
    const res = await request(createApp(loadConfig({}))).get("/api/x");

    expect(res.status).toBe(404);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    expect(res.body).toEqual({ error: "not found: GET /api/x" });
  });

  it("answer 404 JSON even when a UI directory is served", async () => {
    const uiDir = tempUiDir();
    fs.mkdirSync(path.join(uiDir, "api"));
    fs.writeFileSync(path.join(uiDir, "api", "x"), "a file the static handler would serve");

    const res = await request(createApp(loadConfig({}), { uiDir })).get("/api/x");

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: "not found: GET /api/x" });
  });
});

describe("the error handler", () => {
  it("answers an HttpError with its status and message as JSON", async () => {
    const api = express.Router();
    api.get("/teapot", () => {
      throw new HttpError(418, "short and stout");
    });
    const app = createApp(loadConfig({}), { api });

    const res = await request(app).get("/api/teapot");

    expect(res.status).toBe(418);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    expect(res.body).toEqual({ error: "short and stout" });
  });
});

describe("the built UI", () => {
  it("is served from the UI directory given", async () => {
    const res = await request(createApp(loadConfig({}), { uiDir: tempUiDir() })).get("/");

    expect(res.status).toBe(200);
    expect(res.text).toContain("<title>KoPanda studio</title>");
  });

  it("is a 404, not a crash, when no UI directory is given", async () => {
    const res = await request(createApp(loadConfig({}))).get("/");

    expect(res.status).toBe(404);
  });
});
