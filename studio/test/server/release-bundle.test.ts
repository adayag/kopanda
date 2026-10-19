import { afterEach, describe, expect, it } from "vitest";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { buildBundle, buildReleaseBundle, hashTree, sha256Hex } from "../../src/server/bundle.js";

const repo = path.join(import.meta.dirname, "..", "..", "..");
const tsx = path.join(repo, "studio", "node_modules", ".bin", "tsx");
const cli = path.join(repo, "studio", "src", "server", "release-bundle.ts");

const tmpDirs: string[] = [];
afterEach(() => {
  for (const dir of tmpDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

function tempDir(): string {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "kopanda-release-")));
  tmpDirs.push(dir);
  return dir;
}

const META = `-- The release sets version = "X.Y.Z" in its copy; only the key's own line is rewritten.
return {
    fullname = "KoPanda",
    version = "0.0.0-dev",
}
`;

/** A plugin folder holding main.lua, icons/a.svg and _meta.lua (META unless given; none for null). */
function pluginDir(meta: string | null = META): string {
  const dir = path.join(tempDir(), "kopanda.koplugin");
  fs.mkdirSync(path.join(dir, "icons"), { recursive: true });
  fs.writeFileSync(path.join(dir, "main.lua"), "return {}\n");
  fs.writeFileSync(path.join(dir, "icons", "a.svg"), "<svg/>");
  if (meta !== null) fs.writeFileSync(path.join(dir, "_meta.lua"), meta);
  return dir;
}

const text = (bytes: Uint8Array | undefined) => Buffer.from(bytes ?? []).toString("utf8");

describe("buildReleaseBundle", () => {
  it("holds every plugin file under plugin/ and no settings.lua", async () => {
    const bundle = await buildReleaseBundle({ pluginDir: pluginDir(), version: "1.2.3" });

    expect([...bundle.files.keys()].sort()).toEqual(["plugin/_meta.lua", "plugin/icons/a.svg", "plugin/main.lua"]);
  });

  it("sets _meta.lua's version line to the release's and changes nothing else", async () => {
    const bundle = await buildReleaseBundle({ pluginDir: pluginDir(), version: "1.2.3" });

    expect(text(bundle.files.get("plugin/_meta.lua"))).toBe(META.replace('version = "0.0.0-dev"', 'version = "1.2.3"'));
    expect(text(bundle.files.get("plugin/main.lua"))).toBe("return {}\n");
  });

  it("refuses a _meta.lua without a version line, naming it", async () => {
    const dir = pluginDir('return {\n    fullname = "KoPanda",\n}\n');

    await expect(buildReleaseBundle({ pluginDir: dir, version: "1.2.3" })).rejects.toThrow("plugin/_meta.lua");
  });

  it("refuses a _meta.lua with two version lines, naming it", async () => {
    const dir = pluginDir('return {\n    version = "0.1.0",\n    version = "0.2.0",\n}\n');

    await expect(buildReleaseBundle({ pluginDir: dir, version: "1.2.3" })).rejects.toThrow("plugin/_meta.lua");
  });

  it("refuses a plugin folder without _meta.lua, naming it", async () => {
    await expect(buildReleaseBundle({ pluginDir: pluginDir(null), version: "1.2.3" })).rejects.toThrow(
      "plugin/_meta.lua",
    );
  });

  it("hashes exactly its files, the rewritten _meta.lua included", async () => {
    const bundle = await buildReleaseBundle({ pluginDir: pluginDir(), version: "1.2.3" });

    expect(bundle.hash).toBe(hashTree(bundle.files));
    const other = await buildReleaseBundle({ pluginDir: pluginDir(), version: "1.2.4" });
    expect(other.hash).not.toBe(bundle.hash);
  });

  it("lists the release manifest: format 1, profile release, settings false, files in byte order", async () => {
    // a.lua beside a/: a depth-first walk reaches a/b.lua first, but '.' (0x2E) sorts before '/' (0x2F).
    const dir = pluginDir();
    fs.mkdirSync(path.join(dir, "a"));
    fs.writeFileSync(path.join(dir, "a", "b.lua"), "return 2\n");
    fs.writeFileSync(path.join(dir, "a.lua"), "return 1\n");
    const bundle = await buildReleaseBundle({ pluginDir: dir, version: "1.2.3" });

    const meta = bundle.files.get("plugin/_meta.lua") as Uint8Array;
    expect(bundle.manifest()).toEqual({
      format: 1,
      profile: "release",
      hash: bundle.hash,
      settings: false,
      files: [
        { path: "plugin/_meta.lua", size: meta.length, sha256: sha256Hex(meta) },
        { path: "plugin/a.lua", size: 9, sha256: sha256Hex(Buffer.from("return 1\n")) },
        { path: "plugin/a/b.lua", size: 9, sha256: sha256Hex(Buffer.from("return 2\n")) },
        { path: "plugin/icons/a.svg", size: 6, sha256: sha256Hex(Buffer.from("<svg/>")) },
        { path: "plugin/main.lua", size: 10, sha256: sha256Hex(Buffer.from("return {}\n")) },
      ],
    });
  });

  it("lists every other plugin file as the LAN route's manifest does", async () => {
    const dir = pluginDir();
    const release = await buildReleaseBundle({ pluginDir: dir, version: "1.2.3" });
    const lan = await buildBundle({ pluginDir: dir, settingsPath: path.join(dir, "..", "none.lua") });

    const others = (files: { path: string }[]) =>
      files.filter((file) => file.path !== "plugin/_meta.lua" && file.path !== "settings.lua");
    expect(others(release.manifest().files)).toEqual(others(lan.manifestFor("release").files));
  });
});

/** Runs the release CLI with these arguments; its exit status and output. */
function runCli(args: string[]) {
  const run = spawnSync(tsx, [cli, ...args], { encoding: "utf8" });
  return { status: run.status, stdout: run.stdout, stderr: run.stderr };
}

/** Every regular file under dir, as forward-slash paths relative to it. */
function walk(dir: string, prefix = ""): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory() ? walk(path.join(dir, entry.name), `${prefix}${entry.name}/`) : [`${prefix}${entry.name}`],
  );
}

describe("the release CLI", () => {
  it("writes manifest.json as the release manifest, keys sorted, with a trailing newline", async () => {
    const dir = pluginDir();
    const out = path.join(tempDir(), "new", "release");

    const run = runCli(["1.2.3", out, dir]);

    expect(run.stderr).toBe("");
    expect(run.status).toBe(0);
    const written = fs.readFileSync(path.join(out, "manifest.json"), "utf8");
    expect(written.endsWith("}\n")).toBe(true);
    const manifest = JSON.parse(written) as { files: object[] };
    expect(manifest).toEqual((await buildReleaseBundle({ pluginDir: dir, version: "1.2.3" })).manifest());
    expect(Object.keys(manifest)).toEqual(["files", "format", "hash", "profile", "settings"]);
    for (const file of manifest.files) expect(Object.keys(file)).toEqual(["path", "sha256", "size"]);
  });

  it("zips exactly the manifest's files under kopanda.koplugin/, with the manifest's bytes", () => {
    const out = tempDir();
    // A stale zip in the out dir: the new one replaces it rather than adding to it.
    fs.writeFileSync(path.join(out, "stale.txt"), "old");
    execFileSync("zip", ["-q", "kopanda.koplugin.zip", "stale.txt"], { cwd: out });

    expect(runCli(["1.2.3", out, pluginDir()]).status).toBe(0);

    const zip = path.join(out, "kopanda.koplugin.zip");
    const manifest = JSON.parse(fs.readFileSync(path.join(out, "manifest.json"), "utf8")) as {
      files: { path: string; size: number; sha256: string }[];
    };
    const expected = manifest.files.map((file) => `kopanda.koplugin/${file.path.slice("plugin/".length)}`);
    const entries = execFileSync("unzip", ["-Z1", zip], { encoding: "utf8" }).split("\n").filter(Boolean);
    expect(entries.sort()).toEqual([...expected].sort());

    const unpacked = tempDir();
    execFileSync("unzip", ["-q", zip, "-d", unpacked]);
    expect(walk(unpacked).sort()).toEqual([...expected].sort());
    const folder = path.join(unpacked, "kopanda.koplugin");
    for (const file of manifest.files) {
      const bytes = fs.readFileSync(path.join(folder, file.path.slice("plugin/".length)));
      expect({ size: bytes.length, sha256: sha256Hex(bytes) }, file.path).toEqual({
        size: file.size,
        sha256: file.sha256,
      });
    }
    expect(fs.readFileSync(path.join(folder, "_meta.lua"), "utf8")).toContain('version = "1.2.3"');
  });

  it.each(["1.2", "v1.2.3", "1.2.3-dev"])("exits 2 with usage for the version %s", (version) => {
    const run = runCli([version, tempDir()]);

    expect(run.status).toBe(2);
    expect(run.stderr).toContain("usage:");
  });

  it("exits 2 with usage without an out dir", () => {
    const run = runCli(["1.2.3"]);

    expect(run.status).toBe(2);
    expect(run.stderr).toContain("usage:");
  });

  it("exits 2 with usage for an empty plugin dir", () => {
    const run = runCli(["1.2.3", tempDir(), ""]);

    expect(run.status).toBe(2);
    expect(run.stderr).toContain("usage:");
  });

  it("exits 1 naming plugin/_meta.lua when it has no version line, and writes nothing", () => {
    const out = path.join(tempDir(), "release");

    const run = runCli(["1.2.3", out, pluginDir("return {}\n")]);

    expect(run.status).toBe(1);
    expect(run.stderr).toContain("plugin/_meta.lua");
    expect(fs.existsSync(out)).toBe(false);
  });
});

/** The first executable named tool on the test's own PATH. */
function which(tool: string): string {
  for (const dir of (process.env.PATH ?? "").split(path.delimiter)) {
    const file = path.join(dir, tool);
    try {
      fs.accessSync(file, fs.constants.X_OK);
      return file;
    } catch {
      continue;
    }
  }
  throw new Error(`${tool} is not on PATH`);
}

/** A PATH of one scratch folder linking bash and dirname (what bin/bundle needs to start) and these tools. */
function pathWith(tools: string[]): string {
  const dir = tempDir();
  for (const tool of ["bash", "dirname", ...tools]) fs.symlinkSync(which(tool), path.join(dir, tool));
  return dir;
}

describe("bin/bundle", () => {
  it("writes the release into an out dir relative to the caller's directory", () => {
    const cwd = tempDir();

    execFileSync(path.join(repo, "bin", "bundle"), ["1.2.3", "rel", pluginDir()], { cwd });

    expect(fs.readdirSync(path.join(cwd, "rel")).sort()).toEqual(["kopanda.koplugin.zip", "manifest.json"]);
  });

  it("refuses with exit 2 without studio/node_modules", () => {
    const root = tempDir();
    fs.mkdirSync(path.join(root, "bin"));
    fs.copyFileSync(path.join(repo, "bin", "bundle"), path.join(root, "bin", "bundle"));

    const run = spawnSync(path.join(root, "bin", "bundle"), ["1.2.3", tempDir()], { encoding: "utf8" });

    expect(run.status).toBe(2);
    expect(run.stderr).toContain("studio/node_modules");
  });

  it.each([
    ["zip", ["npm"]],
    ["npm", ["zip"]],
  ])("refuses with exit 2 when %s is not on PATH", (missing, present) => {
    const run = spawnSync(path.join(repo, "bin", "bundle"), ["1.2.3", tempDir()], {
      encoding: "utf8",
      env: { ...process.env, PATH: pathWith(present) },
    });

    expect(run.status).toBe(2);
    expect(run.stderr).toContain(`bin/bundle: ${missing} is not on PATH`);
  });
});
