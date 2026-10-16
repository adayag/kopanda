---
node: F-78e5ij
criteria:
  - id: C1
    statement: "Both looks declare identical token paths including the nav block (fill, edge, side padding, tab padding, icon size and gap, icon colours, active rule, active fill, dividers) and the nav_label and nav_label_active type parts, with the boards' values (Editorial NavBar:68-73, Diner NavBarC:70-75), every colour an existing palette role; Diner's home footer has height 0 and Editorial's home bottom margin is 20"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C2
    statement: "NavBar builds Home, Library, Authors, History and Settings in that order with the registry's icons, in five equal columns across the width less the side padding; its height per look is edge, the active rule's overhang, tab padding, icon, gap and one label line, the same at small, medium and large text sizes; the active tab carries Editorial's 3 px ink rule or Diner's mustard block with on_accent text, Diner draws its dividers right of tabs 1 to 4 only, and it paints from Looks.palette in day, night and grey; a tap in a column runs that tab once (Home shows the home from the file browser and does nothing on the home, Library closes the home and calls onHome, Authors shows its note, History dispatches history, Settings opens SettingsMenu with no group) and is consumed; a tab whose run raises is logged and the tap consumed; a hold anywhere on the bar runs nothing and is consumed; a gesture outside the bar is not consumed"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/nav_bar_spec.lua" }
    required: true
  - id: C3
    statement: "The home places its rows, footer and free height in the screen less the bar's height and reports the band as arranged.nav, Layout.fits and Layout.overflow counting it; it draws the bar with Home active in the band; a tap in the band runs the tapped tab before the file manager's zones, so a tap at the bottom corners with a corner zone bound on the file manager runs the Home or Settings tab and not the zone, and a tap on the Home tab leaves the home up; a hold in the band runs nothing and opens no home sheet; a swipe up starting in the band still opens settings; under KOReader's touch lock a tap in the band does nothing"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/layout_spec.lua", "spec/unit/home_layout_spec.lua", "spec/unit/gesture_routing_spec.lua", "spec/unit/hold_routing_spec.lua"] }
    required: true
  - id: C4
    statement: "With KoPanda loaded in a file manager, the file chooser is the screen's height less the active look's bar height, its page footer above the band, and fm[1] holds the original layout with a bar with Library active in the band; FileChooser has no height field after the layout, and a PathChooser built afterwards is full height; a tap on each tab in the file browser runs it (Library calling onHome, Home showing the home), a bound bottom-corner zone on the file manager does not fire for a tap in the bar, and a hold in the bar runs nothing; reinit and onSetRotationMode re-apply the band and bar at the new size; a night-mode toggle repaints the bar in the night palette; storing a new look through the settings menu re-lays the file manager out at the new look's band, and with no file manager does nothing; a refused shell leaves setupLayout KOReader's; the wrapper is installed once per process; after a paint of the file browser on top, one KoPandaSettled with screen file_browser and a numeric paint_ms is sent per layout, and none while the home covers it"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/fm_nav_spec.lua", "spec/unit/menu_spec.lua"] }
    required: true
  - id: C5
    statement: "Upgrade tripwire: the unwrapped FileManager.setupLayout is defined at frontend/apps/filemanager/filemanager.lua:116 of the emulator's KOReader, and after it runs fm[1] is a FrameContainer whose only child is fm.file_chooser named filemanager, and a FileChooser built while FileChooser.height is set has that height as its dimen.h"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/fm_nav_spec.lua" }
    required: true
  - id: C6
    statement: "Every hook still fails safe, the bar's included: a raising band computation runs the original setupLayout alone at full height; the original setupLayout's own error is re-raised unchanged with FileChooser's height field put back; a raising wrap leaves the original layout in fm[1]; a raising bar paint, tab run or relayout is logged; in every case the file manager stays on top and handles input, and an error on the home closes it onto the file browser as before"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:fa0e7dd", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C7
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires and every KOReader internal it reads or patches, each entry with a file:line, including FileManager.setupLayout, its callers, registerModule, Menu:init's height, onScreenResize, the class-field fallback, the event order, Gestures' bottom corners and getNthTopWidget; no KoPanda module name, nav_bar and fm_nav among them, collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:fa0e7dd", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C8
    statement: "The committed filebrowser-diner and filebrowser-editorial goldens on colorsoft and paperwhite match a fresh capture of the populated fixture's file browser with the bar and Library active, each shot on KoPandaSettled with screen file_browser"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/nav_golden_spec.lua" }
    required: true
  - id: C9
    statement: "The ten home goldens, the two night goldens and the four sheet goldens, regenerated with the bar, match fresh captures, and no home capture leaves a row out"
    polarity: introduce
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/night_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua"] }
    required: true
  - id: C10
    statement: "The four editor screen goldens, the swatch goldens and the probe goldens still match fresh captures, and this feature regenerates none of them"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/screens_golden_spec.lua", "spec/emulator/swatch_golden_spec.lua", "spec/emulator/golden_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:fa0e7dd", path: spec/goldens, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C11
    statement: "Each file-browser capture's paint_ms, the wrapped setupLayout's duration plus its first paint on top, is at most 250 ms, and the home's capture still paints within its 250 ms budget with the bar in it, in the emulator on this Mac"
    polarity: introduce
    binding: { type: test, ref: ["spec/emulator/nav_golden_spec.lua", "spec/emulator/home_capture_spec.lua"] }
    required: true
  - id: C12
    statement: "Every gesture the home routed before this feature routes the same way outside the bar's band: the swipe up to settings, the file manager's menu zones, the consumed page swipe, zones registered on the file manager winning over the home's tap and over a tappable slot at a corner above the bar, a tap on a tappable slot running it, a tap elsewhere closing the home, the touch lock, and actions dispatched while the home is up reaching the file manager"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/gesture_routing_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home_gestures.lua"
      captured_at: { kind: git_tree, value: "git:fa0e7dd", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C13
    statement: "On the emulator, a Gestures binding on the file manager's bottom-right corner, tapped above the bar on the home, still shows History over the home"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/gesture_forward_spec.lua" }
    baseline:
      surface: "spec/emulator/scenarios/2-scenario-gesture-forward.lua"
      captured_at: { kind: git_tree, value: "git:fa0e7dd", path: spec/emulator, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C14
    statement: "The schema is unchanged: version 1 with the same nine keys in order, each type validated, and no nav key"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/schema_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/schema.lua"
      captured_at: { kind: git_tree, value: "git:fa0e7dd", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C15
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C16
    statement: "The owner has opened the four file-browser goldens and every regenerated home, night and sheet golden, and confirms the Editorial bar reads as NavBar.dc.html draws it and the Diner bar as NavBarC.dc.html (edge, columns, icons over labels, the active rule or mustard block, Diner's dividers), the home's rows sit above the bar with Diner's stripe gone and Editorial's 20 px bottom, and the file browser's list and page footer sit above the bar, legible and unclipped"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C17
    statement: "The owner has run the emulator in both looks and, from the home and from the file browser, tapped each tab and seen it go where it says (Library to the home folder, a second Library tap to its first page, Authors' note, History and back, the settings menu); held each tab and seen nothing happen; tapped the Home tab's bottom-left corner with Gestures' default frontlight binding and seen the bar win; switched the look from the settings menu with the file browser beneath and seen the bar and list re-laid; toggled night mode in both screens; rotated the file browser and seen the bar follow; and opened History, Favorites and Collections and seen no bar over them"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck (`bin/check`, the `<spec>...` branch, `run_busted ... -- "$@"`); a criterion that
lists several files runs them all. C15 is the lint stage alone. The tests gate's own `bin/check` run covers
the whole suite, the studio included.

C1 to C7, C12 and C14 run on KOReader's LuaJIT under the plugin harness with a real file manager
(`spec/plugin_harness.lua:95-99`), at the unit screen and, where a case needs the device's numbers, at the
Colorsoft (`harness.at_colorsoft`). The harness restores the unwrapped `FileManager.setupLayout` on each load,
so C4 to C6 start from KOReader's function. C2 stubs `LauncherEntries.run`, `SettingsMenu.open` and
`Dispatcher` where a case only needs to see the call. C3 and C12 change three existing cases on purpose (D4):
`gesture_routing_spec.lua:232-254` and `failsafe_spec.lua:510-531` move their corner probes from the
screen's last pixels to just above the bar, still inside the corner eighth; `gesture_routing_spec.lua:303-328`
probes the stats slot's corner (`:319-322`), and its stub heights (`:305-306`) change so that slot still ends
inside the corner eighth above the band rather than dropping; new cases cover the corners inside the bar. `layout_spec.lua:249-257` and `:320-343` change with D7 and the band. C4's look case
drives `menu.lua`'s write through `menu_spec.lua`.

C8, C9 and C11 are emulator captures. C9 binds existing specs whose goldens this feature regenerates on
purpose, which is why it is `introduce`; device-menus' "home goldens unchanged" does not carry over. C10 and
C13 are preserve criteria baselined at `main` `fa0e7dd`; C13's scenario moves its tap above the bar (D4).

C16 and C17 are the human checks: C16 the look at every new and regenerated golden before commit, C17 what
the captures and unit specs stub or can't show (Gestures' real bindings, KOReader's History, Favorites and
Collections, rotation and a look switch with the file browser beneath).
