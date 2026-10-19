import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import { buildReleaseBundle, DEFAULT_PLUGIN_DIR } from "./bundle.js";

/**
 * Writes a release's two assets: `<out_dir>/manifest.json` and `<out_dir>/kopanda.koplugin.zip`,
 * the plugin folder at the zip's top level holding the bundle's files byte for byte.
 *
 *   tsx src/server/release-bundle.ts <X.Y.Z> <out_dir> [plugin_dir]
 *
 * Exit 0 on success, 1 when the bundle cannot be built or written, 2 for bad arguments.
 */

const USAGE = "usage: bin/bundle <X.Y.Z> <out_dir> [plugin_dir]";
const VERSION = /^\d+\.\d+\.\d+$/;
const FOLDER = "kopanda.koplugin";
const ZIP = `${FOLDER}.zip`;

/** `value` as JSON with every object's keys sorted, so two runs are byte-identical. */
function sortedJson(value: unknown): string {
  return JSON.stringify(
    value,
    (_key, inner: unknown) =>
      inner !== null && typeof inner === "object" && !Array.isArray(inner)
        ? Object.fromEntries(Object.entries(inner).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))
        : inner,
    4,
  );
}

async function writeRelease(version: string, outDir: string, pluginDir: string): Promise<void> {
  const bundle = await buildReleaseBundle({ pluginDir, version });
  const work = await fs.mkdtemp(path.join(os.tmpdir(), "kopanda-release-"));
  try {
    for (const [rel, bytes] of bundle.files) {
      const file = path.join(work, FOLDER, rel.slice("plugin/".length));
      await fs.mkdir(path.dirname(file), { recursive: true });
      await fs.writeFile(file, bytes);
    }
    // -X: no extra attributes; -D: file entries only. COPYFILE_DISABLE keeps macOS from adding
    // AppleDouble resource forks, so the zip holds the bundle's files and nothing else.
    await promisify(execFile)("zip", ["-X", "-D", "-q", "-r", ZIP, FOLDER], {
      cwd: work,
      env: { ...process.env, COPYFILE_DISABLE: "1" },
    });
    await fs.mkdir(outDir, { recursive: true });
    await fs.copyFile(path.join(work, ZIP), path.join(outDir, ZIP));
    await fs.writeFile(path.join(outDir, "manifest.json"), `${sortedJson(bundle.manifest())}\n`);
  } finally {
    await fs.rm(work, { recursive: true, force: true });
  }
}

const [version, outDir, pluginDir = DEFAULT_PLUGIN_DIR, ...rest] = process.argv.slice(2);
if (version === undefined || !VERSION.test(version) || !outDir || !pluginDir || rest.length > 0) {
  console.error(USAGE);
  process.exit(2);
}

writeRelease(version, path.resolve(outDir), path.resolve(pluginDir)).catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
