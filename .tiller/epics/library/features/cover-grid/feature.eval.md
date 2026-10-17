---
node: F-2nt0fx
criteria:
  - id: C1
    statement: "Books order and filter as D3, D8 and D9 say: folders first by name; Recent by the reading history's time with never-opened books after by title; Title ignoring a leading The, A or An; Author by the first author's surname key then title, no author last; Series by name then index, no index after, no series last; Reading shows reading, Finished complete, All every book, folders under every status; a page is a slice of six; BookIndex.surname keeps the listed particles with the last word"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_order_spec.lua", "spec/unit/book_index_spec.lua"] }
    required: true
  - id: C2
    statement: "The library's memory lives in the runtime state file under one key, library: a folder never picked reads Recent and All; a picked sort or status is stored for that folder alone and read back after the plugin reloads; the folder and page left are stored when the library closes; State.set stores a table value and reports it written, and still reports false for a file that did not take it; the schema gains no key"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_order_spec.lua", "spec/unit/guards_spec.lua", "spec/unit/schema_spec.lua"] }
    required: true
  - id: C3
    statement: "Both looks declare identical token paths including the library block (header, grid, cover, strip, folder, badge, not-downloaded label, pager) and the library type parts, every colour an existing palette role, each value commented with its board line and, where D2 tightened it, the board value it replaces; the registry gains forward and download, back and chevron_down gain library in their used_in, and the studio catalog matches a fresh bin/catalog-json run"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/looks_spec.lua", "spec/unit/icons_spec.lua", "spec/unit/studio_catalog_spec.lua"] }
    required: true
  - id: C4
    statement: "At the Colorsoft and the Paperwhite sizes, in both looks, the header, the grid's top padding, two rows of tiles and their gap, the pager and the nav bar's height fit the screen's height, and a tile's height does not depend on its title's length, its progress or its being a folder or not downloaded"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/library_tiles_spec.lua" }
    required: true
  - id: C5
    statement: "A book tile shows its cached cover or the typographic placeholder in the look's frame, a progress strip only when the book has a percent and is neither new nor complete and an empty slot of the same height otherwise, and its title in one line; a path-less record shows the download badge and the Not downloaded chip on its cover, at Diner's top-right overhang and Editorial's bottom-right inset; a folder tile shows the folder icon, its direct book count, its reading count when not zero, and its name; tiles paint in day, night and grey"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/library_tiles_spec.lua" }
    required: true
  - id: C6
    statement: "The library window draws the header (the count with the look's wording for none, one and many under the status; Library at the root, the back mark and the folder's name inside a sub-folder; the pickers' current labels), three columns and two rows of the page's tiles, the pager with its page label and dead arrows on the first and last page, and the nav bar with Library active; an empty folder shows its note; the window rebuilds on a variant or screen-size change before painting; BookMetadataChanged and InvalidateMetadataCache re-list the folder; after its first paint on top it sends one KoPandaSettled with screen library and a numeric paint_ms per show"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_screen_spec.lua", "spec/unit/nav_bar_spec.lua"] }
    required: true
  - id: C7
    statement: "On the library, a tap on a downloaded book opens it through filemanagerutil.openFile, on a path-less book does nothing, on a folder tile shows that folder, on the title inside a sub-folder goes up one folder, on a pager arrow pages, on a picker opens its sheet; swipe west and east page without wrapping, and one starting in the top or bottom edge band reaches the file manager instead; with keys, PgFwd and PgBack page; a hold runs nothing and Library.hit names the book, the folder or empty space under a point; a tap in the bar runs its tab first; a gesture the library does not take reaches the file manager's menu zones and a corner zone bound on the file manager; under the touch lock a tap does nothing"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/library_gestures_spec.lua" }
    required: true
  - id: C8
    statement: "The launcher's library entry, the Library tab on the home and in the file browser, and the featured widget's first-run button close the home and show the library at the folder and page last left, the root's first page the first time; the Library tab on the library goes to the root's first page; the Home tab on the library closes it and shows the home; the library closes with the file manager; a book opened from the library and closed shows the library pre-built at the same folder, sort, status and page in one show, one built for another size or variant is dropped and rebuilt, and a failed open shows the library afresh; and the pre-built library shows the closed book's progress as saved after the close; a cancelled open-this-file confirm records no return; a book opened from the home closes to the home"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_lifecycle_spec.lua", "spec/unit/launcher_entries_spec.lua", "spec/unit/nav_bar_spec.lua", "spec/unit/fm_nav_spec.lua", "spec/unit/featured_widget_spec.lua"] }
    required: true
  - id: C9
    statement: "After a page shows the library requests covers for that page's records at the cover box's size, an arrival rebuilds the arrived tiles with their re-read records and sets the library dirty without re-sorting, a new page replaces the request, and closing the library cancels its check"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/library_lifecycle_spec.lua" }
    required: true
  - id: C10
    statement: "The sort and status pickers open sheets with the aside stacked above the heading, a second line on each row and the current choice selected (Diner's teal fill, a check at the row's right in both looks); a tap on a row stores the choice for this folder, closes the sheet and shows the folder's first page; a sheet's failure closes the screen it was shown over, the library or the home; every existing sheet builds as before"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_pickers_spec.lua", "spec/unit/sheet_spec.lua"] }
    required: true
  - id: C11
    statement: "The library fails safe: failing to build when asked to show leaves the file browser at that folder with the home closed; a raising paint or gesture route closes the library onto the file browser; a raising tap action, cover request or arrival is logged with the page as it was; a failed state write keeps the choice for the session; in every case the file manager stays on top and handles input"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    required: true
  - id: C12
    statement: "Every hook that failed safe before this feature still does, the home's and the nav bar's included, and every gesture the home routed before still routes the same way"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/failsafe_spec.lua", "spec/unit/gesture_routing_spec.lua", "spec/unit/hold_routing_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:4564444", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C13
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires and every KOReader internal it reads or patches, each entry with a file:line, including filemanagerutil.openFile, ReadHistory.hist, BookMetadataChanged, InvalidateMetadataCache, onShowingReader, the page keys, Menu:onSwipe's directions, the failed-open paths and changeToPath; no KoPanda module name collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:4564444", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C14
    statement: "The committed library-diner and library-editorial goldens on colorsoft and paperwhite, and library-folder and library-sort in both looks on colorsoft, match fresh captures of the spec-built library (a folder tile, three downloaded books, one of them in progress, and one not downloaded), each shot on KoPandaSettled with screen library or sheet, and each capture's paint_ms is at most 250 ms; the two swatch goldens, regenerated with the two new icons, match fresh captures"
    polarity: introduce
    binding: { type: test, ref: ["spec/emulator/library_golden_spec.lua", "spec/emulator/swatch_golden_spec.lua"] }
    required: true
  - id: C15
    statement: "The home, night, sheet, editor screen, file-browser and probe goldens still match fresh captures, this feature regenerates none of them, and the home's capture still paints within its 250 ms budget"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/night_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua", "spec/emulator/screens_golden_spec.lua", "spec/emulator/nav_golden_spec.lua", "spec/emulator/golden_spec.lua", "spec/emulator/home_capture_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:4564444", path: spec/goldens, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C16
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C17
    statement: "The owner has opened every new library golden and the regenerated swatch goldens, and confirms the Diner grid reads as Main.dc.html draws it and the Editorial grid as GridA.dc.html (header, count, pickers, three columns, two rows, the strip under each cover, the folder tile, the not-downloaded badge and label, the pager, the nav bar with Library lit), the sort sheet as SortC.dc.html, the back mark inside a folder legible, and the tightened sizes acceptable"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C18
    statement: "The owner has run the library on the emulator and on the Kindle with their own library, in both looks: opened it from the Library tab, the launcher and the file browser; entered a sub-folder and come back by the title; paged by swipe and by the pager; picked each sort and status, seen them kept per folder after a restart; opened a book, closed it, and landed back at the same page; seen covers arrive on a page without them; toggled night mode; and found the first page of the real library quick enough to use"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck (`bin/check`, the `<spec>...` branch); a criterion that lists several files runs them
all. C16 is the lint stage alone. The tests gate's own `bin/check` run covers the whole suite, the studio
included.

C1 to C13 run on KOReader's LuaJIT under the plugin harness with a real file manager
(`spec/plugin_harness.lua`), at the unit screen and, where a case needs the device's numbers, at the Colorsoft
(`harness.at_colorsoft`) and the Paperwhite size. C14 and C15 are emulator captures under a fresh `KO_HOME`;
goldens are regenerated only with `KOPANDA_UPDATE_GOLDENS=1` and each regenerated PNG is opened before commit.

C12, C13 and C15 are preserve criteria captured at `main` `4564444`: the same spec files must pass after the
change, with new cases added beside the old and no old case weakened. C3's catalog check passes once
`npm run catalog` in `studio/` has regenerated `studio/src/catalog.json`.

C17 and C18 are the owner's: C17 by eye on the committed PNGs, C18 by hand on the emulator and the Kindle,
pushed through the studio's device push.
