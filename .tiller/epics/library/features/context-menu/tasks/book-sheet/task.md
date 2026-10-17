# The book sheet over a library record, opened by a hold on a book in the library and on the one-series and one-author screens

## Approach

The book sheet generalised over a record, and the hold that opens it. Starts once `library/cover-grid`
(F-2nt0fx) and `library/series-and-authors` (F-yaihx9) have merged to `main`: read `library.lua`,
`library_chrome.lua`, `library_pickers.lua`, `series_screen.lua`, `authors_screen.lua`, `sheet.lua` and
`book_sheet.lua` as merged, since their names and lines exist only then. Repo lines below are `main` at
`5d8a955`; KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Feature sections "Holds", "The book
sheet", decisions D2, D3, D5, D13 to D16; criteria C3, C7, C9.

1. **`book_sheet.lua` over a record.** Split what the home's sheet builds into parts both entries use, leaving
   `BookSheet.open(ctx, built, opts)` with today's rows, order and behaviour (`book_sheet.lua:198-260`):
   - the header: title, authors (a record's list joined with ", ", `featured_book.lua:88-90`; the featured
     book's string as is), the meta, and the cover. The home's cover stays `FeaturedCover.build(book, …)`
     (`:257-258`); a record's is `FeaturedCover.framed(record, w, h, ctx, frame)` with the frame `build`
     passes (`featured_cover.lua:242-250`), factored so both read the same frame;
   - the meta: the home's stays `Featured.shown_percent(book)`, the chapter and opened (`book_sheet.lua:66-78`).
     A record's: from `Books.progress(record)` (`books.lua:361-376`), the percent when it has one or its
     status is `complete` (`Featured.shown_percent(progress)`, as `library_tiles.lua:257` calls it), then
     `opened(record.path, now)` (`book_sheet.lua:49-62`); each part left out when unknown, `meta = nil` when
     both are (the header skips a nil line, `sheet.lua:146-153`); "Not downloaded" for a record with no
     `path` (D2);
   - the rows Open, Book details, Read status and More by this author, each built from a callback set the
     caller hands in: `open()`, `refresh()` (the status sub-sheet's callback, today `ctx.home:refresh()`,
     `:100-102`) and the More by entry (D5).
2. **The record entry,** `BookSheet.open_record(record, window, ctx, opts)` (the name may follow what reads
   best beside `open`): the header and rows above with `open` the window's own open of that record, the
   function its tap on a book runs (cover-grid screen task.md:26-29; series task.md:27, authors task.md:27),
   and `refresh` the window's re-list (series-and-authors chrome task.md:26). Open fact: those two
   functions' names and whether the window exposes them; read them from the merged windows, and where the
   tap's open is a local, expose it as a field rather than duplicating it. Band `book`, name `book` (D16).
   The `book-actions` task adds Add to the home and Delete after More by this author.
3. **Greyed rows (D2):** a record with no `path` gets Open, Book details and Read status with `muted = true`
   and no `run`; the detail of Read status is left out, since `BookList.getBookStatus` needs a path
   (`book_sheet.lua:226`). More by this author keeps its `run`. A tap on a greyed row closes the sheet and runs
   nothing (`sheet.lua:578-591`, D14).
4. **A file gone since the build:** a record with a `path` that is no longer a file
   (`lfs.attributes(path, "mode") ~= "file"`) calls `refresh()` and shows no sheet, as `BookSheet.open` does
   for the home (`book_sheet.lua:200-203`).
5. **More by this author (D5):** the row runs the entry series-and-authors' `routing` gives the home's sheet
   (routing task.md:20-24), with the record. Open fact: whether that entry takes a file (it reads
   `Books.for_path(book.file)`, `books.lua:296-301`) or an author name; if a file only, factor it so the
   record's `authors[1]` reaches the same show, the home's row passing its record as before. A path-less
   record cannot go through `Books.for_path`, so the name form is the one both use.
6. **`kopanda.koplugin/library_sheets.lua` (`LibrarySheets`, new),** the hold's dispatch:
   `LibrarySheets.hold(window, hit, started)` opens the book sheet for `hit.kind == "book"` on any window, with
   `opts = { started = started, beneath = window }` (pickers task.md:24-26); every other kind runs nothing
   here (the `folder-sheet` and `space-sheet` tasks add the library's). A raising dispatch is logged and the
   hold consumed.
7. **The hold step:** the chrome's hold, which series-and-authors leaves consumed with nothing run (D9,
   feature.md:72-76), takes `started = time.monotonic()` at its entry (`home_gestures.lua:100-101`), then
   calls `LibrarySheets.hold(window, window:hit(ges.pos), started)` behind a pcall. The nav bar's band and a
   bound hold corner keep their earlier steps (cover-grid feature.md:254, :269-274). On the Series and
   Authors windows only `book` opens anything (D3); `series`, `author` and `empty` stay inert.
8. `main.lua` requires `library_sheets` (`spec/unit/main_requires_spec.lua`); `HOOKS.md`'s book-sheet entry
   (`kopanda.koplugin/HOOKS.md:1317`) gains the library and the shelf screens as callers of
   `fm.bookinfo:show` and `genStatusButtonsRow`.

## Surfaces

- `kopanda.koplugin/book_sheet.lua`, `featured_cover.lua`, `library_sheets.lua` (new), `library_chrome.lua`
  (the hold step), `library.lua`, `series_screen.lua`, `authors_screen.lua` (only to expose their open and
  re-list), `main.lua`, `HOOKS.md`; the More by entry's module from series-and-authors' `routing` if step 5
  factors it.
- `spec/unit/book_sheet_spec.lua`, `spec/unit/library_sheets_spec.lua` (new),
  `spec/unit/library_gestures_spec.lua`, `spec/unit/shelf_gestures_spec.lua`, `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code:

- `book_sheet_spec.lua` (C3): a record's header (title, two authors joined, the cover through
  `FeaturedCover.framed` asking no extraction); its meta for a reading book with a percent and a history entry,
  a finished book (100%), a new book with no history (no meta line), a book with history but no sidecar;
  the rows in order with their icons; Open calling the window's open once with the record; Book details
  calling `fm.bookinfo:show(record.path)` once; a status written from the sub-sheet calling the window's
  re-list once and not the home; More by this author showing the record's first author's books, and the
  Authors list for a record with no author; a gone file re-listing and showing no sheet; a path-less record's
  meta "Not downloaded", the greyed rows with no `run`, a tap on one running nothing, More by this author
  still running.
- `book_sheet_spec.lua` (C9): every existing home case passes unchanged.
- `library_sheets_spec.lua` (C7): `LibrarySheets.hold` on a library `book` hit shows a sheet named `book`
  with `beneath` the window and `paint_ms` from `started`; on a Series and an Authors `book` hit the same;
  on `series`, `author` and `empty` hits from those windows, no sheet.
- `library_gestures_spec.lua` and `shelf_gestures_spec.lua` (C7): a hold on a book tile reaches the dispatch
  with that record; a hold in the bar's band runs nothing; a hold corner registered on the file manager wins;
  the existing cases pass unchanged (C10).
- `failsafe_spec.lua` (C8): a raising `hit` and a raising dispatch are logged and the hold consumed; a sheet
  failing to show from the library closes the library, not the home.
- `sheet_golden_spec.lua` passes unchanged (C9): the home's book sheet does not move.
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C11) pass with `library_sheets`.
- Scope check: `library_sheets_spec.lua` is new; confirm `bin/check spec/unit/library_sheets_spec.lua` runs
  that file alone (`bin/check:153-160`) and its summary names only its cases.

## Edge cases

- A record from a shelf screen is the window's own copy (`Books.get` re-reads on arrival, series-and-authors
  feature.md:267-270); the sheet reads its progress and history at hold time, so a status changed elsewhere
  shows.
- A book whose CoverBrowser row is gone (a refresh in flight): `BookCovers.read` gives nil and the header
  draws the typographic placeholder (`featured_cover.lua:203-211`); the sheet never asks for an extraction.
- History holds realpaths (`readhistory.lua:26`; `book_sheet.lua:47-50`); a record's `path` is the scanned
  path (`books.lua:121-124`), so `opened` realpaths it, as it does today.
- The home's `BookSheet.open` keeps its `Featured.tap` and `ctx.home:refresh()`; the split must not route the
  home through the window callbacks, or the home's `paint_ms` and refresh cases move.
- `book_sheet.lua` is 262 lines at `5d8a955`; with the record entry and the next task's two rows it stays
  under 500. If it passes 500, split the record entry into its own module and say so in the PR.
