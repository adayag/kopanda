---
node: F-sn4px5
criteria:
  - id: C1
    statement: "SchemaMenu.items() lists every schema key exactly once in schema order, the last item of each group but the last carrying separator; items(group) lists only that group's keys, and a group with no keys (date, clock) or no group lists them all; a choice row reads its label · the stored choice's label and opens radio items with the stored value checked, a tap on another writing it through Settings.set once and refreshing a shown home once, a tap on the checked one writing nothing; the boolean row is checked by its value and a tap writes the negation once; the featured row reads Featured book · Most recent with no pin or a pin to a gone file and Featured book · <title> with a pin to a file that is there, its submenu offering Most recent book (which writes false) and the pinned book when it is there; the Layout and Launcher rows close the menu and open edit layout and launcher management on the next tick; a refused write shows a note, is logged and leaves the settings file byte-identical; a raising callback is logged and writes nothing; a key of a type with no builder is left out and logged"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/menu_spec.lua" }
    required: true
  - id: C2
    statement: "SettingsMenu.open(group) shows a one-tab TouchMenu with the appbar.settings icon holding SchemaMenu.items(group), over the home, which a tap outside it and the Back key close, and a raising open shows nothing and is logged; Tools › KoPanda › Settings in the file manager and the reader is a submenu holding the full list; the home's swipe up, the home sheet's KoPanda settings and the launcher's Settings entry open the full list; a hold on the weather, quote or stats slot opens that widget's group and a hold on the date or clock the full list; the book sheet's This widget's settings opens the featured group"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/settings_menu_spec.lua", "spec/unit/entry_points_spec.lua", "spec/unit/gesture_routing_spec.lua", "spec/unit/home_sheet_spec.lua", "spec/unit/book_sheet_spec.lua", "spec/unit/launcher_entries_spec.lua"] }
    required: true
  - id: C3
    statement: "The place search builds the Open-Meteo geocoding URL from a trimmed, encoded query, adding countryCode=US for exactly five digits; it reads a recorded response into candidates named name, admin1 (or name, country), skipping results without a name or numeric coordinates, and reads no results as none; offline it shows a note, fetches nothing and writes nothing; a failed or unreadable request and an empty result each show their note and write nothing; a picked candidate is stored as exactly { name, latitude, longitude } and the location row's text follows it; after a location or units write with a home shown and connected, Weather.fetch runs once before the home's one refresh, and offline only the refresh runs; Weather.get keeps the weather's timeouts and resets them on every path"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/location_search_spec.lua", "spec/unit/menu_spec.lua", "spec/unit/weather_spec.lua"] }
    required: true
  - id: C4
    statement: "Both looks declare identical token paths including the editor block and the nine editor type parts, every new token keeping the look files' value rules; the icon registry holds chevron_up, chevron_down and action, each a stroke-2 file rendering in opaque black ink with a label and used_in; no plugin module but looks.lua, swatch.lua and the look files contains the word palettes"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/looks_spec.lua", "spec/unit/icons_spec.lua", "spec/unit/night_mode_spec.lua"] }
    required: true
  - id: C5
    statement: "The editor frame in each look draws its aside, title and Done in the header over its rule, its body and its foot, in the look's colours (Diner's header band in band with on_band text, Editorial's on paper); Done, the Back key on a device with keys and a Back event close it; holds, swipes and hold_release do nothing; showing calls UIManager:show with full and schedules nothing, closing calls UIManager:close with full; one KoPandaSettled with its screen and a numeric paint_ms follows the first paint; a body too tall keeps what fits and logs once; a raising build, paint, gesture or key handler is logged and leaves no editor on the stack"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/editor_spec.lua" }
    required: true
  - id: C6
    statement: "The row operations move, add a row, add a column (refused at three), change a widget, set a share from 1 to 3, remove a column from a row of two or more and remove a row (refused for the only row), each returning new rows that pass the rows validator and leaving their input unchanged; unused lists the schema's widgets not on the home in schema order; reset gives a copy of the schema default; shares read full, 1/2, 1/3 and 2/3; Layout.overflow counts the rows the placement leaves out, zero exactly when Layout.fits is true, and logs nothing"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/rows_edit_spec.lua", "spec/unit/layout_spec.lua"] }
    required: true
  - id: C7
    statement: "Edit layout opened from the home sheet's Edit layout row, with no note, and from its own open shows a card per stored row with its caption, its columns' labels and shares and its arrows, the first row's up and the last row's down greyed; a tap selects a row and reveals Add column, Change widget, Width and Remove column (on rows of two or more) and Remove row; each change writes layout.rows once, refreshes a shown home once and repaints the screen once; a change that leaves out more home rows than before shows That won't fit on the home and leaves the settings file byte-identical, as do removing the only row and a refused write; the widget pickers list only unused widgets; Reset writes the schema default; Done closes the screen onto the home"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/edit_layout_spec.lua", "spec/unit/home_sheet_spec.lua"] }
    required: true
  - id: C8
    statement: "The launcher list operations move an entry within its list and remove one, removing a folder's only entry removes the folder; add puts an entry at the end of a folder's list, at the end of a top level under six, at the end of the first top-level folder of a full top level, and with six and no folder makes the sixth and the new entry a folder labelled More in slot six; every result passes the launcher validator and no input is changed"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/entries_edit_spec.lua" }
    required: true
  - id: C9
    statement: "Launcher management shows N of 6 on the home screen, a row per top-level entry with its resolved icon, label and kind line (KoPanda · library, Folder · 3 entries ›, an unavailable entry greyed with its suffix), arrows greyed at the ends and remove; arrows and remove write launcher.entries once and refresh a shown home once, removing a folder only after its confirmation; a tap on a folder's row opens its own list headed Folder · N, whose adds go into that folder and whose Done returns to the top level; a full list refuses another entry with its note and writes nothing; a hold on the launcher widget opens the top level; the folder sheet shows Hold to edit at its header's right and a hold in it opens that folder's list; a sheet without a hold still ignores holds"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/launcher_manage_spec.lua", "spec/unit/launcher_widget_spec.lua", "spec/unit/folder_sheet_spec.lua", "spec/unit/sheet_spec.lua"] }
    required: true
  - id: C10
    statement: "Adding an entry offers KoPanda screen, KOReader screen, Folder on disk, Action and Plugin; the screen pickers list the schema's targets and add { kind, target }; Folder on disk opens a folders-only PathChooser and adds { kind = directory, path, label } with the folder's name as the editable label, refusing /; the action tree is KOReader's Dispatcher:addSubMenu with only its General, Device, Screen and lights and File browser sections, and on close exactly one action ticked true adds { kind = action, action, label, icon = action } with its display name as the editable label, while none, several, or one holding a value add nothing and show their note; Plugin lists only enabled plugins loaded here that are not is_doc_only, KoPanda left out, then the same tree, adding { kind = plugin, plugin, action, label, icon = action }; Cancel and an empty label add nothing"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/entry_picker_spec.lua" }
    required: true
  - id: C11
    statement: "The committed edit-layout-diner, edit-layout-editorial, launcher-diner and launcher-editorial goldens on colorsoft match a fresh capture of the populated home fixture with the screen opened by the scenario (edit layout with row 2 selected, launcher management over the board's six with a Tools folder), each taken on its screen's KoPandaSettled; the four sheet goldens still match"
    polarity: introduce
    binding: { type: test, ref: ["spec/emulator/screens_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua"] }
    required: true
  - id: C12
    statement: "Each of the four screen captures has paint_ms at most 250 ms, from the open to the screen's first paint, in the emulator on this Mac"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/screens_golden_spec.lua" }
    required: true
  - id: C13
    statement: "The schema is unchanged: version 1 with the same nine keys in order, each type validated, and no clock.twenty_four_hour key"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/schema_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/schema.lua"
      captured_at: { kind: git_tree, value: "git:ca26783", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C14
    statement: "Every gesture the home routed before this feature routes the same way: the swipe up to settings, the file manager's menu zones, the consumed page swipe, zones registered on the file manager winning over the home's tap, a tap on a tappable slot running it, a tap elsewhere closing the home, the touch lock, and actions dispatched while the home is up reaching the file manager"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/gesture_routing_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home_gestures.lua"
      captured_at: { kind: git_tree, value: "git:ca26783", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C15
    statement: "Every hook still fails safe, the new ones included: an error thrown by the home's handlers, a sheet's, the settings menu's open or a menu callback, an editor screen's build, paint, gesture or key handler, a picker or the place search is logged, leaves no home, sheet, menu or editor of KoPanda's half shown, and leaves the file manager on top and handling input"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:ca26783", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C16
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line, including TouchMenu's item fields and one-tab use, the menu container pattern, InputDialog, ButtonDialog, ConfirmBox, PathChooser, Dispatcher:addSubMenu and its section order, getDisplayList, PluginLoader's plugin lists, forceRePaint and the geocoding endpoint; no KoPanda module path, menu, location_search, editor, rows_edit, edit_layout, entries_edit, launcher_manage and entry_picker among them, collides with one in frontend/, common/ or a bundled plugin"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:ca26783", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C17
    statement: "Every committed home golden still matches a fresh capture with no row dropped, and this feature regenerates none of them"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/home_golden_spec.lua" }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:ca26783", path: spec/goldens, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C18
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C19
    statement: "The owner has opened the four screen goldens and confirms the Editorial ones read as EditLayout and LauncherManage intend and the Diner ones read as Diner (band header, outlines, tile shadows, mustard selection): header, cards or rows, arrows, boxes with shares, the selected row's buttons, kind lines, Add an entry and the foot, legible and unclipped"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C20
    statement: "The owner has run the emulator in both looks and, from the home's swipe up, the home sheet and Tools › KoPanda › Settings, changed the look, the text size, the units and stats and seen the home follow; unpinned a featured book from the menu; searched a city and a ZIP with the emulator's Wi-Fi on and seen the weather follow, and searched with it off; edited the layout (move, add, width, remove, a refused row, reset); added an entry of each kind, past six into a folder, opened and edited that folder from its row and from its sheet's hold, and removed it; and held a widget without a hold to see its group"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR`
or its default path, after `sheets` has merged (the tweak `split-home-lua` already has, `02ede75`).
Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight to Busted
with no luacheck (`bin/check` header, `run_busted ... -- "$@"`). A criterion that lists several spec files runs
them all. C18 is the lint stage alone. The tests gate's own `bin/check` run covers the whole suite.

C1 to C10 run on KOReader's LuaJIT under the plugin harness with a real file manager under the home,
spying or stubbing `UIManager`, `Dispatcher`, `PluginLoader`, `NetworkMgr` and `socket.http` where a case
needs it. No unit case reaches the network: C3 feeds a recorded geocoding response through a stubbed
`socket.http`, as `weather_spec.lua` stubs the forecast. C1, C7, C8 and C9 write a real settings file
under the scratch `KO_HOME` and compare bytes for the refusals. C2 changes `entry_points_spec.lua`'s
"shows the settings stub from Settings" case, and `sheets`' stub cases in `gesture_routing_spec.lua`,
`home_sheet_spec.lua` and `book_sheet_spec.lua`, to what replaces the stub. C4 reruns `night-mode`'s
`night_mode_spec.lua`, whose scan for the word `palettes` covers the new modules. C10's plugin cases stub
`PluginLoader` rather than read the emulator's own `plugins/`, which holds untracked SimpleUI, Bookshelf
and Solar icon pack folders.

C11 and C12 are the four Colorsoft captures through the screens scenario, C12 their paint tripwire. C11
also reruns `sheets`' sheet goldens, which this feature must not change: the home sheet's rows look the
same, and the folder sheet's new hint has no golden.

C13 to C17 are preserve criteria baselined at `main` `ca26783`, after `split-home-lua` moved the home's
row building into `home_rows.lua` and its gesture order into `home_gestures.lua`; C14's surface is that
gesture order. `sheets` lands between that baseline and this feature, keeping these checks green across
its own merge (`sheets`' C11, C13 to C15), so this feature only has to keep them green on top. C14 is
the existing cases of the spec C2 extends. C15 gains the menu's and the screens' failure cases beside the
home's and the sheets'.

C19 and C20 are the human checks. C19 is the look at the goldens before they are committed. C20 covers
what the goldens and unit specs stub or can't show: KOReader's native menu, keyboard, path chooser and
action tree in use, a live geocoding search, and the home following each change.
