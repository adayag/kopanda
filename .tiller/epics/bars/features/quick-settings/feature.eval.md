---
node: F-rce9ko
criteria:
  - id: C1
    statement: "Both looks declare identical token paths including the quick_settings block (side padding, first and other section padding, section gap and rule, control gap, button size, outline and fill, level bar height, outline, fill and track, grid gap and padding, cell padding, gap, icon size, outline and fill, on fill and on text colours), sheet.quick_settings_band_color, and the quick_label, quick_button and quick_cell type parts, with Editorial's values from QuickSettings.dc.html:34-87 and Diner's from its own sheet, progress and chip tokens as the feature's table gives them (Diner's band the band role), every colour an existing palette role and every face one the look ships"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C2
    statement: "A sheet spec with body lays the body's widget out under the header and frees it with the panel; a tap in an area runs its tap once with the sheet still shown, then the sheet re-lays out by calling body again and asks for exactly one ui refresh of the union of its old and new rectangles; an area with close_first closes the sheet first and then runs; a hold in an area with hold runs it the same way, and a hold elsewhere in the panel runs nothing and keeps the sheet unless the spec has hold; a tap elsewhere in the panel is consumed and runs nothing, outside it closes the sheet; an area's tap or hold that raises is logged and the sheet stays and redraws; body raising closes the sheet, logged; each refresh_on event re-lays the sheet out and is not consumed; Sheet.redraw redraws the shown sheet and does nothing with none; a night toggle rebuilds the body in the night variant; the sheet shows over a bare file manager with no home and a failure there leaves the file manager on top"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/sheet_spec.lua" }
    required: true
  - id: C3
    statement: "Sheets built from rows look and act as before: the home, book and folder sheets keep their rows, chips, hints, holds, taps that close then run, Back, one-sheet-at-a-time, settled signal and dropped rows"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/sheet_spec.lua", "spec/unit/home_sheet_spec.lua", "spec/unit/book_sheet_spec.lua", "spec/unit/folder_sheet_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/sheet.lua"
      captured_at: { kind: git_tree, value: "git:e6f2912", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C4
    statement: "QuickSettings.open shows one sheet named quick_settings, with no home needed, headed Quick settings with Battery N% from the power device's capacity when the device has a battery and no aside without; a Brightness section with the native intensity (0 with the light off) and a fill of value over fl_max, shown only with a frontlight; a Warmth section with the native warmth and its fill, shown only with natural light; and a three-column grid of Wi-Fi, Night, Rotation lock, Sync books, Screenshot and Sleep in that order with the registry's icons, Wi-Fi reading Wi-Fi on or Wi-Fi off with the wifi or wifi_off icon, Night reading Night on or Night off; Wi-Fi, Night and Rotation lock are filled on_fill with on_text label and icon exactly when the radio is on, night_mode is set or lock_rotation is set; Sync books is greyed unless the cwngsync plugin is loaded and cwngsync_sync_now is registered, Sleep greyed without suspend, Wi-Fi greyed without a Wi-Fi toggle, greyed cells muted and never filled; a raising state read greys that control and logs; it paints from Looks.palette in day, night and grey in both looks with its outlines, fills and level bars where the tokens put them, names no palettes table, follows text_size, and the whole panel fits on the Colorsoft's screen, in portrait and with its width and height swapped, at small, medium and large text sizes"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/quick_settings_spec.lua", "spec/unit/night_mode_spec.lua"] }
    required: true
  - id: C5
    statement: "With the power device set to the Kindle's 0 to 24 scales, a tap on brightness plus or minus moves the intensity one native step, clamped at 0 and fl_max, a plus from the light off turns it on at 1, a hold on minus turns the light off and a hold on plus sets fl_max; warmth likewise moves one native step clamped at its minimum and maximum, hold minus its minimum and hold plus its maximum; each goes through a broadcast SetFlIntensity or SetFlWarmth that the file manager's DeviceListener handles, and the sheet stays shown with the new value and fill; Night toggles night mode through a broadcast ToggleNightMode and the sheet repaints in the night variant; Rotation lock flips lock_rotation; Wi-Fi turns the radio off when connected and on when off, through NetworkMgr's interactive toggles, and the cell follows after the toggle's callback and after NetworkConnected or NetworkDisconnected, which still reach the home; Sync books, Sleep and Screenshot each close the sheet before running, Screenshot after a forced repaint so the shot holds no sheet pixels; a greyed cell closes the sheet and shows the launcher's note naming why; an action that raises is logged and the sheet stays"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/quick_settings_controls_spec.lua" }
    required: true
  - id: C6
    statement: "Over a bare file manager with no home shown, every action reaches KOReader: the brightness and warmth steps change the power device, Night changes Screen.night_mode, Wi-Fi changes the radio, Rotation lock changes lock_rotation, Sleep reaches DeviceListener's RequestSuspend, Screenshot reaches the Screenshoter, and Sync books delivers CWNGSyncSyncNow to a plugin module named cwngsync registered on the file manager with cwngsync_sync_now registered; the same over the home"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/quick_settings_controls_spec.lua" }
    required: true
  - id: C7
    statement: "LauncherEntries.KOPANDA has quick_settings labelled Quick settings with the quick_settings icon, and running it opens the quick-settings sheet over the home; the schema stays version 1 with the same keys, its launcher kopanda targets now library, series, authors, settings and quick_settings and its default six unchanged; the entry picker offers Quick settings among KoPanda screens; the icon registry has quick_settings, a Lucide stroke-2 file in opaque black ink, used in the launcher; studio/src/schema.json and studio/src/catalog.json equal fresh bin/schema-json and bin/catalog-json output"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/launcher_entries_spec.lua", "spec/unit/schema_spec.lua", "spec/unit/entry_picker_spec.lua", "spec/unit/icons_spec.lua", "spec/unit/studio_schema_spec.lua", "spec/unit/studio_catalog_spec.lua"] }
    required: true
  - id: C8
    statement: "A hold in the nav bar's Settings column opens the quick-settings sheet once and is consumed: on the home over the home, with no home sheet opened, and in the file browser over the file manager with no home; there a tap on Night then toggles night mode; an open that raises is logged and the hold still consumed"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/nav_bar_spec.lua", "spec/unit/hold_routing_spec.lua", "spec/unit/fm_nav_spec.lua"] }
    required: true
  - id: C9
    statement: "Every other hold on the nav bar is still consumed and runs nothing: a hold on Home, Library, Authors or History, or in Editorial's side padding, opens no sheet and runs no tab, and on the home a hold in the band outside the Settings column opens no home sheet"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/nav_bar_spec.lua", "spec/unit/hold_routing_spec.lua"] }
    baseline:
      surface: "nav-bar/nav-bar D3 (holds), as nav-bar's bar and home-band tasks build it"
      captured_at: { kind: git_tree, value: "git:e6f2912", path: .tiller/epics/nav-bar/features/nav-bar, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C10
    statement: "Every hook still fails safe with the sheet in it: a raising QuickSettings.open from the nav bar is logged and leaves the screen beneath on top and handling input, and from a launcher tap is logged and closes the home onto the file browser, which handles input; a quick-settings sheet whose build or paint raises is closed, logged, and the file manager stays on top and handles input, over the home and over the bare file browser"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:e6f2912", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C11
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes (night_mode and lock_rotation among them) and every KOReader internal it reads or patches, each entry with a file:line, including the power device's reads and scales, the frontlight, warmth, night mode and suspend events and their handlers, NetworkMgr's toggles and events, lock_rotation, sendEvent, broadcastEvent, close and forceRePaint, the Screenshoter, the plugin check and cwngsync's action at df90d5e; no KoPanda module name, quick_settings among them, collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:e6f2912", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C12
    statement: "The quick-settings-diner and quick-settings-editorial goldens on colorsoft match a fresh capture of the sheet opened over the populated home with the battery stubbed at 84, each shot on KoPandaSettled with screen sheet and name quick_settings, and each capture's paint_ms is at most 250 ms"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/quick_settings_golden_spec.lua" }
    required: true
  - id: C13
    statement: "The swatch screen fits every registry icon, quick_settings included, and its two goldens, regenerated for the new cell, match fresh captures"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/swatch_spec.lua", "spec/emulator/swatch_golden_spec.lua"] }
    required: true
  - id: C14
    statement: "The home, night, sheet, editor screen, probe and file-browser goldens still match fresh captures, and this feature regenerates none of them"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/night_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua", "spec/emulator/screens_golden_spec.lua", "spec/emulator/golden_spec.lua", "spec/emulator/nav_golden_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:e6f2912", path: spec/goldens, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C15
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C16
    statement: "The owner has opened the two quick-settings goldens and the two swatch goldens and confirms the Editorial sheet reads as QuickSettings.dc.html draws it (the 2 px ink rule, the serif heading and the battery aside, the hairline-ruled bars with outlined minus and plus, the three-by-two grid of outlined tiles with the on cell in ink), judges the derived Diner sheet (the teal band header, 2 px outlined buttons, tiles and mustard level bars, the on cell in ink with paper text) acceptable, and sees nothing clipped and the new icon's swatch cell"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C17
    statement: "The owner has, on the Kindle Colorsoft SE with this build installed: opened the sheet from a hold on the Settings tab on the home and over the file browser, and from a Quick settings launcher tile placed on the home; stepped brightness and warmth with plus and minus and seen the light follow and the values track, held minus and seen the light go off, held plus and seen it go to the top; toggled Wi-Fi off and on and seen the cell follow (recording whether it lags one redraw, F2); toggled Night and seen the sheet and the home go to night and back; set Rotation lock, opened a book and returned, and seen no rotation change; tapped Screenshot and found a screenshot of the screen beneath without the sheet; tapped Sync books and seen cwngsync sync (its installed copy carrying the cwngsync_sync_now action); tapped Sleep and seen the device sleep; and seen both bars on the device (F3)"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck (`bin/check`, the `<spec>...` branch); a criterion that lists several files runs
them all. C15 is the lint stage alone. The tests gate's own `bin/check` run covers the whole suite, the
studio's typecheck, lint and tests included, which the regenerated `schema.json` and `catalog.json` reach.

Every criterion is satisfiable by this feature once `nav-bar/nav-bar` (F-78e5ij), its recorded prerequisite,
is done: C8 and C9 run through nav-bar's `nav_bar.lua`, `fm_nav.lua` and their specs, which this feature
extends rather than adds, and C14's file-browser goldens are nav-bar's.

C1 to C11 and C13's unit half run on KOReader's LuaJIT under the plugin harness, whose device is the SDL
emulator with a frontlight, natural light, a Wi‑Fi toggle, suspend and a battery
(`frontend/device/sdl/device.lua:152-166`). C4 and C5 reach the Kindle's case by setting the power device's
`fl_max` and `fl_warmth_max` to 24 (and its `warmth_scale`), and the absent cases by stubbing `Device`'s
capability functions, each restored where it is made. C5 and C6 stand cwngsync in with a module named
`cwngsync` registered on the file manager and `cwngsync_sync_now` registered with the Dispatcher, both removed
after; the action's real shape is cited from cwngsync at `df90d5e` (feature.md D2), and C17 confirms it on the
device. The emulator's Wi‑Fi flips its setting at once and broadcasts after `scheduleIn(2)`
(`frontend/device/sdl/device.lua:478-500`), which the harness's tick delivers.

C12 and C13 bind emulator specs whose goldens this feature writes on purpose, which is why they are
`introduce`. C14 is the goldens nothing here draws on. Its comparison target is the goldens on `main` when this
feature's first task starts, after nav-bar's merge regenerates the home, night and sheet goldens and adds the
file-browser ones (nav-bar feature.md, "Goldens and budget"); the `e6f2912` pin records the tree at plan time.
This feature regenerates only the two swatch goldens and adds the two quick-settings goldens.

The preserve criteria are baselined at `main` `e6f2912`, before nav-bar lands; their checks run against the
tree nav-bar leaves, which this feature starts from. C9's baseline is nav-bar's accepted plan, since the bar it
preserves is not built at plan time.

C16 and C17 are the human checks: C16 the look at every new or regenerated golden, Diner's derived sheet
judged by the owner; C17 what the emulator can't show (the Kindle's real light and warmth through lipc, the
radio's timing, sleep, a real screenshot, the installed cwngsync), with open facts F2 and F3 recorded there.
