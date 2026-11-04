import { afterEach, describe, expect, it } from "vitest";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { buildReleaseBundle, DEFAULT_PLUGIN_DIR, hashTree, sha256Hex, type Tree } from "../../src/server/bundle.js";

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
  writeFiles(dir, { "main.lua": "return {}\n", "_meta.lua": 'return {\n    version = "0.0.0-dev",\n}\n', ...extra });
  return dir;
}

describe("the shared vectors", () => {
  const tree = path.join(vectors, "tree");
  const manifest = JSON.parse(fs.readFileSync(path.join(vectors, "manifest.json"), "utf8")) as {
    hash: string;
    files: { path: string; size: number; sha256: string }[];
  };

  function read(rel: string): Buffer {
    return fs.readFileSync(path.join(tree, rel));
  }

  it("hash to the manifest in spec/fixtures/push/manifest.json, as the device computes them", () => {
    const files: Tree = new Map(manifest.files.map((file) => [file.path, read(file.path)]));

    expect(hashTree(files)).toBe(manifest.hash);
    for (const file of manifest.files) {
      const bytes = read(file.path);
      expect({ size: bytes.length, sha256: sha256Hex(bytes) }, file.path).toEqual({ size: file.size, sha256: file.sha256 });
    }
  });

  it("list each plugin file as a release's manifest lists it", async () => {
    const dir = pluginDir();
    fs.cpSync(path.join(tree, "plugin", "icons"), path.join(dir, "icons"), { recursive: true });
    fs.copyFileSync(path.join(tree, "plugin", "main.lua"), path.join(dir, "main.lua"));

    const release = await buildReleaseBundle({ pluginDir: dir, version: "1.2.3" });

    const vectorFiles = manifest.files.filter((file) => file.path.startsWith("plugin/") && file.path !== "plugin/_meta.lua");
    expect(release.manifest().files.filter((file) => file.path !== "plugin/_meta.lua")).toEqual(vectorFiles);
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

describe("buildReleaseBundle's plugin folder", () => {
  it("leaves out a dot-entry and everything under a dot-folder", async () => {
    const dir = pluginDir({ ".DS_Store": "junk", ".git/x": "junk", "icons/.hidden/y.svg": "junk" });

    const bundle = await buildReleaseBundle({ pluginDir: dir, version: "1.2.3" });

    expect([...bundle.files.keys()].sort()).toEqual(["plugin/_meta.lua", "plugin/main.lua"]);
  });

  it("refuses a symlink, naming its path", async () => {
    const dir = pluginDir();
    fs.mkdirSync(path.join(dir, "icons"));
    fs.symlinkSync(path.join(dir, "main.lua"), path.join(dir, "icons", "link.svg"));

    await expect(buildReleaseBundle({ pluginDir: dir, version: "1.2.3" })).rejects.toThrow("plugin/icons/link.svg");
  });

  it("refuses a name outside [A-Za-z0-9._-], naming its path", async () => {
    const dir = pluginDir({ "a b.lua": "return 1\n" });

    await expect(buildReleaseBundle({ pluginDir: dir, version: "1.2.3" })).rejects.toThrow("plugin/a b.lua");
  });

  it("defaults to the repo's kopanda.koplugin", () => {
    expect(DEFAULT_PLUGIN_DIR).toBe(path.join(repo, "kopanda.koplugin"));
  });
});
