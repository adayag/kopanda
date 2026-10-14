# Closing a book lands on a pre-built home in one paint

## Approach

Two parts: the pre-build itself (small, in the plugin), and the emulator scenario support that lets a
spec close a real book and count what was painted (in the harness; `gesture-routing` reuses it).
KOReader citations are at `e1fe1ac`, relative to `~/Projects/kodev/koreader/`.

1. **Pre-build** (`kopanda.koplugin/home.lua`, `main.lua`).
   - `ReaderUI:onClose` sends `CloseDocument` to the reader's modules, the plugin instance among them
     (`frontend/apps/reader/readerui.lua:870-900`, `:887`), then closes the reader (`:893`); its callers
     then show the file manager (`ReaderUI:onHome` `:935-940`, `showFileManager` `:581-596`, the reader
     menu's file-browser tab `frontend/apps/reader/modules/readermenu.lua:65-74`), whose `Show` reaches
     the new file manager's plugin instance (`frontend/apps/filemanager/filemanager.lua:1312-1331`).
   - `Home.prebuild()`: builds a home in `pcall` and keeps it as `Home.pending`, not shown (ennUI's
     shape, `ennui_home.lua:116-127` at `ae26fc4`, read only). The reader instance's `onCloseDocument`
     calls it when there is no pending home already, in `pcall`, returning nothing.
   - `showHome()` in the file manager: when `Home.pending` exists and its `dimen` equals
     `Screen:getSize()`, `Home.show{ widget = pending, started = <onShow time>, prebuilt = true }` and
     `Home.pending = nil`; a pending home of another size is dropped (freed with `free()`) and a fresh one
     built, because `showFiles` resets the rotation before building the file manager
     (`filemanager.lua:1322`). `paint_ms` for a pre-built home is measured from the plugin's `onShow`,
     so it is the home's own share of the close.
   - `CloseDocument` also fires on `reloadDocument` (`readerui.lua:959`), `switchDocument` (`:979`) and
     exit or restart (`readermenu.lua:386-393`), with no file browser after. The reader instance's
     `init` drops any pending home (a reader starting means no file browser followed); exit drops it with
     the process. The wasted build is accepted (the placeholder is cheap); the comment at
     `onCloseDocument` says so.
   - `onShow` changes from `home-lifecycle`'s: when a pending home exists it calls `showHome()` at once,
     synchronously inside `Show` (ennUI `main.lua:62-66` shows its home from `onShow` the same way);
     only with no pending home does it keep the `UIManager:nextTick` show. The home is then on the stack
     before the UI loop's next `_repaint` (`frontend/ui/uimanager.lua:1537-1564`: `_checkTasks` at
     `:1543`, `_repaint` at `:1563`), which skips the file manager beneath the `covers_fullscreen` home
     (`uimanager.lua:1305-1316`), whatever ran the close. Nothing of `start_with` follows a book close,
     so there is nothing to wait for. The emulator spec checks this rather than trusting the reading.
2. **Scenario support in the capture harness** (`spec/emulator/driver.lua`,
   `spec/emulator/patches/2-kopanda-capture.lua`).
   - `capture{ ..., patches = { <path>, ... }, shot_screen = <string> }`: each extra patch is copied into
     the scratch profile's `patches/` (its name must start with `2-`, KOReader's `late` priority, applied
     in natural-sort order, `frontend/userpatch.lua:13`, `:82`), and `shot_screen` (default `home`) is
     passed as `KOPANDA_SHOT_SCREEN`.
   - The capture patch shoots on the first `KoPandaSettled` whose `screen` equals `KOPANDA_SHOT_SCREEN`
     (default `home`) and ignores the others; it copies every string, number or boolean argument of that
     signal into the sidecar, without overwriting `width`, `height`, `color`, `plugins` or `koreader`.
   - `.env.example` documents `KOPANDA_SHOT_SCREEN` as set by the driver; `HOOKS.md`'s harness section
     gains the reader surfaces the scenario uses.
3. **The book-close scenario**, `spec/emulator/scenarios/2-scenario-book-close.lua`, a userpatch:
   - At patch time (before any plugin runs, `reader.lua:190`), wraps `FileManager.paintTo` with a counter
     that counts only while armed (FileManager defines no `paintTo` of its own; it inherits
     `InputContainer`'s, so the wrapper calls that).
   - Registers a `KoPandaSettled` listener. On the first `home` signal: picks the one `.epub` in
     `FileManager.instance.file_chooser.path` and opens it with `ReaderUI:showReader(path)`
     (`readerui.lua:616`; a fresh profile has no archived sidecar, so no restore prompt, `:643-667`),
     from `UIManager:nextTick`. Polls with `UIManager:scheduleIn(0.5, ...)` until `ReaderUI.instance`
     (set `readerui.lua:546`) has a `document`, waits one more tick, arms the counter, notes
     `time.monotonic()`, and calls `ReaderUI.instance:onHome()` from that scheduled task, so the close
     runs inside `_checkTasks` as KOReader's end-of-book file-browser action does
     (`frontend/apps/reader/modules/readerstatus.lua:144-148`): the case where a `nextTick` show would
     lose to the repaint (see Edge cases).
   - On the next `home` signal: emits `KoPandaSettled{ screen = "scenario", fm_paints = <count>,
     prebuilt = <arg>, home_ms = <arg paint_ms>, close_to_paint_ms = <ms since onHome>, paint_ms =
     <same> }`. Any error emits `KoPandaSettled{ screen = "scenario", error = <message> }` so the spec
     fails with the message, not at the settle cap.
   - The spec copies one fixture EPUB into a fresh library dir under `KO_HOME`: KOReader's default
     `document_metadata_folder` is `doc` (`frontend/docsettings.lua:102`), so opening a book writes its
     `.sdr` sidecar beside it, which must not land in `spec/fixtures/library/`.

## Surfaces

- `kopanda.koplugin/home.lua`, `kopanda.koplugin/main.lua` (pre-build, drop, size check)
- `kopanda.koplugin/HOOKS.md` (plugin: `CloseDocument`, reload/switch/exit, `setRotationMode` at
  `showFiles`; harness: `ReaderUI:showReader`, `ReaderUI.instance`, `ReaderUI:onHome`,
  `FileManager.paintTo`, `document_metadata_folder`)
- `spec/emulator/driver.lua`, `spec/emulator/patches/2-kopanda-capture.lua` (scenario support)
- `spec/emulator/scenarios/2-scenario-book-close.lua` (new)
- `spec/unit/prebuild_spec.lua`, `spec/emulator/book_close_spec.lua` (new)
- `spec/unit/driver_spec.lua`, `spec/emulator/capture_spec.lua`, `spec/unit/failsafe_spec.lua` (cases added)
- `.env.example` (`KOPANDA_SHOT_SCREEN`)

## Tests

Written first, each run and seen failing before its implementation.

- `spec/unit/prebuild_spec.lua` (contract C5), with `spec/plugin_harness.lua` and a real `ReaderUI`
  on a fixture EPUB (KOReader's own `spec/unit/readerui_spec.lua:14-17` shape):
  - `readerui:onClose()` leaves `Home.pending` set and not shown (`UIManager:isWidgetShown`);
  - then `showFiles`: right after it returns, before any tick, the top widget is that pending object
    and `Home.pending` is nil; after `tick(2)` it is still the shown home, and a busted spy on the home's
    constructor records no call after `Show`;
  - a pending home whose `dimen` differs from `Screen:getSize()` is not shown; a fresh home is;
  - a new `ReaderUI` made while a home is pending leaves `Home.pending` nil (the switch/reload path);
  - a second `CloseDocument` with a home already pending builds nothing more.
- `spec/emulator/book_close_spec.lua` (contract C6), colorsoft, library dir holding one copied fixture
  EPUB, `patches = { <book-close scenario> }`, `shot_screen = "scenario"`:
  - the sidecar has no `error`, `fm_paints == 0`, `prebuilt == true`, `home_ms <= 100`, and a numeric
    `close_to_paint_ms`;
  - the capture matches the `home-placeholder` colorsoft golden (`golden.check`), so what is on screen
    after the close is the home.
- `spec/unit/driver_spec.lua`: `write_profile` with `patches` copies each into `patches/`; a patch
  whose name does not start with `2-` is refused naming it.
- `spec/emulator/capture_spec.lua`: the probe plus a tiny extra patch that emits `KoPandaSettled{ screen
  = "scenario", marker = "x" }` after the probe's signal; with `shot_screen = "scenario"` the sidecar
  has `screen == "scenario"` and `marker == "x"`; the existing default-`home` cases still pass.
- `spec/unit/failsafe_spec.lua` (contract C14): a home constructor that errors during `CloseDocument`
  lets `onClose` finish and the file manager show, with a fresh build attempted at show and logged.

## Edge cases

- Why a deferred show would lose after a close: a close that runs inside a scheduled task (the
  scenario's poll; KOReader's end-of-book file-browser action, `readerstatus.lua:144-148`, which
  `nextTick`s `openFileBrowser`) would schedule the `nextTick` show with a fresh `time.now()`
  (`scheduleIn`, `uimanager.lua:416`), later than the cached `_now` `_checkTasks` compares against
  (`:1082`, `:1090`), so the show waits for the next pass and `_repaint` (`:1563`) paints the file
  browser first. Showing the pending home synchronously from `onShow` puts it on the stack before that
  repaint. If `fm_paints` still comes back non-zero, look for a forced repaint inside the close path
  (`forceRePaint` and `setSuspendRepaints` in `readerui.lua`; `onHome` calls
  `UIManager:setSuspendRepaints(false)`, `:936`) by logging the paint's caller in the scenario, and stop
  and report: the mechanism is the plan's, so a change to it goes through plan correction.
- The 100 ms ceiling is the home's own share on the emulator, not a device number; the close-to-paint
  time is recorded, not asserted, for `home-layout` to tighten.
- A book that fails to open shows KOReader's own "not supported" message and returns to the file
  manager (`readerui.lua:668-672`); the scenario reports it through `error` after its poll gives up
  (10 s), within the default settle cap.
- The reader's `CloseDocument` arrives on every module of the reader; KoPanda's handler returns nothing
  so the event continues.
- A switch to another book leaves the pending home from the first close until the new reader's `init`
  drops it: one wasted build, as accepted.
