import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { HttpError } from "./http-error.js";

/**
 * The repo's kopanda.koplugin/. src/server/bundle.ts and dist/server/bundle.js both sit three
 * levels below the repo's root.
 */
export const DEFAULT_PLUGIN_DIR = path.resolve(import.meta.dirname, "../../..", "kopanda.koplugin");

/** A bundle's files: forward-slash bundle path -> bytes. */
export type Tree = Map<string, Uint8Array>;

export interface ManifestFile {
  path: string;
  size: number;
  sha256: string;
}

/** What `GET /api/push/:id/manifest` answers; the device refuses any other `format`. */
export interface Manifest {
  format: 1;
  profile: string;
  hash: string;
  /** Every file, in the hash's order. */
  files: ManifestFile[];
}

/** A release's manifest: the plugin's files only, so the device leaves its settings file alone. */
export interface ReleaseManifest extends Manifest {
  profile: "release";
  settings: false;
}

export interface Bundle {
  manifestFor(profileId: string): Manifest;
  files: Tree;
  hash: string;
}

/** What a plugin entry's name, and so each segment of a bundle path, must match; the device refuses the rest. */
const SEGMENT = /^[A-Za-z0-9._-]+$/;

/** `_meta.lua`'s version line: the key at the start of its line, then its quoted value. */
const VERSION_LINE = /^([ \t]*version[ \t]*=[ \t]*)"[^"\n]*"/gm;

/** A settings file's header naming an absolute path ending in the settings file's name. */
const ABSOLUTE_HEADER = /^-- \/.+\/settings\/kopanda\/settings\.lua$/;

const HEADER = "-- settings/kopanda/settings.lua";

/** The settings file of a profile that has none: every key at its default. */
const DEFAULT_SETTINGS = `${HEADER}\nreturn {}\n`;

export function sha256Hex(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex");
}

/** Compare two strings by their UTF-8 bytes, the order Lua's `<` uses. */
function compareBytes(a: string, b: string): number {
  return Buffer.compare(Buffer.from(a, "utf8"), Buffer.from(b, "utf8"));
}

/** The tree's paths in UTF-8 byte order, the order used for hashing and manifests. */
function sortedPaths(tree: Tree): string[] {
  return [...tree.keys()].sort(compareBytes);
}

/**
 * Hex sha256 over the tree; insertion order does not matter. Entries are taken sorted by path in
 * UTF-8 byte order, and each is framed as: u32 big-endian path byte length, u64 big-endian content
 * byte length, the path bytes (UTF-8), then the content bytes.
 */
export function hashTree(tree: Tree): string {
  const hash = createHash("sha256");
  for (const rel of sortedPaths(tree)) {
    const pathBytes = Buffer.from(rel, "utf8");
    const bytes = tree.get(rel) as Uint8Array;
    const lengths = Buffer.alloc(12);
    lengths.writeUInt32BE(pathBytes.length, 0);
    lengths.writeBigUInt64BE(BigInt(bytes.length), 4);
    hash.update(lengths).update(pathBytes).update(bytes);
  }
  return hash.digest("hex");
}

/**
 * Adds every regular file under `dir` to `tree` as `<prefix><name>`. A dot-entry is skipped with
 * everything under it; a symlink or other non-regular entry, or a name outside SEGMENT, fails.
 */
async function readFolder(dir: string, prefix: string, tree: Tree): Promise<void> {
  const names = await fs.readdir(dir);
  for (const name of names) {
    if (name.startsWith(".")) continue;
    const rel = `${prefix}${name}`;
    if (!SEGMENT.test(name)) {
      throw new HttpError(500, `cannot bundle ${rel}: each name must match ${SEGMENT.source}`);
    }
    const full = path.join(dir, name);
    const stat = await fs.lstat(full);
    if (stat.isDirectory()) {
      await readFolder(full, `${rel}/`, tree);
    } else if (stat.isFile()) {
      tree.set(rel, await fs.readFile(full));
    } else {
      throw new HttpError(500, `cannot bundle ${rel}: it is not a regular file or folder`);
    }
  }
}

/** The tree's files as a manifest lists them, in the hash's order. */
function listFiles(tree: Tree): ManifestFile[] {
  return sortedPaths(tree).map((rel) => {
    const bytes = tree.get(rel) as Uint8Array;
    return { path: rel, size: bytes.length, sha256: sha256Hex(bytes) };
  });
}

/**
 * The settings file as served: a first line naming an absolute path ending in the settings file's
 * name becomes HEADER, so no Mac path leaves the machine; any other first line is kept.
 */
async function readSettings(settingsPath: string): Promise<Uint8Array> {
  let bytes: Buffer;
  try {
    bytes = await fs.readFile(settingsPath);
  } catch (err) {
    if ((err as { code?: unknown }).code === "ENOENT") return Buffer.from(DEFAULT_SETTINGS, "utf8");
    throw err;
  }
  const newline = bytes.indexOf(0x0a);
  const end = newline === -1 ? bytes.length : newline;
  if (!ABSOLUTE_HEADER.test(bytes.subarray(0, end).toString("utf8"))) return bytes;
  return Buffer.concat([Buffer.from(HEADER, "utf8"), bytes.subarray(end)]);
}

/**
 * A profile's bundle as it is on disk now: every regular file under the plugin folder as
 * `plugin/<rel>` and the profile's settings file as `settings.lua`.
 */
export async function buildBundle({
  pluginDir = DEFAULT_PLUGIN_DIR,
  settingsPath,
}: {
  pluginDir?: string;
  settingsPath: string;
}): Promise<Bundle> {
  const files: Tree = new Map();
  await readFolder(pluginDir, "plugin/", files);
  files.set("settings.lua", await readSettings(settingsPath));
  const hash = hashTree(files);
  const listed = listFiles(files);
  return {
    files,
    hash,
    manifestFor: (profile) => ({ format: 1, profile, hash, files: listed.map((file) => ({ ...file })) }),
  };
}

/**
 * A release's bundle: every regular file under the plugin folder as `plugin/<rel>`, no settings
 * file, and `plugin/_meta.lua`'s one version line set to `version`. The repo's file is not touched.
 */
export async function buildReleaseBundle({
  pluginDir = DEFAULT_PLUGIN_DIR,
  version,
}: {
  pluginDir?: string;
  version: string;
}): Promise<{ files: Tree; hash: string; manifest(): ReleaseManifest }> {
  const files: Tree = new Map();
  await readFolder(pluginDir, "plugin/", files);
  const meta = files.get("plugin/_meta.lua");
  if (meta === undefined) throw new Error("cannot build a release: the plugin has no plugin/_meta.lua");
  const source = Buffer.from(meta).toString("utf8");
  const lines = source.match(VERSION_LINE) ?? [];
  if (lines.length !== 1) {
    throw new Error(`cannot build a release: plugin/_meta.lua has ${lines.length} version lines, not one`);
  }
  const rewritten = source.replace(VERSION_LINE, (_line, key: string) => `${key}"${version}"`);
  files.set("plugin/_meta.lua", Buffer.from(rewritten, "utf8"));
  const hash = hashTree(files);
  const listed = listFiles(files);
  return {
    files,
    hash,
    manifest: () => ({
      format: 1,
      profile: "release",
      hash,
      settings: false,
      files: listed.map((file) => ({ ...file })),
    }),
  };
}
