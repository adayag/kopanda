# A placeholder home over the file browser, closed with it, signalling its paint

## Approach

The plugin's skeleton, the home widget as a placeholder, the show/close lifecycle around the file
manager, and the settled signal, proven headless in unit specs and in the emulator with goldens. Every
outside claim below is at KOReader `e1fe1ac` (paths relative to `~/Projects/kodev/koreader/`) or ennUI
`ae26fc4` (read, never copied).

1. **`kopanda.koplugin/_meta.lua`**: `return { fullname = "KoPanda", description = "...", version =
   "0.1.0" }`. No `name` key: the runtime name is the folder's, `kopanda`
   (`frontend/pluginloader.lua:210`, `:249`; a `name` is ignored with a warning, `:256-259`).
2. **`kopanda.koplugin/main.lua`**, a `WidgetContainer:extend{ name = "kopanda", is_doc_only = false }`.
   - Requires every KoPanda module at the top of the file. KOReader prepends the plugin root to
     `package.path` only while it `dofile`s `main.lua` (`pluginloader.lua:242`, restored `:269-270`)
     and later appends every enabled plugin's root (`:283-286`), so a lazy `require` could resolve to
     another plugin's same-named file.
   - `init`: body in `pcall`, logging through `logger.err` on failure; sets `self.in_fm =
     self.ui ~= nil and self.ui.document == nil` (the file manager makes instances with `{ ui = self }`,
     `frontend/apps/filemanager/filemanager.lua:418-429`; the reader adds `document`,
     `frontend/apps/reader/readerui.lua:464-478`; ennUI `main.lua:44` uses the same test).
   - `onShow` (file manager only; KOReader sandboxes `on*` plugin handlers, `pluginloader.lua:117-164`,
     `:263`, but the body still guards itself so it can fall back): `UIManager:nextTick(function()
     self:showHome() end)` (`frontend/ui/uimanager.lua:431-433`). Returns nothing: a true return stops
     `Show` reaching later modules (`frontend/ui/widget/container/widgetcontainer.lua:80-89`).
   - `showHome()`: returns when the module's shown home exists, or when
     `package.loaded["apps/filemanager/filemanager"]` has no `instance` (set `filemanager.lua:447`,
     cleared `:839`; read the way ennUI does, `main.lua:91`). Otherwise `Home.show{ started =
     time.monotonic() }`.
   - `onCloseWidget` (file manager only): `Home.close()`. Closing the file manager sends it
     `CloseWidget` (`uimanager.lua:300`; `filemanager.lua:819-826` on quit, `:842-849` when a book
     opens), which reaches the plugin instance as an array child (`filemanager.lua:379-389`).
3. **`kopanda.koplugin/home.lua`**, the home widget and its module state.
   - `Home = InputContainer:extend{ name = "kopanda_home", covers_fullscreen = true }`
     (`uimanager.lua:1305-1316` skips `paintTo` beneath it; ennUI `ennui_home.lua:108`). `init` sets
     `dimen = Screen:getSize()` and builds the placeholder: a white `FrameContainer` the size of the
     screen holding a `CenterContainer` with a `VerticalGroup` of two `TextWidget`s, "KoPanda" and "Tap
     to open the file browser", in `Font:getFace("cfont", ...)` at `Screen:scaleBySize` sizes (the
     probe's widgets, `spec/fixtures/probe.koplugin/main.lua`). Fixed strings, so captures compare equal.
   - Module state: `Home.shown` (the instance on screen or nil).
   - `Home.show(opts)`: build in `pcall`; `UIManager:show(home, "full")` (`uimanager.lua:229`; ennUI
     `main.lua:111`); `UIManager:tickAfterNext` (`uimanager.lua:447-456`) to a callback that computes
     `paint_ms = time.to_ms(time.monotonic() - opts.started)` and calls
     `UIManager.event_hook:execute("KoPandaSettled", { screen = "home", paint_ms = paint_ms, prebuilt =
     opts.prebuilt == true })` in `pcall`, once per instance (`uimanager.lua:53`,
     `frontend/ui/hook_container.lua:88-98`; with no listener it runs nothing). Any error: log, close the
     widget if it reached the stack, `Home.shown = nil`.
   - `Home.close()`: `UIManager:close(Home.shown)` when shown; `Home.shown = nil`. The home's own
     `onCloseWidget` also clears `Home.shown` when it is the shown one, so a close from elsewhere leaves
     no stale reference.
   - `Home:paintTo`: `InputContainer.paintTo` in `pcall`; on error log and `UIManager:nextTick` a close
     (a widget can't be closed from inside the repaint), leaving the file browser beneath.
   - `Home:onGesture(ges)` in `pcall` (the home is not a plugin, so KOReader does not sandbox it, and an
     error in `UIManager:sendEvent` would reach the UI loop): a `tap` outside KOReader's top menu zones
     (`DTAP_ZONE_MENU` and `DTAP_ZONE_MENU_EXT`, read through `G_defaults:readSetting` as
     `frontend/apps/filemanager/filemanagermenu.lua:74-75` does; `defaults.lua:59-60`) closes the home
     and returns true; anything else returns false. `gesture-routing` replaces this body with the full
     routing. On error: log, close the home, return true.
4. **`spec/plugin_harness.lua`**, the unit specs' way to run the plugin inside a real headless file
   manager: `load()` calls commonrequire's `disable_plugins()` (`spec/unit/commonrequire.lua:57-62` in
   the KOReader source, installed at `spec/front/unit/`), unloads KoPanda's modules with
   `package.unload` (`commonrequire.lua:37-42`) so module state starts fresh, then `PluginLoader:_load{
   { main = <repo>/kopanda.koplugin/main.lua, meta = .../_meta.lua, path = <repo>/kopanda.koplugin,
   name = "kopanda" } }` (`pluginloader.lua:231-271`, the fields read at `:237-241`), so handlers are
   sandboxed as on a device. `show_fm(dir)` runs `FileManager:showFiles(dir)` (`filemanager.lua:1312-1331`;
   KOReader's own `spec/unit/filemanager_spec.lua:16-25` builds one headless); `tick(n)` runs
   `fastforward_ui_events()` n times (`commonrequire.lua:77-85`); `top(n)` is
   `UIManager:getNthTopWidget(n)` (`uimanager.lua:832`); `teardown()` closes the file manager and
   anything left on the stack. A reader is `ReaderUI:new{ dimen = Screen:getSize(), document =
   DocumentRegistry:openDocument(<fixture epub>) }` (KOReader `spec/unit/readerui_spec.lua:14-17`).
5. **`kopanda.koplugin/HOOKS.md`**: a new section "Plugin (`kopanda.koplugin/`)" above the harness
   section, one entry per KOReader surface this task reads, each with `file:line` and one line of why:
   the `Show` event and plugin instances (pointing to the harness entry), `self.ui.document` as the
   reader test, `package.path` during plugin load, the handler sandbox, `FileManager.instance`,
   `CloseWidget` on file-manager close, `covers_fullscreen` in `_repaint`, `nextTick`/`tickAfterNext`,
   `UIManager:show`/`close`, `G_defaults` `DTAP_ZONE_MENU`/`_EXT`, `InputContainer` gesture dispatch,
   and each widget module required.
6. **Goldens**: `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/home_golden_spec.lua`, open both PNGs,
   confirm the placeholder fills the screen and nothing of the file browser shows, commit them with
   their sidecars (contract C4).

## Surfaces

- `kopanda.koplugin/_meta.lua`, `kopanda.koplugin/main.lua`, `kopanda.koplugin/home.lua` (new)
- `kopanda.koplugin/HOOKS.md` (plugin section)
- `spec/plugin_harness.lua` (new)
- `spec/unit/home_lifecycle_spec.lua`, `spec/unit/failsafe_spec.lua`, `spec/unit/hooks_doc_spec.lua` (new)
- `spec/emulator/home_capture_spec.lua`, `spec/emulator/home_golden_spec.lua` (new)
- `spec/goldens/home-placeholder-colorsoft.png`, `.json`, `spec/goldens/home-placeholder-paperwhite.png`,
  `.json` (new)

## Tests

Written first, each run and seen failing before its implementation.

- `spec/unit/home_lifecycle_spec.lua` (contract C1), on a headless file manager over
  `spec/fixtures/library/`:
  - right after `showFiles` returns, before any tick, the top widget is the file manager (the show is
    deferred to the next tick);
  - after `tick(2)`, the top widget is the KoPanda home, `covers_fullscreen` is true, its `dimen` is the
    screen's, and `top(2)` is `FileManager.instance`;
  - `showFiles` then `FileManager.instance.history:onShowHist()` synchronously (the order `reader.lua:291-295`
    uses for `start_with = history`), then `tick(2)`: the home is on top and the history list is
    beneath it;
  - `FileManager.instance:onClose()`: the home is no longer shown (`UIManager:isWidgetShown`,
    `uimanager.lua:881`) and the stack is empty;
  - closing the file manager and calling `showFiles` again shows exactly one home;
  - a reader made on a fixture EPUB with the plugin loaded: its KoPanda instance's `onShow` shows no
    home;
  - a synthetic tap (`{ ges = "tap", pos = Geom:new{ x, y, w = 0, h = 0 }, time = time.now() }`, the
    fields `GestureRange:match` reads, `frontend/ui/gesturerange.lua:21-51`) sent with
    `UIManager:sendEvent(Event:new("Gesture", ges))` mid-screen closes the home and leaves the file
    manager on top; the same tap at the top centre (inside `DTAP_ZONE_MENU`) leaves the home shown.
- `spec/unit/failsafe_spec.lua` (contract C14; later tasks add their cases here):
  - with the home's `init` replaced by one that errors, `showFiles` + `tick(2)` leaves the file manager
    on top, no home on the stack, and the error in the log;
  - with `InputContainer.paintTo` erroring for the home only, after `tick(3)` the home is closed and the
    file manager is on top;
  - with the home's gesture body erroring, a tap is consumed, the home is closed, nothing propagates.
- `spec/unit/hooks_doc_spec.lua` (contract C15): scans `kopanda.koplugin/**/*.lua`; every
  `require("<m>")` and `package.loaded["<m>"]` whose `<m>` is not a file in the plugin appears in
  `HOOKS.md` in backticks; every `G_reader_settings:<method>("<key>")` and `G_defaults:readSetting("<key>")`
  key appears; every `<name>._<field>` or `:_<method>` access appears; and every `###` entry under the
  plugin section has a line matching `%.lua:%d+`. Seen failing first against a HOOKS.md missing one
  entry. It also checks that no KoPanda module path (a `.lua` file in the plugin other than `main.lua`
  and `_meta.lua`) is also a module path in the emulator's `frontend/`, `common/` or any
  `plugins/*.koplugin/`: `package.loaded` is one table for the whole process, so a same-named module
  required first by another plugin would be the one KoPanda gets.
- `spec/emulator/home_capture_spec.lua` (contract C2): for colorsoft and paperwhite,
  `driver.capture{ profile, plugin_dir = <root>/kopanda.koplugin }` on the fixture library returns a PNG
  of the profile's size; the sidecar has `screen == "home"`, numeric `paint_ms > 0`, and `plugins`
  containing `kopanda`; the log has one `KOPANDA_SHOT: saved` line and no `settle cap`.
- `spec/emulator/home_golden_spec.lua` (contract C3): for both profiles,
  `golden.assert_golden("home-placeholder", profile, result)`.
- Scope check: `bin/check spec/unit/home_lifecycle_spec.lua` lists only that spec's tests.

## Edge cases

- `FileManager.instance` is nil inside `FileManager:init` and set at `:447`; `onShow` runs after it, and
  the deferred show checks it again because the file manager can close between `Show` and the tick.
- Two file managers in a row (book open then close) each make a fresh plugin instance; the shown home
  lives at module level, so a second `onShow` while a home is shown is a no-op.
- The capture patch quits 0.5 s after the first signal; the home signals once per instance, so the
  capture is the first paint.
- `Home:onCloseWidget` may run because KOReader closed the home itself (e.g. a future "close all"
  path); `Home.shown` is cleared there so `showHome` doesn't think a closed home is up.
- Module names: at the pinned build no `home.lua` exists under `frontend/`, `common/` or the emulator's
  `plugins/` (one plugin there ships a `weather.lua`, which matters to `home-layout`); the hooks spec
  keeps it that way for every later module.
- `paint_ms` on the Mac is a few milliseconds and varies; the spec asserts only that it is positive.
- The golden is per profile; the paperwhite capture is grey (`EMULATE_BW_SCREEN`), so the placeholder
  must read in grey, which plain black text on white does.
