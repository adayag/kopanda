# Book status page: implementation plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task.

**Goal:** A read-only, full-screen KoPanda page for one book (cover, facts, progress, reading history,
description), opened from the hold sheet's Book details row on the home and every library window, in place
of KOReader's details page.

**Architecture:** A pure `book_status.lua` turns a Books record, its progress, its CoverBrowser cache row
and its Statistics history into the page's sections and splits the description across pages. A
`book_status_screen.lua` window on `LibraryChrome.Window` draws them from the look and pages by swipe.
Back re-shows the screen it was opened from, by the same path a book's close takes (`main.lua:258-287`).

**Tech stack:** Lua on KOReader's LuaJIT; Busted unit specs; emulator capture specs.

Design: `docs/plans/2026-11-02-book-status-design.md`. Build after Focused mode release 3 ships. About 1.5–2
days, about 600 changed lines: one Opus builder, then one reviewer with the **full review** (it reads files
the plugin didn't write: the cache row, the sidecar, the Statistics database), five mutation checks and a
re-check after the fix.

---

## Verified facts (2026-11-02, pinned build `e1fe1ac`)

- The cache row: `books.lua:72-79` `row(path)` calls `bim:getBookInfo(path, false)` (no cover); its
  `pages` and `description` columns are `plugins/coverbrowser.koplugin/bookinfomanager.lua:50,59`.
- Sidecar pages: `books.lua:360-370` `sidecar_pages(doc)`, in BookList's order.
- Plain text: `util.htmlToPlainTextIfHtml` (`frontend/util.lua:1295`), as
  `frontend/apps/filemanager/filemanagerbookinfo.lua:450` uses it.
- Statistics: `ReadingStats.seconds_per_page(md5)` (`reading_stats.lua:403-437`) is the pattern for
  `book_history`: `off()`, `db_path()`, `util.fileExists`, `stamp(path)`, `memo`, `with_db`, pcall, logged,
  never raises. Tables: `book` (`last_open`, `total_read_time`, `total_read_pages`,
  `plugins/statistics.koplugin/main.lua:464-477`), `page_stat_data.start_time` (`:406`).
- `summary.modified` is written as `%Y-%m-%d` on **every** summary save, not only a status change: a status
  change (`frontend/apps/reader/modules/readerstatus.lua:215`, `frontend/ui/widget/bookstatuswidget.lua:199`)
  and any `filemanagerutil.saveSummary` (`frontend/apps/filemanager/filemanagerutil.lua:111`), which a note or
  rating save also takes. See open question 1.
- The sheet: `book_sheet.lua:224-262` `book_rows`; Book details is row 2, its run `show_details(file)`
  (`:107-115`, KOReader's `fm.bookinfo:show`). With no file, rows 1–3 are muted. `BookSheet.open`
  (`:366`, the home's featured book) and `BookSheet.open_record` (`:412`, every library window) both use it.
- The window: `LibraryChrome.show(cls, opts, fields)` (`library_chrome.lua:533-553`) closes the home and the
  window shown before showing the new one. So "back to the screen beneath" is a re-show, not a pop: record
  the opener (`screen`, `view`, `page`, or the home) and show it again on back, as `show_return`
  (`main.lua:273-287`) does after a book closes.
- Model window: `series_screen.lua` (326 lines): `extend`, `fields`, `init`, `view`, `build`, `back`,
  `action_at`, `hit`, `refresh`, `show`, `close`.
- Reusable drawing: `FeaturedCover.framed` (`featured_cover.lua:202`), `Featured.bar`
  (`widgets/featured.lua:222`), `LibraryChrome.chip` (`library_chrome.lua:119`).

## Decided while planning

1. **Finished date** (the owner, 2026-11-02): a finished book shows "Finished 28 Oct" from `summary.modified`,
   though that is the date the summary last changed (a note or rating saved later moves it). KoPanda writes
   no notes or ratings and Focused mode hides KOReader's status page, so on these devices it is the day the
   book was marked finished. A missing or malformed `modified` shows "Finished" alone.

## Tasks

TDD each step: write the test, run it with `bin/check spec/unit/<name>_spec.lua`, see it fail for the right
reason, implement, rerun. Read `bin/check` output through a filter (`grep -E "PASSED|FAILED|ERROR|Total:|NOTE"`).

### Task 1: `ReadingStats.book_history(md5)`

**Files:** modify `kopanda.koplugin/reading_stats.lua`; test `spec/unit/reading_stats_spec.lua`.

1. Tests on a fixture database built in the spec (as the existing `seconds_per_page` tests build theirs):
   totals (`seconds` = `total_read_time`), `days` = distinct local dates of `page_stat_data.start_time`
   (two reads either side of midnight count two days), `first` = min `start_time`, `last` = `last_open`;
   nil for a book with no row; nil and logged for a missing or locked database; nil with Statistics off.
2. Implement in `seconds_per_page`'s pattern, with its own `memo.history` keyed by stamp and md5.

### Task 2: `Books.details(record)`

**Files:** modify `kopanda.koplugin/books.lua`; test `spec/unit/books_spec.lua`.

1. Tests: returns `{ description, pages }` from the cache row, `pages` falling back to `sidecar_pages`;
   description nil when the row has none; `{}` when CoverBrowser is off or the row is missing; a raising
   `getBookInfo` is logged and gives `{}`. A library listing (`Books.folder`, `Books.all`) still holds no
   description (assert the records have no `description` field).
2. Implement with the existing `row(path)` and `sidecar(path)`; called only by the screen on open.

### Task 3: `book_status.lua`, the sections

**Files:** create `kopanda.koplugin/book_status.lua`; test `spec/unit/book_status_spec.lua`.

1. `BookStatus.sections(record, progress, details, history, now)` returns an ordered list of sections:
   `book` (title, author, `series` "Series · #2", `length` "412 pages", `subjects`), `progress` (percent,
   page and pages, `left` text, or `finished` with its date), `history` ("7 h 40 min over 12 days",
   "Started 3 Oct · Last read 1 Nov"), `description` (plain text).
2. Tests, one per case in the design: a new book (no progress, no history), reading, finished, Statistics
   off (no history, no time left), no description, no page count (no length line). Time left = seconds per
   page × pages to go, rounded to 10 min above an hour, to the minute below, "Under a minute" below 60 s.
   An HTML description comes out as plain text through `util.htmlToPlainTextIfHtml`.

### Task 4: `book_status.lua`, the description's split

1. `BookStatus.split(text, first_h, rest_h, measure)` → a list of pages of lines; `measure` is injected
   (line height and wrap at a width), so the test needs no fonts.
2. Tests: no line lost or repeated (join of the pages equals the wrapped text); every page within its
   height; page 1 uses `first_h`, the rest `rest_h`; a paragraph break at a page end doesn't start the next
   page with a blank line; an empty text gives no pages.

### Task 5: `book_status_screen.lua`

**Files:** create `kopanda.koplugin/book_status_screen.lua`; modify `kopanda.koplugin/main.lua` (a
`showBookStatus` beside `showSeries`, `:239`); test `spec/unit/book_status_screen_spec.lua`.

1. A `LibraryChrome.Window`, `screen = "book_status"`, fields `record`, `opener`, `page`. Header as the Series
   screen's: the back mark and "Book details". Page 1: cover at a third of the width with the book block
   beside it, then progress (`Featured.bar`), history, the description's first part; pages 2+ the description
   full width. West / east swipes turn the page (the chrome already routes them); pager "1 / 3".
2. `opener` is `{ screen = "home" }` or `{ screen, view, page }` for a library window; `back()` re-shows it
   (the home through `goHome`, a window through `showLibrary` / `show_shelf` with its view and page).
3. Read-only: `action_at` returns only the back mark; chips don't respond.
4. A build that raises is logged, the window closes, and the opener is re-shown.
5. Unit tests: sections drawn in order and an empty one left out; page count from the split; back re-shows
   the opener with its view and page; a raising build re-shows the opener.

### Task 6: `book_sheet.lua`, Book details opens the page

**Files:** modify `kopanda.koplugin/book_sheet.lua:107-115`, `:224-262`; test `spec/unit/book_sheet_spec.lua`.

1. Tests: Book details opens the screen with the record and the opener (home from `BookSheet.open`, the
   window's screen, view and page from `open_record`); muted with no file and with a cwngsync placeholder
   (`record.placeholder == true`); if the screen fails to show, KOReader's details page opens instead.
2. Replace `show_details` with the screen's show, keeping `fm.bookinfo:show` only as that fallback.

### Task 7: looks, HOOKS.md, emulator

1. Tokens: reuse `library` and `sheet` tokens; add to `looks/base.lua` only where none fits, and check
   `spec/unit/looks_spec.lua` passes.
2. HOOKS.md: the cache's `description` and `pages` columns, the Statistics tables and columns read,
   `util.htmlToPlainTextIfHtml`.
3. `spec/emulator/book_status_capture_spec.lua`: from a library hold on the fixture library, Book details,
   in every look by day and night on the Colorsoft: renders, a long description pages, back returns to the
   library at the same page, paint budget kept. No goldens. Save one capture per look for the owner.
4. Update the design doc with any decision made on the way.

## Done

`bin/check --unit` green, `bin/check spec/emulator/book_status_capture_spec.lua` green, the reviewer's fixes
in and re-checked, the lead's full `bin/check`, the captures opened for the owner. Cuts the next release.
