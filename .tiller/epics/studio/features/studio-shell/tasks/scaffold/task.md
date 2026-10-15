# Studio package, env config, Express server and Vite UI with dev and start

## Approach

Create `studio/` as one npm package on the theme studio's shape and versions
(`~/Projects/elatedpanda/koreader-theme-studio` @a0de5dd; read it, copy what fits, it is the owner's
code). Pin the versions its `package-lock.json` resolved: express 5.3.0, react and react-dom 19.3.0,
zod 4.6.5; vite 8.3.4, vitest 5.0.3, @vitejs/plugin-react 6.1.2, typescript 5.9.3, eslint 10.12.0 with
@eslint/js, typescript-eslint, eslint-plugin-react-hooks and globals, concurrently, tsx, supertest,
@types/*, jsdom and @testing-library/react, /dom and /jest-dom (theme studio `package.json:32-70`).
Leave out every SimpleUI-era dependency (js-yaml, luaparse, sharp, @fontsource, pngjs, pixelmatch).
Commit `studio/package-lock.json`.

1. `package.json`: `"type": "module"`, `engines.node ">=22"`, `private: true`, scripts `dev`
   (`concurrently` running `tsx watch src/server/index.ts` and `vite`), `build` (`vite build && tsc -p
   tsconfig.server.json`), `start` (`node dist/server/index.js`), `typecheck` (both tsconfigs,
   `--noEmit`), `lint` (`eslint .`), `test` (`vitest run`), `check` (typecheck, lint, test in order).
   Theme studio `package.json:11-30`.
2. `tsconfig.json` and `tsconfig.server.json` as the theme studio's (`tsconfig.json:2-18`,
   `tsconfig.server.json:1-13`), the server one covering `src/server` only.
3. `src/server/config.ts`: `loadConfig(env = process.env)`, pure, returning `{ port, profilesDir }`
   from `KOPANDA_STUDIO_PORT` (default 4490) and `KOPANDA_STUDIO_PROFILES_DIR` (default
   `~/.kopanda/profiles`); empty means default; leading `~` or `~/` expands to `os.homedir()`; a port
   that is not all digits or outside 1–65535 throws `KOPANDA_STUDIO_PORT must be a port number, got
   "<v>"`. Theme studio `src/server/config.ts:14-42` is the model, minus its host, themes, emulator,
   library and cache variables. Export the variable names as one list so the `.env.example` test reads
   them from the code, not a copy.
4. `src/server/app.ts`: `createApp(config, options)` building the Express app: JSON `404 { error }`
   for any unmatched `/api` path, `express.static` of the built UI after it when a UI directory is
   given, and a JSON error handler reading `err.status`/`err.statusCode` (theme studio `app.ts:139-170`,
   `http-error.ts:2-10`). No health or other routes; `profiles` mounts its router here.
5. `src/server/start.ts` and `src/server/index.ts`: listen on `127.0.0.1` and the configured port,
   log `listening on http://127.0.0.1:<port>`; a config error or `EADDRINUSE` prints one line
   (the latter naming `KOPANDA_STUDIO_PORT`) and exits 1 (theme studio `index.ts:22-29,55`,
   `start.ts:15-38`). Do not copy the model's final catch (`index.ts:60-62`, `console.error(err)`),
   which prints a stack: print the message only. The built UI is served only when running from `dist/server/index.js` and
   `dist/ui/index.html` exists (theme studio `index.ts:16-20`).
6. `vite.config.ts`: React plugin, dev port 5173, proxy `/api` to `http://127.0.0.1:<port>` with the
   port from `loadConfig`, build to `dist/ui` (theme studio `vite.config.ts:3-13`). `vitest.config.ts`:
   `test/**/*.test.ts(x)`, node environment, jsdom by per-file docblock, setup file adding jest-dom
   and cleanup when `document` exists (theme studio `vitest.config.ts:4-9`, `test/ui/setup.ts:5-37`).
7. `eslint.config.js` with the theme studio's blocks (`eslint.config.js:7-27`), type-aware on
   `src/server/**`, but built with `defineConfig` from `eslint/config`: the model's `tseslint.config(...)`
   is deprecated (`typescript-eslint` `dist/config-helper.d.ts:67`).
8. `index.html` and `src/ui/main.tsx` rendering a placeholder `App` titled "KoPanda studio";
   `profile-screens` replaces its body. Dark background, one violet accent, set as CSS custom
   properties in one stylesheet.
9. `.env.example` at the repo root gains both variables, each with a comment line above, in the
   file's existing style (`.env.example:1-3`).

## Surfaces

- `studio/package.json`, `studio/package-lock.json`, `studio/tsconfig.json`,
  `studio/tsconfig.server.json`, `studio/vite.config.ts`, `studio/vitest.config.ts`,
  `studio/eslint.config.js`, `studio/index.html`
- `studio/src/server/config.ts`, `app.ts`, `start.ts`, `index.ts`, `http-error.ts`
- `studio/src/ui/main.tsx`, `App.tsx`, `styles.css`
- `studio/test/server/config.test.ts`, `index.test.ts`, `app.test.ts`, `studio/test/ui/setup.ts`
- `.env.example`

AGENTS.md asks that a new env var be reported for `~/Projects/strem` (compose, `.env.example`,
`.env.enc`); the owner settles at approval whether strem runs the studio (see the feature's Notes).

## Tests

- `test/server/config.test.ts` (C3): defaults; empty value takes the default; `~` and `~/x` expand;
  ports `0`, `65536`, `abc`, `80.5` and `-1` throw naming the variable and value; `65535` and `1` pass;
  every name in the exported variable list appears as `NAME=` at a line start in `../.env.example`.
- `test/server/index.test.ts` (C3): spawn the entry with `tsx` and `KOPANDA_STUDIO_PORT=abc`, expect
  exit 1 and stderr exactly one line naming the variable; occupy a port, start on it, expect exit 1 and
  stderr exactly one line naming `KOPANDA_STUDIO_PORT`. Both spawns set `KOPANDA_STUDIO_PROFILES_DIR`
  to a temp path, so no test touches the owner's real profiles directory once `profiles` seeds at start.
- `test/server/app.test.ts`: supertest; an unknown `/api/x` is 404 JSON with `error`; a route that
  throws an `HttpError(418)` answers 418 JSON; a static directory given to `createApp` is served.
- Confirm `npm --prefix studio test -- test/server/config.test.ts` runs only that file (the scope the
  C3 binding assumes).

## Edge cases

- A port collision between `npm run dev`'s two processes: Vite stays on 5173, the server on the
  configured port; the proxy follows the config.
- `npm start` before `npm run build`: the server starts, `/api` answers, and `/` is a 404 rather than
  a crash.
- `tsx`'s ESM resolution needs the `.js` suffix on relative server imports (theme studio `app.ts:10`).
