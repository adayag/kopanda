# Early apply patch swaps the plugin, settings and shells, and rolls back an install whose home never painted

## Approach

The device's start-time half, built and tested against the stage format the feature specifies, so it
needs no pull: specs write `staged/`, `staged.lua` and folders by hand. Read the theme studio's
`lua/themestudio.koplugin/apply.lua` (@a0de5dd) first; its record writes, `purge` and result handling port,
its per-file replace and merge do not.

1. **`kopanda.koplugin/push_apply.lua`**, a module that is also the patch:
   - `PushApply.paths(data_dir)`: the push folder `<data_dir>/settings/kopanda/push` and every path in the
     feature's table, the settings file, `state.lua`, `settings.reader.lua` and `<data_dir>/patches`.
   - `PushApply.run(data_dir)`: the feature's `run` (probation → restore `rolled_back`; no `staged.lua` →
     return; else apply), wrapped so any error is written to `result.lua` as `failed` (or
     `restore_failed` inside a restore) and logged, never raised.
   - Helpers, local: `exists` by `lfs.symlinkattributes`; `purge` without following links (theme studio
     `sync.lua:249-261`); `write_record(path, value)` through `dump(value, nil, true)` to `<path>.tmp`,
     `fsyncOpenedFile`, remove `path`, rename, `fsyncDirectory` (`apply.lua:74-104`); `read_record` with
     `load(chunk, "=" .. path, "t", {})` (`apply.lua:63-72`); `move(from, to)` that refuses when `to`
     exists, so no rename the patch makes itself targets an existing path (`LuaSettings:flush`'s backup
     rename onto `.old`, `frontend/luasettings.lua:262`, is KOReader's and outside the rule); `set_reader_key(data_dir, key, value_or_nil)` and
     `set_state(data_dir, "boot_pending", false)` through `LuaSettings:open`, `saveSetting`/`delSetting`,
     `flush` (`frontend/luasettings.lua:21-48`, `:252-275`), making `settings/kopanda/` first for the state
     file as `state.lua` does (`kopanda.koplugin/state.lua:42-50`).
   - `PushApply.arm(plugin_dir, data_dir)`: refuse when `patches/.patches_disabled` exists; make
     `patches/`; copy `<plugin_dir>/push_apply.lua` to `patches/1-kopanda-apply.lua.tmp` with
     `ffiUtil.copyFile`, check the copy's size equals the source's (`copyFile` ignores write errors,
     `base/ffi/util.lua:223-241`), remove the old patch, rename. Returns `true` or `nil, message`.
   - `PushApply.probation(data_dir)`, `PushApply.clear_probation(data_dir)`,
     `PushApply.take_result(data_dir)` (read, remove, return the table or nil) for the plugin side.
   - At the end: `if select("#", ...) == 0 then` run under `pcall` with `DataStorage:getDataDir()`, an
     outer `pcall` writing a last-resort result as theme studio `apply.lua:462-474`; then `return PushApply`.
     `require` calls the loader with the module name (Lua 5.1 manual §5.3); that `dofile` passes nothing
     is LuaJIT's behaviour, which the module case in `push_apply_spec.lua` proves.
   - Requires only `datastorage`, `dump`, `ffi/util`, `libs/libkoreader-lfs`, `logger`, `luasettings`
     at the top.
2. **`kopanda.koplugin/home.lua`:** `finish(opts, painted)` passes `painted` to `opts.finished`;
   `settle` passes `home.painted_at ~= nil and not home.paint_failed`; the catch in `Home.show` passes
   `false`. Update the comment at `:201-203`.
3. **`kopanda.koplugin/push_notice.lua`:** `on_painted()`: `clear_probation` if set, then `take_result`
   and show its notice with `UIManager:nextTick` (`InfoMessage`, no timeout), each step `pcall`ed and
   logged. `on_refused()`: when no probation, `take_result` and show. The four wordings from the feature.
4. **`kopanda.koplugin/main.lua`:** require `push_apply` and `push_notice`; the boot guard's
   `opts.finished = function(painted) State.set("boot_pending", false) if painted then
   PushNotice.on_painted() end end`; in `init`'s refused branch, from a file-manager instance,
   `PushNotice.on_refused()` beside `Guards.notify_once()`.
5. **`kopanda.koplugin/HOOKS.md`:** the apply patch entry (early priority `frontend/userpatch.lua:11-12`,
   `:65-100`, `reader.lua:25-27` before `:39-40`, plugins at `filemanager.lua:418-429`; the push folder
   `datastorage.lua:60-62`, `:79-81`; `plugins_disabled` in `settings.reader.lua`,
   `frontend/pluginloader.lua:175`, `:212`, written back at exit `reader.lua:306-308`; `luasettings`;
   `ffi/util` `copyFile`, `fsyncOpenedFile`, `fsyncDirectory`; `dump`), the `boot_pending` edit under
   the runtime state entry (`:189`), and the result notices under `InfoMessage` (`:181`).
6. **AGENTS.md:** the runtime-state line also names `settings/kopanda/push/` (stage, rollback set,
   probation, result), not a setting, never read by the studio.

## Surfaces

- `kopanda.koplugin/push_apply.lua`, `push_notice.lua` (new); `home.lua`, `main.lua`, `HOOKS.md`
- `spec/unit/push_apply_spec.lua`, `spec/unit/push_notice_spec.lua` (new)
- `AGENTS.md`

## Tests

Written first and run failing. Each case builds a scratch data dir under the run's `KO_HOME` (a
`plugins/kopanda.koplugin/` with a marker file, `settings/kopanda/settings.lua`, `settings.reader.lua`
with a `plugins_disabled` table holding an unrelated name, `state.lua` with `boot_pending = true`) and a
stage by hand.

- `spec/unit/push_apply_spec.lua` (C8, C9):
  - apply: the plugin and settings swapped, the old ones in `rollback/`, `plugins_disabled` gains each
    `disable` name and keeps the unrelated one, `boot_pending` false, `probation.lua` and result `applied`
    written, no stage left; with no `settings.lua` before, `had_settings` false and none in `rollback/`;
    `plugins_disabled` absent before is recorded absent.
  - nothing staged and no probation: every file's bytes and mtime unchanged.
  - a stage record that doesn't load, a relative `plugin_dir`, one not ending `/kopanda.koplugin`, a
    missing `staged/plugin/main.lua`: result `failed`, nothing moved, no stage, no probation.
  - a failure injected at the plugin move, the settings move and the `plugins_disabled` write (a spec seam
    replacing `move` or the reader-settings writer, named with a leading underscore and listed in
    HOOKS.md as `Settings._migrate` is): everything restored, result `failed` with the step, no probation.
  - a failure injected at each part of step 9 (the result write, the removal of `staged.lua`, the purge of
    `staged/`): the install stays applied (plugin and settings swapped, `plugins_disabled` set, probation
    and `rollback/` kept), no restore, the failure logged; then, with probation cleared as a painted home
    clears it, a `run` over the leftover `staged.lua` (no `staged/plugin/`) ends `failed` with nothing
    moved and no stage left.
  - rollback: with `probation.lua` after an apply, the next `run` restores plugin, settings (and their
    absence), `plugins_disabled` (and its absence), clears `boot_pending`, purges stage and `rollback/`,
    result `rolled_back`.
  - `settings.lua.old`: with no `settings.lua` and no `.old` before the apply, a `.old` made after it (as
    the new install's flush would) is gone after the rollback and `LuaSettings:open` of the settings path
    reads `{}`; a `.old` present before the apply is left byte-identical.
  - interrupted applies: states built as an apply leaves them after each of steps 4–8 (probation written,
    plugin moved aside only, plugin swapped, settings moved aside only, settings swapped); `run` returns
    each to the pre-apply tree, compared file by file.
  - a restore whose plugin move fails: `plugins_disabled` equals the record's, the settings restored and
    `boot_pending` false (the later steps still tried), result `restore_failed` naming the plugin step,
    probation and `rollback/` kept; the next `run` with the fault gone completes it.
  - a restore whose final purge of `discard/` fails: the swap stands, the failure is logged, result
    `rolled_back`.
  - every rename the patch's own `move` makes goes to an absent path (the `move` seam records and asserts).
  - the module: `require("push_apply")` changes nothing on disk; `dofile` of a copy under a `KO_HOME`
    with a stage applies it; a `dofile` whose `run` raises writes `result.lua` and does not raise.
  - `arm`: `.patches_disabled` refuses; the patch file equals `push_apply.lua` byte for byte; a re-arm
    replaces it.
- `spec/unit/push_notice_spec.lua` (C10), through the plugin harness: a home whose paint succeeds calls
  `finished(true)`; a paint, build or show that throws calls `finished(false)`; on `true` probation is
  removed and the result's notice is on the stack and the file gone; on `false` both files stay; refused
  with a fake shell enabled and no probation the notice shows, with probation nothing shows and both stay;
  each kind's text.
- `spec/unit/failsafe_spec.lua` is not edited: the boot guard ignores the new argument, so its cases pass unchanged (C10, C16).

## Edge cases

- **A crash inside the patch's own write of `probation.lua`** leaves a temporary file and no probation:
  nothing has moved yet, and the stage is applied again from step 2 at the next start.
- **`settings.reader.lua` corrupt:** `LuaSettings:open` falls back to `.old` then `{}`
  (`frontend/luasettings.lua:31-45`); the patch writes what it read plus the names, as KOReader would.
- **`state.lua` absent:** the patch creates it with `boot_pending = false`, which the plugin reads as no
  flag.
- **The patch is the previous build's code** after a successful apply until the next pull re-arms; it
  only needs the stage and record formats, which `format = 1` pins.
- **A home that paints, then the process dies before `clear_probation` runs** rolls back at the next
  start; `clear_probation` runs first in `on_painted`, before the notice.
