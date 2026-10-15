# Device profiles on disk, seeded defaults and the profiles API

## Approach

1. `studio/src/server/default-profiles.json`: `{ "colorsoft": {...}, "paperwhite": {...} }` with
   `name`, `device`, `width`, `height`, `dpi`, `color`: Colorsoft "Kindle Colorsoft SE", 1264×1680 @ 300,
   colour (handoff `.tiller/design/handoff-2026-10-08.md:40,57`); Paperwhite "Kindle Paperwhite (11th
   gen)", 1236×1648 @ 300, greyscale (`.tiller/design/2026-10-13-kopanda-ui-direction.md:38`). Names
   are "Colorsoft" and "Paperwhite"; the owner renames them in the file.
2. `studio/src/server/profiles.ts`: a zod schema for `profile.json` (theme studio
   `src/core/profiles.ts:6-32` is the model, minus its `root` field, which device-push adds); id
   `^[a-z0-9-]+$`; positive integer `width`, `height`, `dpi`; boolean `color`; non-empty `name` and
   `device`. `ensureProfilesDir(dir)` creates the directory and each seed profile's `profile.json`
   only when `dir` does not exist. `listProfiles(dir)` reads each subdirectory on every call, skips one
   without `profile.json`, returns `{ dir, profiles }`, valid ones with `has_settings` (whether
   `settings/kopanda/settings.lua` exists) and invalid ones as `{ id, error }`, sorted by id.
   `getProfile(dir, id)` adds `settings_path`, absolute.
3. `studio/src/server/routes/profiles.ts`: `GET /` and `GET /:id` as the feature specifies, a 404
   `HttpError` for an unknown or invalid id. Mount at `/api/profiles` in `createApp`; `index.ts` calls
   `ensureProfilesDir` once at start. Load the seed with a JSON import (`with { type: "json" }` under
   NodeNext), so `tsc` carries it into `dist/server` and `npm start` seeds as `npm run dev` does;
   reading it with `fs` relative to the module would find nothing in `dist/`.
4. `spec/unit/studio_profiles_spec.lua`: decode the seed file with `rapidjson` (on `LUA_CPATH` under
   `bin/check`, `bin/check:45`) and compare with `spec/emulator/profiles.lua` (`:3-6`).

## Surfaces

- `studio/src/server/default-profiles.json`, `profiles.ts`, `routes/profiles.ts`, `app.ts`, `index.ts`
- `studio/test/server/profiles.test.ts`, `studio/test/server/index.test.ts` (its spawns already point
  `KOPANDA_STUDIO_PROFILES_DIR` at a temp path), `spec/unit/studio_profiles_spec.lua`

## Tests

- `studio/test/server/profiles.test.ts` (C4), each case on its own temp directory:
  - a missing directory is created holding exactly `colorsoft/profile.json` and
    `paperwhite/profile.json` equal to the seed, and no `settings/`;
  - an existing empty directory and one holding a single profile are left byte-identical;
  - `GET /api/profiles` answers `dir` as the absolute directory and lists in id order with every field; a profile written to disk after the app
    starts appears on the next request; a directory without `profile.json` is absent; malformed JSON
    and a `width: 0` file each appear as `{ id, error }`;
  - `has_settings` is true once `settings/kopanda/settings.lua` is created;
  - `GET /api/profiles/colorsoft` returns `settings_path` ending
    `colorsoft/settings/kopanda/settings.lua` and absolute; an unknown id and an invalid one are 404
    with `error`;
  - `GET /api/nope` is 404 JSON with `error` with the profiles router mounted.
- `spec/unit/studio_profiles_spec.lua` (C2): the seed's ids are exactly `colorsoft` and `paperwhite`;
  width, height, dpi and color match `profiles.lua`; a mismatch names the id and field.

## Edge cases

- A profiles directory path that exists as a file: `ensureProfilesDir` throws naming the path, and the
  server's start prints it and exits 1.
- A subdirectory with a `profile.json` whose name breaks the id pattern (e.g. `My Kindle`) is listed as
  invalid with the reason; non-directories and directories without `profile.json` are skipped.
- Hidden entries (`.DS_Store`, dot-directories) are ignored, not listed as invalid.
- An id in the URL is matched against the listed ids, never joined into a path unchecked, so `..` or
  an encoded slash cannot reach outside the profiles directory.
