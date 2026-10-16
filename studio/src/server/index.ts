import fs from "node:fs";
import path from "node:path";
import { loadConfig, type Config } from "./config.js";
import { ensureProfilesDir } from "./profiles.js";
import { startLines, startServer } from "./start.js";

// src/server/index.ts and dist/server/index.js both sit two levels below the studio's root.
const studioRoot = path.resolve(import.meta.dirname, "../..");

// The built server (dist/server/index.js) serves the built UI. Under tsx this module is
// src/server/index.ts and the UI comes from the Vite dev server, even when an old build exists.
const uiDir = path.join(studioRoot, "dist/ui");
const fromBuild = import.meta.filename === path.join(studioRoot, "dist/server/index.js");
const hasBuiltUi = fromBuild && fs.existsSync(path.join(uiDir, "index.html"));

let config: Config;
try {
  config = loadConfig();
} catch (err) {
  // A config error's message names the variable and its bad value; a stack trace would only bury it.
  console.error((err as Error).message);
  process.exit(1);
}

ensureProfilesDir(config.profilesDir)
  .then(() => startServer(config, hasBuiltUi ? { uiDir } : {}))
  .then((server) => {
    for (const line of startLines(server.host, server.port)) console.log(line);
    if (!hasBuiltUi) console.log("UI: run `npm run dev` for the Vite dev server, or `npm run build` first");
  })
  .catch((err: unknown) => {
    console.error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  });
