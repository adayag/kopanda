# Night goldens, the Paperwhite inverse check, the toggle scenario and the night paint budget

## Approach

The emulator half of the feature: start the emulator in night mode, commit what the panel shows, and
drive a live toggle. Paths into KOReader are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **Night mode at start** (`spec/emulator/driver.lua`). `M.write_profile` writes the scratch
   `settings.reader.lua` from a fixed format string today (`driver.lua:108-111`). Add a `night_mode`
   option to `M.capture` and pass it through to `write_profile`. When it is true, the file also carries
   `["night_mode"] = true`. The device then toggles the screen before any UI exists
   (`frontend/device/generic/device.lua:344-347`). Without the option the file is byte-identical to
   today's, so no existing capture changes.
2. **`spec/emulator/night_golden_spec.lua`** (new), modelled on `home_golden_spec.lua`, with the same
   fixture userpatch, `TZ` and `KOPANDA_HOME_LOOK` handling.
   - **Goldens**: `home-night-diner` and `home-night-editorial` on `colorsoft`, `populated`, through
     `golden.assert_golden` (regenerated only under `KOPANDA_UPDATE_GOLDENS=1`).
   - **Paper corner**: read the capture's pixel at (2, 2) and assert it is within `compare.lua`'s
     tolerance of `#1e1c1a` (Diner) or `#15161a` (Editorial). This is the check that the PNG is the
     panel view, not the painted inverse.
   - **Paperwhite inverse**: capture each look on `paperwhite` with night mode on. Compare it with the
     committed day `home-diner`/`home-editorial` Paperwhite golden inverted per channel, under the
     default tolerance and with the day sidecar's masks. The featured cover's rectangle is masked out of
     that compare, because `ImageWidget` re-inverts it in night mode
     (`frontend/ui/widget/imagewidget.lua:591-593`). Inside that rectangle, the capture is compared with
     the day golden un-inverted. The rectangle comes from the home's slot rect for the featured widget
     and the cover box; read the exact source from `featured-book`'s code when this task starts. Nothing
     new is committed for it.
   - **Paint budget**: assert the Colorsoft night captures' sidecar `paint_ms` is at most 250.
3. **`spec/emulator/scenarios/2-scenario-night-toggle.lua`** (new userpatch), in the style of
   `2-scenario-book-close.lua`: it reports through a `"scenario"` `KoPandaSettled` signal, and a failure
   is reported as `error`.
   - On the first `KoPandaSettled` with `screen = "home"`, wrap `package.loaded["home"]`'s `paintTo` to
     count calls, then toggle.
     - `KOPANDA_NIGHT_ROUTE=menu`: `UIManager:broadcastEvent(Event:new("ToggleNightMode"))`, as the menu
       does (`frontend/ui/elements/common_settings_menu_table.lua:266-271`).
     - `KOPANDA_NIGHT_ROUTE=dispatcher`: `Dispatcher:execute({ night_mode = true })`
       (`frontend/dispatcher.lua:138`, `:1549-1598`), which goes through the plugin's dispatch bridge.
   - `UIManager:tickAfterNext` then reports `home_paints`, `night_mode`
     (`require("device").screen.night_mode`) and the screen. The capture patch shoots on that signal.
4. **`spec/emulator/night_toggle_spec.lua`** (new). For each route, on `colorsoft` with the populated
   fixture and Diner: `shot_screen = "scenario"`. Assert `error` is nil, `night_mode` is true and
   `home_paints` is 1, and that the capture matches the `home-night-diner` golden. The golden is passed
   by name, so this spec never writes it.
5. Generate the two goldens with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/night_golden_spec.lua`,
   `open` each PNG for the owner (C13), and commit them with their sidecars.

## Surfaces

`spec/emulator/driver.lua`, `spec/emulator/night_golden_spec.lua` (new),
`spec/emulator/night_toggle_spec.lua` (new), `spec/emulator/scenarios/2-scenario-night-toggle.lua` (new),
`spec/goldens/home-night-diner-colorsoft.{png,json}`, `spec/goldens/home-night-editorial-colorsoft.{png,json}`
(new); `spec/unit/driver_spec.lua`; `kopanda.koplugin/HOOKS.md`'s harness section for the scenario's
`ToggleNightMode` broadcast and `Dispatcher:execute`.

## Tests

Written first and run failing; the goldens spec fails until the goldens exist.

- `driver_spec.lua`: `write_profile` with `night_mode = true` writes a `settings.reader.lua` that a
  `dofile` reads back with `night_mode == true`. Without it, the file has no `night_mode` key.
- `night_golden_spec.lua` (C6, C7) and `night_toggle_spec.lua` (C8), as in the Approach.
- `home_golden_spec.lua` (C9) runs unchanged and passes. `git diff --stat` shows no day golden touched.

Open facts for this task to determine:

- **Can `compare.lua` compare against an inverted reference?** Read `spec/emulator/compare.lua` and
  `golden.lua`. If neither takes a transform, add an `invert` option to the compare call rather than
  writing an inverted PNG to disk. Prove it in `compare_spec.lua` with `spec/fixtures/png/base.png`
  against its inverse.
- **Does the Paperwhite capture invert within the default tolerance?** On the software path, glyph
  blending runs through Lua blits on the inverted buffer (`base/ffi/blitbuffer.lua:737-740`) rather than
  the C blitter. Anti-aliased edges may round differently. If the default `max_fraction` fails only on
  glyph edges (open the diff image), stop and ask the owner before loosening it for this check.
- **Is the night paint inside 250 ms?** The Lua blits are slower than the C ones day captures use. Read
  `paint_ms` from the first night capture. If it is over, stop and ask; don't move the budget.
- **Does the toggle reach the home once?** If `home_paints` is 2, the home is being dirtied twice. That
  could be `DeviceListener`'s `setDirty("all", "full")` plus a second request. Find the second request
  from a `setDirty` trace in the scenario before changing anything.

## Edge cases

- The toggle writes `night_mode` into the scratch profile's settings. Each capture uses a fresh
  `KO_HOME`, so no later run inherits it.
- The fixture's 08:42 is daytime, so Diner's weather icon is the sun at night too. That is the `weather`
  widget's `is_day` rule, not this feature's.
- If `launcher` lands after this feature and adds a row to the default layout, its golden run fails here
  too. Its executor regenerates these two goldens with its own.
- The capture's watchdog shoots after `KOPANDA_SHOT_CAP_S` if no signal comes. A scenario whose home
  never settles fails on the missing `scenario` screen, not on a stale PNG.
