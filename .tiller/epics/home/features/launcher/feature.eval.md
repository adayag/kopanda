---
node: F-ydcqb0
criteria:
  - id: C1
    statement: "schema.lua still loads by a plain dofile with no require and no functions, at version 1; launcher.entries follows featured.pinned, of type launcher, label \"Launcher\", group launcher, with max_entries 6, the kopanda targets library, series, authors, settings and the koreader targets history, favorites, collections, wifi, and the default six in order Library, Series, Authors, History, Wi-Fi, Settings; layout.rows' widgets list ends with launcher and its default is the spec's five rows with a full-width launcher row fourth; the launcher type has a validator the default passes; bin/schema-json still round-trips the schema"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/schema_spec.lua", "spec/unit/schema_json_spec.lua"] }
    required: true
  - id: C2
    statement: "Settings.set accepts, each surviving a reopen, the default, an empty list, one entry of each kind, a folder of three and a plugin entry naming an absent plugin; it refuses, leaving the file byte-identical, seven top-level entries, an unknown kind, a target outside targets, an extra or missing field, an empty label, a non-string action, a relative path or \"/\", a folder in a folder, an empty folder, a list with a hole and a non-table; a stored invalid list reads as the default six without raising; a layout naming launcher is accepted"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/settings_spec.lua" }
    required: true
  - id: C3
    statement: "LauncherEntries: the fixed target tables match the schema's targets; resolve gives ready for a loaded plugin with a registered action, an existing directory, a folder and the kopanda targets, plugin missing for a plugin not loaded or whose action is unregistered, not available for an unregistered action or a raising resolution, folder missing for an absent path or a file, and off with wifi_off for Wi-Fi with the fake Wi-Fi off; with a real file manager under the home, History shows over the home and closes back to it, Wi-Fi reaches NetworkListener:onToggleWifi, an available plugin or action entry sends its event once, Library closes the home and calls onHome, a directory entry closes the home and changes the file chooser to it, and Settings opens SettingsMenu; Series, Authors, a folder and each unavailable cause show an InfoMessage with the spec's text and no timeout, schedule nothing and dispatch nothing; no case writes the settings file"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/launcher_entries_spec.lua" }
    required: true
  - id: C4
    statement: "The launcher widget per look on both profiles' full-width columns: built width equals the column and height equals height(width, ctx); six entries lay out 2×3 in Editorial and 3×2 in Diner with columns and gaps summing to the width, fewer entries fill in order and none makes height 0; Diner's tiles fill mustard, pink, teal, then paper, in day and grey, with outline and hard shadow, and Editorial draws a hairline_light rule per entry; labels are in order, icons tinted ink; off draws wifi_off and an \"off\" suffix in muted; unavailable draws the dashed plugin_missing icon with label and suffix in muted, Editorial's suffix on the label's line and Diner's below it; a long label ends in an ellipsis inside its column; through the real home a tap on each entry runs that entry, a tap in a gap falls through to the home's next step, and a raising run closes the home onto the file browser; stale is true exactly when the drawn Wi-Fi state differs from NetworkMgr:isWifiOn()"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/launcher_widget_spec.lua" }
    required: true
  - id: C5
    statement: "TintedIcon paints a registry icon's ink in the given colour, Color8 or RGB32, with no pixel outside the blend from the ground to that colour and some pixels inked; it frees its mask; an unrenderable file gives a blank widget of its size and a log line"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/tinted_icon_spec.lua" }
    required: true
  - id: C6
    statement: "A shown home refreshes exactly once on NetworkConnected (after the weather) and on NetworkDisconnected when a widget's stale returns true, not at all when it returns false or raises, and leaves both events unconsumed for the other windows; a widget's tap receives the tap's position"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/home_layout_spec.lua" }
    required: true
  - id: C7
    statement: "Both looks declare identical token paths including the launcher block and the launcher_label and launcher_suffix type parts, every new token keeping the look files' value rules, the accents naming palette roles or false, and every type part naming a face and a palette role"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C8
    statement: "The committed home goldens match a fresh capture under the fixture userpatch, each taken on KoPandaSettled with screen \"home\" and no row dropped (no \"doesn't fit the screen\" line in its log): populated with the default six in Diner and Editorial on colorsoft and paperwhite; empty, with Terminal greyed and labelled plugin missing in the sixth place, in Diner and Editorial on colorsoft and paperwhite; and the typographic cover in Diner and Editorial on colorsoft"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_golden_spec.lua" }
    required: true
  - id: C9
    statement: "A freshly built populated home, launcher row included, has paint_ms at most 250 ms on each profile in the emulator on this Mac"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_capture_spec.lua" }
    required: true
  - id: C10
    statement: "In the emulator, closing a fixture book lands on the home with the file manager's paintTo never called before the home's settled signal, the pre-built home shown, and the home's share (onShow to paint) at most 100 ms, now with the launcher row resolving its entries in the pre-build"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/book_close_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:bfb043c", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C11
    statement: "Every hook still fails safe with the launcher row: an error thrown by the home's build, paint, gesture or event handlers is logged, leaves no home on the stack, and leaves the file manager on top and handling input"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:bfb043c", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C12
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line, including those the launcher uses; no KoPanda module path, launcher_entries, tinted_icon and widgets/launcher among them, collides with one in frontend/, common/ or a bundled plugin"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:bfb043c", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C13
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C14
    statement: "The owner has opened all ten committed home goldens and confirms the launcher reads as the canvas boards intend for each look and profile: Editorial's two columns of ruled rows and Diner's three columns of outlined tiles with mustard, pink and teal first, the icons, labels, the Wi-Fi off suffix and the greyed Terminal plugin missing entry, legible and unclipped, with the strip still present under the launcher"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C15
    statement: "The owner has run the home in the emulator in both looks and tapped each default entry: Library reveals the file browser at the home folder, Series and Authors show the coming-with-the-library note and a tap dismisses it, History opens and closes back to the home, Wi-Fi toggles and the tile changes between on and off on its own within a few seconds, Settings opens KoPanda's settings; and, with a folder entry, a directory entry and a missing plugin entry written to the settings file, seen the folder's note, the file browser open at the directory, and the greyed entry's note"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR`
or its default path, after `featured-book` has merged. Ref-only `test` bindings resolve to
`bin/check <spec file>`, which passes spec paths straight to Busted with no luacheck (`bin/check` header,
`run_busted ... -- "$@"`). C1 lists two spec files and so runs both. C13 is the lint stage alone. The tests
gate's own `bin/check` run covers the whole suite.

C1 and C2 extend `schema_spec.lua` and `settings_spec.lua`, as `featured-book` leaves them, with the ninth
key and the `launcher` id. C1 also reruns `schema_json_spec.lua` unchanged, proving the new key's data
survives the studio's JSON dump. C3 to C6 run on KOReader's LuaJIT under the plugin harness, with
`PluginLoader`, `LauncherEntries` and `UIManager:show` stubbed or spied where a case needs it. C3's run
cases use the real file manager and dispatch bridge. C7 is `looks_spec.lua`'s identical-paths invariant over
the new tokens.

C6 names "a widget's tap receives the tap's position" as an observable outcome. The `widget` task settles
whether `featured-book` already provides it or this feature adds it, and the criterion holds either way.

C8 regenerates the eight `home-*` goldens `featured-book` commits, since the default layout gains the
launcher row, and adds the empty pair on the Paperwhite. C8's no-dropped-row clause is the measurement
for Diner's unmeasured height budget. If it cannot pass without changing a token or the default, the
`goldens` task stops for the owner (see that task). C9 is the fresh-build tripwire.

C10 to C12 are preserve criteria baselined at `main` `bfb043c`. That is the latest commit that exists
with `home-layout` merged and the launcher absent. `featured-book`'s own preserve criteria carry the same
three checks across its merge, so launcher only has to keep them green on top of it. C10 now carries the
launcher's resolution in the close path's pre-build. A raising entry run is C4's, through the same
`onGesture` net C11 keeps.

C14 and C15 are the human checks. C14 is the look at goldens before they are committed. C15 covers the
live paths the goldens and unit specs stub or can't show: a real Wi-Fi toggle and its repaint, the notes'
dismissal, and entries other than the defaults.
