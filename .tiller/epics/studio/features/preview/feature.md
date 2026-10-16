# Emulator preview per profile and look

## Summary

The studio shows the real thing: the home screen rendered headless by the emulator for the open profile,
in both looks, re-rendered when settings change (design §6 Preview).

## Behavior

- The server materialises the profile's settings into a scratch `KO_HOME`, with the plugin from the
  working tree, and runs the capture from `home/dev-loop` at the profile's resolution.
- The UI shows the render beside the form, with its profile and look named, a status line (rendering,
  rendered in n s, stale, failed with the last log lines), and a re-render button; on-change
  re-rendering debounces.
- Both looks can be shown side by side for the same settings.
- Night mode can be toggled for the preview.
- A test proves a settings change produces a different render and that a failed render keeps the last
  good image.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. Repo paths are
on `main` at `8bbff12` unless marked.

### Order and what is cited as spec

This feature starts after four recorded prerequisites:

- `home/dev-loop` (F-xo6obj), built: the capture driver `spec/emulator/driver.lua`, the capture patch
  `spec/emulator/patches/2-kopanda-capture.lua`, the golden check `spec/emulator/golden.lua` and the
  fixture library.
- `home/home-layout` (F-wkj9iy), built: the home and its `KoPandaSettled` signal
  (`kopanda.koplugin/home.lua:159-173`).
- `studio/studio-shell` (F-kglqs4), specified, not built: the profiles API, where `GET /api/profiles/:id`
  gives `width`, `height`, `dpi`, `color` and `settings_path`
  (`.tiller/epics/studio/features/studio-shell/feature.md:97-103`), and the profile screen
  (`:117-128`).
- `studio/settings-form` (F-k4yn5f), specified, not built, recorded by this specification: the form and
  both editors in the profile screen, every change one `PUT` whose answer is the moment it landed
  (`.tiller/epics/studio/features/settings-form/feature.md:191-193`, `:374-378`), the settings state
  with `values.look` (`:158-161`), and the `bin/layout-fit` shape this feature's script copies
  (`:233-243`; `tasks/layout-fit/task.md:11-30`).

Each task that uses a module a studio feature builds reads the built code first and records in its PR any
line that differs from the spec cited here.

### What the preview renders (decision P1)

Owner's decision, 2026-10-15: the preview shows the goldens' populated home fixture, frozen.

- **The fixture** is `spec/emulator/scenarios/2-scenario-home-fixture.lua` with
  `KOPANDA_HOME_FIXTURE=populated` (`:8-16`): the fixture library, Frankenstein featured at 62 % with its
  cover and chapter, a Statistics database with a 4-day streak, and the clock frozen at Tuesday
  2026-10-13 08:42 (`:32-46`), run with `TZ=America/Chicago` as the goldens are
  (`spec/emulator/home_golden_spec.lua:57`).
- **The weather reading** is written for the location and units the plugin reads from the profile's
  settings, so the weather row shows a reading wherever the profile's weather is set. Today the fixture
  writes one for the schema's defaults only (`2-scenario-home-fixture.lua:176-186`), and a reading for
  other coordinates or units reads as none (`kopanda.koplugin/weather.lua:133-153`), which would show
  "Weather needs Wi-Fi" (`:23`, `:159-161`). The temperature is 61.4 in Fahrenheit and 16.3 in Celsius, the same
  weather.
- **The settings** are the profile's file, copied into the scratch `KO_HOME` at
  `settings/kopanda/settings.lua` before the emulator starts, read there by the plugin's own `Settings`
  (`kopanda.koplugin/settings.lua:233-239`). A profile with no file is every key at its default. The
  look rendered is set by the fixture's `KOPANDA_HOME_LOOK` (`2-scenario-home-fixture.lua:57-60`,
  `:73-79`), always passed explicitly (`diner` or `editorial`, never empty), so the other look can be
  shown for the same settings; the fixture writes it into the scratch copy only.
- **The plugin** is the working tree's `kopanda.koplugin/`, copied by the driver
  (`spec/emulator/driver.lua:131-135`).
- **Night** is the driver's `night_mode`, on from the start (`driver.lua:80-83`, `:110`): the look's
  night palette on a colour profile, the grey palette under KOReader's inversion on a greyscale one
  (`kopanda.koplugin/looks.lua:31-44`; `spec/emulator/night_golden_spec.lua:5-8`).
- **The screen** is the profile's `width`, `height`, `dpi` and `color`, so a hand-added profile renders
  at its own size.

Same settings, look and night give the same image, so a preview of the default settings is the
committed golden of that look and profile, and a difference between two renders is a difference in
settings. What the device would show differently, the preview shows as the emulator has it: a pinned
book that isn't in the fixture library falls back to the last opened, Frankenstein
(`kopanda.koplugin/featured_book.lua:65-76`); a launcher entry for a plugin the emulator lacks reads
"plugin missing" and a device folder "folder missing" (`kopanda.koplugin/launcher_entries.lua:60-80`, through
`resolve`, `:84-90`);
a row that doesn't fit is left out and logged (`kopanda.koplugin/layout.lua:115`), as on the device.
The date, the clock and the quote of the day stay at the frozen day.

### The capture inputs

`spec/emulator/driver.lua`'s `capture` gains two options; without them it behaves as today:

- `device = { width, height, dpi, color }`: used in place of `profiles[opts.profile]` for the screen
  (`driver.lua:233-237`, `:263-277`) and the `color_rendering` setting (`:111-114`); `opts.profile` is
  then only the name of the scratch's files (`:257-261`), and must match `^[a-z0-9-]+$`.
- `settings_file`: a path copied to `<scratch>/settings/kopanda/settings.lua` before the run; a path
  that is not a file is an error naming it.

The home fixture gains `KOPANDA_HOME_WEATHER_LATITUDE`, `KOPANDA_HOME_WEATHER_LONGITUDE` and
`KOPANDA_HOME_WEATHER_UNITS`: all three set, the populated reading is written for them (`celsius`
writing 16.3); none set, it is written as today; one or two set, or a value that isn't a number or a
schema unit, is a fixture failure (exit 4, `2-scenario-home-fixture.lua:285-290`). The coordinates
cross the environment as `%.17g`, which a `tonumber` reads back to the same double, so the plugin's
equality test (`weather.lua:147-151`) holds.

When the fixture stores the look into a copied file whose chunk returns something other than a table,
it resets the data to `{}` first, as the plugin reads such a file (`kopanda.koplugin/settings.lua:261-263`);
today `saveSetting` would raise on it (`frontend/luasettings.lua:29-33`) and fail the render.

### bin/preview

`bin/preview <width> <height> <dpi> <color|grey> <diner|editorial> <day|night> <out.png> [settings file]`,
shaped like `bin/layout-fit` (`settings-form/tasks/layout-fit/task.md:11-30`):

- **Refusals, exit 2:** no `luajit` at `KOPANDA_EMULATOR` (default as `bin/check:17-18`), naming the
  path; a wrong argument count, a size that isn't a positive integer, a value outside its list, or a
  settings file argument that is not a file, each with the usage.
- **Its process:** a scratch directory (`mktemp -d`, removed by a trap) as `KO_HOME`, the settings file
  copied to `$KO_HOME/settings/kopanda/settings.lua` when given, then `bin/preview.lua` on the
  emulator's LuaJIT with `LUA_PATH` and `LUA_CPATH` as `run_busted` sets them minus the three `spec/rocks/`
  entries (`bin/check:93-99`), `KOPANDA_ROOT` exported and `TZ=America/Chicago`.
- **`bin/preview.lua`** loads KOReader's `commonrequire` as the specs do, reads the effective
  `weather.location` and `weather.units` with the plugin's own `Settings.get` over the copied file
  (`settings.lua:279-299`), so a stored value the plugin refuses gives the default here as there; then
  runs `driver.capture` with the populated fixture, the look, the three weather variables, `device`,
  `settings_file`, `night_mode` for `night`, the repo's plugin and an `out_dir` under the scratch, and
  copies the PNG to `<out.png>`.
- **Its answer:** exit 0 and one JSON line on stdout, `{ "png": <out.png>, "width": w, "height": h,
  "paint_ms": n }`; any failure, the driver's included (its message carries the log's last 40 lines,
  `driver.lua:288-291`), exit 1 with the message alone on stderr. KOReader's library-loading chatter is
  printed on stdout (`ffi/loadlib.lua:22`, `frontend/logger.lua:89`), so `bin/preview` drops the
  LuaJIT process's stdout: `bin/preview.lua` writes its JSON line to a file in the scratch, which
  `bin/preview` prints on exit 0, and writes its failure with `io.stderr:write`.

### The server

`POST /api/profiles/:id/preview` with `{ look, night }`, on the profiles router
(`studio-shell/feature.md:97-103`):

- `look` one of the schema's `look` choices (`studio/src/schema.json`, built by `studio/studio-shell`,
  `studio-shell/feature.md:107-115`), `night` a boolean; anything else
  is `400 { error }`. An id that is not a valid profile is `404 { error }`.
- It runs `bin/preview` with the profile's `width`, `height`, `dpi`, `color` (`color` or `grey`), the
  look, `day` or `night`, a temporary PNG path, and the profile's `settings_path` when the file exists.
  Success answers `200` with the PNG (`Content-Type: image/png`, `Cache-Control: no-store`), the
  temporary file removed.
- Exit 2 answers `503 { error, log }`; any other failure, including no answer within the time limit (150 s),
  answers `502 { error, log }`: `error` the first line of stderr, which `bin/preview` keeps to the
  failure's message (or "No render within 150 s"), `log` its
  remaining lines, the last 40. A timed-out run is killed with its whole process group, so no emulator
  outlives it.
- **One render at a time,** server-wide, in arrival order: the emulator is the slow, heavy part. A
  queued request whose client has gone before its turn never runs; a running one finishes and its
  answer is dropped.
- The script is found from the server module's own location, as `bin/layout-fit` is
  (`settings-form/tasks/layout-fit/task.md:31-36`), and the server's environment passes through, so
  `KOPANDA_EMULATOR` works as for `bin/check`. The command is injectable for tests, so `npm test` needs
  no emulator.
- The server keeps no image. The last good render of each frame is the UI's.

### The preview pane

`PreviewPane.tsx` sits in the profile screen beside the form, on all three profile routes (the form, the
layout editor and the launcher editor, `settings-form/feature.md:171-173`).

- **Header:** the profile's name and `<device> · <width>×<height>`; a **Both looks** toggle; a **Night**
  toggle; **Re-render**.
- **Frames:** off, one frame for the profile's look (`values.look` from the settings state, so a look
  change moves the frame to the new look); on, Diner and Editorial side by side in the schema's choice
  order. Each frame is named under it ("Diner", "Editorial", with "· night" when night is on), keeps the
  device's aspect ratio, and scales to its column. The frame is white with no chrome, the one bright
  thing on the page (theme studio `.tiller/design/2026-10-09-studio-ui-direction.md:26`).
- **A frame is one look and day or night.** Its last good image lives for the open profile, so turning
  night off and on again shows the night image kept, until it renders again. Opening another profile
  starts empty.
- **Rendering on change:** every write the profile screen's form or editors land marks each frame's
  image stale. 1.5 s after the last landed write, each shown frame renders; a write within the 1.5 s
  restarts it. A frame already rendering finishes first: if it ends before the pause does, it renders
  when the pause ends; if the pause ends while it renders, it renders again as soon as it ends. A frame
  not shown stays stale and renders when it is shown. A shown frame with no image that has not been
  requested since the last landed write renders at once; a failed frame renders again only on a landed
  write, Re-render, or being shown again, so a missing emulator costs one request, not a loop.
- **Re-render** renders every shown frame now; it is disabled while any shown frame is rendering.
- **States, per frame,** the theme studio's (`2026-10-09-studio-ui-direction.md:44-50`):
  - Rendering: the previous image stays, dimmed, with "Rendering in the emulator…".
  - Rendered: "Rendered in <n> s", the time from the request to its image.
  - Stale: a "stale" badge on the image while it predates the last landed write, with "Settings changed
    · re-rendering in 1.5 s" while the pause runs.
  - Failed: an amber panel with the error, "Showing the last good render." or "No earlier render to
    show.", and the log lines in mono. The last good image stays. A failure leaves the frame stale only
    if it was stale.
- Requests are aborted when the profile screen closes.

## Notes

Owner decision of 2026-10-15 written in: P1 (the preview shows the goldens' populated fixture, frozen,
with the weather reading written for the profile's location and units).

For the owner, each a default the spec chose that you can overturn at approval:

- **On change only,** with a 1.5 s pause and Re-render; no On change / On demand switch as the theme
  studio had. A render takes about ten seconds, so a quick run of edits renders once.
- **One render at a time.** Both looks with night on costs two renders in a row, about twenty seconds.
- **Both looks is off by default** and not remembered across reloads; nor is Night.
- **No server-side cache.** The theme studio kept renders on disk keyed by a tree hash; here the UI keeps
  the last good image per frame for the open profile, and a reload renders again.
- **TZ is Chicago's** for every render, as the goldens'. The frozen time reads 08:42 in any zone; the
  zone only fixes DST edges.
- **Wording to replace with your own:** "Both looks", "Night", "Re-render", "Rendering in the
  emulator…", "Rendered in <n> s", "stale", "Settings changed · re-rendering in 1.5 s", "Showing the last
  good render.", "No earlier render to show.", "No render within 150 s", "· night".

No settings key and no studio environment variable is added. The home fixture gains three test-only
variables, `KOPANDA_HOME_WEATHER_*`, listed in `.env.example` beside `KOPANDA_HOME_FIXTURE`
(`.env.example:13-18`); the studio is not a strem service, so whether `~/Projects/strem` needs them is
your call (likely not).
