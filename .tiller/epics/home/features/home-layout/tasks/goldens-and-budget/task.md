# Home goldens in both looks and the paint budget

## Approach

1. **Fixture userpatch `spec/emulator/scenarios/2-scenario-home-fixture.lua`**, beside the existing
   scenario patches. It is late priority, applied
   before any plugin code runs (`frontend/userpatch.lua:13`, `reader.lua:190`), and copied in through
   `driver.capture{ patches = {...} }` (`spec/emulator/driver.lua:66-75`). It reads its scenario from
   environment variables the spec passes, and does four things:
   - Freezes the clock: `os.time()` with no argument returns the epoch of 2026-10-13 08:42 in the run's
     `TZ` (America/Chicago, passed in the driver's env), and `os.date(fmt)` with no time argument formats
     that epoch. Calls with arguments pass through. `ui/time`'s monotonic clock is left alone, so
     `paint_ms` stays real.
   - Stubs `require("ui/network/manager").isConnected` to return false, so no fetch runs, neither after
     the show nor from the `NetworkConnected` that NetworkMgr broadcasts at start
     (`frontend/ui/network/manager.lua:152-154`; the SDL emulator's own `isConnected` is always true,
     `frontend/device/sdl/device.lua:445-449`). The weather task gates `on_connected` on `isConnected`
     for this.
   - Populated scenario only: writes `settings/kopanda/weather.lua` with the default location, °F, 61.4°,
     code 2, `is_day = 1`, `fetched_at` 20 minutes before the frozen time. It also builds
     `settings/statistics.sqlite3` with the Statistics DDL and `user_version 20221111` through the
     emulator's own SQ3, with a 4-day streak ending today, 23 minutes today and 3 books this month.
     `plugins/statistics.koplugin/main.lua:372-399` accepts a current-version file.
   - Look: writes `settings/kopanda/settings.lua` with `look` and `schema_version = 1` for the Editorial
     scenarios; Diner is the default.

   The patch writes inside the scratch `KO_HOME` only, from `DataStorage:getSettingsDir()`.
2. **`spec/emulator/home_golden_spec.lua`** (new; the placeholder's was removed in `row-engine`). For
   each scenario it runs `driver.capture{ profile, plugin_dir, patches = { fixture }, env = {...} }` and
   `golden.assert_golden(name, profile, result)` (`spec/emulator/golden.lua`):
   - `home-diner-colorsoft`, `home-diner-paperwhite`, `home-editorial-colorsoft` and
     `home-editorial-paperwhite`, populated;
   - `home-empty-diner-colorsoft` and `home-empty-editorial-colorsoft`.

   `driver.capture` has no way to pass extra environment variables: its options are documented at
   `driver.lua:215-221` and its variables built at `:254-268`. Add an `env` option merged into that list,
   which `env_assignments` (`:179-185`) and `run_emulator` (`:194-213`) already pass on, with a
   `driver_spec.lua` case.
3. **`spec/emulator/home_capture_spec.lua`** gains C10: a populated capture's `sidecar.paint_ms <= 250`
   on each profile. The existing assertions stay.
4. **`spec/emulator/book_close_spec.lua`** (C13), with its placeholder golden check already removed in
   `row-engine`, runs against the real home. If the
   `reading-stats` task moved the stats read to show time, this spec proves the 100 ms share still holds.
5. Generate the goldens with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/home_golden_spec.lua`,
   open every PNG, and compare each against its board (Main, HomeRetro, PWEditorial, PWRetro,
   EmptyStates). The PR lists anything that differs on purpose: the Diner quote tile, the strip layout,
   text sizes from `scaleBySize`. The owner's look is C11.

## Surfaces

`spec/emulator/scenarios/2-scenario-home-fixture.lua` (new), `spec/emulator/home_golden_spec.lua` (new),
`spec/emulator/home_capture_spec.lua`, `spec/emulator/driver.lua` and `spec/unit/driver_spec.lua` (the
`env` option), `spec/goldens/home-*.png` and `.json` (new, six pairs); `HOOKS.md` harness section
(the patch's `os.time`/`os.date` override and the `NetworkMgr` stub).

## Tests

- `home_golden_spec.lua` (C9): fails first, because no goldens exist. Then it is generated, eyeballed,
  committed, and passes on a second plain run.
- `home_capture_spec.lua` (C10): the 250 ms assertion is added first and run to confirm it reads the
  sidecar. If the real number is close to 250 on this Mac, report it rather than raise the bound.
- A determinism check before committing: two consecutive plain runs of `home_golden_spec.lua` both pass
  with empty masks. If the quote or clock moves between runs, the freeze is leaking: fix the patch, don't
  mask.

## Edge cases

- `os.date` is also used by KOReader's own logger and the Statistics plugin. Freezing only the no-argument
  forms keeps their explicit-time calls right. The empty scenario still starts the Statistics plugin,
  which creates its own empty database. That is expected, and its absence of rows gives the empty
  wording.
- The paperwhite profile runs grey (`EMULATE_BW_SCREEN`, `spec/emulator/profiles.lua`), so `Looks.variant()`
  picks `grey` and `on_band` uses the grey value.
- A capture that never settles (a widget raising on paint closes the home) hits the settle cap and fails
  with the log tail, which names the widget.
