---
node: F-l0kw8m
criteria:
  - id: C1
    statement: "Hidden folders live in the runtime state file under the library key's hidden sub-key, by realpath, and nowhere in the schema: a hidden folder reads back after the plugin reloads, an unhidden one is gone from the file, a malformed hidden value is dropped and logged while the folders and at parts survive every write, a hide or unhide whose write fails holds for the session; the library's grid leaves out a hidden sub-folder's tile while Books.folder and Books.all still list its books; the schema gains no key"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_order_spec.lua", "spec/unit/library_screen_spec.lua", "spec/unit/schema_spec.lua"] }
    required: true
  - id: C2
    statement: "The registry holds the seven board icons home_plus, trash, folder_open, eye_off, sort, filter and refresh, each a stroke file inked in black, 38 in all; both looks declare identical token paths including the library_folder and library_empty bands, the folder box, the sort and show chips and the sheet_chip_plain part, every colour an existing palette role, each value commented with its board line or a lead-by-analogy note; the swatch draws every icon with every palette panel's content inside its panel at the Colorsoft and the Paperwhite; the studio's catalog matches a fresh bin/catalog-json run"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/icons_spec.lua", "spec/unit/looks_spec.lua", "spec/unit/swatch_spec.lua", "spec/unit/studio_catalog_spec.lua"] }
    required: true
  - id: C3
    statement: "The book sheet over a library record shows the cover, the title, the authors joined with commas and the meta line (the percent when known or 100 for a finished book, then when it was last opened, either left out when unknown, no chapter), then Open, Book details, Read status with KOReader's label, More by this author, Add to the home and Delete in that order with their icons; Open runs the window's own open of that record, Book details shows KOReader's details for its path, a status written from the sub-sheet re-lists the window, More by this author shows the record's first author's books or the Authors list for a record with no author; a record whose file went since the build re-lists the window and shows no sheet; a record with no path shows the meta Not downloaded and greys Open, Book details, Read status, Add to the home and Delete, each running nothing on a tap, while More by this author still works"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/book_sheet_spec.lua" }
    required: true
  - id: C4
    statement: "Add to the home stores the book's realpath as featured.pinned and leaves the library shown; for the book featured.pinned already names the row reads On the home, ticked, and a tap writes nothing; a refused write is logged and changes nothing. Delete shows KOReader's delete confirm for the book's path through FileManager:showDeleteFileDialog, a confirmed delete removes the file and re-lists the window at its page clamped, a cancel or a failed delete re-lists nothing, and a deleted pinned book leaves the home featuring the last book opened"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/book_sheet_spec.lua" }
    required: true
  - id: C5
    statement: "The folder sheet heads with the folder icon in its box, the folder's name and the meta of the books directly in it with the reading and finished counts each shown only when not zero; Open shows that folder at its remembered page; Set as library root shows KOReader's Set as HOME confirm for that folder through FileManager:setHome, a confirm leaves home_dir set to it and the library at the new root's first page recorded as where it was left, a cancel changes nothing; Hide stores the folder as hidden and re-lists the library without its tile"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/library_sheets_spec.lua" }
    required: true
  - id: C6
    statement: "The empty-space sheet heads with this folder above the folder's name, Library at the root, and the grid header's count in each look's wording; Sort and Show carry the folder's current choices and open cover-grid's Sort and Show sheets; Refresh covers deletes CoverBrowser's row and BookList's cached entry for every book directly in the folder, forgets them as asked, re-lists the library and asks CoverBrowser to extract them in one request at the grid's cover box, and is greyed when CoverBrowser is disabled; the Hidden folders row shows only when a sub-folder of this folder is hidden and opens a sheet of those folders by name whose tap unhides one and re-lists the library with its tile; every other BookCovers behaviour is unchanged"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_sheets_spec.lua", "spec/unit/book_covers_spec.lua"] }
    required: true
  - id: C7
    statement: "On the library a hold on a book tile opens the book sheet, on a folder tile the folder sheet, and anywhere else outside the nav bar's band the empty-space sheet, each shown over the library as the screen beneath with paint_ms from the hold; on the one-series list and the one-author grid a hold on a book opens the book sheet over that window, and a hold on a series row, an author row or empty space runs nothing; a hold in the nav bar's band runs nothing, and a hold corner bound on the file manager still wins; each sheet sends one KoPandaSettled with screen sheet and its name book, library_folder, library_empty or library_hidden"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/library_gestures_spec.lua", "spec/unit/shelf_gestures_spec.lua", "spec/unit/library_sheets_spec.lua"] }
    required: true
  - id: C8
    statement: "The holds and sheets fail safe: a sheet that fails to build or paint closes the window it was shown over onto the file browser and not the home; a raising row (a pin, a delete, a hide, a refresh, a root change, a status write) is logged with the window as it was; a raising hit or hold dispatch is logged and the hold consumed; in every case the file manager stays on top and handles input"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    required: true
  - id: C9
    statement: "The home's book sheet renders and behaves as library/series-and-authors (F-yaihx9) leaves it on main: its header, meta line with the chapter, rows Open, Book details, Read status, More by this author, Feature a different book and This widget's settings, its read status sub-sheet refreshing the home and its picker pass their spec cases as they stand when this feature's first task starts, none weakened, and the sheet-book and sheet-home goldens in both looks match fresh captures without being regenerated"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/book_sheet_spec.lua", "spec/unit/sheet_spec.lua", "spec/unit/home_sheet_spec.lua", "spec/emulator/sheet_golden_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/book_sheet.lua"
      captured_at: { kind: git_tree, value: "git:5d8a955", path: kopanda.koplugin, observed_at: "2026-10-17T04:03:00Z" }
    required: true
  - id: C10
    statement: "Every hook that failed safe before this feature still does, the home's, the nav bar's, the library's and the shelf screens' included, and every gesture the home, the library and the shelf screens routed before still routes the same way, holds aside, as library/cover-grid (F-2nt0fx) and library/series-and-authors (F-yaihx9) leave them: their spec cases pass as they stand when this feature's first task starts, none weakened"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/failsafe_spec.lua", "spec/unit/gesture_routing_spec.lua", "spec/unit/hold_routing_spec.lua", "spec/unit/library_gestures_spec.lua", "spec/unit/shelf_gestures_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:5d8a955", path: kopanda.koplugin, observed_at: "2026-10-17T04:03:00Z" }
    required: true
  - id: C11
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires or reads from package.loaded, every G_reader_settings and G_defaults key it reads and every underscore-prefixed field or method it touches, and every entry of its Plugin section cites a file:line; no KoPanda module name collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load, library_sheets included"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:5d8a955", path: kopanda.koplugin, observed_at: "2026-10-17T04:03:00Z" }
    required: true
  - id: C12
    statement: "The committed library-hold-book, library-hold-remote, library-hold-folder and library-hold-empty goldens in both looks on colorsoft match fresh captures over cover-grid's capture library, each shot on KoPandaSettled with screen sheet and the sheet's name, and each capture's paint_ms is at most 250 ms"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/library_hold_golden_spec.lua" }
    required: true
  - id: C13
    statement: "The regenerated swatch goldens on colorsoft and paperwhite match fresh captures, drawing all 38 registry icons"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/swatch_golden_spec.lua" }
    required: true
  - id: C14
    statement: "The home, night, sheet, editor screen, file-browser, probe, library and series and authors goldens, as library/cover-grid (F-2nt0fx) and library/series-and-authors (F-yaihx9) leave them, still match fresh captures, this feature regenerates none of them, and the home's capture still paints within its 250 ms budget"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/night_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua", "spec/emulator/screens_golden_spec.lua", "spec/emulator/nav_golden_spec.lua", "spec/emulator/golden_spec.lua", "spec/emulator/library_golden_spec.lua", "spec/emulator/series_authors_golden_spec.lua", "spec/emulator/home_capture_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:5d8a955", path: spec/goldens, observed_at: "2026-10-17T04:03:00Z" }
    required: true
  - id: C15
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C16
    statement: "The owner has opened the eight new goldens and the regenerated swatch goldens, and confirms the Diner book sheet reads as HoldBookC.dc.html draws it and the Editorial one as HoldBookA.dc.html (header, cover, meta, rows, icons, chips), the Diner folder sheet as HoldFolderC.dc.html and the empty-space sheet as HoldEmptyC.dc.html (band, header, sub-lines, chips), that the not-downloaded book's greyed rows and the undrawn Editorial folder and empty-space sheets read as the same sheets in their look, that the undrawn hidden-folders sub-sheet, seen on the emulator in both looks, reads as the empty-space sheet's own, and that the seven new icons read as the boards draw them"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C17
    statement: "The owner has run the holds on the emulator and on the Kindle with their own library, in both looks: opened each sheet from a book, a folder tile and empty space; opened a book, its details and its read status from the sheet; opened More by this author; added a book to the home and seen it featured; deleted a copied book through KOReader's confirm and seen it leave the grid; hidden a folder, seen its books still in Series and Authors, and unhidden it from Hidden folders; set a folder as the library root and seen the Library tab open there; refreshed a folder's covers; held a book on one series and on one author; toggled night mode; and found each sheet quick enough to use"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck (`bin/check:153-160`) and refuses a path that is not a file; a criterion that lists
several files runs them all. C15 is the lint stage alone. The tests gate's own `bin/check` run covers the
whole suite, the studio included.

C1 to C11 run on KOReader's LuaJIT under the plugin harness with a real file manager
(`spec/plugin_harness.lua`), at the unit screen and, where a case needs the device's numbers, at the Colorsoft
(`harness.at_colorsoft`) and the Paperwhite size. `spec/unit/library_sheets_spec.lua` is new (the
`book-sheet` task creates it); `library_screen_spec.lua`, `library_gestures_spec.lua` and
`library_golden_spec.lua` are `library/cover-grid`'s (F-2nt0fx), and `shelf_gestures_spec.lua` and
`series_authors_golden_spec.lua` are `library/series-and-authors`' (F-yaihx9), both recorded prerequisites, so
they exist on `main` before this feature's first task that names them starts. C12 to C14 are emulator captures
under a fresh `KO_HOME`; goldens are regenerated only with `KOPANDA_UPDATE_GOLDENS=1` and each regenerated PNG
is opened before commit.

C9, C10, C11 and C14 are preserve criteria whose `captured_at` is `main` `5d8a955`, the last commit this spec
can name. C9, C10 and C14 hold their surfaces as cover-grid and series-and-authors leave them on `main` when
this feature's first task starts (C9's `book_sheet_spec.lua` More by this author case, which
series-and-authors' `routing` changes on purpose, included): the same spec files must pass after the change,
with new cases added beside the old and no old case weakened. C11's `hooks_doc_spec.lua` finds modules,
settings keys and underscore-prefixed internals, not named functions (`spec/unit/hooks_doc_spec.lua:21-58`),
so the `HOOKS.md` entries the tasks add for `showDeleteFileDialog` and `deleteFile` (`book-actions`),
`setHome` and `home_dir` (`folder-sheet`), and `deleteBookInfo` and `resetBookInfoCache` (`space-sheet`) are
each task's review item, each with its file:line.

C16 and C17 are the owner's: C16 by eye on the committed PNGs and, for the hidden-folders sub-sheet, on the
emulator; C17 by hand on the emulator and the Kindle, pushed through the studio's device push.
