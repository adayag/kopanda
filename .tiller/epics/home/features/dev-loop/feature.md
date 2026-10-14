# Lua specs, emulator goldens and bin/check

## Summary

The project's one gate command and the two test layers everything else is built with (design §8): Busted
unit specs on KOReader's own LuaJIT under a fresh `KO_HOME`, and headless emulator goldens per device
profile. Lands first so the next feature's first test has somewhere to run.

## Behavior

- `bin/check` runs the Lua specs and luacheck and exits non-zero on any failure; Tiller's build and tests
  gates in `.tiller/tiller.yml` are wired to it by this feature.
- A spec can `require` a plugin module with KOReader's `frontend` on the path, using the rocks KOReader
  ships for its own tests (`kodev test`, `koreader/kodev:659`; `spec/rocks` in the emulator build), with a temporary
  `KO_HOME` created and removed per run.
- An emulator run captures the home screen headless at a named profile's resolution (Colorsoft
  1264×1680, Paperwhite 1236×1648, both 300 DPI) and compares it to a committed golden with any mask
  rectangles the golden's sidecar lists excluded; goldens regenerate only through an explicit flag and
  are eyeballed before commit.
- The capture waits on a settled signal the plugin itself announces, not on KOReader internals.
- A paint-time measurement is recorded alongside the golden so later features can assert a budget.
- Every capture runs a scratch profile that disables SimpleUI, Bookshelf, ennUI and the Solar icon pack,
  so the copies in the emulator's own `plugins/` never load (design §1b, coexistence); the run refuses,
  naming the path, only when the emulator's `plugins/` holds `kopanda.koplugin`, which would load twice.
- Fixture books for goldens are public-domain EPUBs with known covers, pinned in the repo or by hash.

## Specification

Everything below runs without Tiller. `bin/check` is an ordinary project script; Tiller only invokes it.

### `bin/check`

One bash script at the repo root, the project's single gate command.

- `bin/check` with no arguments runs, in order: luacheck over every Lua file in the repo outside
  `spec/fixtures/` (which holds deliberately bad inputs), then every unit spec under `spec/unit/`, then every
  emulator spec under `spec/emulator/`. It stops at the first failing stage and exits non-zero; it
  exits zero only when all three are clean.
- `bin/check <spec file>...` runs exactly those spec files and nothing else (no luacheck), so a
  contract criterion can bind to one spec and a developer can iterate on one file. Paths are
  repo-relative or absolute.
- `bin/check --lint` runs luacheck alone.
- The Busted runner is KOReader's own: the emulator's `./luajit` with Busted 2.3.0 from the emulator
  build's `spec/rocks/`, invoked the way KOReader's `base/test-runner/runtests` invokes it (the
  `runtests_busted` function, `runtests:85–120`: `./luajit -e 'require "busted.runner" {standalone = false}'
  /dev/null` from the install dir, with the `LUA_PATH` the script exports at `runtests:226–227`
  covering `?.lua;common/?.lua;frontend/?.lua` and the rocks).
  `kodev test` (`koreader/kodev:659`, `kodev-test`) is the wrapper KOReader itself uses; `bin/check`
  does not go through `kodev`, which rebuilds and needs GNU getopt on the path, but calls the same
  LuaJIT and rocks directly.
- The repo's own paths are added to `LUA_PATH`: `spec/?.lua` for helpers and `kopanda.koplugin/?.lua`
  so a spec can `require` a plugin module by its name inside the plugin folder.
- Every run gets a fresh `KO_HOME`: a new temporary directory, exported before LuaJIT starts, and
  removed when the run ends, pass or fail. KOReader's `DataStorage:getDataDir()` reads `KO_HOME`
  (`datastorage.lua:19–20`) and creates `plugins/`, `settings/`, `patches` excepted, under it
  (`datastorage.lua:97–123`), so nothing a spec writes lands in the emulator folder or the repo.
- Spec bootstrap reuses KOReader's `spec/unit/commonrequire.lua` (installed in the emulator at
  `spec/front/unit/commonrequire.lua`): dummy framebuffer and input so no SDL window opens,
  `G_reader_settings` and `G_defaults` under the data dir. A spec starts with `require("commonrequire")`
  as KOReader's own do (`spec/unit/luasettings_spec.lua:4`).
- The emulator's location is `KOPANDA_EMULATOR`, defaulting to
  `~/Projects/kodev/koreader/koreader-emulator-arm64-apple-darwin23.5.0-debug/koreader`. A missing
  `luajit` there, or a missing `luacheck` on the path, is a refusal naming the path and, for luacheck,
  the install command (`brew install luacheck`; Homebrew's formula is 1.2.0, KOReader's own
  `Makefile:214–218` does the same check). Nothing is skipped silently.
- `.luacheckrc` follows KOReader's (`.luacheckrc` at the repo root of the pinned source): `std = "luajit"`,
  KOReader's globals (`G_reader_settings`, `G_defaults`), `+busted` for `spec/**`, and `self = false`.
  Line length is enforced (KOReader ignores 631; this project does not).
- `.tiller/tiller.yml` gets `build: bin/check --lint` and `tests: bin/check`, both on feature and task.
  `tiller eval` appends a criterion's `ref` to the tests command, so a ref-only `test` binding resolves
  to `bin/check <spec file>`, which runs that spec alone.

### Emulator capture

A Lua driver module, `spec/emulator/driver.lua`, used by the emulator specs and, from stage 2, by the
studio through the same `bin/check`-free entry point (a spec or the studio calls the module; the
module shells out to the emulator). No TypeScript at stage 1.

- **Profiles.** A table of named device profiles in `spec/emulator/profiles.lua`: `colorsoft`
  (1264×1680, 300 DPI, colour) and `paperwhite` (1236×1648, 300 DPI, grayscale). A profile is the
  emulator screen env (`EMULATE_READER_W` and `EMULATE_READER_H`, `base/ffi/SDL3.lua:118–119`;
  `EMULATE_READER_DPI`, `base/ffi/framebuffer.lua:128`; `EMULATE_READER_FORCE_PORTRAIT`, presence
  only, `frontend/device/sdl/device.lua:188`) plus, for the Paperwhite, `EMULATE_BW_SCREEN=1`, which
  makes the emulator report no colour screen (`base/ffi/framebuffer_SDL3.lua:21`), and the
  `color_rendering` setting KOReader reads to decide colour rendering
  (`frontend/device/generic/device.lua:266–267`), true for the Colorsoft and false for the Paperwhite.
  Writing the key also suppresses the first-run colour notice (`reader.lua:195–203`). The emulator's
  framebuffer is 32-bit RGB whatever the profile (`base/ffi/framebuffer_SDL3.lua:85`), so a grayscale
  profile changes what the plugin draws, not how the screenshot is encoded.
- **Scratch profile.** Each capture builds a fresh `KO_HOME` directory holding: `settings.reader.lua`
  with the profile's `color_rendering` and a `plugins_disabled` table naming `simpleui`, `bookshelf`,
  `ennUI` and `solariconpack` (keys are folder names without `.koplugin`,
  `frontend/pluginloader.lua:210–215`), so the copies in the emulator's own `plugins/` never load;
  `plugins/<the plugin under test>` copied from the repo, which KOReader finds because a profile with
  no `extra_plugin_paths` key gets `<KO_HOME>/plugins/` added on its first run
  (`frontend/pluginloader.lua:193–199`), so the scratch profile never writes that key; and
  `patches/2-kopanda-capture.lua`, the capture userpatch, which KOReader runs after the UI is up: the
  `2-` prefix is the `late` priority (`frontend/userpatch.lua:13, 73`), read from `<KO_HOME>/patches`
  (`frontend/userpatch.lua:38`) at `reader.lua:190`, before the file manager is shown at `reader.lua:250`. Fonts the plugin ships are reached through the
  profile the same way the theme studio did it, if looks-and-schema needs it; this feature does not
  ship fonts.
- **Preflight refusals,** each naming the offending path: the emulator's `plugins/` holds
  `kopanda.koplugin` (KOReader loads every lookup path's copy with no dedup, `frontend/pluginloader.lua:200–227`);
  no `luajit` in the emulator dir; the plugin folder to copy does not exist.
- **The settled signal.** The plugin under test announces that its home screen is painted by calling
  `UIManager.event_hook:execute("KoPandaSettled", { screen = "home", paint_ms = <number> })`
  (`frontend/ui/uimanager.lua:53`, `frontend/ui/hook_container.lua:88`), once, after the paint
  that shows the home (`UIManager:tickAfterNext`, `frontend/ui/uimanager.lua:447–456`, runs its callback
  after the repaint that follows `UIManager:show`). `paint_ms` is measured with `time.monotonic()`
  (`frontend/ui/time.lua`), not `time.now()`, whose coarse clock can be 10 ms on a device. `paint_ms` is the time from the start of building the home widget to that
  paint, measured by the plugin. The capture patch registers for that hook name before any plugin
  runs; with no listener registered, `execute` runs nothing and returns 0, so the plugin's call costs
  nothing on a device. This is the only coupling between the harness and the plugin; the patch reads no
  KOReader internals to decide when to shoot.
- **The capture patch** (`spec/emulator/patches/2-kopanda-capture.lua`) is active only when
  `KOPANDA_SHOT=<png path>` is set. On the signal it writes the screenshot with `Screen:shot(path)`
  (`base/ffi/framebuffer.lua:566`, the whole framebuffer as an RGBA PNG), writes `<png>.json` beside
  it (`screen`, `paint_ms`, screen width and height, the names of the plugins KOReader enabled, from
  `PluginLoader:loadPlugins()`, memoised, `frontend/pluginloader.lua:273`), logs one `KOPANDA_SHOT:`
  line on stdout (`frontend/logger.lua:73`), and quits KOReader through `UIManager:quit()`
  (`frontend/ui/uimanager.lua:892`) so the process exits zero (`reader.lua:305–328`). If the signal has not arrived
  `KOPANDA_SHOT_CAP_S` seconds after the patch loaded (default 20), it logs `KOPANDA_SHOT: settle cap`,
  shoots anyway for diagnosis and quits non-zero. The driver kills the process itself after a hard
  timeout (default 120 s), from the shell it starts it in, in case KOReader hangs before the patch
  loads or inside a call the patch's scheduled watchdog cannot interrupt.
- **The driver** builds the scratch profile, starts `./luajit reader.lua <library dir>` in the emulator
  dir (a directory argument opens the file manager on it and skips the quickstart guide,
  `reader.lua:145–151, 248–251`) with `SDL_VIDEO_DRIVER=offscreen`, `KO_HOME` and `XDG_DOCUMENTS_DIR` pointing at the scratch
  profile and the profile's screen env, waits for exit, and returns the PNG path, its size, the
  sidecar's contents, the log path and the scratch dir. Failure is an error that quotes the last lines
  of the emulator log. The scratch profile is removed on success; on failure it is left for inspection
  and its path is in the error.
- **The probe plugin.** `spec/fixtures/probe.koplugin/` is a tiny plugin that exists so the harness can
  be proven before `kopanda.koplugin` draws anything: on the file manager's first show it puts a
  full-screen widget with a fixed pattern (a frame, a centred label naming the profile's width and
  height, and four corner marks) over the file browser and emits the settled signal with its measured
  paint time. It is the harness's permanent self-test; `plugin-shell` swaps in the real plugin for its
  own goldens. It copies nothing from ennUI.
- **Library dir.** The emulator opens the directory passed to `reader.lua`; captures use
  `spec/fixtures/library/` (see Fixture books) or an empty temporary directory when a spec says so.

### Goldens

- A golden is a committed PNG under `spec/goldens/<name>-<profile>.png` with a `<name>-<profile>.json`
  sidecar carrying the paint time, the profile, the screen size and the KOReader build (`e1fe1ac`)
  the golden was taken on. The sidecar is written only when the golden is (re)generated, so a passing
  run leaves the tree clean.
- Comparison runs in Lua on the emulator's LuaJIT, loading both PNGs through KOReader's own PNG
  decoder forced to RGB (`Png.decodeFromFile(path, 3)`, `base/ffi/png.lua:43`) and comparing pixel by
  pixel; alpha is never compared. A pixel differs when any channel differs by more than a small tolerance; the
  comparison fails when more than 0.05 % of compared pixels differ (the theme studio's limit, at which
  a quarter of one icon fails: `test/emulator/helpers.ts`, `MAX_DIFFERING_FRACTION`). A failing
  comparison writes a diff PNG next to the capture and names both paths.
- A golden may carry mask rectangles, in device pixels, listed in its sidecar; masked pixels are not
  compared. KoPanda's home has no status strip (direction doc, "Status bar: None"), so the default
  mask is empty; the clock and date widgets will need either a mask or a pinned clock when home-layout
  specifies them.
- A capture whose size differs from the golden's fails before any pixel is compared, naming both sizes.
- `KOPANDA_UPDATE_GOLDENS=1` makes a golden spec write the capture as the new golden and its sidecar
  instead of comparing, and print the paths it wrote. Without the flag a missing golden is a failure
  that says how to generate it. Regenerated goldens are looked at before they are committed; the
  contract carries that as a manual criterion.
- The probe's goldens for both profiles are committed by this feature.

### Fixture books

- `spec/fixtures/library/` holds three public-domain EPUBs with embedded covers, from Project
  Gutenberg or Standard Ebooks, committed to the repo, each under 2 MB, with
  `spec/fixtures/library/manifest.lua` listing file name, title, author, source URL and SHA-256
  (hashed in Lua with KOReader's `ffi/sha2`, `base/ffi/sha2.lua:4356`).
- A unit spec recomputes each hash and fails on a mismatch or a file missing from the manifest or the
  folder.

### Keys

This feature adds no settings key to the schema.

## Notes

Reuses the kodev capture recipe (`~/Projects/kodev/capture.sh`, `2-autoshot.lua`) and the theme
studio's driver pattern (`test/emulator/helpers.ts`, `src/server/emulator/driver.ts`,
`lua/patches/2-kts-capture.lua`) as references, not as code. The driver is Lua, not a shell script or
TypeScript: the comparison needs a PNG decoder and the emulator already ships one, the specs that call
it are Lua, and the studio can shell out to a spec or require the module through the same LuaJIT.

`koreader/kodev:911` in the decomposition is the help text for `kodev test`; the implementation is
`kodev-test` at `koreader/kodev:659`, which sources `base/test-runner/runtests` and runs `make testfront`.
Busted 2.3.0 is built into the emulator (`base/thirdparty/spec/busted`, installed at the emulator's
`spec/rocks/bin/busted`); luacheck is not, and is not installed on this Mac.

The decomposition said the run refuses when SimpleUI, Bookshelf or ennUI is enabled in the emulator's
`plugins/`. With a scratch `KO_HOME` the harness can instead disable them in the profile it writes, so
no manual step precedes a run and the emulator's own `plugins/` can stay as it is for interactive use.
The refusal that remains is for `kopanda.koplugin` itself in the emulator's `plugins/`, which would
load twice.
