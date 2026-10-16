import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { spawn } from "node:child_process";
import fs from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";

const root = path.join(import.meta.dirname, "..", "..");
const entry = path.join(root, "src", "server", "index.ts");
const tsx = path.join(root, "node_modules", ".bin", "tsx");

/** A child still running after this long is killed; each test waits longer than that. */
const killAfterMs = 15_000;

let tmp: string;

beforeEach(() => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-index-"));
});

afterEach(() => {
  fs.rmSync(tmp, { recursive: true, force: true });
});

/** Runs the server entry under tsx until it exits; the profiles directory is always a temp path. */
function start(port: string): Promise<{ status: number | null; stderr: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(tsx, [entry], {
      cwd: root,
      env: {
        ...process.env,
        KOPANDA_STUDIO_PORT: port,
        KOPANDA_STUDIO_PROFILES_DIR: path.join(tmp, "profiles"),
      },
    });
    let stderr = "";
    child.stderr.setEncoding("utf8").on("data", (chunk: string) => (stderr += chunk));
    const timer = setTimeout(() => child.kill(), killAfterMs);
    child.on("error", reject);
    child.on("close", (status) => {
      clearTimeout(timer);
      resolve({ status, stderr });
    });
  });
}

/** Listens on a free loopback port and resolves with the server holding it. */
function occupyPort(): Promise<net.Server> {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

describe("the server entry point", { timeout: killAfterMs + 5_000 }, () => {
  it("exits 1 with one line naming the variable for a bad KOPANDA_STUDIO_PORT", async () => {
    const { status, stderr } = await start("abc");

    expect(status).toBe(1);
    expect(stderr).toBe('KOPANDA_STUDIO_PORT must be a port number, got "abc"\n');
  });

  it("exits 1 with one line naming KOPANDA_STUDIO_PORT when the port is in use", async () => {
    const holder = await occupyPort();
    try {
      const { port } = holder.address() as net.AddressInfo;

      const { status, stderr } = await start(String(port));

      expect(status).toBe(1);
      expect(stderr).toMatch(/^[^\n]*KOPANDA_STUDIO_PORT[^\n]*\n$/);
      expect(stderr).toContain(String(port));
    } finally {
      await new Promise((done) => holder.close(done));
    }
  });
});
