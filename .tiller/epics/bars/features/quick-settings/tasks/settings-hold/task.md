# A hold on the nav bar's Settings tab opens the sheet, on the home and over the file browser

## Approach

The one branch nav-bar reserved: a hold in the Settings column opens the quick-settings sheet; every other hold
on the bar stays consumed and inert. Starts after `bars/quick-settings/controls` and once `nav-bar/nav-bar` is
done (the feature's prerequisite), since it edits nav-bar's `nav_bar.lua` and specs. Repo lines on `main` at
`e6f2912`, and nav-bar's files as its tasks `bar` (T-3648b1), `home-band` (T-rl8eso) and `file-browser`
(T-9h0fhs) leave them. The feature's "The Settings-tab hold" is the spec.

1. **Read nav-bar's built `bar:handle`** first: its plan routes a `hold` inside the bar to "true, nothing run"
   (nav-bar task `bar`, its lines 38-39) and `bar:column_at(pos)` gives the tab (its line 37). If the built
   code differs in shape from the plan (a different name for the routing point, holds handled elsewhere),
   stop and bring the difference to the lead before changing it.
2. **The branch.** In `bar:handle`, a `hold` whose column is the Settings tab calls
   `require("quick_settings").open{ started = time.monotonic() }` in `pcall`, an error logged with the tab's
   name, and returns true; any other hold inside the bar returns true with nothing run, as before. The
   require is at call time, as nav-bar's runs reach `launcher_entries` lazily, so loading `nav_bar` doesn't
   load the sheet's chain. The comment over `handle` names the branch and this feature.
3. **Nothing else moves:** the home's route (`HomeGestures.route`, nav-bar task `home-band` step 5) already
   hands holds in the band to `handle`, and the file browser's bar listens for `hold` through its own
   `ges_events` (nav-bar task `bar`, its lines 34-36).
4. **`HOOKS.md`:** the nav bar's hold entry (nav-bar's section on the hold on the home, `HOOKS.md:911`, as
   `home-band` step 8 leaves it) says the Settings hold opens the quick-settings sheet.

## Surfaces

`kopanda.koplugin/nav_bar.lua`, `kopanda.koplugin/HOOKS.md`. Specs: `spec/unit/nav_bar_spec.lua`,
`spec/unit/hold_routing_spec.lua`, `spec/unit/fm_nav_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `nav_bar_spec.lua` (C8, C9): nav-bar's "a hold on any column returns true and runs nothing" (nav-bar task
  `bar`, its line 83) becomes two cases: a hold in the Settings column calls a spied `QuickSettings.open` once
  with a numeric `started` and returns true; a hold in each of the other four columns and in Editorial's side
  padding returns true and calls nothing. An `open` stubbed to raise is logged and `handle` still returns true.
- `hold_routing_spec.lua` (C8, C9): on a shown home, a hold on the Settings tab shows a sheet named
  `quick_settings` over the home and no home sheet; nav-bar's "a hold in the band opens no home sheet"
  (nav-bar task `home-band`, its line 94) keeps its assertion for a hold on the Home tab.
- `fm_nav_spec.lua` (C8): with the file browser shown and no home, a hold on the bar's Settings tab (a `Gesture`
  sent through the bar's `ges_events`) shows the sheet over the file manager; a tap on its Night cell then
  flips `Screen.night_mode` (restored after), proving the route over the bare file browser end to end.
- `quick_settings_controls_spec.lua`, `gesture_routing_spec.lua` and `failsafe_spec.lua` pass unchanged.

## Edge cases

- The hold's `hold_release` reaches the sheet, now on top, which takes nothing for it (`HOOKS.md:898-901`), so
  it reaches only the active widgets below, as for the home's hold that opens the home sheet.
- Under KOReader's touch lock the bar's `ges_events` and the home's zones are filtered (nav-bar feature.md,
  "The touch lock"), so the hold opens nothing, as every other tap and hold.
- A hold while a quick-settings sheet is already up can't reach the bar: the sheet covers the screen for
  gestures (`sheet.lua:413-419`).
