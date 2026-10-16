# bin/layout-fit runs the plugin's fit rule for a profile

## Approach

Decision S1: the studio measures with the plugin's own `Layout.overflow`, run by a script on the
emulator's LuaJIT, and the server asks it. Starts after `home/device-menus/edit-layout` has merged (it adds
`Layout.overflow`, `device-menus/tasks/edit-layout/task.md:10-12`) and after `studio/studio-shell`; read
both as built first. Independent of the other tasks here. Repo lines on `main` at `c0fbd0d`; KOReader
relative to `~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **`bin/layout-fit`** (bash), shaped like `bin/schema-json:8-16`: resolve `KOPANDA_ROOT` from `$0`,
   default `KOPANDA_EMULATOR` as `bin/check` does, exit 2 naming the path with no `luajit` there. Usage
   `bin/layout-fit <width> <height> <dpi> [settings file]`; a missing or non-integer size is exit 2 with
   the usage. Make a scratch `KO_HOME` (`mktemp -d`, removed by a trap), copy the settings file to
   `$KO_HOME/settings/kopanda/settings.lua` when it is given and exists, `cd` to the emulator and run
   `bin/layout-fit.lua` with `LUA_PATH` and `LUA_CPATH` as `run_busted` sets them, minus the Busted rocks
   (`bin/check:92-99`), stdin passed through.
2. **`bin/layout-fit.lua`**:
   - `require("ffi/loadlib")` and KOReader's `commonrequire` (as `spec/helper.lua:26` and
     `spec/plugin_harness.lua:7` do), which builds the dummy screen and `G_reader_settings` under the
     scratch `KO_HOME`.
   - Size the screen to `<width>×<height>` at `<dpi>` (open fact below), so both `Layout.screen`
     (`layout.lua:13`) and `Font:getFace`'s scaling (`frontend/ui/font.lua:276`) see the profile's screen.
   - Read stdin with `rapidjson.decode`; not an array of arrays: exit 1, "input is not a JSON array of
     row lists". Each row list must pass `Settings.validators.rows(entry, rows)`; else exit 1 naming its
     index.
   - The ctx: `{ look = Looks.active(), variant = Looks.variant(), text_size = Settings.get("text_size"),
     now = os.time(), screen = Screen }`, as `home_rows.lua:84-91` without `home`.
   - Print `rapidjson.encode({ screen = { width, height }, overflow = { … } })` and a newline; exit 0.
     Any Lua error: its message on stderr, exit 1. Library-loading chatter goes to stderr, not stdout.
3. **`studio/src/server/layout-fit.ts`**: `checkFit({ command, width, height, dpi, settingsPath, current,
   proposed, timeoutMs = 30000 })` → `{ checked: true, current, proposed }` or `{ checked: false, reason
   }`. `execFile` with stdin `JSON.stringify([current, proposed])`; exit 2 → reason "no emulator: <stderr
   first line>"; other exits, unparseable stdout or a timeout → their reason. `command` defaults to the
   repo's `bin/layout-fit`, resolved from `import.meta.url` to the repo root in both `src/server/` and
   `dist/server/` (three levels up from either; check against the built layout).
4. **`studio/src/server/routes/layout-fit.ts`**: `POST /api/profiles/:id/layout-fit` `{ rows }`; `400`
   for a body without `rows`; the profile's `width`, `height`, `dpi` and `settings_path`, the current rows
   as `readSettings` gives `layout.rows`; answers `checkFit`'s result with status 200 either way. The
   command is injectable through `createApp`'s options for tests.
5. **AGENTS.md** Commands gains `bin/layout-fit`'s line, in the `bin/schema-json` line's style.

**Open facts, settled here and recorded in the PR:**

- **The screen size.** `commonrequire` makes a dummy framebuffer whose blitbuffer is fixed at 600×800
  (`base/ffi/framebuffer_SDL3.lua:18-20`), and the DPI comes from `EMULATE_READER_DPI` at init
  (`base/ffi/framebuffer.lua:128`, `:369`). Candidates: (a) keep the dummy and replace `Screen.bb` with a
  `BB.new(width, height)` before any plugin module loads, `EMULATE_READER_DPI` set; (b) a real offscreen
  SDL screen with `SDL_VIDEO_DRIVER=offscreen` and `EMULATE_READER_W/H/DPI`, as the captures run
  (`spec/emulator/driver.lua:262-276`; `base/ffi/SDL3.lua:118-119`). Tell them apart by
  `Screen:getWidth()`, `Screen:getHeight()` and `Screen:scaleBySize(100)` (211 at 1264×1680,
  `base/ffi/framebuffer.lua:414-425`) inside the script, and by the default layout's row heights against
  the same at that size in an emulator capture's process; prefer (a) if both agree, as it opens no window
  system.
- **The start time.** Run `time bin/layout-fit 1264 1680 300 < rows.json` ten times and record the
  median and worst in the PR. Over 2 s, say so in the PR: the editor's "Checking fit…" covers it, but the
  owner may want a long-running process instead, which is a new decision.
- **The weather row** reads the cached reading (`widgets/weather.lua:26`), absent in the scratch. Record
  whether the default layout's row heights differ with a cached reading present (the harness's
  `weather_file`, `spec/plugin_harness.lua:21`); if they do, note it in HOOKS-style prose in the script's
  header comment, since the device has one.
- **A valid layout that overflows** at a size the spec runs: every widget on its own row at 600×800, or
  the default at a landscape 1680×1264 (`spec/unit/layout_spec.lua:345-346` drops rows there, but with stubbed heights, so the real
  widgets' overflow is unverified); pick one that gives a count of
  1 or more and use it in the spec.

## Surfaces

- `bin/layout-fit`, `bin/layout-fit.lua` (new), `AGENTS.md`
- `studio/src/server/layout-fit.ts`, `studio/src/server/routes/layout-fit.ts` (new), `app.ts`
- `spec/unit/layout_fit_spec.lua`, `studio/test/server/layout-fit.test.ts` (new)

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `spec/unit/layout_fit_spec.lua` (C7), running the script as `spec/unit/schema_json_spec.lua:6-15`
  runs `bin/schema-json`:
  - at 600 800 160 with no settings file, the counts for the default rows and for the every-widget layout
    equal `Layout.overflow` computed in this process (the unit layer's screen is the dummy 600×800, with
    no settings file under the fresh `KO_HOME`), and at least one is above 0;
  - at 1264 1680 300 the `screen` is 1264×1680 and the default rows count 0, as device-menus asserts in
    process (`device-menus/tasks/edit-layout/task.md:79-81`);
  - a settings file with `text_size = "large"` and the other look changes the count of a layout the test
    finds near the edge, against the same layout with no file (so the file is read);
  - a row list with a repeated widget exits 1 naming index 2 (the second list); `not json` exits 1;
    `KOPANDA_EMULATOR=/nonexistent` exits 2 naming the path;
  - no `tmp.*` directory it made is left (compare `TMPDIR` before and after, or make the script print its
    scratch path on stderr for the test).
- `studio/test/server/layout-fit.test.ts` (C8): with the command pointed at small fake scripts under
  `studio/test/fixtures/` (print a fixed answer and echo stdin to a file; exit 2 with a message; exit 1;
  print `garbage`; sleep past a 200 ms timeout): the route passes `1264 1680 300 <settings_path>` and
  `[current, proposed]` on stdin, current being the stored rows or the default; answers `checked: true`
  with both counts, and `checked: false` with a reason for each failure; the default command path exists
  on disk.

## Edge cases

- The day changes the date, clock and quote of the day (`widgets/date.lua:40`, `widgets/quote.lua:75`);
  a spec comparing two processes run seconds apart could straddle midnight. The in-process comparison
  runs both within the same minute; accept the flake risk and name it in the spec's comment.
- A settings file the plugin can't read is copied anyway; the plugin reads defaults from it, as on a
  device (`settings.lua:256-275`).
- A settings file from a newer schema is read, not written (`settings.lua:265-268`); the script never
  writes settings, so nothing changes.
- `commonrequire` removes and writes `defaults.tests.lua` and `settings.tests.lua` under the data dir
  (`spec/front/unit/commonrequire.lua:10-18` in the emulator); the scratch `KO_HOME` keeps them away from
  the profile directory.
- Diner's launcher puts a suffix on its own line (`looks/diner.lua:321`), and on the Mac plugin and
  directory entries resolve unavailable; both counts carry that, which the feature records.
