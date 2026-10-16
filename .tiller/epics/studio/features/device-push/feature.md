# Wi-Fi pull with staged apply and rollback

## Summary

Getting a profile onto its Kindle: the plugin gets a Studio menu where the owner names the Mac's host
and port and picks a profile, pulls that profile's bundle (the working tree's plugin folder and the
profile's settings file) over Wi-Fi, verifies and stages it, and the next start swaps the plugin folder,
replaces the settings file, turns the other shells off, and rolls everything back on its own when the
new home doesn't paint (design §6 Push). This is what makes the studio the switch-over gate.

## Behavior

- The studio stays on `127.0.0.1` unless `KOPANDA_STUDIO_HOST` opens it to the LAN; then other machines
  reach only the health check, the push profile list, a profile's manifest and its files, and nothing
  that carries an absolute Mac path.
- A profile's bundle is the working tree's `kopanda.koplugin/` and the profile's settings file, served
  as a JSON manifest (paths, sizes, sha256s and one bundle hash) plus one GET per file. The profile
  screen shows whether the LAN is on, the address to type on the Kindle, and the profile's bundle hash.
- On the device, Tools → KoPanda → Studio (in the normal menu and in the menu KoPanda keeps while
  another shell is enabled): set the address once, choose a profile, pull. The plugin downloads every
  file, checks every path, size and sha256 and recomputes the bundle hash; any failure refuses with
  nothing staged and an earlier stage kept. A good pull is staged, the apply patch is armed, and the
  plugin offers to restart.
- The next start applies before any plugin loads: the old plugin folder is moved into the rollback set
  and the new one moved in, the settings file is replaced whole (device-only edits are lost), and
  SimpleUI, Bookshelf and ennUI are added to KOReader's disabled plugins. The install is on probation
  until the new home paints; the home then says what was pulled.
- A start that ends on probation (the plugin didn't load, crashed, hung, or the home's build, show or
  paint failed) is followed by a start that restores the old plugin folder, settings file and disabled
  list, and says so. A failed apply undoes itself at once. Only the last rollback set is kept, and there
  is no manual Roll back.
- Unit specs cover the bundle on both sides through shared vectors, every refusal, stage, arm, apply,
  undo and rollback; emulator specs cover a pull that switches a shell off and lands on KoPanda's home,
  and a broken plugin that rolls back on the next start.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. Theme studio
paths are relative to `~/Projects/elatedpanda/koreader-theme-studio/` at `a0de5dd`. Repo paths are on
`main` at `f3f3bb6` unless marked.

### Order and what is cited as spec

This feature starts after its two recorded prerequisites:

- `home/plugin-shell` (F-yrw3g6), built: the plugin, its boot guard (`kopanda.koplugin/main.lua:117-150`),
  the home's show and its `finished` callback (`kopanda.koplugin/home.lua:144-153`, `:159-199`,
  `:205-224`), the coexistence guard (`kopanda.koplugin/guards.lua:13-48`) and the runtime state file
  (`kopanda.koplugin/state.lua:15-61`).
- `studio/studio-shell` (F-kglqs4), specified, not built: the config module and its variable list
  (`.tiller/epics/studio/features/studio-shell/tasks/scaffold/task.md:21-27`), `createApp` and the
  loopback listener (`:28-37`), the profiles model and loader (`studio-shell/tasks/profiles/task.md:10-22`),
  the profile directory layout (`studio-shell/feature.md:64-81`) and `ProfileScreen.tsx`
  (`studio-shell/tasks/profile-screens/task.md:13-16`).

The studio-shell profiles task says its model leaves out the theme studio's `root` field, "which
device-push adds" (`studio-shell/tasks/profiles/task.md:10-11`). The theme studio's `root` is the
device's install root, substituted for a `${root}` token in theme settings (theme studio
`src/core/profiles.ts:13`, `src/core/materialise.ts:4-6`, `:55-60`). KoPanda needs none: the bundle's
plugin paths are relative, the settings file carries device paths only as the owner typed them
(`featured.pinned`, `kopanda.koplugin/schema.lua:89-96`), and the device finds its own data folder and
plugin folder when it pulls (below). This feature adds no profile field.

Each task that uses a module a studio feature builds reads the built code first and records in its PR
any line that differs from the spec cited here. `studio/settings-form` and `studio/preview` are not
prerequisites; `emulator-push` and `preview/capture-inputs` both edit `spec/emulator/driver.lua`, and
whichever lands second merges onto the other.

### The bundle

A profile's bundle is a set of files, each a path and its bytes:

- `plugin/<rel>` for every regular file under the repo's working-tree `kopanda.koplugin/` (as the preview
  copies it, `preview/feature.md:68-69`), `<rel>` its path below the folder with `/` separators. An entry
  whose name starts with `.` (`.DS_Store`) is skipped with everything under it. A symlink or any other
  non-regular entry, or a path with a segment outside `^[A-Za-z0-9._-]+$`, fails the bundle with an error
  naming it: the device refuses the same paths (below), so the studio never serves one.
- `settings.lua`: the profile's `settings/kopanda/settings.lua`. When its first line matches the Lua
  pattern `^-- /.+/settings/kopanda/settings%.lua$` (`-- ` and an absolute path ending in the settings
  file's name: the header the settings-form writer and `LuaSettings:flush` write,
  `settings-form/feature.md:85`, `frontend/util.lua:1126-1128`, whether or not the path is this file's own
  as the studio spells it), that line is replaced by `-- settings/kopanda/settings.lua`, so no Mac path
  leaves the machine however it was written; any other first line is kept.
  A profile with no settings file gets `-- settings/kopanda/settings.lua\nreturn {}\n`, which the plugin
  reads as every key at its default (`kopanda.koplugin/settings.lua:260-263`).

**The bundle hash** is the theme studio's `hashTree` (`src/core/tree.ts:18-34`): sha256 over the files
taken in UTF-8 byte order of their paths, each framed as the path's byte length (u32 big-endian), the
content's byte length (u64 big-endian), the path's bytes, then the content. Lowercase hex.

**The manifest** is JSON:

```json
{
  "format": 1,
  "profile": "colorsoft",
  "hash": "<64 hex>",
  "files": [
    { "path": "plugin/HOOKS.md", "size": 81234, "sha256": "<64 hex>" },
    { "path": "settings.lua", "size": 412, "sha256": "<64 hex>" }
  ]
}
```

`files` lists every file in the hash's order. `format` is 1; a device refuses any other, so a later
change to the shape fails loudly on an older plugin rather than staging something it misreads.

**Shared vectors** pin the format for both sides: `spec/fixtures/push/tree/` holds a small bundle tree
(`plugin/_meta.lua`, `plugin/main.lua`, a nested `plugin/icons/a.svg`, and `settings.lua` whose first line
is a header to keep) and `spec/fixtures/push/manifest.json` its expected manifest for profile id
`vector`, with every `sha256` and the `hash` derived once outside both implementations (`shasum -a 256`
over the files, and over the framed bytes written with `printf`), the commands recorded in the PR. A
Vitest builds the manifest from the tree and asserts it equals the file byte for byte after
`JSON.stringify(_, null, 2) + "\n"`; a Lua spec recomputes every sha256 and the hash from the same tree.
Neither side can drift without failing.

### The studio's routes

All under `/api`, JSON unless said otherwise; the bundle is built from disk on each request, nothing
cached.

- `GET /api/health`: `{ ok: true, host, port, addresses }`, `addresses` the machine's non-internal IPv4
  addresses when `host` is not loopback and `[]` otherwise (theme studio `src/server/app.ts:55-82`).
- `GET /api/push/profiles`: `{ profiles: [{ id, name, device }] }`, the valid profiles in id order, from
  the shell's loader. No `dir`, no `settings_path`, no invalid entries.
- `GET /api/push/:id/manifest`: the manifest above. An id that is not a valid profile is `404 { error }`;
  a bundle that fails to build (a symlink, a bad name) is `500 { error }` naming the entry.
- `GET /api/push/:id/files/:hash/*path`: the file's bytes, `Content-Type: application/octet-stream`,
  `Cache-Control: no-store`. When `:hash` is not the profile's current bundle hash: `409 { error, hash }`
  with the current hash, as the theme studio refuses a stale bundle (`src/server/routes/bundles.ts:132-139`).
  A path not in the bundle: `404 { error }`. An unknown profile: `404 { error }`.

**LAN opt-in.** `KOPANDA_STUDIO_HOST` (default `127.0.0.1`; empty takes the default) is the address the
server binds, as the theme studio's `KTS_HOST` (`src/server/config.ts:6`, `:14-16`, `:45`); `0.0.0.0`
serves the LAN. It joins the config module's exported variable list and `.env.example`. The start line
names the bound address, and with the LAN on, each address from `/api/health` as
`http://<address>:<port>`.

**The guard.** `lanGuard`, mounted first in `createApp` so the UI's files are covered too (theme studio
`src/server/app.ts:77-78`), passes every request from a loopback peer (`127.0.0.0/8`, `::1`, and
`::ffff:127.x` from a dual-stack socket; `src/server/lan-guard.ts:3-9`). From any other peer it passes
only `GET` of `/api/health`, `/api/push/profiles`, `/api/push/<id>/manifest` and
`/api/push/<id>/files/<64 hex>/<path>`, and answers everything else `403 { error }`. `/api/profiles`
(its `dir` is an absolute Mac path, `studio-shell/feature.md:99`), the settings API and the preview stay
loopback-only. There is no authentication: anyone on the LAN while it is on can read the plugin and the
profile's settings, the weather location among them.

**The profile screen** gains one block under the device facts:

- LAN on: "Pull from the Kindle at `<address>:<port>`", one line per address; off: "LAN off · start the
  studio with KOPANDA_STUDIO_HOST=0.0.0.0 to pull from the Kindle".
- "Bundle `<first 12 hex of hash>`", from the manifest route, with a Refresh button that fetches it
  again; a failed fetch shows its error in place of the hash.

### The device: Tools → KoPanda → Studio

`KoPanda:addToMainMenu` gains a **Studio** item in both its menus, before Swatches: the normal one
(`kopanda.koplugin/main.lua:316-332`) and the one it keeps while another shell is enabled
(`:296-302`), which is how the first switch-over pull happens. The first KoPanda install onto the
Kindle is by hand over MTP (handoff `§4`, `.tiller/design/handoff-2026-10-08.md:63-68`). Its items,
each acting from the next tick as the menu's other items do (`main.lua:262-268`):

- **Address: `<host:port>`** (or "Address: not set"): an `InputDialog` (`frontend/ui/widget/inputdialog.lua:583`
  `getInputText`, `:640` `onShowKeyboard`) with the hint `192.168.1.20:4490`, as the theme studio's
  (`lua/themestudio.koplugin/main.lua:133-165`). Saved trimmed; empty clears it. `http://` is prefixed
  when the text has no scheme and trailing slashes dropped (`lua/themestudio.koplugin/sync.lua:66-71`).
- **Profile: `<id>`** (or "Profile: not chosen"): fetches `/api/push/profiles` and offers one button per
  profile by name, as the theme studio's chooser (`main.lua:196-215`); the choice is saved.
- **Pull `<id>`**, enabled once an address and a profile are set: the pull below.

Both values live in `settings/kopanda/state.lua` as `studio_address` and `studio_profile` through
`State.get`/`State.set` (`kopanda.koplugin/state.lua:27-61`): device-local runtime state, never in the
schema, never pushed, never read by the studio. AGENTS.md's runtime-state line names them and the push
folder below.

Network access runs inside `NetworkMgr:runWhenConnected` (`frontend/ui/network/manager.lua:713-719`),
which needs only a connection, not DNS (`isOnline` resolves a hostname, `:641-648`). Every request uses
`socket.http` with `socketutil:set_timeout(FILE_BLOCK_TIMEOUT, FILE_TOTAL_TIMEOUT)` (15 s and 60 s,
`frontend/socketutil.lua:32-33`, `:52-61`), a `table_sink` for JSON or a `file_sink` for a file
(`:98-140`), and `reset_timeout` on every path (`:64-70`), the theme studio's request
(`sync.lua:73-113`). `Accept-Encoding: identity`.

### The pull

**Refused before anything is fetched**, each with a message and nothing written:

- no address or no profile;
- `<data>/patches/.patches_disabled` exists (`frontend/userpatch.lua:39-40`, `datastorage.lua:79-81`):
  the patch would never run;
- `settings/kopanda/push/probation.lua` exists: the last pull hasn't painted its home yet;
- the running plugin's folder (`self.path`, set by the loader, `frontend/pluginloader.lua:248`) is not
  named `kopanda.koplugin`.

Then a ConfirmBox says what the pull replaces: "Pull `<id>` from the studio? KoPanda and its settings on
this Kindle are replaced by the studio's; settings changed only on this Kindle are lost." With another
shell enabled it adds "SimpleUI, Bookshelf and ennUI are turned off at the restart." (the names the
coexistence guard checks, `kopanda.koplugin/guards.lua:13-17`). An InfoMessage "Pulling `<id>`…" is
shown and painted (`UIManager:forceRePaint`, as `main.lua:255-257` of the theme studio) while the pull
runs, and closed after.

**Fetch and verify.** The pull works in `settings/kopanda/push/download/`, purged first (never following
symlinks, as `sync.lua:249-261`; KOReader's `ffiUtil.purgeDir` follows them, `base/ffi/util.lua:259-281`):

1. `GET <base>/api/push/<id>/manifest`, decoded with `rapidjson` (`common/rapidjson.so`, as the weather
   does). It is refused unless: an object; `format` is 1; `profile` is the chosen id; `hash` is 64
   lowercase hex; `files` is a non-empty array of objects each with a string `path`, a non-negative
   integer `size` and a 64-hex `sha256`; every path is safe (not empty, no leading `/`, no `\`, no empty,
   `.` or `..` segment, as `sync.lua:197-203`, and every segment matching `^[A-Za-z0-9._-]+$`); every path
   is `settings.lua` or starts `plugin/`; no two paths are equal ignoring case (the Kindle's storage is
   FAT, theme studio `apply.lua:17-18`); `settings.lua`, `plugin/main.lua` and `plugin/_meta.lua` are
   present; and the list is in byte order.
2. Each file: `GET <base>/api/push/<id>/files/<hash>/<path>` into `download/<path>` (folders made as
   needed). A 409 refuses with "`<id>` changed in the studio during the pull; pull again."; any other
   failure names the path.
3. Each downloaded file must be a regular file with one link (`lfs.symlinkattributes`, `nlink`, as
   `sync.lua:349-351`), of the manifest's size and sha256 (streamed through `ffi/sha2`'s `sha256()`
   updater, `base/ffi/sha2.lua:4356-4410`, `:5612`; `sync.lua:205-222`).
4. The bundle hash is recomputed over the downloaded files and must equal the manifest's `hash`. The
   theme studio trusted the hash it was handed on this path (`sync.lua:358-362`); KoPanda never does.

Any refusal purges `download/` and leaves an earlier stage exactly as it was.

**Stage.** Only after every check passes: remove `push/staged.lua`, purge `push/staged/`, rename
`push/download/` to `push/staged/`, and write `push/staged.lua` last, so its presence means a complete
stage:

```lua
return {
    format = 1,
    profile = "colorsoft",
    hash = "<64 hex>",
    plugin_dir = "/mnt/us/koreader/plugins/kopanda.koplugin",
    disable = { "simpleui", "bookshelf" },
    at = "2026-10-16T14:02:11Z",
}
```

`plugin_dir` is the running plugin's folder made absolute (on the Kindle the loader's path is relative,
`plugins/kopanda.koplugin`, `frontend/pluginloader.lua:24`, `:177`, `:204`, under the launcher's working
directory, `platform/kindle/koreader.sh:8`, `:130`; under `KO_HOME` it is `<KO_HOME>/plugins//kopanda.koplugin`,
`pluginloader.lua:196`, `:204`, and the doubled slash is collapsed). `disable` holds the runtime names
(folder names, `pluginloader.lua:210`) of the enabled plugins whose lower-cased name the guard checks
(`guards.lua:11-17`, `:24-44`), from `PluginLoader:loadPlugins()` (`pluginloader.lua:273-274`), so a
clone named `ennUI.koplugin` is disabled as `ennUI`; `plugins_disabled` is matched by exact name
(`pluginloader.lua:212`).

**Arm.** The running plugin copies its own `push_apply.lua` to `<data>/patches/1-kopanda-apply.lua`
(through a temporary name, the old copy removed first), so the patch is always the code of a build that
loaded on this device, as the theme studio armed (`sync.lua:385-396`). `ffiUtil.copyFile`
ignores write errors (`base/ffi/util.lua:223-241`), so the copy's size is checked. A failed arm removes
`push/staged.lua` and refuses.

**Restart offer.** A ConfirmBox "Restart to apply `<id>`?" with Restart and Later (theme studio
`main.lua:272-281`): Restart broadcasts `Event:new("Restart")`, which closes the menu and the file
manager and quits with 85 (`frontend/device/devicelistener.lua:454-456`,
`frontend/apps/filemanager/filemanagermenu.lua:998-1004`, `frontend/ui/uimanager.lua:1765-1769`); the
Kindle's launcher starts KOReader again on 85 (`platform/kindle/koreader.sh:333-340`). Later leaves the
stage armed for the next start.

### The apply patch

`kopanda.koplugin/push_apply.lua` is one file with two uses. Required by `main.lua` as every module is
(`main.lua:5-7`, `spec/unit/main_requires_spec.lua`), it returns its functions and does nothing else.
Copied to `patches/1-kopanda-apply.lua` it is an early user patch: KOReader `dofile`s it under `pcall`
(`frontend/userpatch.lua:84-92`) for the prefix `1` (`:12`, `:73`), at `reader.lua:25-27`, before
`G_reader_settings` is opened (`reader.lua:39-40`) and before any plugin is discovered (plugins load
with the first file manager, `frontend/apps/filemanager/filemanager.lua:418-429`). The file tells the
two apart by its chunk's varargs: `require` calls the loader with the module name (Lua 5.1 reference
manual §5.3 `require`), and `dofile` passes the chunk nothing, which is LuaJIT's behaviour rather than
the manual's word and is proven by `push_apply_spec`'s module case (`require` changes nothing, `dofile`
of a copy applies); with none it runs `run(DataStorage:getDataDir())`.

It requires only what loads before `G_reader_settings` exists: `datastorage`, `dump`, `ffi/util`,
`libs/libkoreader-lfs`, `logger` and `luasettings`. The first five are the theme studio's early patch's
own (`lua/themestudio.koplugin/apply.lua:29-33`). `luasettings` requires `dump`, `lfs`, `logger` and
`util` (`frontend/luasettings.lua:5-8`), so it adds only `util`, which the theme studio's patch also
required early (`apply.lua:35`); `util` loads `ffi/utf8proc`, `ffi/util`, `lfs`, `ffi/sha2` and `gettext`
(`frontend/util.lua:5-9`), none of which reads `G_reader_settings` at load. It catches its own errors
and writes them to the result file, because an early patch's failure is only logged (`frontend/userpatch.lua:89-100`; theme studio
`apply.lua:11-12`, `:462-474`).

**The push folder**, `<data>/settings/kopanda/push/` (`datastorage.lua:60-62`), on the same filesystem as
`plugins/` on both targets (the Kindle's data folder is the launcher's working directory,
`datastorage.lua:41-42`, `koreader.sh:130`; the emulator's is `KO_HOME`, `datastorage.lua:19-20`), so
every rename is a move:

| Path | What |
|---|---|
| `download/` | the pull in progress |
| `staged/` and `staged.lua` | the verified bundle and its record; the record is written last and removed first |
| `rollback/` | `record.lua`, `plugin/` (the previous plugin folder), `settings.lua` (the previous settings file, when there was one) |
| `probation.lua` | `{ profile, hash, at }`: an install not yet proven by a painted home |
| `result.lua` | `{ ok, kind, profile, hash, message }`, `kind` one of `applied`, `failed`, `rolled_back`, `restore_failed` |
| `discard/` | a plugin folder on its way out, purged at once |

**No rename the patch makes itself targets an existing path.** Its own `move` refuses an existing target:
a folder is always moved aside before another takes its name, and a file removed before a file is renamed
onto its name; records are written to a temporary name, synced, and renamed onto a name that was removed
first (`ffiUtil.fsyncOpenedFile`, `base/ffi/util.lua:588`; `fsyncDirectory`, `:614`; theme studio
`apply.lua:74-100`). Whether the Kindle's FAT storage replaces an existing folder on rename is therefore
never relied on. `settings.reader.lua` and `state.lua` are written through `LuaSettings:flush`
(`frontend/luasettings.lua:252-275`), as KOReader writes them itself; that flush's own backup renames a
file onto an existing `<file>.old` (`:262`), which is KOReader's rename of a file, not the patch's, and
outside the rule.

**`run(data_dir)`**, every start:

1. `probation.lua` present: **restore** (below) with `kind = "rolled_back"`, then stop. A pull is
   refused while probation is set, so no stage is waiting; any that is is purged.
2. `staged.lua` absent: return. This is every ordinary start: one `lfs` call.
3. Otherwise **apply**:
   1. The record loads (`load` with an empty environment, as theme studio `apply.lua:63-72`),
      `plugin_dir` is absolute, ends `/kopanda.koplugin` and is a folder, and `staged/plugin/main.lua`,
      `staged/plugin/_meta.lua` and `staged/settings.lua` are files. Otherwise: result `failed`, stage
      purged, stop.
   2. Purge `rollback/` and make it again: only the last rollback set is kept.
   3. Write `rollback/record.lua`: `profile`, `hash`, `plugin_dir`, `had_settings` (whether
      `settings/kopanda/settings.lua` exists), `had_settings_old` (whether `settings/kopanda/settings.lua.old`
      exists), and `plugins_disabled`, the current value read from
      `settings.reader.lua` through `LuaSettings:open` (`frontend/luasettings.lua:21-48`), with
      `had_plugins_disabled` telling an absent key from an empty table.
   4. Write `probation.lua`. From here a start cut short (power loss, a crash) is restored at the next
      start.
   5. Rename `plugin_dir` to `rollback/plugin`, then `staged/plugin` to `plugin_dir`.
   6. With `had_settings`, rename `settings/kopanda/settings.lua` to `rollback/settings.lua`; then
      rename `staged/settings.lua` to `settings/kopanda/settings.lua`. An existing `settings.lua.old` is
      left alone.
   7. In `settings.reader.lua`, set `plugins_disabled[name] = true` for each name in the record's
      `disable`, keeping every other entry, and flush. Only this early point is safe: KOReader writes
      `G_reader_settings` back at exit (`reader.lua:306-308`), and reader.lua opens it after this patch.
   8. In `state.lua`, set `boot_pending` to `false`, so the boot guard (`main.lua:122-139`) never skips
      the home that is to prove the install.
   9. Write `result.lua` `{ ok = true, kind = "applied", profile, hash }`, then remove `staged.lua` and
      purge `staged/`. Each of the three is `pcall`ed and a failure only logged: the install stays
      applied, on probation like any other, and the failure is never turned into `failed` or a restore.
      A failed result write means the home shows no notice. A `staged.lua` left behind has no
      `staged/plugin/` (it moved in step 5), so the next start that reaches step 3 fails its step 1
      harmlessly: result `failed`, the stage purged, nothing moved.

   A failure in 2–4 writes result `failed` with the reason, removes `probation.lua` if written, and
   purges the stage; nothing has moved. A failure in 5–8 runs **restore** at once with `kind = "failed"`
   and the failing step's message.

**Restore**, from `rollback/record.lua`, idempotent so a restore cut short is finished by the next start.
The shells come back first, so a restore that fails part-way never leaves them disabled with no working
KoPanda; every step after the first is attempted even when an earlier one failed:

1. The record must load; if it doesn't, result `restore_failed`, `probation.lua` removed (nothing could
   ever restore), stop.
2. Set `plugins_disabled` in `settings.reader.lua` back to the record's value, or delete the key when it
   was absent, and flush.
3. When `rollback/plugin` is a folder: if `plugin_dir` exists, purge `discard/` and rename `plugin_dir`
   to `discard/`; rename `rollback/plugin` to `plugin_dir`; purge `discard/`. A failure of that last
   purge is only logged: the swap is done, and a leftover `discard/` is purged before its next use.
4. When `rollback/settings.lua` exists: remove `settings/kopanda/settings.lua` if present and rename
   `rollback/settings.lua` onto it. Otherwise, when the record's `had_settings` is false, remove
   `settings/kopanda/settings.lua` if present. Otherwise the file never moved and is left. Then, when the
   record's `had_settings_old` is false, remove `settings/kopanda/settings.lua.old` if present: the new
   install's `LuaSettings:flush` may have made one (`frontend/luasettings.lua:252-275`), and
   `LuaSettings:open` reads `.old` when the file is absent or broken (`:36-40`), so a restored absence
   would otherwise read the pulled settings.
5. Set `boot_pending` to `false` in `state.lua`.
6. Only when steps 2–5 all succeeded: remove `probation.lua`, purge the stage and `rollback/`, write the
   result with the kind given and the message.

When any of steps 2–5 fails, the restore writes `restore_failed` naming each failed step, after trying
the rest, and leaves `probation.lua` and `rollback/`, so the next start tries again.

### Probation, the result notice and the home

**A successful first paint** is now told apart from a caught failure. Today `finish` runs after the
settled signal and also after a failed paint (the settle path runs it whether `paint_failed` or not,
`home.lua:159-199`) and after a caught build or show failure (`:216-222`). `Home.show` passes `finish`
one argument, `painted`: true only from `settle` when the home painted (`home.painted_at` set,
`:297-298`) and `paint_failed` is not set (`:300-301`); false on every other path. The boot guard's
`finished` ignores it (`main.lua:147-149`).

**On a painted first home** of a process (the boot guard's `finished` path, `main.lua:145-150`), the plugin
removes `probation.lua` when present, then, when `result.lua` is present, reads and removes it and shows
its notice from the next tick over the home. Nothing else ever clears probation, so a plugin that fails
to load (only logged, `frontend/pluginloader.lua:244-246`), crashes, hangs, or whose home's build, show or
paint fails leaves it for the next start's restore.

**Refused** (another shell enabled, `main.lua:70-76`): from a file-manager instance, when
`probation.lua` is absent and `result.lua` is present, the plugin reads and removes it and shows its
notice from the next tick, in place of the home it can't show. With probation set it shows nothing and
leaves both files: the next start restores and reports that.

The notices, each an `InfoMessage` (`frontend/ui/widget/infomessage.lua:47`, `:52-53`):

- `applied`: "KoPanda pulled `<profile>` from the studio (bundle `<first 12 hex>`)."
- `rolled_back`: "KoPanda's home didn't draw after the pull of `<profile>`, so the previous KoPanda and
  its settings are back."
- `failed`: "KoPanda couldn't apply the pull of `<profile>`: `<message>`. Nothing changed."
- `restore_failed`: "KoPanda couldn't restore the previous version: `<message>`. It tries again at the
  next start."

### Tests

- **Studio, Vitest:** the bundle and manifest from the shared vectors; the settings header rewrite and
  the missing-file default; a symlink and a bad name failing the bundle; every route's answers, 404s and
  409; `KOPANDA_STUDIO_HOST` in config and `.env.example`; the guard's allowed and refused requests from
  a non-loopback peer; the profile screen's block.
- **Plugin, Busted unit specs** on scratch folders under the run's `KO_HOME`, with `socket.http`'s
  `request` stubbed as the weather spec does (`spec/unit/weather_spec.lua:42-61`, `:131-139`): the
  vectors; every manifest and file refusal leaving no stage and an earlier stage intact; stage and arm
  and their refusals; the Studio menu in both menus and its state keys; apply, its failures at each
  step (step 9's only logged), restore after each interrupted step and with a step that fails, and
  rollback; the `painted` flag; probation cleared only by
  a painted home; the notices; the patch file's two uses.
- **Emulator:** a two- and three-start mode of the capture driver on one scratch `KO_HOME`, accepting
  exit 85 and a capped start; a background `luajit` file server serving bundles built by the spec; a
  pull from the refused menu's code path that turns a fixture shell named `ennui` off (the emulator's
  own `plugins/` already holds the real `simpleui` and `bookshelf`, so a fixture of either name would
  load twice) and lands on KoPanda's home with
  the applied notice; a broken plugin that rolls back on the next start with the rolled-back notice.

### HOOKS.md

The plugin section gains entries, each with its `file:line`: the Studio menu (`InputDialog`,
`ButtonDialog`, `ConfirmBox`, the `Restart` event and its path to exit 85); the pull (`NetworkMgr:runWhenConnected`,
`socket.http`, `socketutil`'s file timeouts and sinks, `ffi/sha2`, `rapidjson`); the plugin's own path
(`self.path`) and `PluginLoader:loadPlugins()` names for the disable list; the patches folder and
`.patches_disabled`; the apply patch's early priority, its `pcall(dofile)`, its place before
`G_reader_settings` and plugin discovery, its edit of `plugins_disabled` in `settings.reader.lua` and of
`boot_pending` in `state.lua`; and the result notices. The capture-harness section gains the multi-start
runs, exit 85 and the file server's `socket.bind`. `spec/unit/hooks_doc_spec.lua` already fails on any
module or key the new files use that HOOKS.md doesn't name.

### Settings keys

None. This feature adds no key to `kopanda.koplugin/schema.lua`; the address and profile are runtime
state.

## Notes

The theme studio's companion (`lua/themestudio.koplugin/apply.lua`, `sync.lua`, `main.lua`) is the
reference and much of it ports: the address dialog, profile chooser, request with file timeouts, safe
paths, streaming sha256, tree hash, purge without following links, arm, restart offer and result file.
It never replaced its own plugin (`apply.lua:17-23`), never rolled back after a start (its Roll back
item is disabled, `main.lua:116-119`), and trusted the hash on the Wi-Fi path (`sync.lua:358-362`);
those three are new here. It was reviewed at full depth once and the port gets the same review.

Owner's decisions of 2026-10-16 written in: the plugin swaps as a whole folder; the settings file is
replaced whole; the push turns SimpleUI, Bookshelf and ennUI off (their folders stay); the LAN is opt-in
with an allow-list and no auth; rollback waits for a painted home and costs one extra restart.

For the owner, each a choice the spec made that you can overturn at approval:

- **The apply step is an early user patch** copied from the running plugin at each pull, so the code
  that applies and the code that rolls back is always a build that loaded on this device. It stays in
  `patches/` and returns at once when nothing is staged or on probation. The first switch-over pull runs
  from the refused menu of the hand-installed build, which has never painted its home on the Kindle, so
  the first apply and its rollback run that build's code; C15 is the proof that it works there.
- **Manifest plus one GET per file, no zip.** No archive hazards (links, hard links) and no zip writer
  in the studio. About 80 requests per pull; each rebuilds the bundle from disk on the Mac.
- **The device recomputes the bundle hash** and checks sizes, sha256s, path safety and case-insensitive
  duplicates before staging; a new pull replaces an earlier stage only after it verifies.
- **The shells to disable are the enabled ones at pull time,** by their exact folder names. A shell
  enabled between the pull and the restart stays on, the home is refused, and the next start rolls back.
  The Solar icon pack is left as it is; the coexistence guard doesn't check it.
- **The apply clears `boot_pending`** in `state.lua`, so the boot guard can't skip the home that has to
  prove the install, and the restore clears it so the restored home shows with its notice.
- **Probation is cleared only by a painted home.** A start that opens a book first clears it at the first
  home after; a process that ends before any home paints rolls back at the next start. A refused new
  install (a shell still on) rolls back too.
- **The settings header is rewritten** to `-- settings/kopanda/settings.lua` in the bundle whenever it
  is any absolute path ending `/settings/kopanda/settings.lua`, not only the profile's own path as the
  studio spells it, so no absolute Mac path crosses the LAN; the plugin rewrites the header with its own path at
  its first save.
- **Address and profile live in `state.lua`** (`studio_address`, `studio_profile`): device-only, never
  pushed. The profile is chosen once and every pull after uses it, as in the theme studio.
- **`GET /api/health`** is new and LAN-visible; it serves the profile screen's LAN line, and lists the
  Mac's LAN addresses to any machine on the LAN.
- **Wording to replace with your own:** the menu items, the confirm and restart texts, "Pulling
  `<id>`…", the four notices, the refusals, and the profile screen's LAN and bundle lines.

`KOPANDA_STUDIO_HOST` is a new environment variable. AGENTS.md asks that `~/Projects/strem` (compose,
`.env.example`, `.env.enc`) get the same change; the studio runs only locally and is not a strem service
(`studio-shell/feature.md:146-148`), so whether strem needs it is your call. The emulator specs add three
test-only variables, `KOPANDA_PUSH_ADDRESS`, `KOPANDA_PUSH_PROFILE` and `KOPANDA_NOTICES`, listed in
`.env.example` beside the other spec-set variables (`.env.example:13-18`).

Facts settled while specifying:

- KOReader `v2026.07.1` (tag commit `9192014`, the Kindle's version per the handoff,
  `.tiller/design/handoff-2026-10-08.md:57`) has `reader.lua`, `datastorage.lua`,
  `frontend/userpatch.lua`, `frontend/pluginloader.lua`, `frontend/luasettings.lua`,
  `frontend/socketutil.lua` and `frontend/ui/network/manager.lua` byte-identical to `e1fe1ac`, read from a
  sparse clone on 2026-10-16. Its restart path differs only in line numbers:
  `UIManager:restartKOReader` quits with 85 (`frontend/ui/uimanager.lua:1688-1691`),
  `DeviceListener:onRestart` (`frontend/device/devicelistener.lua:450-452`), the launcher's loop
  (`platform/kindle/koreader.sh:329-335`) and its `cd` (`:125`).
- KOReader's `base` differs between the two: `v2026.07.1` pins koreader-base `6e4bc81`, `e1fe1ac` pins
  `eeabdaa` (`git ls-tree <commit> base`; the tag's through the GitHub contents API). `ffi/sha2.lua` is
  byte-identical. `ffi/util.lua` differs in one hunk, `util.df`'s `statvfs` (`eeabdaa` lines 108-122);
  `copyFile`, `purgeDir`, `fsyncOpenedFile` and `fsyncDirectory` are unchanged and sit 10 lines earlier
  on `6e4bc81` (`:213`, `:249`, `:578`, `:604` against the cited `:223`, `:259`, `:588`, `:614`).
- **Express 5's wildcard parameter** arrives as an array of decoded segments: the theme studio's pinned
  `express` 5.3.0 depends on `router` 2.2.0, which matches through `path-to-regexp` with its own
  `decodeParam` (`node_modules/router/lib/layer.js:86-90`), and `path-to-regexp` 8.4.2 decodes a wildcard
  as `value.split(delimiter).map(decode)` (`node_modules/path-to-regexp/dist/index.js:231`), all read in
  the theme studio's `node_modules` @`a0de5dd`. `bundle-server` joins the segments with `/` and records
  in its PR if the studio's installed versions differ.

Open facts for execution:

- **The Kindle's KOReader version.** Read `/mnt/us/koreader/git-rev` (`frontend/version.lua:9-13`) before
  the manual pull. `v2026.07.1` is covered above; any other version gets the same file diff against the
  cited lines (`git clone --depth 1 --branch <tag> --filter=blob:none --sparse` of KOReader), recorded in
  the manual criterion's evidence, and a difference in those lines stops for the owner.
- **The Kindle's storage and the folder swap.** The patch never renames onto an existing path itself, so the
  FAT question is moot; the manual pull is the proof on the device that the plugin folder swap, the
  settings rename and the rollback set work there.
