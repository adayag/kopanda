# Headless emulator capture per device profile on the plugin's settled signal

## Approach

Three pieces, each small: the profiles and driver module, the capture userpatch, and the probe plugin
that gives the driver something to capture. Then an emulator spec that captures the probe on both
profiles.

1. **`spec/emulator/profiles.lua`**: pure data.
   `colorsoft = { width = 1264, height = 1680, dpi = 300, color = true }`,
   `paperwhite = { width = 1236, height = 1648, dpi = 300, color = false }`.
2. **`spec/emulator/driver.lua`**, `capture(opts)` with `opts = { profile = <name>, plugin_dir = <path>,
   library_dir = <path>, out_dir = <path>, cap_s = 20, timeout_s = 120 }`:
   - Preflight, each an `error()` naming the path: `opts.plugin_dir` is not a directory;
     `<emulator>/luajit` missing; `<emulator>/plugins/kopanda.koplugin` exists (KOReader would load the
     plugin from both lookup paths).
   - Scratch profile at `<out_dir>/profile-<profile>/`: `settings.reader.lua` written as
     `return { ["color_rendering"] = <bool>, ["plugins_disabled"] = { ["simpleui"] = true,
     ["bookshelf"] = true, ["ennUI"] = true, ["solariconpack"] = true } }`, which `LuaSettings:open`
     reads by `dofile` (`frontend/luasettings.lua:21–48`); the keys are plugin folder names without
     `.koplugin` (`frontend/pluginloader.lua:210–215`). The file must not contain `extra_plugin_paths`:
     when that key is absent KOReader adds `<KO_HOME>/plugins/` itself on first run
     (`frontend/pluginloader.lua:193–199`), and when present KOReader adds only the listed paths to its
     own `plugins/` (`frontend/pluginloader.lua:177, 184–188`), so `<KO_HOME>/plugins/` would be skipped.
     `color_rendering` present also suppresses the first-run colour notice (`reader.lua:195–203`).
     Then `plugins/<basename of plugin_dir>/` copied recursively and `patches/2-kopanda-capture.lua`
     copied from `spec/emulator/patches/`.
   - Run: through `io.popen` with `sh -c`, a wrapper that starts the emulator in the background and kills
     it after `timeout_s` without needing a `timeout` binary:
     `cd <emulator> && env <vars> ./luajit reader.lua <library_dir> > <log> 2>&1 & pid=$!;
     (sleep <timeout_s>; kill $pid 2>/dev/null) & wait $pid; echo; echo $?`. The status is the last
     line. `EMULATE_BB_TYPE` is cleared in the same `env` call so the framebuffer stays 32-bit
     (`base/ffi/framebuffer_SDL3.lua:69, 85`). Vars: `KO_HOME`,
     `XDG_DOCUMENTS_DIR` (both the scratch profile), `SDL_VIDEO_DRIVER=offscreen`,
     `EMULATE_READER_W/H/DPI`, `EMULATE_READER_FORCE_PORTRAIT=1` (presence is what counts,
     `frontend/device/sdl/device.lua:188`), `EMULATE_BW_SCREEN=1` for a profile with `color = false`
     (`base/ffi/framebuffer_SDL3.lua:21`), `KOPANDA_SHOT=<out_dir>/<profile>.png`, `KOPANDA_SHOT_CAP_S`.
     The directory argument makes KOReader open the file manager on it and skip the quickstart guide
     (`reader.lua:145–151, 248–251`); nothing else prompts on a fresh profile
     (`frontend/apps/filemanager/filemanager.lua:396–447` and `showFiles`, `:1312–1331`, show no first-run
     UI). The paperwhite profile's `color_rendering = false` is load-bearing: with `EMULATE_BW_SCREEN`
     set, `Device:hasColorScreen()` is false (`base/ffi/framebuffer_SDL3.lua:21–22`, carried into
     `frontend/device/generic/device.lua:264`) and a true `color_rendering` would raise a blocking
     ConfirmBox (`reader.lua:205–223`). A kill by the wrapper is reported as "timed out after N s" with
     the log tail; the patch's scheduled watchdog (below) is the fast path for a plugin that never
     signals, not the guarantee against a hang.
   - Result: `{ png = <path>, width, height, sidecar = <decoded JSON table>, log = <path>,
     scratch = <path> }`. Width and height are read from the PNG's IHDR (bytes 17–24, big-endian) with
     `string.byte`, no decoder needed. On any failure, `error()` with the last 40 log lines appended and
     the scratch dir left in place.
   - JSON: the sidecar is decoded with `require("rapidjson")`, present in the emulator's `common/`
     (used the same way by the theme studio's capture patch, `lua/patches/2-kts-capture.lua`).
3. **`spec/emulator/patches/2-kopanda-capture.lua`**: returns immediately unless `KOPANDA_SHOT` is set.
   Then `UIManager.event_hook:register("KoPandaSettled", handler)` (`frontend/ui/uimanager.lua:53`,
   `frontend/ui/hook_container.lua`, `register`/`execute`). The handler, once: `Screen:shot(path)`
   (`base/ffi/framebuffer.lua:566`), write `<path>.json` with `screen`, `paint_ms` from the args,
   `width`/`height` from `Screen:getWidth()/getHeight()`, `plugins` (the `.name` of each module in the
   enabled array `PluginLoader:loadPlugins()` returns, memoised so the call is free,
   `frontend/pluginloader.lua:273–291`), `koreader = "e1fe1ac"`; log `KOPANDA_SHOT: saved <path>
   paint_ms=<n>` (stdout, `<date> INFO  KOPANDA_SHOT: ...`, `frontend/logger.lua:71–90`, the padded
   prefix at `:32`);
   `UIManager:scheduleIn(0.5, function() UIManager:quit() end)` as `2-autoshot.lua` does. A watchdog
   scheduled at `KOPANDA_SHOT_CAP_S` (default 20) that has not seen the signal logs
   `KOPANDA_SHOT: settle cap`, shoots for diagnosis, and quits with exit code 3
   (`UIManager:quit(3)`, `frontend/ui/uimanager.lua:892`; `reader.lua:305–328` passes it to
   `os.exit`). Scheduled tasks run only from the UI loop (`frontend/ui/uimanager.lua:1081–1106`), so
   this watchdog cannot fire if KOReader hangs; the driver's kill covers that. Every log line starts
   with `KOPANDA_SHOT:` so the driver can quote them.
4. **`spec/fixtures/probe.koplugin/`**: `_meta.lua` (`fullname`, `description`, `version`; the name is
   the folder's, `probe`) and `main.lua`, a `WidgetContainer` plugin with `is_doc_only = false`. The
   file manager instantiates plugins in `FileManager:init`
   (`frontend/apps/filemanager/filemanager.lua:418–429`) and `registerModule` inserts each instance as an
   array child (`filemanager.lua:384`). `FileManager:showFiles` (`filemanager.lua:1312–1331`) calls
   `UIManager:show(file_manager)` at `:1330`, which sends `Event:new("Show")` to the widget
   (`frontend/ui/uimanager.lua:259`); `WidgetContainer:handleEvent` propagates it to the array children
   (`frontend/ui/widget/container/widgetcontainer.lua:80–107`), and `FileManager` defines no `onShow` of
   its own, so the plugin instance's `onShow` fires on the file manager's first show (ennUI relies on
   the same, `main.lua:62` at ae26fc4, read, not copied). The handler returns nothing: a true return
   would stop propagation to later modules (`widgetcontainer.lua:83–85`). No plugin code runs before
   the capture patch registers its listener: `applyPatches(late)` at `reader.lua:190` precedes
   `showFiles` at `:250`, and `PluginLoader:loadPlugins()` has no caller before `filemanager.lua:418`.
   On that `onShow`, once: note `time.monotonic()` (`frontend/ui/time.lua`; `time.now()` is the coarse
   clock, 10 ms on some devices), build a full-screen `FrameContainer` (`covers_fullscreen = true`)
   holding a centred `TextWidget` reading `<width>×<height>` in KOReader's default font and four small
   `FrameContainer` squares in the corners, `UIManager:show` it, then from `UIManager:tickAfterNext`
   (`frontend/ui/uimanager.lua:447–456`: the callback is re-queued past the next `_repaint`, so it runs
   after the paint that shows the widget whether `show` was called from a task or an event handler,
   `uimanager.lua:1537–1564`) compute `paint_ms` and call
   `UIManager.event_hook:execute("KoPandaSettled", { screen = "home", paint_ms = paint_ms })` inside a
   `pcall`. Fixed strings and sizes only, so the capture is deterministic.
5. **First-run suppression**: the two prompts a fresh profile can raise are the colour notice, suppressed
   by writing `color_rendering` (`reader.lua:195–203`), and the quickstart guide, bypassed by the
   directory argument (`reader.lua:257–261` runs only without one). Both are recorded in `driver.lua`
   with their lines. A userpatch that errors shows an InfoMessage (`frontend/userpatch.lua:92–101`),
   so the capture patch wraps its body in `pcall` and logs instead of raising.

## Surfaces

- `spec/emulator/profiles.lua`, `spec/emulator/driver.lua`, `spec/emulator/patches/2-kopanda-capture.lua`
  (new)
- `spec/fixtures/probe.koplugin/_meta.lua`, `spec/fixtures/probe.koplugin/main.lua` (new)
- `spec/unit/driver_spec.lua`, `spec/emulator/capture_spec.lua` (new)
- `kopanda.koplugin/HOOKS.md` (new): the KOReader surfaces the harness touches
  (`UIManager.event_hook`, `Screen:shot`, `UIManager:quit`, `UIManager:tickAfterNext` and the clock
  fact it rests on, the `Show` event reaching plugin instances, `PluginLoader:loadPlugins`,
  `plugins_disabled`, `extra_plugin_paths`, `color_rendering`, `EMULATE_BW_SCREEN`, `KO_HOME`), each
  with its `file:line`.
- `.env.example`: `KOPANDA_SHOT` and `KOPANDA_SHOT_CAP_S`, one line each, marked as set by the driver.

## Tests

Written first, each seen failing before its implementation.

- `spec/unit/driver_spec.lua` (no emulator run; a fake emulator dir under `KO_HOME`):
  - `capture` with a fake emulator dir lacking `luajit` errors naming `<dir>/luajit`.
  - with `plugins/kopanda.koplugin` present in the fake emulator dir, errors naming that path.
  - with a missing `plugin_dir`, errors naming it.
  - `driver.write_profile(dir, profile)` writes `settings.reader.lua` that `LuaSettings:open` reads back
    with `color_rendering == false` for paperwhite and `true` for colorsoft, `plugins_disabled`
    carrying exactly `simpleui`, `bookshelf`, `ennUI`, `solariconpack`, and no `extra_plugin_paths`
    key; `patches/2-kopanda-capture.lua` and `plugins/<name>/` are present.
  - `driver.png_size(path)` returns the IHDR size of a 2×3 PNG fixture.
  - a fake emulator dir whose `luajit` is a shell script that sleeps forever: `capture{ timeout_s = 2 }`
    errors with "timed out after 2 s" in about two seconds and the process is gone.
- `spec/emulator/capture_spec.lua` (runs the emulator, about 15 s per profile): for each of colorsoft
  and paperwhite, `capture{ profile, plugin_dir = "spec/fixtures/probe.koplugin", library_dir = <empty
  temp dir> }` returns a PNG whose size is the profile's; the sidecar has `screen == "home"`, a numeric
  `paint_ms` greater than 0, and `plugins` containing `probe` and none of `simpleui`,
  `bookshelf`, `ennUI`, `solariconpack`; the log has exactly one `KOPANDA_SHOT: saved` line and no
  `settle cap`; the scratch dir is gone.
  - and one negative: `plugin_dir` pointing at a copy of the probe with its `execute` call removed
    (built by the spec into `KO_HOME`) makes `capture` error with `settle cap` in the message, in
    about `cap_s` seconds (`cap_s = 5` for the test).

## Edge cases

- The emulator's `plugins/` also holds `hello.koplugin` and KOReader's bundled plugins; those load in the
  scratch profile too, as they would on a device. Only the four shell plugins are disabled.
- Two captures in one spec run must not share a scratch dir: `out_dir` is unique per call (the driver
  makes a subdirectory under `os.getenv("KO_HOME")` when `out_dir` is nil).
- `Screen:shot` writes the whole framebuffer as an RGBA PNG on every profile, since the emulator's
  buffer is 32-bit while `EMULATE_BB_TYPE` is unset (`base/ffi/framebuffer_SDL3.lua:69, 85`,
  `base/ffi/blitbuffer.lua:2460–2474`); the driver reports only size and leaves decoding to golden-compare.
- The probe's `paint_ms` is monotonic-clock time on a Mac and varies; the spec asserts only that it is a
  positive number.
- `ennUI` is the folder name of the reference plugin's repository (`critterforks/ennUI.koplugin`, design
  §2); it is not installed in the emulator, so the entry is a guard, and the spelling is checked against
  the scratch clone when one is next made.
- A plugin that crashes on load: KOReader logs and continues without it, so the signal never comes and
  the cap fires; the error quotes the log tail, which carries the Lua error.
- SDL offscreen driver missing from a future build: the log says so; the error quotes it.
