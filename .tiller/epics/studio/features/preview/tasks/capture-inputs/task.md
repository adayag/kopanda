# The capture driver takes a profile's screen and settings file, and the home fixture a weather reading for them

## Approach

The dev loop's capture gains what a studio profile needs, with every existing call unchanged. Repo
lines on `main` at `8bbff12`. Independent of the studio features: it touches only `spec/`.

1. **`spec/emulator/driver.lua`, `opts.device`.** `capture` (`:231-319`) and `write_profile`
   (`:93-149`) resolve the screen once: `opts.device` when given, else `profiles[opts.profile]` as
   today (`:94-97`, `:233-237`). `device` must hold positive integer `width`, `height`, `dpi` and a
   boolean `color`; anything else is an error naming the field. With `device`, `opts.profile` must
   match `^[a-z0-9-]+$` (it names `profile-<name>`, `<name>.png` and `<name>.log`, `:257-261`), an error
   otherwise. The screen feeds the `EMULATE_READER_*` variables (`:267-269`), `EMULATE_BW_SCREEN` for a
   grey screen (`:275-277`) and `color_rendering` (`:111-114`). `write_profile` takes the screen through
   its `opts` (`opts.device`), keeping its positional arguments, so its callers in
   `spec/unit/driver_spec.lua:142-234` stay as they are.
2. **`opts.settings_file`.** After `settings/` is made (`:116`), when given: an error naming the path
   unless it is a file; else `mkdir settings/kopanda` and copy the file to
   `settings/kopanda/settings.lua`. Update the options comment (`:221-230`) and the `write_profile`
   comment (`:67-92`) in their style.
3. **`spec/emulator/scenarios/2-scenario-home-fixture.lua`, the weather variables.** Read
   `KOPANDA_HOME_WEATHER_LATITUDE`, `_LONGITUDE` and `_UNITS` at the top with the fixture name
   (`:27-30`). None set: the reading is written as today (`:176-186`). All three: `latitude` and
   `longitude` through `tonumber`, `units` one of `fahrenheit` or `celsius` (`kopanda.koplugin/schema.lua:60-68`),
   and the reading uses them, `temperature` 61.4 for Fahrenheit and 16.3 for Celsius. One or two set,
   a coordinate `tonumber` refuses, or another unit: `error(...)`, which the fixture's guard turns into
   exit 4 (`:285-290`). Update the header comment (`:8-19`) to say so. The empty fixture writes no
   reading whatever is set (`:81-83`).
4. **The non-table copy.** Before storing the look (`:73-79`), when `LuaSettings:open`'s `data` is not a
   table, `reset({})` it, as the plugin reads such a file (`kopanda.koplugin/settings.lua:261-263`);
   today `saveSetting` would raise on it and end the run with exit 4.
5. **`.env.example`**: the three variables join the fixture block (`.env.example:13-18`), its "Set by"
   list and the fixture's header (`:1-3`) gaining `capture_inputs_spec.lua`, `preview_spec.lua` and
   `bin/preview.lua`.

## Surfaces

- `spec/emulator/driver.lua`
- `spec/emulator/scenarios/2-scenario-home-fixture.lua`
- `spec/emulator/capture_inputs_spec.lua` (new)
- `.env.example`

## Tests

`spec/emulator/capture_inputs_spec.lua` (C1), written first and run failing:

- **`device`:** the probe plugin (`spec/fixtures/probe.koplugin`, as `capture_spec.lua:51-79` uses it)
  captured with `profile = "studio-1"` and `device = { width = 1072, height = 1448, dpi = 300, color =
  false }` gives a 1072×1448 PNG whose sidecar says `color = false`; a `device` missing `dpi` and a
  profile name `"../x"` each raise naming the problem, before any emulator runs.
- **`settings_file`:** `write_profile` with `opts.settings_file` leaves the file's exact bytes at
  `<dir>/settings/kopanda/settings.lua`; a missing path raises naming it.
- **The weather variables:** a settings file storing `weather.location = { name = "Paris, Île-de-France",
  latitude = 48.85341, longitude = 2.3488 }` and `weather.units = "celsius"`, captured with the
  populated fixture (and `TZ`, as `home_golden_spec.lua:56-60` passes it) once with the three variables
  set to that location's `%.17g` coordinates and `celsius` and once without them: the two PNGs differ
  (`compare.compare(...).ok` false), since the second shows "Weather needs Wi-Fi"
  (`kopanda.koplugin/weather.lua:23`, `:159-161`). Four runs each fail with the driver's exit-4 message
  (`driver.lua:302-304`) naming the variables in its log tail: only `KOPANDA_HOME_WEATHER_UNITS` set;
  `_LATITUDE` and `_LONGITUDE` set without `_UNITS`; `_LATITUDE=abc` with the other two; `_UNITS=kelvin`
  with the other two.
- **The non-table copy:** a settings file holding `return 5`, captured with the populated fixture and
  `KOPANDA_HOME_LOOK=diner`, succeeds and passes the `home-diner` golden check on the Colorsoft
  (`golden.check` with `update = false` and the home goldens' fraction).

Then C9: every emulator spec at the baseline and `spec/unit/driver_spec.lua`, with no golden regenerated
(the run in the binding).

## Edge cases

- **A shadowed default.** A `device` given with a known profile name (`colorsoft`) still uses the
  `device`, so the studio's profile wins over `profiles.lua`; the test above uses an unknown name, and
  the comment says so.
- **Float round trip.** The variables are strings; `%.17g` and `tonumber` give back the same double, and
  the plugin compares the cache's coordinates to the stored ones with `~=`
  (`kopanda.koplugin/weather.lua:148-149`). The spec formats the coordinates exactly as `bin/preview.lua`
  will.
- **The fixture writes the look into the copied file** (`2-scenario-home-fixture.lua:73-79`) with
  `LuaSettings:open`, which reads the copy first, so the profile's other keys stay. A copy that is
  unloadable reads as `{}` there (`frontend/luasettings.lua:31-45`), so it ends holding only the look,
  which is what the plugin would make of it: every other key at its default.
- **Timing:** the new spec adds nine emulator runs (the four failures end early), about 70 s, to
  `bin/check`'s emulator stage.
