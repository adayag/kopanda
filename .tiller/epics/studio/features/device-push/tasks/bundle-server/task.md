# Studio serves a profile's bundle: manifest, files, LAN opt-in and guard, shared vectors

## Approach

The studio half of the push, and the shared vectors both halves assert. Starts after `studio/studio-shell`
is built; read the built `studio/src/server/` first (`config.ts` and its exported variable list, `app.ts`'s
`createApp`, `start.ts`/`index.ts`, `profiles.ts` and the profiles router's 404, `ProfileScreen.tsx`) and
record in the PR any line that differs from `studio-shell/feature.md` and its task specs. The theme studio
(`~/Projects/elatedpanda/koreader-theme-studio` @a0de5dd) is the owner's code: copy what fits.

1. **Shared vectors, first.** `spec/fixtures/push/tree/` with `plugin/_meta.lua`, `plugin/main.lua`,
   `plugin/icons/a.svg` (a few bytes each, ASCII, one with no trailing newline) and `settings.lua` whose
   first line is `-- settings/kopanda/settings.lua` (kept as is: it is not an absolute path), and
   `spec/fixtures/push/manifest.json`, the expected manifest for profile `vector`, as
   `JSON.stringify(manifest, null, 2) + "\n"`. Derive every `sha256` with `shasum -a 256 <file>` and the
   `hash` by writing the framed bytes with `printf` (per file in byte order of paths: u32 BE path length,
   u64 BE size, path, then `cat` the file) into `shasum -a 256`; put the exact commands in the PR. Neither
   implementation computes the expected values. `spec/fixtures/**` is outside luacheck (`.luacheckrc`).
2. **`studio/src/server/bundle.ts`:** `sha256Hex`, `hashTree` (theme studio `src/core/tree.ts:9-34`,
   with its byte-order compare, `src/core/bytes.ts`), and `buildBundle({ pluginDir, settingsPath })` →
   `{ manifestFor(profileId), files: Map<path, Uint8Array>, hash }` reading the plugin folder recursively
   with `lstat` (dot-entries skipped with everything under them; a symlink or other non-regular entry, or
   a segment outside `^[A-Za-z0-9._-]+$`, throws an `HttpError(500)` naming the path) and the settings
   file with the header rule: when its first line matches `/^-- \/.+\/settings\/kopanda\/settings\.lua$/`
   (the feature's Lua pattern `^-- /.+/settings/kopanda/settings%.lua$`; any absolute path ending in the
   settings file's name, not only `settingsPath`), replace that line with
   `-- settings/kopanda/settings.lua`; missing file → `-- settings/kopanda/settings.lua\nreturn {}\n`.
   `pluginDir` defaults to the repo's `kopanda.koplugin/`, resolved from the module's own location as
   `bin/layout-fit` and `bin/preview` are (`settings-form/tasks/layout-fit/task.md:31-36`).
3. **`studio/src/server/routes/push.ts`:** `GET /profiles`, `GET /:id/manifest`, `GET /:id/files/:hash/*path`
   as the feature specifies, mounted at `/api/push`; profiles through the shell's loader, ids matched
   against listed ids, never joined unchecked. Each request builds the bundle afresh. `*path` arrives as
   an array of decoded segments (theme studio @a0de5dd: `express` 5.3.0 → `router` 2.2.0,
   `node_modules/router/lib/layer.js:86-90` → `path-to-regexp` 8.4.2,
   `node_modules/path-to-regexp/dist/index.js:231`, `value.split(delimiter).map(decode)`); join it with
   `/`. Check the versions in `studio/node_modules` and record in the PR if they differ. A requested path is looked up in the bundle's map, never joined to
   a filesystem path.
4. **`GET /api/health`** in `app.ts`: `{ ok: true, host, port, addresses }` with `lanAddresses` as theme
   studio `src/server/app.ts:62-68`.
5. **`studio/src/server/lan-guard.ts`:** `isLoopback` and `lanGuard` as theme studio
   `src/server/lan-guard.ts:1-24`, with the allow-list `^/api/health$`, `^/api/push/profiles$`,
   `^/api/push/[a-z0-9-]+/manifest$`, `^/api/push/[a-z0-9-]+/files/[0-9a-f]{64}/.+$`, `GET` only; message
   "only the push routes are served to other machines". Mounted first in `createApp`.
6. **Config:** `KOPANDA_STUDIO_HOST` (default `127.0.0.1`, empty takes the default) in `loadConfig` and the
   exported variable list; `start.ts` listens on it; the start line names `http://<host>:<port>` and, with
   a non-loopback host, each LAN address. `.env.example` gains it with a comment line above, in the file's
   style.
7. **UI:** `studio/src/ui/PushStatus.tsx` in `ProfileScreen.tsx` under the device facts: `fetch` of
   `/api/health` and `/api/push/<id>/manifest` on mount, the LAN lines and the bundle line as specified,
   Refresh re-fetching the manifest; `api.ts` gains the two typed fetches with its `ApiError`.

## Surfaces

- `spec/fixtures/push/tree/**`, `spec/fixtures/push/manifest.json` (new)
- `studio/src/server/bundle.ts`, `routes/push.ts`, `lan-guard.ts` (new); `app.ts`, `config.ts`, `start.ts`,
  `index.ts`
- `studio/src/ui/PushStatus.tsx` (new), `ProfileScreen.tsx`, `api.ts`, `styles.css`
- `studio/test/server/bundle.test.ts`, `push.test.ts`, `lan-guard.test.ts` (new); `config.test.ts`;
  `studio/test/ui/push-status.test.tsx` (new)
- `.env.example`

## Tests

Written first and run failing; confirm `npm --prefix studio test -- test/server/bundle.test.ts` runs only
that file.

- `test/server/bundle.test.ts` (C1): the vector tree as `pluginDir` + `settings.lua` gives a manifest
  whose `JSON.stringify(_, null, 2) + "\n"` equals `spec/fixtures/push/manifest.json`; `hashTree` of an
  empty tree is sha256 of nothing (`e3b0c442…b855`); insertion order doesn't change the hash; a temp plugin
  folder with `.DS_Store` and `.git/x` leaves both out; a symlink and a file named `a b.lua` each throw
  naming the path; a settings file whose first line is `-- <its absolute path>` is served with
  `-- settings/kopanda/settings.lua` and the rest byte-identical, as is one whose first line is another
  absolute path ending `/settings/kopanda/settings.lua` (`-- /Users/other/p/settings/kopanda/settings.lua`);
  first lines `-- settings/kopanda/settings.lua`, `-- /a/settings/kopanda/settings.lua.bak` and
  `return {` are kept unchanged; none is served as the default text.
- `test/server/push.test.ts` (C2), supertest on temp profile dirs and a temp `pluginDir`: the list has
  exactly `id`, `name`, `device` per valid profile and skips an invalid one; the manifest for an unknown
  id is 404 and for a symlinked plugin entry 500 naming it; each listed file answers its bytes with
  `application/octet-stream` and `no-store`; a wrong hash is 409 with `hash` the current one; changing the
  settings file after taking the manifest makes the next file request 409; `plugin/nope` is 404; an
  encoded `..` (`plugin/%2e%2e/x`) is 404.
- `test/server/lan-guard.test.ts` (C3): the theme studio's harness (a middleware setting
  `req.socket.remoteAddress`, `test/server/lan-guard.test.ts:12-25` there): from `192.168.1.30` the four
  allowed GETs pass; `GET /api/profiles`, `/api/profiles/colorsoft`, `/api/profiles/colorsoft/settings`,
  `PUT .../settings/look`, `POST .../preview`, `GET /`, `GET /assets/x.js`, `HEAD /api/push/profiles`
  and a manifest path with an upper-case id are 403 JSON; from `127.0.0.1`, `::1` and `::ffff:127.0.0.1`
  all pass. `/api/health` on a loopback config has `addresses: []`.
- `test/server/config.test.ts` (C3): host default, empty, `0.0.0.0`; the existing `.env.example` check
  covers the new name through the exported list.
- `test/ui/push-status.test.tsx` (C4), jsdom with `fetch` stubbed: LAN on with two addresses shows two
  lines; LAN off shows the off line; the bundle line shows 12 hex; Refresh re-fetches and shows a new hash;
  a 500 shows its error.

## Edge cases

- **A profile's settings change between a pull's manifest and its files:** 409, and the device refuses
  and says to pull again; the server never serves a mix.
- **Building per request** costs reading about 1.9 MB per file request; about 80 requests per pull is
  fine locally. No cache.
- **The working tree mid-edit:** whatever is on disk is served; the hash makes a mid-pull edit a 409.
- **IPv6 LAN peers** are non-loopback and get the allow-list.
- **The UI's files** are behind the guard, so a LAN browser gets 403 for `/`.
- New env var: tell the owner that `~/Projects/strem` would need `KOPANDA_STUDIO_HOST` if it ever runs the
  studio (AGENTS.md rule; the feature's Notes leave it to the owner).
