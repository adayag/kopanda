# Goldens of both screens in both looks and their paint budget

## Approach

Four goldens of the two hand-written screens, Diner and Editorial, on the Colorsoft, and their paint
tripwire. Repo lines on `main` at `ca26783`; the home fixture, the capture patch and the driver are as
`sheets`' goldens task leaves them. Starts after `home/device-menus/edit-layout` and
`home/device-menus/launcher-manage`.

1. **The scenario userpatch**, `spec/emulator/scenarios/2-scenario-screens.lua`, modelled on the sheet
   hold scenario `sheets` adds (`sheets/tasks/goldens/task.md` step 1) and
   `2-scenario-gesture-forward.lua`:
   - Its name sorts after `2-scenario-home-fixture.lua` (`frontend/userpatch.lua:60-61`, alphanumeric), so
     the fixture has written its settings first.
   - It reads `KOPANDA_SCREEN`, `layout` or `launcher`; anything else is reported as a `scenario` signal
     with `error`, so the spec fails with the message.
   - For `launcher`, at patch time it stores `launcher.entries` through `LuaSettings` into
     `settings/kopanda/settings.lua`, as the fixture stores its keys (`2-scenario-home-fixture.lua:56-79`),
     keeping what is there: Library, Series, Authors, History, `{ kind = "folder", label = "Tools",
     entries = <three action entries for dispatcher ids the emulator lists, such as screenshot> }`, and
     Settings (LauncherManage:29-93). It checks the list against `Settings.validators.launcher` once the
     plugin is loaded and reports an error if refused.
   - On the first `KoPandaSettled` with `screen = "home"`, from the next tick, it calls
     `EditLayout.open{ selected = 2 }` (row 2 selected, as EditLayout:43-58 draws it) or
     `LauncherManage.open{}`.
   - The header comment says what it writes and what it opens.
2. **`spec/emulator/screens_golden_spec.lua`**, modelled on `home_golden_spec.lua` (`:9-70`) and the sheet
   goldens spec. For `edit-layout-diner`, `edit-layout-editorial`, `launcher-diner` and
   `launcher-editorial` on `colorsoft`:
   - `driver.capture{ profile = "colorsoft", plugin_dir, patches = { fixture, scenario }, shot_screen =
     "edit_layout" or "launcher", env = { TZ = "America/Chicago", KOPANDA_HOME_FIXTURE = "populated",
     KOPANDA_HOME_LOOK = look or "", KOPANDA_SCREEN = screen } }` (`spec/emulator/driver.lua:221-231`);
   - assert `result.sidecar.screen` is the screen and `result.sidecar.error` is nil;
   - **the budget:** `paint_ms` a number with `0 < paint_ms <= 250` (`home_capture_spec.lua:7-10`),
     printed as `home_capture_spec.lua:54` prints it;
   - exactly one "KOPANDA_SHOT: saved" and no "settle cap" in the log;
   - `golden.assert_golden(name, "colorsoft", result)`, failing unless `KOPANDA_UPDATE_GOLDENS=1`.
3. **Generate** with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/screens_golden_spec.lua`.
   - Open each PNG (`open <png>`) next to its board: EditLayout and LauncherManage for Editorial; for
     Diner, against the feature's Diner column.
   - The PR lists every difference that is on purpose:
     - chevron icons for the board's ▲ ▼ and the registry's `close` for ×;
     - Editorial's selected card in `hairline_light`, not `#e9e6dc`;
     - the Width and Remove column buttons on two-column rows (row 2 has one column, so they don't
       show in the golden);
     - row 5 reads "Weather" and "Reading stats" side by side (the schema's default), where the board has
       Reading stats alone;
     - kind lines "KoPanda · library" where the board writes "Screen · library";
     - five kind buttons, KoPanda screen added, where the board has four;
     - Diner has no board at all.
4. **Determinism.** Two plain runs in a row pass with empty masks. If a region differs run to run, mask
   only that region in the sidecar with a note, and say why in the PR.

## Surfaces

`spec/emulator/scenarios/2-scenario-screens.lua` (new), `spec/emulator/screens_golden_spec.lua` (new),
`spec/goldens/edit-layout-diner-colorsoft.{png,json}`, `edit-layout-editorial-colorsoft.*`,
`launcher-diner-colorsoft.*` and `launcher-editorial-colorsoft.*` (new). The fixture and the driver change
only if step 1 can't be done without it; if so, stop and say why first.

## Tests

- `screens_golden_spec.lua` (C11, C12): fails first, since the scenario and the goldens are missing. Then
  the goldens are generated, eyeballed and committed, and a second plain run passes.
  - Prove the budget assertion can fail: in a scratch run, lower it to 1 ms and see it fail with the
    figure.
  - Prove the scenario's screen is the one shot: in a scratch run with `KOPANDA_SCREEN=layout` and
    `shot_screen = "launcher"`, see the capture hit its settle cap.
- `sheet_golden_spec.lua` (C11) and `home_golden_spec.lua` (C17) run unchanged and pass: the home
  sheet's rows look the same and the home is untouched.

## Edge cases

- The fixture's weather fetch doesn't run (the driver turns the fake Wi‑Fi off, `driver.lua:80`, `:112`),
  so no home refresh repaints under the screen before the shot; nothing beneath is painted anyway while
  the screen covers it.
- The Tools folder's actions resolve against the emulator's dispatcher. An id it doesn't list would grey
  only inside the folder's list, which isn't shot; the top-level row reads "Folder · 3 entries ›" either
  way.
- `selected = 2` exists for this scenario; no other caller passes it.
