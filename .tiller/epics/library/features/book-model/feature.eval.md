---
node: F-alfeze
criteria:
  - id: C1
    statement: "Books.folder(dir) gives { books, folders }, the records of the files directly in dir and a { name, path } per kept sub-folder, each in byte order of name, and Books.all() every book under KOReader's home folder: dot names only with FileChooser.show_hidden on, no folder matching exclude_dirs (.sdr included) or file matching exclude_files, no ._ file, only files DocumentRegistry:hasProvider accepts; an unreadable folder is skipped and logged; a folder linked into itself is visited once and each id listed once; a missing root lists no local books, logged; neither asks for an extraction or writes a sidecar, the settings file or CoverBrowser's database, and neither calls DocSettings:open itself; KOReader's hasProvider may, for a suffix with no provider that has a sidecar, as the file browser's own filter does"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/books_spec.lua" }
    required: true
  - id: C2
    statement: "A record is { id, source, path, title, authors, series, series_index, cover } with id \"file:\" plus the file's realpath and source \"file\"; title, authors, series and series_index come from one getBookInfo(path, false) call, else the sidecar's doc_props title and authors, else the file name without its extension and no authors; authors split on newlines, each trimmed with white space runs made one space and empty names dropped; cover is none for CoverBrowser disabled, unsupported, ignore_cover or a fetched book with no cover, missing for no row or an unfetched cover, cached for has_cover; a raising CoverBrowser or sidecar read is logged and only that source reads as absent; Books.for_path gives the record for any file and nil for a path that is not a file; Books.get finds a record by its id"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/books_spec.lua" }
    required: true
  - id: C3
    statement: "Books.progress reads the sidecar light on each call: status new with no sidecar, the summary's reading, abandoned or complete, and reading for any other value or an unreadable sidecar; percent_finished clamped to 0 to 1 or nil when not a number; pages from pagemap_doc_pages only with page labels on, else doc_pages, else a non-zero stats.pages; md5 the partial_md5_checksum; a book read again after its sidecar changes gives the new values"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/books_spec.lua" }
    required: true
  - id: C4
    statement: "With a source added through Books.add_source, its path-less records appear in Books.all() and in the root's Books.folder after the local books and in no sub-folder; Books.get finds them; Books.for_path never gives them; BookIndex lists them under their authors and series; BookCovers.read draws their cover from the source and BookCovers.request never asks CoverBrowser for them; Books.progress gives the source's progress or status new; a source whose books, cover or progress raises is logged and leaves the local books listed; a record without an id or title is dropped and logged"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/books_source_spec.lua" }
    required: true
  - id: C5
    statement: "BookIndex.authors gives one entry per distinct name as written, a two-author book in both entries and counted in each, a book with no authors in none; BookIndex.series gives one entry per series with its books by ascending series_index, fractional indexes included, books with no index after those with one, ties by title; entries by lowercase name, then name; books ties by id; a records list that changes between two calls gives two indexes that follow it, with nothing kept between calls"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/book_index_spec.lua" }
    required: true
  - id: C6
    statement: "With bookinfomanager stubbed: BookCovers.read gives a usable cached bitmap and frees an unusable one; BookCovers.request asks one extractInBackground for every wanted file of a batch with the specs given, never for a file already asked in this process, a path-less record or a cover that fits; checks once a second while extraction runs for at most 30 checks; calls on_arrival once per check that finds arrivals, with exactly those records; reads each still-pending file with its cover at the last check, freeing the bitmap; stops at the next check once alive() is false; a new request drops the earlier check and lets its unarrived files be asked again; cancel leaves nothing scheduled; a failed fork schedules nothing and its files stay asked; when checking ends no KoPanda task is left in UIManager's queue"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/book_covers_spec.lua" }
    required: true
  - id: C7
    statement: "Against the real CoverBrowser loaded in the harness, with extractBookInfo run on the three fixture books: before extraction each record has its file name as title and cover missing; after it, Books.all() gives three records with the manifest's titles and authors and cover cached, and BookCovers.read gives a bitmap no larger than the box; after setBookInfoProperties writes two newline-separated authors, a series and a fractional index to one row, its record and BookIndex follow; after deleteBookInfo its cover reads missing again"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/books_coverbrowser_spec.lua" }
    required: true
  - id: C8
    statement: "The featured book reads through the model with its behaviour unchanged: the featured book, cover, widget, book sheet, prebuild, menu and failsafe specs pass with no assertion changed, among them one getBookInfo call per FeaturedBook.current(), no DocSettings:open, one extraction ask per file, at most 30 checks and one home refresh on arrival"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/featured_book_spec.lua", "spec/unit/featured_cover_spec.lua", "spec/unit/featured_widget_spec.lua", "spec/unit/book_sheet_spec.lua", "spec/unit/prebuild_spec.lua", "spec/unit/menu_spec.lua", "spec/unit/failsafe_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:52f7ad0", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C9
    statement: "The home and sheet goldens still match fresh captures and this feature regenerates none of them; a freshly built populated home paints in at most 250 ms on each profile, and after a book close the home's share is at most 100 ms with the featured row reading the book just closed"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua", "spec/emulator/home_capture_spec.lua", "spec/emulator/book_close_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:52f7ad0", path: spec/goldens, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C10
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires and every KOReader internal it reads, each with a file:line; no KoPanda module name, books, book_index and book_covers among them, collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:52f7ad0", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C11
    statement: "The schema is unchanged: the same version and keys in order, each type validated, and no library key"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/schema_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/schema.lua"
      captured_at: { kind: git_tree, value: "git:52f7ad0", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
  - id: C12
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C13
    statement: "The owner has run the home in the emulator from a profile whose cover cache is empty and seen the featured cover replace the typographic placeholder without touching the screen; opened a fixture book, read a few pages, closed it, and seen the home feature it with its cover, progress and time left or pages left; and held the featured book and seen its sheet's cover and details as before"
    polarity: preserve
    binding: { type: manual }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:52f7ad0", path: kopanda.koplugin, observed_at: "2026-10-16T00:00:00Z" }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck (`bin/check`, the `<spec>...` branch); a criterion that lists several files runs
them all. C12 is the lint stage alone. The tests gate's own `bin/check` run covers the whole suite, the
studio included.

Every criterion is satisfiable by this feature alone. Its one prerequisite, `home/featured-book` (F-e8jz6h),
is done. Nothing here draws a new screen: the grid, the Series and Authors screens, the not-downloaded badge
and the context menu's actions are `library/cover-grid` (F-2nt0fx), `library/series-and-authors` (F-yaihx9)
and `library/context-menu` (F-l0kw8m).

C1 to C6 run on KOReader's LuaJIT under the plugin harness, on a scratch library under the data directory
with `home_dir` pointed at it and `document_metadata_folder = "dir"`, so no sidecar lands in
`spec/fixtures/library/`. CoverBrowser is stubbed in `package.loaded` where a case needs a row, and
unrequirable where it needs CoverBrowser off, as `featured_book_spec.lua` does. C4's source is a table the
spec registers and removes. C6 records `UIManager.scheduleIn` and `unschedule`, as `featured_cover_spec.lua`
does. C7 is the check that the stubs match CoverBrowser: the real `bookinfomanager`, its real database under
the scratch `KO_HOME`, and the three fixture EPUBs.

C8 to C11 are preserve criteria baselined at `main` `52f7ad0`, the tree this plan was written against. C8's
specs are the featured book's own contract (`home/featured-book` C3, C5, C6 and the sheet's); "no assertion
changed" is checked in review against the diff, where a changed `assert` in those files would show. C9's
comparison target is the goldens on `main` when this feature's first task starts: `nav-bar/nav-bar`
(F-78e5ij), which is ready, regenerates the home goldens if it merges first, and that is not this feature's
change. The golden specs compare against whatever goldens are committed, so a regenerated golden would show
as a file in this feature's diff. C10's specs check requires, `package.loaded` names, `G_reader_settings`
and `G_defaults` keys and `_`-prefixed internals (`spec/unit/hooks_doc_spec.lua:20-57`); that HOOKS.md carries the entries
the Specification's "HOOKS.md" section lists (the home folder, the file chooser's filters, `hasProvider`,
the `bookinfo` series columns and authors separator, the series split, `hasSidecarFile` and `BookList`'s
status rules) is checked in review. C11 holds the no-new-key rule.

C13 is the human check of the live paths the unit specs stub: a real background extraction in a forked
process, a real close and a real sheet.
