# Coexistence refusal, boot guard and the runtime state file

## Approach

The two safety nets around the shell, and the runtime state file the boot guard needs (which
`entry-points` reuses for its tab-index marker). KOReader citations are at `e1fe1ac`, relative to
`~/Projects/kodev/koreader/`; ennUI at `ae26fc4`, read only.

1. **`kopanda.koplugin/state.lua`**, runtime state, not settings.
   - Opens `DataStorage:getSettingsDir() .. "/kopanda/state.lua"` (`datastorage.lua:60`) with
     `LuaSettings:open` (`frontend/luasettings.lua:21-48`: a missing or corrupt file reads as an empty
     table, falling back to `.old`) on first use, once per process.
   - `State.get(key)`, `State.set(key, value)`: `set` saves and flushes at once, so the value survives a
     crash. `LuaSettings:flush` writes through `util.writeToFile`, which does not create directories
     (`luasettings.lua:270-275`, `frontend/util.lua:1124-1143`), so `set` first creates
     `settings/kopanda/` with `lfs.mkdir` when missing. Every call is in `pcall`; a failure logs and
     returns nil (get) or false (set), and callers treat that as "flag absent".
   - Keys this feature uses: `boot_pending` (here) and `menu_tab_shifted` (`entry-points`). No schema
     entry, no studio access.
   - `AGENTS.md`, Conventions, one line: runtime state (the boot guard flag, one-time migration markers)
     lives in `settings/kopanda/state.lua` through `LuaSettings`; it is not a setting, has no schema
     entry, and the studio never reads or writes it.
2. **`kopanda.koplugin/guards.lua`**, coexistence.
   - `Guards.conflicts()`: the display names of enabled shells, from the list
     `PluginLoader:loadPlugins()` returns (memoised, `frontend/pluginloader.lua:273-292`; by the time any
     plugin instance exists it has run, `filemanager.lua:418`, `readerui.lua:464`). Not `loaded_plugins`
     or `getPluginInstance`, which fill in path order as instances are made (`pluginloader.lua:479-482`).
     Each module's `.name` (the folder name, `pluginloader.lua:210`, `:249`) is lowercased and matched
     against `simpleui` → "SimpleUI", `bookshelf` → "Bookshelf", `ennui` → "ennUI". ennUI's `_meta.lua`
     says `ennui` but a git clone's folder is `ennUI.koplugin`, and KOReader ignores `_meta` names
     (`pluginloader.lua:256-259`), hence the lowercase match.
   - Computed once per process at module level; `Guards.refused()` is true when the list is non-empty.
   - `Guards.notify_once()`: the first call in a process schedules, with `UIManager:nextTick`, an
     `InfoMessage` saying KoPanda's home is off while the named plugins are enabled and to disable them
     in Plugin management and restart (ennUI raises its startup notice from `nextTick` the same way,
     `main.lua:69-79`); later calls do nothing.
   - `main.lua`'s `init`, in both the file manager and the reader: when `Guards.refused()`, set
     `self.refused = true`, call `notify_once()` (file manager only), and return before anything else.
     Every other handler returns at once when `self.refused`. `entry-points` and `gesture-routing`
     follow the same rule for what they add.
3. **Boot guard** (`main.lua`'s `showHome`, `home.lua`'s show path).
   - Module flag `first_show_done`, false at load. On the first `showHome` of a process:
     - if `State.get("boot_pending")` is true: `State.set("boot_pending", false)`, mark the first show
       done, show an `InfoMessage` (timeout 8, from `nextTick`) saying the home was skipped because it
       didn't finish drawing last time and that it opens from the Home tab or Tools › KoPanda, and show
       no home this time (ennUI's `boot_pending`, `main.lua:69-79`, read);
     - otherwise `State.set("boot_pending", true)` before `Home.show`, and pass callbacks so the flag is
       cleared from the same `tickAfterNext` callback that sends the settled signal (after a successful
       first paint) and on any caught failure of the build, show or paint (ennUI clears on failure,
       `main.lua:98`, `:125`).
   - Later shows in the process are not guarded: no state write, book closes included.
   - What leaves the flag set is exactly what the guard is for: a crash, a hang or a kill between the
     show and its paint.

## Surfaces

- `kopanda.koplugin/state.lua`, `kopanda.koplugin/guards.lua` (new)
- `kopanda.koplugin/main.lua`, `kopanda.koplugin/home.lua` (refusal check, boot guard callbacks)
- `kopanda.koplugin/HOOKS.md` (`PluginLoader:loadPlugins` and plugin names, `LuaSettings`,
  `DataStorage:getSettingsDir`, `util.writeToFile` not creating directories, `InfoMessage`)
- `AGENTS.md` (Conventions, one line)
- `spec/unit/guards_spec.lua` (new), `spec/unit/failsafe_spec.lua` (cases added)

## Tests

Written first, each run and seen failing before its implementation.

- `spec/unit/guards_spec.lua`, with `spec/plugin_harness.lua`:
  - coexistence (contract C11): after the harness loads KoPanda, a fake module `{ name = "simpleui" }`
    is appended to `PluginLoader.enabled_plugins`; `showFiles` + `tick(2)`: no KoPanda home on the
    stack, exactly one `InfoMessage` whose text contains "SimpleUI";
  - the same with `ennUI` (mixed case) names "ennUI"; with `bookshelf` and `simpleui` together names
    both;
  - closing the file manager and showing it again in the same process raises no second message;
  - a reader made while refused: its `CloseDocument` leaves no pending home;
  - boot guard (contract C12): on a fresh profile, a spy on `State.set` records `("boot_pending", true)`
    before the `UIManager:show` of the home, and `("boot_pending", false)` from the settled callback; after
    `showFiles` + `tick(2)`, `state.lua` read back with `LuaSettings:open` has `boot_pending == false`
    (one `fastforward_ui_events()` runs the whole show → repaint → `tickAfterNext` chain,
    `commonrequire.lua:77-85`, `uimanager.lua:1542-1564`, so no tick count observes the flag set);
  - with `state.lua` pre-written as `{ boot_pending = true }`: `showFiles` + `tick(2)` shows no home,
    one `InfoMessage`, and the file reads back `boot_pending == false`; then closing and showing the file
    manager again shows the home;
  - the second show of a process does not touch the file (its modification time and content are
    unchanged);
  - with no `settings/kopanda/` directory, the first show creates it and the file;
  - a home whose build errors leaves `boot_pending == false`.
- `spec/unit/failsafe_spec.lua` (contract C14): `settings/kopanda` made a plain file (so the directory
  can't be created) still shows the home and logs the write failure; a corrupt `state.lua` reads as
  absent and the home shows.
- The AGENTS.md line is checked by contract C13's `grep`.

## Edge cases

- A user with SimpleUI enabled and KoPanda installed sees the message on every start until one of
  them is disabled; that is the intent of "refuses and says which".
- The emulator's own `plugins/` holds SimpleUI, Bookshelf and the Solar icon pack; the capture driver
  disables them by folder name (`spec/emulator/driver.lua`, `disabled_plugins`), so the emulator specs
  never trip the refusal.
- `state.lua` is written by `LuaSettings`, which keeps a `.old` backup on flush (`luasettings.lua:252-269`);
  both live under `settings/kopanda/`.
- A first show that is skipped by the guard still marks the first show done, so a book close later in
  that process shows the home without a guard write.
- `Guards.conflicts()` runs from `init`; if the call errors (a plugin module without `.name`), it logs
  and treats the list as empty, never refusing KOReader's own file browser.
