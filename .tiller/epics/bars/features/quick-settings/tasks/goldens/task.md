# Quick-settings goldens in both looks on the Colorsoft and their paint budget

## Approach

Two new goldens, the quick-settings sheet over the populated home in each look on the Colorsoft profile,
shot on the sheet's settled signal within the sheets' 250 ms budget. Starts after
`bars/quick-settings/controls`, so the captured panel is the finished one. Repo lines on `main` at `e6f2912`;
KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. The feature's "Goldens and budget" is the
spec.

1. **The scenario** `spec/emulator/scenarios/2-scenario-quick-settings.lua`, a late userpatch shaped as
   `2-scenario-sheet-hold.lua` (`:1-103`): on the first `KoPandaSettled` with `screen = "home"`, from the next
   tick, it sets the power device's `getCapacity` to return 84 (an instance field on
   `Device:getPowerDevice()`, so the emulator's reading of the Mac's battery, `frontend/device/sdl/powerd.lua:28-33`,
   stays out), then calls `package.loaded["quick_settings"].open{ started = time.monotonic() }`. The module is
   in `package.loaded` because `main.lua` requires every KoPanda module at load (`spec/unit/main_requires_spec.lua`);
   a userpatch can't `require` it by name once the plugin's path is gone (`HOOKS.md:27-34`). Any failure is
   reported as a `"sheet"` `KoPandaSettled` with `error`, as the sheet-hold scenario does (`:20-23`). Its
   header comment says what it does and that it writes nothing.
2. **The spec** `spec/emulator/quick_settings_golden_spec.lua`, shaped as `sheet_golden_spec.lua` (`:1-74`):
   for `quick-settings-diner` and `quick-settings-editorial` (look passed, empty for Diner), `driver.capture{
   profile = "colorsoft", plugin_dir, patches = { fixture, scenario }, shot_screen = "sheet", env = { TZ =
   "America/Chicago", KOPANDA_HOME_FIXTURE = "populated", KOPANDA_HOME_LOOK = look } }`; asserts no error,
   screen `sheet`, name `quick_settings`, `0 < paint_ms <= 250`, one shot, no settle cap, and the golden.
3. **Regenerate** with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/quick_settings_golden_spec.lua`.
   Open both PNGs (`open <png>`) beside `QuickSettings.dc.html` and list the deliberate differences in the PR:
   the home beneath at full strength (the board dims it to 25 %, an illustration, QuickSettings:19), the
   emulator's 50 of 100 brightness and warmth against the board's 12 and 4 of 24, Sync books greyed (no
   cwngsync in the emulator), the registry's stroke-2 icons, the "Wi-Fi" hyphen, the minus and plus F1 chose,
   and Diner's derived sheet, which no board draws. A second plain run passes.
4. **The budget:** if a capture's `paint_ms` exceeds 250 ms, stop and bring the figures to the lead with the
   build and paint times split, rather than raising the budget.
5. **`HOOKS.md`**, the capture harness section: the quick-settings scenario, as the sheet-hold scenario's
   entry (`HOOKS.md:1325-1336`).

## Surfaces

`spec/emulator/scenarios/2-scenario-quick-settings.lua` (new), `spec/emulator/quick_settings_golden_spec.lua`
(new), `spec/goldens/quick-settings-diner-colorsoft.{png,json}` and
`spec/goldens/quick-settings-editorial-colorsoft.{png,json}` (new), `kopanda.koplugin/HOOKS.md`.

## Tests

- `quick_settings_golden_spec.lua` (C12): fails first with no goldens; then the goldens are written, eyeballed
  and committed, and a second plain run passes. Prove the shot holds the sheet: a scratch run with the
  scenario's open call removed fails the spec, the capture waiting for a `sheet` signal until the driver's
  settle cap (`spec/emulator/driver.lua:254`, its failure at `:300`) rather than matching the golden.
- `home_golden_spec.lua`, `night_golden_spec.lua`, `sheet_golden_spec.lua`, `screens_golden_spec.lua`,
  `golden_spec.lua` and `nav_golden_spec.lua` (C14) run unchanged and pass.

## Edge cases

- The fake Wi‑Fi defaults on (`frontend/device/sdl/device.lua:497-499`) and the scratch `KO_HOME` holds no
  `night_mode` or `lock_rotation`, so the cells read Wi‑Fi on, Night off, Rotation lock off on every run.
- The emulator's frontlight starts at 50 of 100 and its warmth at 50 (`frontend/device/sdl/powerd.lua:4-12`),
  the same every run.
- Open facts F2 and F3 are the owner's device check (C17), not this task's; this task hands the owner that
  check's list in the PR.
- No night or Paperwhite golden (feature, "Goldens and budget").
