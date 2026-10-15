---
node: F-e8jz6h
criteria:
  - id: C1
    statement: "schema.lua still loads by a plain dofile with no require and no functions, at version 1; featured.pinned follows stats.show, of type path, default false, label \"Featured book\", group featured; layout.rows' widgets list holds featured, and its default is the spec's four rows with a full-width featured row second; the path type has a validator in settings.lua"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/schema_spec.lua" }
    required: true
  - id: C2
    statement: "Settings.set refuses, leaving the file byte-identical, a featured.pinned of true, a number, a table, an empty string, \"/\" and a relative path; it accepts false and an absolute path, both surviving a reopen, and accepts an absolute path to a file that does not exist; a stored invalid value reads as false; a layout naming featured is accepted"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/settings_spec.lua" }
    required: true
  - id: C3
    statement: "FeaturedBook.current(): a pinned path to an existing file wins; a pinned path that is gone falls back to history and leaves the setting unchanged; the history walk takes the first entry whose file exists, skipping vanished files, select_enabled false and the QuickStart guide; no pin and no existing entry gives nil; title, authors (newlines joined by \", \"), percent (floored, nil as 0), status (complete as Finished), pages (pagemap_doc_pages only with pagemap_use_page_labels, then doc_pages, then a non-zero stats.pages) and their fallbacks match the spec; the chapter appears only when featured_chapter_file is the featured book after realpath and the title is non-empty; KoPanda's CloseDocument records the file and TOC title in state.lua before pre-building, and a raising TOC leaves no chapter and still pre-builds; no read calls DocSettings:open or writes the settings file, a sidecar or the history"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/featured_book_spec.lua", "spec/unit/prebuild_spec.lua"] }
    required: true
  - id: C4
    statement: "Against fixture Statistics databases: ReadingStats.seconds_per_page(md5) picks the most recently opened book row for that md5, and equals the plugin's capped average (sum over pages of min(per-page duration sum, max_sec) divided by the page count) with max_sec from the statistics settings or 120 when absent; an unknown md5, a book with no page times, a missing file and the plugin disabled give no rate; the database is opened read-only and a missing file is not created"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/reading_stats_spec.lua" }
    required: true
  - id: C5
    statement: "With BookInfoManager stubbed: a cached cover is drawn fitted and centred in the 2:3 box on paper; extraction is asked, once per file per process and never from build, height or paintTo, exactly when the info is nil, cover_fetched is nil or isCachedCoverInvalid is true, and never for unsupported, ignore_cover or a book with no cover; while extraction runs the widget checks once a second for at most 30 checks and refreshes the home exactly once when the cover arrives; closing the home unschedules the check; once extraction ends no KoPanda task is left in UIManager's queue; with bookinfomanager unrequirable the typographic placeholder is drawn in cover and on_cover and nothing is asked"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/featured_cover_spec.lua" }
    required: true
  - id: C6
    statement: "The featured widget per look at both profiles' widths: cover box size, gap and the 40 % cap in a narrow column; height is box plus cover shadow y; Editorial and Diner text columns carry the spec's parts in their face, size and colour roles, the title capped at two lines with an ellipsis; the caption reads \"62%\" with \"2 h 10 min left\", \"45 min left\", \"1 h left\", \"84 pages left\", \"1 page left\", the percent alone, or \"100%\" with \"Finished\" as the data says; the bar fills to the shown percent with the look's progress tokens and the grey Diner fill is striped; the first-run state shows \"No book yet\", \"Nothing open yet.\", the body line and \"Open the Library\"; a tap opens the existing book through FileManager:openFile, a tap on a vanished book refreshes the home, and a tap on the first-run button closes the home and calls the file manager's onHome"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/featured_widget_spec.lua" }
    required: true
  - id: C7
    statement: "Both looks declare identical token paths including the featured block, the new type parts and the cover and on_cover roles in all three palettes, every new token keeping the look files' value rules, and every type part naming a face role and a palette role"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C8
    statement: "The committed home goldens match a fresh capture under the fixture userpatch, each taken on KoPandaSettled with screen \"home\": populated with the fixture book's real cover, 62 % and a known time left in Diner and Editorial on colorsoft and paperwhite; empty, showing the first-run slot, in Diner and Editorial on colorsoft; and the typographic cover with CoverBrowser disabled in Diner and Editorial on colorsoft"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_golden_spec.lua" }
    required: true
  - id: C9
    statement: "A freshly built populated home, featured row included, has paint_ms at most 250 ms on each profile in the emulator on this Mac"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_capture_spec.lua" }
    required: true
  - id: C10
    statement: "In the emulator, closing a fixture book lands on the home with the file manager's paintTo never called before the home's settled signal, the pre-built home shown, and the home's share (onShow to paint) at most 100 ms, now with the featured row reading the book just closed"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/book_close_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C11
    statement: "Every hook still fails safe with the featured row: an error thrown by the home's build, paint, gesture or event handlers is logged, leaves no home on the stack, and leaves the file manager on top and handling input"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C12
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line, including those the featured book uses; no KoPanda module path collides with one in frontend/, common/ or a bundled plugin"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C13
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C14
    statement: "The owner has opened all eight committed home goldens and confirms the featured row reads as the canvas boards intend for each look and profile: the cover in its frame, the label or chip, title, authors, chapter, progress bar and caption, the first-run slot and the typographic cover, legible and unclipped"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C15
    statement: "The owner has run the home in the emulator, opened a fixture book, read a few pages and closed it, and seen the home feature that book with its real cover, its progress, a time left or pages left, and its chapter; tapped the featured book and seen it open; and, starting from a profile whose cover cache is empty, seen the cover replace the typographic placeholder without touching the screen"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR`
or its default path, after `looks-and-schema` and `home-layout` have merged. Ref-only `test` bindings
resolve to `bin/check <spec file>`, which passes spec paths straight to Busted with no luacheck. C13 is
the lint stage alone. The tests gate's own `bin/check` run covers the whole suite.

C1 and C2 extend `home-layout`'s `schema_spec.lua` and `settings_spec.lua` with the eighth key and the
`featured` id. C3, C5 and C6 run on KOReader's LuaJIT under the plugin harness, with `readhistory`,
`bookinfomanager`, `FileManager` and `UIManager`'s scheduler stubbed where the real ones would need a
document or a subprocess. C4 keeps every SQLite use in `reading_stats_spec.lua`, as `home-layout`'s
`reading-stats` task requires. C7 is `looks_spec.lua`'s identical-paths invariant over the new tokens.

C8 regenerates the six `home-*` goldens `home-layout` commits, since the default layout gains the featured
row, and adds the two typographic-cover goldens. C9 is the fresh-build tripwire.

C10 to C12 are preserve criteria, baselined like `home-layout`'s at `plugin-shell`'s accepted state,
`2c954f4`. C10 now carries the featured row's reads and the chapter recording in the close path.

C14 and C15 are the human checks. C14 is the look at goldens before they are committed. C15 covers the
live paths the goldens and unit specs stub: a real close, a real Statistics flush and a real background
cover extraction.
