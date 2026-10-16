# Studio menu pulls, verifies, stages and arms a profile's bundle

## Approach

The device's pull half. Starts after `bundle-server` (the shared vectors under `spec/fixtures/push/`)
and `apply-and-rollback` (`PushApply.paths`, `arm`, `probation`); read both as built and record any
difference from the feature spec in the PR. The theme studio's `lua/themestudio.koplugin/sync.lua` and
`main.lua` (@a0de5dd) are the model: `baseUrl` (`sync.lua:66-71`), `request`/`fetchJson`/`fetchFile`
(`:73-113`), `unsafePath` (`:197-203`), `feed`/`sha256File`/`treeHash` (`:205-247`), the address dialog,
`withStudio` and profile chooser (`main.lua:133-215`), the busy message and restart offer
(`:255-281`).

1. **`kopanda.koplugin/push_bundle.lua`**, pure over files: `safe_path(path)` (the feature's rules,
   segment charset included); `check_manifest(doc, profile_id)` → `manifest` or `nil, reason` for every
   refusal the feature lists, the byte-order and case-insensitive duplicate checks included;
   `sha256_file(path)` streaming through `require("ffi/sha2").sha256()` (`base/ffi/sha2.lua:4356-4410`,
   `:5612`); `bundle_hash(dir, files)` with the `hashTree` framing (u32 BE path length, u64 BE size,
   path, bytes); `verify_files(dir, manifest)` → `true` or `nil, reason` (regular file, `nlink` 1, size,
   sha256, then the bundle hash).
2. **`kopanda.koplugin/push_pull.lua`:** `pull{ address, profile, data_dir, plugin_dir, disable }` →
   `true` or `nil, message, code`, synchronous and UI-free so a spec or the emulator scenario can drive it:
   refusals (no address or profile; `.patches_disabled`; probation; a plugin folder not named
   `kopanda.koplugin`); purge and make `download/`; `GET` the manifest (`table_sink`, `rapidjson.decode`)
   and check it; `GET` each file into `download/<path>` (`file_sink`, folders made with `util.makePath`);
   `verify_files`; then stage (remove `staged.lua`, purge `staged/`, rename `download/` to `staged/`,
   write `staged.lua` as `PushApply`'s records are written) and `PushApply.arm`, removing `staged.lua` if
   the arm fails. Every request through one `request(url, make_sink)` with `socketutil:set_timeout(
   FILE_BLOCK_TIMEOUT, FILE_TOTAL_TIMEOUT)` and `reset_timeout` on every path, `socket.http` looked up at
   call time (`pcall(http.request, …)`, as `kopanda.koplugin/weather.lua:70-77` does). A 409 on a file
   gives "`<id>` changed in the studio during the pull; pull again." `plugin_dir` is made absolute
   (`lfs.currentdir()` prefixed when relative) and `//` collapsed.
3. **`kopanda.koplugin/guards.lua`:** `Guards.enabled_shell_names()`, the runtime names (as loaded, case
   kept) of the enabled plugins whose lower-cased name is in `SHELLS`, from the same
   `PluginLoader:loadPlugins()` walk as `conflicts` (`guards.lua:24-44`), `pcall`ed, `{}` on failure.
4. **`kopanda.koplugin/studio_menu.lua`:** `StudioMenu.item(plugin)` → the **Studio** sub-menu table:
   Address (`InputDialog`, hint `192.168.1.20:4490`, saved with `State.set("studio_address", …)`,
   cleared when emptied with `State.set("studio_address", nil)`, which deletes the key: `saveSetting(key,
   nil)` sets it to nil (`frontend/luasettings.lua:102-105`) and `State.set`'s read-back accepts nil
   (`kopanda.koplugin/state.lua:50-53`)), Profile (`NetworkMgr:runWhenConnected` → fetch
   `/api/push/profiles` → `ButtonDialog`, `State.set("studio_profile", id)`), Pull `<id>` (enabled when
   both set; the confirm naming enabled shells from `Guards.enabled_shell_names()`; "Pulling `<id>`…"
   shown and `forceRePaint`ed; `PushPull.pull`; on success the Restart/Later `ConfirmBox`, Restart
   broadcasting `Event:new("Restart")`; on failure an `InfoMessage` with the message). Item texts read
   the state each time the menu draws (`text_func`), with `keep_menu_open` on Address and Profile. Every
   callback wrapped as `main.lua`'s `after_menu`/`guarded` (`main.lua:252-268`).
5. **`kopanda.koplugin/main.lua`:** require the three modules; `addToMainMenu` inserts
   `StudioMenu.item(self)` before Swatches in both the refused (`:296-302`) and normal (`:316-332`) tables.
6. **`kopanda.koplugin/HOOKS.md`:** the Studio menu (`ui/widget/inputdialog` `:583`, `:640`;
   `ui/widget/buttondialog`; `ui/widget/confirmbox`; `ui/event`; the `Restart` path
   `devicelistener.lua:454-456`, `filemanagermenu.lua:998-1004`, `uimanager.lua:1765-1769`,
   `koreader.sh:333-340`); the pull (`ui/network/manager` `:713-719`; `socketutil` `:32-33`, `:52-70`,
   `:98-140`; `socket.http`; `ffi/sha2`; `rapidjson`; `util` `makePath`); `self.path`
   (`pluginloader.lua:248`, relative on the Kindle `:24`, `:177`, `:204`); `.patches_disabled`
   (`userpatch.lua:39-40`); the state keys under the runtime state entry.
7. **AGENTS.md:** the runtime-state line names `studio_address` and `studio_profile`.

## Surfaces

- `kopanda.koplugin/push_bundle.lua`, `push_pull.lua`, `studio_menu.lua` (new); `guards.lua`, `main.lua`,
  `HOOKS.md`
- `spec/unit/push_bundle_spec.lua`, `spec/unit/push_pull_spec.lua`, `spec/unit/studio_menu_spec.lua` (new);
  `spec/unit/guards_spec.lua` (the new function)
- `AGENTS.md`

## Tests

Written first and run failing; `socket.http`'s `request` stubbed per case as
`spec/unit/weather_spec.lua:42-61`, `:131-139` do, answering from a table of URL → status and body
(bodies read from a scratch bundle tree), and feeding the request's sink.

- `spec/unit/push_bundle_spec.lua` (C5): over `spec/fixtures/push/tree/` every `sha256` and the `hash`
  equal `spec/fixtures/push/manifest.json` (decoded with `rapidjson`), and `check_manifest` accepts it for
  `vector` and refuses it for `colorsoft`; `safe_path` table cases.
- `spec/unit/push_pull_spec.lua` (C6, C7): one case per refusal in C6, each asserting `download/` gone,
  no `staged.lua`, and an earlier stage (written by a first good pull) byte-identical; a good pull stages
  the files, writes `staged.lua` with the expected fields (an emulator-style `<KO_HOME>/plugins//kopanda.koplugin`
  and a relative `plugins/kopanda.koplugin` both made absolute), and arms; each pre-request refusal makes
  no request; a failed arm (a read-only `patches/`) leaves no `staged.lua`; `socketutil` is reset after a
  request that raises.
- `spec/unit/studio_menu_spec.lua` (C7), through the plugin harness: Tools › KoPanda has Studio before
  Swatches in the normal menu and with a fake shell enabled; Address saves and clears `studio_address`;
  Profile lists the stubbed profiles and saves the choice; Pull is disabled until both are set; a
  successful stubbed pull shows the Restart box, whose Restart broadcasts `Restart` (a stubbed
  `UIManager:broadcastEvent` records it) and whose Later does nothing; a failed pull shows its message;
  the confirm names SimpleUI when a fake `simpleui` is enabled.
- `spec/unit/guards_spec.lua`: `enabled_shell_names` returns `ennUI` for an `ennUI.koplugin`, nothing for
  a disabled one.
- `spec/unit/hooks_doc_spec.lua` passes with the new modules named.

## Edge cases

- **The pull blocks the UI** while files download, behind the painted "Pulling…" message, as the theme
  studio does; no timer, no progress redraws (e-ink rule).
- **Wi-Fi off:** `runWhenConnected` prompts or turns Wi-Fi on as the user's KOReader setting says
  (`manager.lua:605-618`) and runs the pull once connected.
- **A manifest of thousands of files or huge sizes** is fetched as given; the LAN is the owner's and the
  studio serves one plugin folder.
- **`studio_profile` names a profile the studio no longer has:** the manifest is a 404 and the pull says
  so; Profile chooses another.
- **Pulling from the reader:** the menu is the same; `Restart` closes the reader through its menu's
  `exitOrRestart` (`frontend/apps/reader/modules/readermenu.lua:386`).
