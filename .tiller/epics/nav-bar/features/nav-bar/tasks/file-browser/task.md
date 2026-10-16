# The bar under KOReader's file browser: the setupLayout patch, its failsafe and its tripwire

## Approach

The first patch into KOReader's own layout: `FileManager.setupLayout` wrapped so the file chooser is built
short of the band and the bar sits in it, with every step failing safe, an upgrade tripwire, and the
`HOOKS.md` record. Starts after `nav-bar/nav-bar/bar`. Repo lines on `main` at `fa0e7dd`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. The feature's "The file browser", "Failure behaviour" and "Upgrade
tripwire and HOOKS.md" are the spec.

1. **The tripwire first** (C5), in `spec/unit/fm_nav_spec.lua`, against KOReader's unwrapped function before
   anything is patched: `debug.getinfo(FileManager.setupLayout, "S")` has a `source` ending in
   `frontend/apps/filemanager/filemanager.lua` and `linedefined` 116; on `harness.show_fm()`, `fm[1]` is a
   `FrameContainer` with exactly one array child, `fm.file_chooser`, whose `name` is `"filemanager"` and whose
   `dimen.h` is the screen's height; a `FileChooser:new{ path = harness.library, height = 500 }` has `dimen.h`
   500 (`frontend/ui/widget/menu.lua:701-704`). It passes today and must keep passing. The case's comment says
   what to do when it fails: re-read `setupLayout` and the lines `HOOKS.md` cites, then change the pin.
2. **`spec/plugin_harness.lua`:** `M.fm_setup_layout = require("apps/filemanager/filemanager").setupLayout`
   beside `M.dispatcher_execute` (`:56-57`), restored in `M.load()` beside it (`:72`), and the comment over
   `load` (`:59-68`) says so. The tripwire reads `M.fm_setup_layout`.
3. **`kopanda.koplugin/fm_nav.lua`** (`FmNav`), requiring `looks`, `nav_bar` and KOReader's widgets at load,
   and `apps/filemanager/filemanager` and `ui/widget/filechooser` there too (both are loaded before any
   plugin instance exists: a file manager is that module, which requires the chooser at load,
   `filemanager.lua:12`, before its plugins, `:418-431`; in a reader, KoPanda's own `main.lua:8-9` load
   `dispatcher` first, which requires the file manager at load, `frontend/dispatcher.lua:39`):
   - `FmNav.install()`: once per process behind a module-local flag, as `DispatchBridge.install`
     (`dispatch_bridge.lua:33-58`). The wrapper, in the feature's five steps: KoPanda's instance present and
     not refused, else the original alone; the band from `NavBar.height(Looks.active(), Screen)` and
     `time.monotonic()`, in `pcall` (failure: logged, original alone); `FileChooser.height = Screen:getHeight()
     − band`, `pcall(original, fm)`, `FileChooser.height = nil` on both paths, the original's error re-raised
     with `error(err, 0)`; then, in `pcall`, `fm[1] = FmNav.Frame:new{ ... }` holding `fm_ui` and
     `NavBar.new{ look, variant, width, where = "file_browser", listen = true }` at `(0, height − band)`
     (failure: logged, `fm[1]` left as the original set it).
   - `FmNav.Frame`: a `WidgetContainer` with `dimen` the screen, its array children the bar then `fm_ui` so
     events reach the bar first (`frontend/ui/widget/container/widgetcontainer.lua:80-88`); `paintTo` paints
     `fm_ui` at its origin, then the bar at its place, the bar's paint in `pcall` (a failure logged once per
     frame). Before painting it compares its variant with `Looks.variant()` and rebuilds the bar when it
     changed, as `home.lua:282-291` does. It keeps `look`, `variant`, `band` and the setupLayout duration.
   - **The settled signal:** after each paint, `UIManager:tickAfterNext` checks the file manager is
     `UIManager:getNthTopWidget(1)` and this frame hasn't signalled; if so it sends `KoPandaSettled{ screen =
     "file_browser", paint_ms }`, `paint_ms` the setupLayout duration plus this paint's, in ms, through
     `UIManager.event_hook:execute` in `pcall` as `home.lua:165-176` sends its own.
   - `FmNav.relayout()`: in `pcall`; with `FileManager.instance` whose `fm[1]` is an `FmNav.Frame`,
     `fm:reinit()` (`filemanager.lua:789-810`) then `UIManager:setDirty(fm, "ui")`; else nothing.
4. **`main.lua`:** requires `fm_nav` at load; `KoPanda:init` calls `FmNav.install()` after
   `DispatchBridge.install()` when `self.in_fm` (`main.lua:86-97`), inside the existing `pcall`. The
   boot-guard notice's wording stays (`main.lua:136-138`, D10).
5. **`menu.lua`:** `write` (`menu.lua:51-69`), after a stored change to the `look` key, calls
   `FmNav.relayout()` before its home refresh. `fm_nav` is required at call time here, as `home` is
   (`menu.lua:49-50`, `:61`). A load-time require would not loop (`fm_nav` reaches only `looks`, `nav_bar`
   and KOReader's modules, and `nav_bar` reaches `launcher_entries` and `home` only at call time, task
   `bar`), so this keeps `menu.lua`'s requires as they are rather than avoiding a cycle.
6. **`HOOKS.md`:** a section "The nav bar in the file browser: `setupLayout`, the chooser's height and the
   event order" with every citation the feature's "Upgrade tripwire and HOOKS.md" lists, what KoPanda relies on
   in each, and that the tripwire in `fm_nav_spec.lua` guards it.

## Surfaces

`kopanda.koplugin/fm_nav.lua` (new), `kopanda.koplugin/main.lua`, `kopanda.koplugin/menu.lua`,
`kopanda.koplugin/HOOKS.md`, `spec/plugin_harness.lua`. Specs: `spec/unit/fm_nav_spec.lua` (new),
`spec/unit/menu_spec.lua`, `spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `fm_nav_spec.lua`:
  - **Tripwire** (C5): step 1.
  - **Layout** (C4): after `harness.load()` and `show_fm()`, the chooser's `dimen.h` is the screen's height
    less `NavBar.height(Looks.active(), Screen)`; its page footer's bottom is at or above the band's top;
    `fm[1]` is an `FmNav.Frame` whose bar has Library active at the band; `rawget(FileChooser, "height")` is
    nil; a `PathChooser:new{ path = harness.library }` built afterwards is the screen's height
    (`frontend/ui/widget/pathchooser.lua:13`).
  - **Taps** (C4): a tap at each tab's centre through `UIManager:sendEvent` runs it (`LauncherEntries.run`
    and `KoPanda:goHome` spied): Library calls `fm:onHome` once, Home shows the home; with a tap zone
    registered on the file manager over the bottom-right eighth, a tap at `(w − 10, h − 10)` runs Settings
    and not the zone; a hold in the bar runs nothing; a tap on a book row above the band still selects it.
  - **Re-layout** (C4): `fm:reinit()` and `fm:onSetRotationMode` to landscape and back each leave a frame
    with a bar at the new width and a chooser short of the band.
  - **Night** (C4): `Screen.night_mode` toggled (as `night_mode_spec.lua` toggles it), a paint rebuilds the
    bar once and paints the night palette's inverted fill in the band.
  - **Refused** (C4): with `Guards.refused` stubbed true before `load`, `FileManager.setupLayout` is the
    harness's original after `show_fm`.
  - **Once** (C4): two file managers in a row wrap once; the second's chooser is short of the band too.
  - **Settled** (C4): with the home closed and the file manager on top, a paint then two ticks sends one
    `KoPandaSettled` with `screen = "file_browser"` and a numeric `paint_ms > 0`; a second paint sends none;
    with the home up over it, a paint sends none.
  - **Failure paths** of the feature's list, each with the file manager on top and handling a tap afterwards:
    `NavBar.height` raising (full-height chooser, `fm[1]` a `FrameContainer`); the original raising
    (re-raised unchanged, `rawget(FileChooser, "height")` nil); `NavBar.new` raising (`fm[1]` the original's
    `FrameContainer`); the bar's paint raising (logged once over two paints); a tab's run raising (logged, tap
    consumed); `fm.reinit` raising inside `relayout` (logged).
- `menu_spec.lua` (C4): choosing Editorial in the look submenu with a file manager up calls `fm:reinit()` once
  (spied) and leaves a frame whose band is Editorial's height; choosing the stored look calls nothing; with
  no file manager (the reader's menu), nothing.
- `failsafe_spec.lua` (C6): the patch's failure cases in the file's own "leaves the file manager usable"
  form, so the preserve criterion carries them.
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C7) pass with `fm_nav` required and the new section in.
- `gesture_routing_spec.lua`'s "opens no settings on a swipe up from the bottom edge in the file browser"
  (`:415`) still passes with the bar there.

## Edge cases

- **SimpleUI or another shell enabled:** KoPanda is refused (`main.lua:78-85`) and never installs, so
  SimpleUI's own `setupLayout` wrapper (`infra/sui_patches.lua:359`, SimpleUI 2.7.5 as installed) is alone.
- **A window resize** in the emulator re-runs the chooser's `init` through `Menu:onScreenResize`
  (`menu.lua:1316-1319`) at full height; only the SDL and Android ports send it
  (`frontend/device/sdl/device.lua:314`, `frontend/device/android/device.lua:169`). Not handled; the Kindle
  never sends it.
- **Key navigation** stays the chooser's (`fm.layout`, `filemanager.lua:356`); the bar is touch only.
- **History, Favorites and Collections** are full-screen widgets of their own (`filemanagerhistory.lua:59-97`)
  and get no bar (D1).
- **CoverBrowser** patches `FileChooser.updateItems`, not `setupLayout` (`plugins/coverbrowser.koplugin/main.lua:681`);
  its rows size from the chooser's shorter inner height, as a `height` gives.
- **The relayout under a shown home:** `reinit` rebuilds the file manager beneath; the home covers it
  (`covers_fullscreen`), so nothing paints until the home closes.
