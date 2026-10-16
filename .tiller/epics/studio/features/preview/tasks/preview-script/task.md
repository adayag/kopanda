# bin/preview renders a profile's home in one look, day or night

## Approach

One command the studio's server runs: a profile's screen and settings in, the home's PNG out, through the
dev loop's driver and the populated home fixture (decision P1). Starts after
`studio/preview/capture-inputs`. If `studio/settings-form/layout-fit` has merged, read its built
`bin/layout-fit` and `bin/layout-fit.lua` first and match their shape; otherwise follow
`settings-form/tasks/layout-fit/task.md:11-30`. Repo lines on `main` at `8bbff12`.

1. **`bin/preview`** (bash), shaped like `bin/schema-json:8-16`: `KOPANDA_ROOT` from `$0`,
   `KOPANDA_EMULATOR` defaulted as `bin/check:17-18`, exit 2 naming the path without an executable
   `luajit`. Usage `bin/preview <width> <height> <dpi> <color|grey> <diner|editorial> <day|night> <out.png>
   [settings file]`; a wrong count, a size not matching `^[1-9][0-9]*$`, a value outside its list, or a
   settings file argument that is not a file: exit 2 with the usage. Scratch `KO_HOME` by `mktemp -d`,
   removed by a `trap` on `EXIT`; the settings file copied to `$KO_HOME/settings/kopanda/settings.lua`
   when given; `cd "$KOPANDA_EMULATOR"`; run `bin/preview.lua` with `LUA_PATH` and `LUA_CPATH` as
   `run_busted` sets them minus the three `spec/rocks/` entries (`bin/check:93-99`), `KOPANDA_ROOT` and
   `KO_HOME` exported, `TZ=America/Chicago`, the arguments as `arg[1..]` (the script is a file, not an
   `-e` chunk), and the LuaJIT process's stdout sent to `/dev/null`: KOReader's library-loading chatter
   is printed there (`ffi/loadlib.lua:22`, `frontend/logger.lua:89`). On exit 0 `bin/preview` prints
   the JSON line the script wrote to `$KO_HOME/result.json`; otherwise it exits 1, the script's stderr
   passed through.
2. **`bin/preview.lua`:**
   - `require("ffi/loadlib")` and `require("commonrequire")`, as `spec/helper.lua` and
     `spec/plugin_harness.lua` do, so `DataStorage` reads the scratch `KO_HOME`.
   - `local Settings = require("settings")` (the plugin's, on `LUA_PATH`); `location =
     Settings.get("weather.location")`, `units = Settings.get("weather.units")`.
   - `driver.capture{ profile = "preview", device = { width, height, dpi, color }, settings_file = <the
     copy, when given>, plugin_dir = KOPANDA_ROOT .. "/kopanda.koplugin", patches = { the home fixture },
     night_mode = (variant == "night"), out_dir = KO_HOME .. "/capture", env = { TZ, KOPANDA_HOME_FIXTURE =
     "populated", KOPANDA_HOME_LOOK = look, KOPANDA_HOME_WEATHER_LATITUDE = ("%.17g"):format(lat),
     _LONGITUDE, _UNITS = units } }` inside `pcall`, after `lfs.mkdir` of the `out_dir` (the driver
     makes only `<out_dir>/profile-<name>`, non-recursively, `spec/emulator/driver.lua:103-104`).
   - Success: copy `result.png` to `<out.png>`, write `rapidjson.encode({ png, width, height, paint_ms
     = result.sidecar.paint_ms })` and a newline to `$KO_HOME/result.json`, exit 0. Failure: the error
     message alone with `io.stderr:write`, exit 1, so its first line is the message the server shows.
3. **AGENTS.md** Commands gains `bin/preview`'s line in the `bin/schema-json` line's style.
4. **`.luacheckrc`**, if `bin/preview.lua` needs a std or globals entry the way spec files do; read it
   first.

**Open fact, settled here and recorded in the PR:** whether `commonrequire` reads `KO_HOME` at require
time through `DataStorage` (`datastorage.lua:19-20`) so `Settings.get` opens the scratch copy, or needs
the copy at another path. Tell by a settings file storing `weather.units = "celsius"`: `Settings.get`
answers `celsius` inside the script. If it reads elsewhere, point it at the copy and say how in the
script's header.

## Surfaces

- `bin/preview`, `bin/preview.lua` (new)
- `spec/emulator/preview_spec.lua`, `spec/unit/preview_cli_spec.lua` (new)
- `AGENTS.md`, `.luacheckrc` if needed

## Tests

Written first and run failing:

- **`spec/emulator/preview_spec.lua`** (C2, C3), each case running `bin/preview` through `io.popen`
  with `KOPANDA_UPDATE_GOLDENS` unset in its environment:
  - `1264 1680 300 color diner day` with no settings file: `golden.check("home-diner", "colorsoft",
    { png = out }, { update = false, max_fraction = 0.00002 })` (`spec/emulator/golden.lua:90-136`,
    the home goldens' fraction `home_golden_spec.lua:19`); `editorial night`: the same against
    `home-night-editorial` at the default fraction (`night_golden_spec.lua:99`, `golden.assert_golden` with no opts,
    `golden.lua:137-140`). `update = false` is
    explicit, so the spec can never write a golden. Stdout is one JSON line with `png`, `width`,
    `height` and a number `paint_ms`, and stderr is empty.
  - A settings file storing `text_size` at a non-default choice (`schema.lua`) renders differently from
    the no-file render (`compare.compare(...).ok` false).
  - Paris in `celsius` against Paris in `fahrenheit` (the coordinates as `capture_inputs_spec.lua` has
    them): the two differ.
  - A file storing `look = "editorial"` rendered with `diner` passes the `home-diner` golden check.
  - `1072 1448 300 grey diner day`: the PNG is 1072×1448 (`driver.png_size`).
- **`spec/unit/preview_cli_spec.lua`** (C4), shell runs with no emulator needed except where named:
  each refusal (count, `0` and `12a` sizes, `colour`, `classic`, `dusk`, a missing settings file) exits
  2 with "usage:"; `KOPANDA_EMULATOR=/nonexistent` exits 2 naming `/nonexistent/luajit`; a fake emulator
  directory whose `luajit` prints "capture preview: boom" and two log lines to stderr and exits 1
  makes `bin/preview` exit 1 with those lines on stderr and empty stdout; after both success (the fake
  `luajit` writing the PNG and the JSON line) and failure, no directory the run's `mktemp` made is left
  (the fake records `$KO_HOME`).

Then the emulator stage of `bin/check` for C9.

## Edge cases

- **A shadowed plugin.** With `kopanda.koplugin` in the emulator's own `plugins/`, the driver refuses
  (`driver.lua:249-252`); that is a failed render with the driver's message, not a hang.
- **Library chatter on stdout.** KOReader's `ffi/loadlib` prints on load (`bin/check:63-64`); it would
  break the server's JSON parse and, sent to stderr, would become the failure's first line. Dropping
  the LuaJIT stdout and writing the result to a file avoids both; the spec asserts stdout is the JSON
  line alone and stderr empty on success.
- **A killed run.** The server's SIGTERM runs the `EXIT` trap once the child exits; only its SIGKILL 5 s
  later leaves the scratch under `$TMPDIR`. Acceptable, and said in the script's header.
- **Run time:** about 10 s a render (handoff §3); the emulator spec adds seven renders to `bin/check`.
