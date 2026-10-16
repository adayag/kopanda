import { afterEach, describe, expect, it } from "vitest";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { buildBundle, DEFAULT_PLUGIN_DIR, hashTree } from "../../src/server/bundle.js";

const repo = path.join(import.meta.dirname, "..", "..", "..");
const vectors = path.join(repo, "spec", "fixtures", "push");

const tmpDirs: string[] = [];
afterEach(() => {
  for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

function tempDir(): string {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-bundle-")));
  tmpDirs.push(dir);
  return dir;
}

/** Writes each relative path's text under dir, making folders. */
function writeFiles(dir: string, files: Record<string, string>): void {
  for (const [rel, text] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), text);
  }
}

/** A plugin folder holding main.lua and _meta.lua, plus any further files given. */
function pluginDir(extra: Record<string, string> = {}): string {
  const dir = path.join(tempDir(), "kopanda.koplugin");
  writeFiles(dir, { "main.lua": "return {}\n", "_meta.lua": "return {}\n", ...extra });
  return dir;
}

const text = (bytes: Uint8Array | undefined) => Buffer.from(bytes ?? []).toString("utf8");

describe("the shared vectors", () => {
  it("build the manifest in spec/fixtures/push/manifest.json byte for byte", async () => {
    const bundle = await buildBundle({
      pluginDir: path.join(vectors, "tree", "plugin"),
      settingsPath: path.join(vectors, "tree", "settings.lua"),
    });

    const written = `${JSON.stringify(bundle.manifestFor("vector"), null, 2)}\n`;

    expect(written).toBe(fs.readFileSync(path.join(vectors, "manifest.json"), "utf8"));
  });

  it("hold each file's bytes under its bundle path, and the manifest's hash", async () => {
    const tree = path.join(vectors, "tree");
    const bundle = await buildBundle({
      pluginDir: path.join(tree, "plugin"),
      settingsPath: path.join(tree, "settings.lua"),
    });

    expect([...bundle.files.keys()].sort()).toEqual([
      "plugin/_meta.lua",
      "plugin/icons/a.svg",
      "plugin/main.lua",
      "settings.lua",
    ]);
    for (const [rel, bytes] of bundle.files) {
      expect(Buffer.from(bytes).equals(fs.readFileSync(path.join(tree, rel))), rel).toBe(true);
    }
    expect(bundle.hash).toBe(bundle.manifestFor("vector").hash);
  });
});

describe("hashTree", () => {
  it("is the sha256 of nothing for an empty tree", () => {
    expect(hashTree(new Map())).toBe("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  });

  it("does not depend on insertion order", () => {
    const a: [string, Uint8Array][] = [
      ["plugin/main.lua", Buffer.from("x")],
      ["plugin/_meta.lua", Buffer.from("y")],
      ["settings.lua", Buffer.from("z")],
    ];

    expect(hashTree(new Map(a))).toBe(hashTree(new Map([...a].reverse())));
  });

  it("takes paths in UTF-8 byte order, not UTF-16 order", () => {
    // U+FF61 (EF BD A1) sorts before U+10000 (F0 90 80 80) in UTF-8 bytes, after its surrogate D800 in UTF-16.
    const high = "\u{10000}";
    const low = "｡";
    const framed = (rel: string, body: string) => {
      const pathBytes = Buffer.from(rel, "utf8");
      const lengths = Buffer.alloc(12);
      lengths.writeUInt32BE(pathBytes.length, 0);
      lengths.writeBigUInt64BE(BigInt(Buffer.byteLength(body)), 4);
      return Buffer.concat([lengths, pathBytes, Buffer.from(body)]);
    };
    const expected = createHash("sha256")
      .update(Buffer.concat([framed(low, "a"), framed(high, "b")]))
      .digest("hex");

    expect(hashTree(new Map([[high, Buffer.from("b")], [low, Buffer.from("a")]]))).toBe(expected);
  });
});

describe("buildBundle's plugin folder", () => {
  it("leaves out a dot-entry and everything under a dot-folder", async () => {
    const dir = pluginDir({ ".DS_Store": "junk", ".git/x": "junk", "icons/.hidden/y.svg": "junk" });

    const bundle = await buildBundle({ pluginDir: dir, settingsPath: path.join(dir, "..", "none.lua") });

    expect([...bundle.files.keys()].sort()).toEqual(["plugin/_meta.lua", "plugin/main.lua", "settings.lua"]);
  });

  it("refuses a symlink, naming its path", async () => {
    const dir = pluginDir();
    fs.mkdirSync(path.join(dir, "icons"));
    fs.symlinkSync(path.join(dir, "main.lua"), path.join(dir, "icons", "link.svg"));

    await expect(buildBundle({ pluginDir: dir, settingsPath: path.join(dir, "..", "none.lua") })).rejects.toMatchObject({
      status: 500,
      message: expect.stringContaining("plugin/icons/link.svg") as unknown,
    });
  });

  it("refuses a name outside [A-Za-z0-9._-], naming its path", async () => {
    const dir = pluginDir({ "a b.lua": "return 1\n" });

    await expect(buildBundle({ pluginDir: dir, settingsPath: path.join(dir, "..", "none.lua") })).rejects.toMatchObject({
      status: 500,
      message: expect.stringContaining("plugin/a b.lua") as unknown,
    });
  });

  it("defaults to the repo's kopanda.koplugin", () => {
    expect(DEFAULT_PLUGIN_DIR).toBe(path.join(repo, "kopanda.koplugin"));
  });
});

describe("buildBundle's settings file", () => {
  const body = 'return {\n    ["look"] = "diner",\n}\n';

  async function served(firstLine: string | undefined): Promise<string> {
    const dir = tempDir();
    const settingsPath = path.join(dir, "settings", "kopanda", "settings.lua");
    if (firstLine !== undefined) {
      writeFiles(dir, { "settings/kopanda/settings.lua": `${firstLine.replace("<own>", settingsPath)}\n${body}` });
    }
    const bundle = await buildBundle({ pluginDir: pluginDir(), settingsPath });
    return text(bundle.files.get("settings.lua"));
  }

  it.each(["-- <own>", "-- /Users/other/p/settings/kopanda/settings.lua"])(
    "rewrites the absolute-path header %s and keeps the rest byte for byte",
    async (header) => {
      expect(await served(header)).toBe(`-- settings/kopanda/settings.lua\n${body}`);
    },
  );

  it.each(["-- settings/kopanda/settings.lua", "-- /a/settings/kopanda/settings.lua.bak", "return {"])(
    "keeps the first line %s as it is",
    async (line) => {
      const answer = await served(line);
      expect(answer).toBe(`${line}\n${body}`);
      expect(answer).not.toBe("-- settings/kopanda/settings.lua\nreturn {}\n");
    },
  );

  it("serves a missing file as every key at its default", async () => {
    expect(await served(undefined)).toBe("-- settings/kopanda/settings.lua\nreturn {}\n");
  });
});
