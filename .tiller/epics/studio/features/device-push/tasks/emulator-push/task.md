# Emulator proves the pull, the switch-over and the rollback across restarts

## Approach

End-to-end proof on the real KOReader: several starts of the emulator on one scratch `KO_HOME`, with a
file server in a separate process. Starts after `pull-and-stage` (and through it `apply-and-rollback`);
read `spec/emulator/driver.lua` as it stands then (`preview/capture-inputs` may have changed it) and
build on it.

1. **Driver: `M.run_starts(opts)`** in `spec/emulator/driver.lua`. Takes `capture`'s options for the
   profile, plugin, library, emulator and patches, plus `extra_plugins` (folders copied into
   `<scratch>/plugins/` beside the plugin) and `starts`, a list of
   `{ env, shot = bool, cap_s, accept = { statuses } }`. `write_profile` runs once (its `assert(lfs.mkdir)`
   calls, `:116`, `:131`, `:137`, forbid a second run on one scratch) with the driver's default
   `M.disabled_plugins` (`driver.lua:16-18`, `:106-114`), unchanged. It refuses, before any start, when
   `<emulator>/plugins/<name>` exists for any extra plugin, as `capture` refuses a shadowed KoPanda
   (`driver.lua:249-252`): KOReader would load that folder twice. Each start runs
   `run_emulator` (`:200-219`) with the driver's variables plus that start's `env`, setting `KOPANDA_SHOT`
   only when `shot` is true (the capture patch is inactive without it, `patches/2-kopanda-capture.lua:8-11`).
   A start's status must be in its `accept` list (default `{ 0 }`), the timeout marker absent; a start
   with `shot` must leave its PNG and sidecar as `capture` checks them (`:305-315`). Returns
   `{ scratch, starts = { { status, log, png?, sidecar? } } }` and leaves the scratch for the spec to
   inspect; the spec removes it. `capture` is unchanged.
2. **`spec/emulator/push_server.lua`:** a `luajit` script run from the emulator directory with
   `LUA_PATH` and `LUA_CPATH` as `bin/check` sets them (`bin/check:93-95`, `:99`; the path needs
   `common/?.lua`, since `common/socket.lua` is Lua), args `<root> <port_file> <lifetime_s>`:
   `socket.bind("127.0.0.1", 0)` (`common/socket.lua:27-40`), the bound port written to `port_file`, then
   one connection at a time, `GET` only: `/api/push/profiles` from `<root>/profiles.json`,
   `/api/push/<id>/manifest` from `<root>/<id>/manifest.json`, `/api/push/<id>/files/<hash>/<path>` from
   `<root>/<id>/tree/<path>`, 409 `{ error, hash }` when `<hash>` is not the manifest's, 404 otherwise;
   `Content-Length` on every answer, `Connection: close`. It exits after `lifetime_s` with no request.
   Busted blocks on the driver's `io.popen():read` while the emulator runs (`driver.lua:215-217`), so the
   server must be its own process: the spec starts it with `os.execute("… &")`, writing its pid to a file,
   waits for `port_file`, and kills it in a `finally`.
3. **`spec/emulator/push_bundles.lua`:** writes a served bundle under a root: a tree from a plugin folder
   (`plugin/…`) and settings bytes (`settings.lua`), and `manifest.json` from the plugin's own
   `push_bundle` (`sha256_file`, `bundle_hash`) encoded with `rapidjson`; the format is pinned against
   the studio by the shared vectors, so using the device's hashing here only drives the flow.
4. **`spec/emulator/scenarios/2-scenario-push-pull.lua`:** active when `KOPANDA_PUSH_ADDRESS` is set;
   polls with `UIManager:scheduleIn` (as `2-scenario-book-close.lua:11-12`, `:89`) until
   `FileManager.instance` and `package.loaded.push_pull` exist, calls `PushPull.pull` with the address,
   `KOPANDA_PUSH_PROFILE`, the data dir, the KoPanda plugin's `path` from `PluginLoader:loadPlugins()`
   and `Guards.enabled_shell_names()`, then broadcasts `Event:new("Restart")`, as the menu's Restart does.
   A failed pull quits with status 5 after logging `KOPANDA_SCENARIO: <message>`.
5. **`spec/emulator/scenarios/2-scenario-notices.lua`:** active when `KOPANDA_NOTICES` names a file;
   wraps `UIManager.show` to append each shown `InfoMessage`'s `text` as one line to it, then calls the
   original.
6. **`spec/fixtures/push/shells/ennui.koplugin/`:** `_meta.lua` and a `main.lua` returning a bare
   `WidgetContainer` plugin that does nothing; a stand-in the coexistence guard matches by its
   lower-cased name (`kopanda.koplugin/guards.lua:11-17`). Not `simpleui` or `bookshelf`: the emulator's
   `plugins/` is a symlink to `~/Projects/kodev/koreader/plugins`, which holds the real `simpleui`,
   `bookshelf` and `solariconpack` and is scanned as `plugins` (`frontend/pluginloader.lua:24`, `:177`).
   The driver's default list disables `ennUI` by exact name (`pluginloader.lua:212`), so `ennui` stays
   enabled and a real `ennUI` stays off.
7. **`spec/emulator/push_spec.lua`:**
   - *Switch-over* (C11): bundle = the working tree's plugin with one added file `plugin/pushed.txt` and a
     settings file storing `look = "editorial"`; `extra_plugins` the fixture shell; start 1
     `{ env = address, profile, notices; accept = { 85 } }`; start 2 `{ shot = true, env = notices }`.
     Assert: start 2's sidecar `plugins` has `kopanda` and not `ennui`; `settings.reader.lua` has
     `plugins_disabled.ennui == true` and still every default entry; `plugins/kopanda.koplugin/pushed.txt`
     exists and `push/rollback/plugin/` lacks it; `settings/kopanda/settings.lua` equals the served bytes;
     no `probation.lua`, no `staged.lua`, no `result.lua`; the notices file's last line is the applied
     notice.
   - *Rollback* (C12): no fixture shell; bundle = the working tree's plugin with `plugin/main.lua` as
     `error("kopanda-test: broken bundle")`; start 1 pulls (`accept = { 85 }`); start 2 `{ shot = true,
     cap_s = 15, accept = { 3 } }` (no settle: KoPanda didn't load); assert `probation.lua` present; start
     3 `{ shot = true }`: the home captured, `plugins/kopanda.koplugin/main.lua` equals the working
     tree's, the settings file as before the pull, no `probation.lua`, no `rollback/`, the notices file's
     last line the rolled-back notice.
8. **`.env.example`:** `KOPANDA_PUSH_ADDRESS`, `KOPANDA_PUSH_PROFILE` and `KOPANDA_NOTICES`, set by
   `push_spec.lua` through the driver's env, never by hand, in the file's style.
9. **HOOKS.md**, capture-harness section: the multi-start runs and exit 85 (`uimanager.lua:1765-1769`,
   `reader.lua:312-313`, `:328`), the restart not relaunching on macOS (`frontend/device/sdl/device.lua:142`),
   the file server's `socket.bind`, and the two scenarios.

## Surfaces

- `spec/emulator/driver.lua`, `spec/emulator/push_server.lua`, `spec/emulator/push_bundles.lua` (new),
  `spec/emulator/scenarios/2-scenario-push-pull.lua`, `2-scenario-notices.lua` (new),
  `spec/emulator/push_spec.lua` (new)
- `spec/fixtures/push/shells/ennui.koplugin/` (new)
- `spec/unit/driver_spec.lua` (the new function)
- `.env.example`, `kopanda.koplugin/HOOKS.md`

## Tests

Written first and run failing; read output through `bin/check`'s default summary.

- `spec/emulator/push_spec.lua` (C11, C12) as above.
- `spec/unit/driver_spec.lua`: `run_starts` writes the profile once with the default disabled list,
  copies `extra_plugins`, refuses a shadowed extra plugin (a fake emulator directory whose `plugins/`
  holds a folder of the extra plugin's name) before any start, refuses a status outside `accept` naming
  the start, and keeps the scratch, with the probe plugin and a scenario that quits with a chosen status.
- The preserve set (C16) passes: every emulator spec at `f3f3bb6` and `driver_spec.lua`, goldens
  unchanged.

## Edge cases

- **The emulator doesn't relaunch on 85** (`canRestart = notOSX`, `frontend/device/sdl/device.lua:142`); the
  driver's next start is the relaunch.
- **The server outlives a failed spec:** its lifetime bound ends it, and the `finally` kills it.
- **A real shell of the fixture's name in the emulator's `plugins/`** would load twice; `run_starts`
  refuses it, and the fixture is named `ennui`, which the emulator doesn't hold.
- **Port 0** avoids collisions between parallel worktrees running `bin/check`.
- **Wi-Fi in the emulator is off** (`driver.lua:80-81`); the scenario calls the pull directly, bypassing
  `runWhenConnected`, which the unit spec covers with a stub.
- **The capped start** (rollback start 2) costs `cap_s`; 15 s keeps the spec's runtime reasonable.
- **Pull from the refused path:** start 1 of the switch-over runs with KoPanda refused, the same code the
  refused menu's Pull calls.
