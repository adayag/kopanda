---
node: F-yaihx9
criteria:
  - id: C1
    statement: "The series and authors logic holds as D3 and D12 to D16 say: a series' next unread is its first book in series order that is not complete, a reading book included, an abandoned one skipped, a path-less one allowed; under way, finished and not started by D3, the N of M count of complete books; under-way series first, then the rest, each by the title order ignoring a leading The, A or An; the series' author is the first author of its first book with one, plus and others when another first author differs; authors by surname key, then lowercase name, then name, a two-author book under both, a book with no author under none; the letter is the key's first ASCII letter uppercased, else #, after Z; one author's books in cover-grid's Series order with each series' next unread marked from the whole series; a page holds the whole rows that fit, at least one, a split letter group repeats its letter on the next page; the page holding a given series or author is found"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/shelf_order_spec.lua" }
    required: true
  - id: C2
    statement: "Both looks declare identical token paths including the shelf block and its type parts, every colour an existing palette role, each value commented with its board line or a lead-by-analogy note and, where the fit tightened it, the board value it replaces; back, forward and download name series and authors in their used_in; the schema gains no key"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/looks_spec.lua", "spec/unit/icons_spec.lua", "spec/unit/schema_spec.lua"] }
    required: true
  - id: C3
    statement: "A series row draws up to three stacked covers with the first in front, the name, the sub-line and the state's chip; a one-series row draws the index, the cover with the download badge when path-less, the title, then the bar full for complete or at the percent, the read-this-one-next note or the not-on-the-Kindle line, and the Finished, Up next or Not downloaded chip, the up-next row filled where the look fills it; an author group draws its letter beside its rows with each count; a one-author tile carries the Up next chip on its cover's foot, in place of the Not downloaded chip when both apply with the badge kept, at the same tile height; a small cover without a cached one is a plain fill; every widget paints in day, night and grey; at the Colorsoft and the Paperwhite in both looks the one-author header, two rows of tiles, the pager and the nav bar fit the screen, and at the Colorsoft the lists hold at least five series rows, three book rows and seven author rows in five groups a page"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/shelf_rows_spec.lua", "spec/unit/library_tiles_spec.lua"] }
    required: true
  - id: C4
    statement: "The Series window's list shows the header with D10's count wording for none, one and many and the static label, a page of series rows in D12's order, the pager with dead arrows at the ends, and the nav bar with no tab lit; one series shows the back control, the author and count aside over the series name, its books in series order as rows, the pager and no tab lit; no series shows the empty note; the window rebuilds on a variant or size change before painting, re-lists on BookMetadataChanged and InvalidateMetadataCache, and sends one KoPandaSettled with screen series and a numeric paint_ms per show"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/series_screen_spec.lua" }
    required: true
  - id: C5
    statement: "The Authors window's list shows the header with D10's count wording and the static label, a page of letter groups in D13's order with each author's book count, the pager and the nav bar with Authors lit; one author shows the back control, the books and finished count over the name, three columns and two rows of book tiles in D16's order with the up-next chip, the pager and Authors lit; no authors shows the empty note; the window rebuilds on a variant or size change, re-lists on the metadata events, and sends one KoPandaSettled with screen authors and a numeric paint_ms per show"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/authors_screen_spec.lua" }
    required: true
  - id: C6
    statement: "On both windows a tap on a series or author row shows its view, on back shows the list at the page holding that series or author, on a downloaded book opens it through filemanagerutil.openFile, on a path-less book or a static label does nothing of the window's own, on a pager arrow pages; swipe west and east page without wrapping, one from the top or bottom edge band reaching the file manager; with keys PgFwd and PgBack page; a hold runs nothing and hit names the series, book, author or empty space under a point; a tap in the bar runs its tab first; a gesture the window does not take reaches the file manager's menu zones and a corner zone bound on the file manager; under the touch lock a tap does nothing"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/shelf_gestures_spec.lua" }
    required: true
  - id: C7
    statement: "After its first paint each window requests extraction for the records of the whole library CoverBrowser has no row for, at the library grid's cover box; an arrival re-reads the arrived records, rebuilds the index and sets the window dirty only when the shown page changes; closing the window cancels its check; after the last of the 30 checks the files that did not arrive are no longer marked asked, so a later request asks for them again, and every other BookCovers behaviour, the featured cover's included, is unchanged"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/shelf_lifecycle_spec.lua", "spec/unit/book_covers_spec.lua", "spec/unit/featured_cover_spec.lua"] }
    required: true
  - id: C8
    statement: "The launcher's Series and Authors entries and the Authors tab from the home, the file browser and the library close what is shown and open their screen's list at its first page, and no note is shown; the Authors tab on an Authors view goes to the list's first page; the Home tab on these windows closes them and shows the home; the Library tab from them shows the library with one KoPanda window up; the book sheet's More by this author shows the book's first author's books, or the Authors list for a book with no author; the windows close with the file manager; a book opened from a series or author view and closed shows that window pre-built at the same view and page in one show, with the closed book's progress as saved after the close, one built for another size or variant dropped and rebuilt, a failed open shown afresh, and a series or author gone by then shown as the list's first page"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/shelf_lifecycle_spec.lua", "spec/unit/launcher_entries_spec.lua", "spec/unit/book_sheet_spec.lua", "spec/unit/nav_bar_spec.lua"] }
    required: true
  - id: C9
    statement: "Both windows fail safe: failing to build when asked to show leaves the file browser up with the home closed; a raising paint or gesture route closes the window onto the file browser; a raising tap action, index build, progress read, cover request or arrival is logged with the page as it was; in every case the file manager stays on top and handles input"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    required: true
  - id: C10
    statement: "The library behaves as cover-grid built it after its chrome moves into library_chrome.lua: every library spec passes with no case changed or weakened, and the library goldens match fresh captures without being regenerated"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/library_screen_spec.lua", "spec/unit/library_gestures_spec.lua", "spec/unit/library_lifecycle_spec.lua", "spec/unit/library_pickers_spec.lua", "spec/unit/library_tiles_spec.lua", "spec/unit/library_order_spec.lua", "spec/emulator/library_golden_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:b05fe55", path: kopanda.koplugin, observed_at: "2026-10-17T03:30:00Z" }
    required: true
  - id: C11
    statement: "Every hook that failed safe before this feature still does, the home's, the nav bar's and the library's included, and every gesture the home routed before still routes the same way"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/failsafe_spec.lua", "spec/unit/gesture_routing_spec.lua", "spec/unit/hold_routing_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:b05fe55", path: kopanda.koplugin, observed_at: "2026-10-17T03:30:00Z" }
    required: true
  - id: C12
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires and every KOReader internal it reads or patches, each entry with a file:line, its extraction entry naming the series and authors screens as askers and the 30-check cap; no KoPanda module name collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:b05fe55", path: kopanda.koplugin, observed_at: "2026-10-17T03:30:00Z" }
    required: true
  - id: C13
    statement: "The committed series-list, series-books, authors-list and author-books goldens in both looks on colorsoft match fresh captures of the spec-built capture library (an under-way, a finished and a not-started series, a reading up-next book, a not-downloaded book in a series, a two-author book, at least three letters, one author's two rows across a series and outside one), each shot on KoPandaSettled with screen series or authors, and each capture's paint_ms is at most 250 ms"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/series_authors_golden_spec.lua" }
    required: true
  - id: C14
    statement: "The home, night, sheet, editor screen, file-browser, probe, swatch and library goldens still match fresh captures, this feature regenerates none of them, and the home's capture still paints within its 250 ms budget"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/night_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua", "spec/emulator/screens_golden_spec.lua", "spec/emulator/nav_golden_spec.lua", "spec/emulator/golden_spec.lua", "spec/emulator/swatch_golden_spec.lua", "spec/emulator/library_golden_spec.lua", "spec/emulator/home_capture_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:b05fe55", path: spec/goldens, observed_at: "2026-10-17T03:30:00Z" }
    required: true
  - id: C15
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C16
    statement: "The owner has opened the eight new goldens and confirms the Diner series list reads as SeriesC.dc.html draws it, one series as SeriesBooksC.dc.html, the authors list as AuthorsC.dc.html and the Editorial one author as AuthorBooksA.dc.html (header, back control, counts, rows or tiles, chips, the up-next mark, the not-downloaded badge, the pager, the nav bar's lit tab or none), and that the undrawn Editorial series list, one series and authors list and the Diner one author read as the same screens in their look"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C17
    statement: "The owner has run both screens on the emulator and on the Kindle with their own library, in both looks: opened Series and Authors from the launcher, the Authors tab and the book sheet's More by this author; opened a series and an author and come back by the back control to the same page; paged by swipe and by the pager; opened a book from one series and from one author, closed it, and landed back where they were; seen rows and covers arrive on a library CoverBrowser had not fully indexed; toggled night mode; and found the first page of each list quick enough to use"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck (`bin/check:153-160`); a criterion that lists several files runs them all. C15 is
the lint stage alone. The tests gate's own `bin/check` run covers the whole suite, the studio included.

C1 to C12 run on KOReader's LuaJIT under the plugin harness with a real file manager
(`spec/plugin_harness.lua`), at the unit screen and, where a case needs the device's numbers, at the Colorsoft
(`harness.at_colorsoft`) and the Paperwhite size. C13 and C14 are emulator captures under a fresh `KO_HOME`;
goldens are regenerated only with `KOPANDA_UPDATE_GOLDENS=1` and each regenerated PNG is opened before commit.

C10, C11, C12 and C14 are preserve criteria captured at `main` `b05fe55`: the same spec files must pass after
the change, with new cases added beside the old and no old case weakened. C10's spec files and the library
golden are `library/cover-grid`'s (F-2nt0fx), a recorded prerequisite of this feature, so they exist on `main`
before this feature's first task starts; C10 holds them as cover-grid left them.

C16 and C17 are the owner's: C16 by eye on the committed PNGs, C17 by hand on the emulator and the Kindle,
pushed through the studio's device push.
