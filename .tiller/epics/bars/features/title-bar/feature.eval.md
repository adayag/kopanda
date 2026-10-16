---
node: F-iwl43d
criteria:
  - id: C1
    statement: "Both looks declare identical token paths including the title_bar block (fill, side, top and bottom padding, edge, line gap, picker gap, sort and status fills, picker outline and padding, icon size and colour, count_on_shelf) and the title_bar_count, title_bar_title, title_bar_sort and title_bar_status type parts, with the boards' values (Editorial Library:17-27, Diner LibraryC:19-27), every colour an existing palette role and every face one the look ships"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C2
    statement: "The icon registry has a plus entry used in the title bar, a Lucide stroke-2 file in opaque black ink, and check is used in the title bar too; the studio's catalog lists the new registry"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/icons_spec.lua", "spec/unit/studio_catalog_spec.lua"] }
    required: true
  - id: C3
    statement: "KoTitleBar is a TitleBar subclass whose getHeight, dimen.h and getSize().h are one height per look, edge, top padding, the taller of the count-over-title column and the picker row, and bottom padding, the same at small, medium and large text sizes; its title is Library at the home folder and the folder's own name elsewhere; its count is the chooser's files after the status filter, folders and the go-up entry left out, worded 'N books', '1 book' or 'No books' and, in Diner, with 'on the shelf'; its sort label maps every BookList collate id to its short label (access to Recent) and any other id to its own text; its status label is All, one status's string, or the first status and +n; it re-reads all of these at paint and rebuilds only when one changed; it paints Editorial's 1 px ink edge under paper and Diner's mustard band over a 4 px ink edge with the sort chip on paper and the status chip on pink, each 2 px outlined, from Looks.palette in day, night and grey; a tap in the sort, status or plus area runs on_sort, on_status or the right icon's tap callback once and is consumed; a tap on the title or count is not consumed; a hold there runs the kept left icon hold callback once and is consumed with its hold_release; a hold on a picker or the plus is not; setRightIcon check shows the check icon and plus the plus; setTitle and setSubTitle keep no text; setLeftIcon does nothing; both layout generators return empty; left_button.image.dimen is the title column's box, from the bar's top to the title line's bottom, after a paint; a state read that raises on the first paint leaves the fill and edge painted"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/title_bar_spec.lua" }
    required: true
  - id: C4
    statement: "With KoPanda loaded in a file manager, fm.title_bar and the chooser's title_bar are one KoTitleBar and the chooser's rows fill its height less that bar's height and its page footer; after changeToPath to a subfolder the bar shows the subfolder's name and count, after onHome Library; after onSetSortBy access its sort label is Recent, after a status filter its status label and count follow; a tap on the sort or status picker shows a one-tab TouchMenu whose items are KOReader's sort or book-status items, and picking one changes the chooser's sort or filter and the bar's label; a tap on the plus shows KOReader's plus dialog; a hold on the title shows KOReader's folder menu, whose anchor is the title column's box, below it; select mode shows the check icon and leaving it the plus; reinit, a rotation and a look change through the settings menu each leave a KoTitleBar in the new look and width; a refused shell leaves KOReader's TitleBar"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/fm_title_bar_spec.lua" }
    required: true
  - id: C5
    statement: "Upgrade tripwire: TitleBar has no new field of its own in the emulator's KOReader; during the unwrapped FileManager.setupLayout the first TitleBar.new call precedes any FileChooser:new and carries left_icon home, right_icon plus, a right icon tap callback and a left icon hold callback; afterwards fm.title_bar is that bar and fm.file_chooser.title_bar the same table, and the chooser's available height is its inner height less the bar's getHeight and its page footer"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/fm_title_bar_spec.lua" }
    required: true
  - id: C6
    statement: "Every other title bar stays KOReader's: after KoPanda's layout TitleBar has no new field of its own; a Menu with a title, a PathChooser, History's and Collections' lists built afterwards, and a Menu built in a reader each carry a KOReader TitleBar"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/fm_title_bar_spec.lua" }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:6443f03", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C7
    statement: "Every hook still fails safe, the title bar's included: a raising look leaves KOReader's own layout, its TitleBar included; a raising KoTitleBar build gives the file manager KOReader's own TitleBar with its Home and plus buttons; the original setupLayout's own error is re-raised unchanged with TitleBar.new and FileChooser.height put back; a raising state read, paint, tap or hold handling or picker menu is logged and the tap or hold is left unconsumed; in every case the file manager stays on top and handles input, and an error on the home closes it onto the file browser as before"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:6443f03", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C8
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires and every KOReader internal it reads or patches, each entry with a file:line, including TitleBar's class and its missing new, the file manager's bar construction and callbacks, every consumer of the bar's interface, the item table and is_file, the status filter, getCollate, the refresh path and PathChanged's order, the collates and status strings, the two menu tables and getHomeFolder; no KoPanda module name, title_bar among them, collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:6443f03", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C9
    statement: "The filebrowser-diner and filebrowser-editorial goldens on colorsoft and paperwhite, regenerated with the title bar, match a fresh capture of the populated fixture's home folder with the bar reading Library, 3 books, Name and All, each shot on KoPandaSettled with screen file_browser, and each capture's paint_ms is at most 250 ms"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/nav_golden_spec.lua" }
    required: true
  - id: C10
    statement: "The swatch screen fits every registry icon, plus included, and its two goldens, regenerated for the plus cell, match fresh captures"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/swatch_spec.lua", "spec/emulator/swatch_golden_spec.lua"] }
    required: true
  - id: C11
    statement: "The home, night, sheet, editor screen and probe goldens still match fresh captures, and this feature regenerates none of them"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/night_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua", "spec/emulator/screens_golden_spec.lua", "spec/emulator/golden_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:6443f03", path: spec/goldens, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C12
    statement: "The schema is unchanged: version 1 with the same nine keys in order, each type validated, and no title bar key"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/schema_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/schema.lua"
      captured_at: { kind: git_tree, value: "git:6443f03", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C13
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C14
    statement: "The owner has opened the four file-browser goldens and the two swatch goldens and confirms the Editorial header reads as Library.dc.html draws it (count over a serif title, plain small-caps pickers with their down marks, the 1 px ink rule) and the Diner header as LibraryC.dc.html draws it (the mustard band, the Caveat count, the heavy title, the paper and pink chips, the 4 px ink edge), the plus icon sits at the header's right, nothing is clipped, and the list sits between the header and the nav bar"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C15
    statement: "The owner has run the emulator in both looks and, in the file browser, opened a subfolder and seen its name and count, gone home and seen Library; changed the sort from the sort picker and the filter from the status picker and seen the labels and the count follow; tapped the plus and seen KOReader's plus menu; held the title, saw the folder menu under it and opened a folder from it; entered select mode and seen the check, left it; tapped the title and seen KOReader's menu as before; toggled night mode and seen the header's night palette; rotated and seen the header follow; switched the look from the settings menu with the file browser beneath; and opened History, Collections, Favorites and a book's table of contents and seen KOReader's own title bars there"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck (`bin/check`, the `<spec>...` branch); a criterion that lists several files runs
them all. C13 is the lint stage alone. The tests gate's own `bin/check` run covers the whole suite, the
studio included.

Every criterion is satisfiable by this feature once `nav-bar/nav-bar` (F-78e5ij), its recorded prerequisite,
is done: C4, C5, C7 and C9 run through nav-bar's `FmNav` wrapper, its harness restore of `setupLayout` and
its file-browser scenario and `nav_golden_spec.lua`, which this feature extends rather than adds.

C1 to C8, C10's unit half and C12 run on KOReader's LuaJIT under the plugin harness with a real file manager
(`spec/plugin_harness.lua:95-99`), at the unit screen and, where a case needs the device's numbers, at the
Colorsoft (`harness.at_colorsoft`). C3 builds the bar against a real chooser on a scratch folder and stubs
`on_sort`, `on_status` and the plus callback where a case only needs to see the call. C4's look case drives
`menu.lua`'s write through nav-bar's `FmNav.relayout()`. C2's catalog half diffs `studio/src/catalog.json`,
regenerated with `npm run catalog`, against a fresh `bin/catalog-json`.

C9 and C10 bind emulator specs whose goldens this feature regenerates on purpose, which is why they are
`introduce`. C9 also carries nav-bar's 250 ms file-browser budget forward with the bar in it. C11 is the
goldens nothing here draws on. Its comparison target is the goldens on `main` when this feature's first
task starts, after nav-bar's merge, which regenerates the home, night and sheet goldens (nav-bar
feature.md:330-333); the `6443f03` pin records the tree at plan time. The golden specs compare against
whatever goldens are committed, so a change to one would show as a regenerated file in this feature's diff;
this feature regenerates only the `filebrowser-*` goldens and the two swatch goldens (D10).

The preserve criteria are baselined at `main` `6443f03`, before nav-bar lands; their checks run against the
tree nav-bar leaves, which this feature starts from.

C14 and C15 are the human checks: C14 the look at every regenerated golden before commit, C15 what the unit
specs stub or the captures can't show (KOReader's menus and dialogs, select mode, night mode, rotation, a look
switch with the file browser beneath, and the title bars KOReader keeps).
