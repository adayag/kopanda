# Sheet goldens in both looks and the sheet paint budget

## Approach

Four goldens of the two sheets a hold opens, Diner and Editorial, on the Colorsoft, and the sheet's paint
tripwire. Repo lines are on `main` at `f2ef10b`; the home fixture, the capture patch and the driver are
as `launcher`'s and `night-mode`'s goldens tasks leave them. This task starts after
`home/sheets/hold-and-home-sheet` and `home/sheets/book-sheet`.

1. **The scenario userpatch**, `spec/emulator/scenarios/2-scenario-sheet-hold.lua`, modelled on
   `2-scenario-gesture-forward.lua` (`:28-83`):
   - It reads `KOPANDA_SHEET_HOLD`, which must be `book` or `home`. Anything else is reported as a
     `scenario` signal with `error`, so the spec fails with the message.
   - On the first `KoPandaSettled` with `screen = "home"`, from the next tick, it finds the shown home (the
     window named `kopanda_home`) and picks the point:
     - `book`: the centre of the rectangle of the slot whose `widget == "featured"`;
     - `home`: `x = 4` (inside the side margin, `looks/*.lua` `home.margin.side` scaled), `y = half the
       screen's height`. It checks the point is outside every slot's `rect` and outside the four
       `DTAP_ZONE_*` corners (`defaults.lua:66-69`, the KOReader root's). If not, it reports an error
       naming the slot.
   - It sends `UIManager:sendEvent(Event:new("Gesture", { ges = "hold", pos = Geom:new{ x, y, w = 0,
     h = 0 }, time = time.now() }))`, the fields `GestureRange:match` reads
     (`frontend/ui/gesturerange.lua:21-51`). No `hold_release` follows: the capture shoots before a lift
     would come.
   - The sheet's own `KoPandaSettled{ screen = "sheet", name, paint_ms }` is what the capture patch shoots
     on (`spec/emulator/patches/2-kopanda-capture.lua:61-74`, with `KOPANDA_SHOT_SCREEN = "sheet"`). It
     copies `name` and `paint_ms` into the sidecar (`:49-55`).
   - The header comment says what it writes (nothing) and what it sends.
2. **`spec/emulator/sheet_golden_spec.lua`**, modelled on `home_golden_spec.lua` (`:9-70`). For each of
   `{ name = "sheet-book-diner", hold = "book" }`, `{ "sheet-book-editorial", look = "editorial",
   hold = "book" }`, `{ "sheet-home-diner", hold = "home" }` and `{ "sheet-home-editorial",
   look = "editorial", hold = "home" }` on `colorsoft`:
   - `driver.capture{ profile = "colorsoft", plugin_dir, patches = { fixture, scenario }, shot_screen =
     "sheet", env = { TZ = "America/Chicago", KOPANDA_HOME_FIXTURE = "populated", KOPANDA_HOME_LOOK =
     look or "", KOPANDA_SHEET_HOLD = hold } }` (`spec/emulator/driver.lua:218-227`);
   - assert `result.sidecar.screen == "sheet"`, `result.sidecar.name` is `book` or `home` as held, and
     `result.sidecar.error` is nil;
   - **the budget:** `paint_ms` is a number with `0 < paint_ms <= 250`, the home's tripwire
     (`spec/emulator/home_capture_spec.lua:7-10`). The figure is printed as `home_capture_spec.lua:54`
     prints it;
   - the log has exactly one "KOPANDA_SHOT: saved" and no "settle cap";
   - `golden.assert_golden(name, "colorsoft", result)`, failing unless `KOPANDA_UPDATE_GOLDENS=1`
     (`home_golden_spec.lua:65-68`).
3. **Generate** with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/sheet_golden_spec.lua`.
   - Open each PNG next to its board: HoldBook, HoldBookC, HoldHome, HoldHomeC.
   - Check the meta reads "62% · Letter IV · opened today", the weather row "20 min ago", and Wi‑Fi "Off"
     with `wifi_off`.
   - The PR lists every difference that is on purpose:
     - the home behind is not dimmed;
     - "More by this author" with a chevron and no count, against the board's "More by Susanna Clarke 3";
     - the small cover's frame is the look's (Editorial's shadow and 3 px radius, Diner's 3 px outline
       and pink shadow), against the boards' plain 2 px;
     - "Off" and `wifi_off` where the board shows "On";
     - "opened today" and "Letter IV" where the board writes "opened yesterday" and "Part 3";
     - the Diner background has no greeting (HoldBookC:21);
     - icons at stroke 2 against Editorial's 1.6.
4. **Determinism.** Two plain runs in a row pass with empty masks. If a region differs from run to run,
   mask only that region in the sidecar, with a note, as `golden.lua` keeps masks across an update. Say
   why in the PR.

## Surfaces

`spec/emulator/scenarios/2-scenario-sheet-hold.lua` (new), `spec/emulator/sheet_golden_spec.lua` (new),
`spec/goldens/sheet-book-diner-colorsoft.{png,json}`, `sheet-book-editorial-colorsoft.*`,
`sheet-home-diner-colorsoft.*` and `sheet-home-editorial-colorsoft.*` (new). `HOOKS.md`'s harness section,
if it lists the scenario patches. The home fixture and the driver change only if step 1 can't be done
without it; if so, stop and say why first.

## Tests

- `sheet_golden_spec.lua` (C9, C10): fails first, since the scenario and the goldens are missing. Then
  the goldens are generated, eyeballed and committed, and a second plain run passes.
  - Prove the budget assertion can fail: in a scratch run, lower it to 1 ms and see it fail with the
    figure.
  - Prove the hold is the one shot: in a scratch run with `KOPANDA_SHEET_HOLD=home` and the point moved
    into the featured slot, see the sidecar's `name` become `book` and the assertion fail.
- `home_golden_spec.lua` (C15), `home_capture_spec.lua` and `book_close_spec.lua` (C12) run unchanged and
  pass. The sheet changes nothing until something is held.

## Edge cases

- The featured cover is extracted into CoverBrowser's cache before the home is built
  (`2-scenario-home-fixture.lua:9-11`). The book sheet's small cover reads that cached thumbnail, which
  is bigger than its box and so still fits (`plugins/coverbrowser.koplugin/bookinfomanager.lua:1013-1030`).
  The book golden therefore shows the real cover, never the placeholder.
- The home's `after_show` may schedule the cover check (`featured_cover.lua:319-381`) if the cache is
  thought stale. The fixture's extraction makes `wants_extraction` false, so nothing is scheduled. If a
  capture's log shows an extraction, stop and report it rather than wait for it.
- The hold lands one tick after the home's settled signal. `Weather.after_show` doesn't fetch with the
  fake Wi‑Fi off (`weather.lua:199-204`), so no refresh repaints under the sheet before the shot.
- The Paperwhite and night sheets have no golden: the unit specs cover the grey and night palettes, and
  the owner's emulator run looks at night.
