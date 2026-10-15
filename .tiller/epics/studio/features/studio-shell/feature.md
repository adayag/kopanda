# Studio app, device profiles and the schema contract

## Summary

The studio's skeleton: server and UI, device profiles with a settings file each, and the contract with
the plugin, the schema as JSON (design §3, §6).

## Behavior

- `npm run dev` serves the UI with the API proxied; `npm start` serves a build. Config is env vars with
  one prefix and defaults, every one listed in `.env.example`.
- A device profile names a device (Colorsoft, Paperwhite), its resolution and DPI, whether it has colour,
  and owns one settings file in the plugin's format. Profiles are files under a configured directory;
  a person is a profile (design §1b).
- The schema JSON is produced from `schema.lua` by running KOReader's LuaJIT through `npm run schema`
  and checked in; a test asserts the checked-in JSON equals a fresh dump, so the form and the device menus cannot drift.
- `bin/check` gains the studio's typecheck, lint and tests.
- The first screen lists profiles and opens one.

## Specification

### The package

`studio/` is one npm package on the theme studio's stack and versions (theme studio `package-lock.json`
@a0de5dd): `"type": "module"`, `engines.node ">=22"`, Express 5, React 19, Vite 8 with
`@vitejs/plugin-react`, Vitest 5, TypeScript 5.9, ESLint 10 with `typescript-eslint`, `zod` 4,
`concurrently` and `tsx` for dev, `supertest`, `jsdom` and Testing Library for tests. Nothing
SimpleUI-era comes across (no `js-yaml`, `luaparse`, `sharp`, fonts or theme stores).

Layout, the theme studio's shape: `studio/index.html`, `studio/src/server/` (Express, Node only),
`studio/src/ui/` (React), `studio/test/`, two tsconfigs (the bundler one for the UI and tests, a NodeNext
one for the server build). Scripts:

- `npm run dev`: the server under `tsx watch` and Vite together; Vite's dev server proxies `/api` to the
  server's port, read from the same config module, so a changed port moves both.
- `npm run build`: Vite builds the UI to `dist/ui`, `tsc` builds the server to `dist/server`.
- `npm start`: `node dist/server/index.js`, serving `dist/ui` and the API from one port.
- `npm run typecheck`, `npm run lint`, `npm test`, and `npm run check` running those three in order.
- `npm run schema`: rewrites the checked-in schema JSON (below).

The server binds to `127.0.0.1` only. Serving other machines, and the guard that limits what they
can reach, arrive with `studio/device-push`.

### Config

Every studio variable starts `KOPANDA_STUDIO_`, so none clashes with the spec harness's `KOPANDA_*`
variables. An unset or empty variable takes its default; a value of `~` or a leading `~/` expands to the home directory.

| Variable | Default | Meaning |
|---|---|---|
| `KOPANDA_STUDIO_PORT` | `4490` | The port the server listens on (`npm start`, and the API under `npm run dev`). An integer 1–65535, otherwise the server refuses to start, naming the variable and the value. |
| `KOPANDA_STUDIO_PROFILES_DIR` | `~/.kopanda/profiles` | The directory holding the device profiles. |

4490 rather than the theme studio's 4480 so both can run at once. Each variable is listed in
`.env.example` with a comment line above it, as the file's existing entries are. Nothing loads `.env`
automatically. A server that cannot start (a bad port, a port in use) prints one line saying why and
exits 1.

### Device profiles

Profiles live beside the repo, not in it (owner's decision, 2026-10-15): studio edits never touch the
working tree, and the household member's settings are not committed.

One profile is one directory under the profiles directory, named by its id, shaped like a `KO_HOME`
so the preview can use it as one:

```
<profiles dir>/
  colorsoft/
    profile.json
    settings/kopanda/settings.lua
  paperwhite/
    profile.json
    settings/kopanda/settings.lua
```

`profile.json` holds `name` (shown in the list, the person's or the device's name), `device` (the
model, e.g. "Kindle Colorsoft SE"), `width`, `height`, `dpi` and `color`. The id is the directory name
and matches `^[a-z0-9-]+$`. `settings/kopanda/settings.lua` is the path the plugin reads under a
`KO_HOME` (`kopanda.koplugin/settings.lua:233-239`, KOReader `datastorage.lua:19-20,60-62`
@e1fe1ac). A profile with no settings file yet is valid and means every key at its default, which is
also how the plugin reads a missing file. This feature never writes or parses a settings file; reading
and writing one arrives with `studio/settings-form`.

When the profiles directory does not exist, the server creates it with the two known profiles,
Colorsoft (1264×1680 @ 300, colour) and Paperwhite (1236×1648 @ 300, greyscale), from one seed file
in the studio, `studio/src/server/default-profiles.json`, and no settings files. An existing directory,
empty or not, is never seeded or changed. The seed's dimensions are the ones the emulator specs
capture at (`spec/emulator/profiles.lua:3-6`); a Lua spec asserts they agree, so the studio and the
goldens cannot disagree about a device.

Profiles are read from disk on each request, so a profile edited or added by hand shows without a
restart. A directory without a `profile.json` is skipped. A `profile.json` that is not valid JSON or
fails validation (missing or mistyped field, non-positive size) is listed as invalid with the reason,
not dropped and not fatal, so a hand edit gone wrong is visible.

API, JSON throughout:

- `GET /api/profiles`: `{ dir, profiles: [...] }`, the profiles directory's absolute path and the profiles in id order, each with `id`, `name`, `device`, `width`,
  `height`, `dpi`, `color` and `has_settings`, or `id` and `error` for an invalid one.
- `GET /api/profiles/:id`: one valid profile as above, plus `settings_path`, the settings file's
  absolute path; `404 { error }` for an id that is not a valid profile.
- Any other `/api` path is `404 { error }`; a thrown error is `500 { error }` with the message.

### The schema contract

`studio/src/schema.json` is checked in and is byte-for-byte the output of `bin/schema-json` (sorted keys,
pretty, trailing newline; `bin/schema-json:19-24`). `npm run schema` rewrites it from `../bin/schema-json`.
The studio imports this file; nothing in the studio runs LuaJIT, so `npm run build`, `npm start` and
`npm test` work without the emulator. A Lua unit spec diffs the checked-in file against a fresh
`bin/schema-json` run and fails naming `npm run schema` as the fix, so a `schema.lua` change that
skips the regeneration fails `bin/check`. The studio carries a TypeScript type for the schema's shape
(`version`, and `keys` as an ordered array of `id`, `type`, `default`, `label`, `group` plus the
type-specific fields, `kopanda.koplugin/schema.lua:6-118`) and a test that the checked-in file
satisfies it, so a new key type fails the schema test rather than surfacing at runtime in the form.

### The first screen

The studio's first screen lists the profiles: each row shows the name, the device, resolution, DPI and
colour or greyscale, and whether a settings file exists yet; an invalid profile shows its id and
reason and does not open; an empty directory shows "No profiles in <dir>". Choosing a profile opens it: a profile screen naming it, its device facts
and its settings file path, with "All settings at their defaults" when there is no file yet, and a way
back to the list. The profile screen is the page `studio/settings-form` fills with the form. The open
profile is in the URL hash (`#/profiles/<id>`), so a reload stays on it and no server fallback route
is needed. An unknown id in the hash shows "No profile <id>" with the way back. A failed request shows
its error in place of the list. Loading shows a one-line "Loading profiles". Visual direction is the
theme studio's 2026-10-09 default (dark, one violet accent) at its simplest; this screen gets no
drawn board.

### bin/check

`bin/check` with no arguments runs a `== studio` stage after lint and before the unit specs:
`npm run check` in `studio/` (typecheck, lint, tests). It comes before the Lua specs because it is
the faster to fail. If `node` is not on `PATH`, or `studio/node_modules` is missing, the no-argument
run refuses with exit 2 and the commands to fix it (`brew install node` when node is missing, then
`npm ci --prefix studio`), as the luacheck refusal does; the `--lint` and named-spec modes do not require node and behave as before. `bin/check --lint`
stays luacheck alone. luacheck skips `studio/node_modules` and `studio/dist`. Every checkout and
worktree that runs `bin/check` (the Tiller gates included) needs `npm ci --prefix studio` once.

## Notes

The theme studio's `src/server/config.ts`, `lan-guard.ts` and its Express and Vite setup are the
reference shape; copy what fits, it's the owner's code. `lan-guard.ts` is device-push's, not this
feature's, because this feature never listens beyond loopback.

The two `KOPANDA_STUDIO_*` variables are new. AGENTS.md asks that `~/Projects/strem` (compose,
`.env.example`, `.env.enc`) get the same change; the studio runs only locally and is not a strem
service, so whether strem needs them is the owner's call at approval.
