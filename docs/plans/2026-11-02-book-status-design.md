# Book status (2026-11-02)

Decided on 2026-11-02 with the owner, after reading Project: Title (joshuacant/ProjectTitle `1f89add`,
AGPL-3.0: read, don't copy), whose restyled book status page shows a book's description. KoPanda gets
its own page instead: a read-only, full-screen window opened from the hold sheet's Book details row on
the library and the home. Tap on a book still opens it. The reader's status page, the end-of-book page
and the sleep screen stay KOReader's (design doc §4).

## Facts

- Project: Title doesn't add a screen; it swaps its own `genHeader`, `getStatusContent`,
  `genBookInfoGroup`, `genSummaryGroup` and `genStatisticsGroup` into KOReader's `BookStatusWidget`
  (`main.lua:297-302`), which KOReader shows from the reader's menu and end-of-book action
  (`frontend/apps/reader/modules/readerstatus.lua:19-28,126,155`) and as a sleep screen
  (`frontend/ui/screensaver.lua:543`). A tap on a book in its file browser opens it
  (`covermenu.lua:341`).
- CoverBrowser's cache row holds `pages` and `description`
  (`plugins/coverbrowser.koplugin/bookinfomanager.lua:50,59`), from the same `getBookInfo` call
  `books.lua` reads today (`books.lua:78`). For an EPUB never opened, crengine gives no reliable page
  count, so `pages` is usually empty; the sidecar's count (`books.lua:358-369`) fills in once read.
- KOReader's details page turns a description to plain text with `util.htmlToPlainTextIfHtml`
  (`frontend/util.lua:1295`, used at `frontend/apps/filemanager/filemanagerbookinfo.lua:450`).
- The Statistics database's `book` table holds `last_open`, `total_read_time` and `total_read_pages`
  (`plugins/statistics.koplugin/main.lua:464-477`); `page_stat_data` holds each page's `start_time`
  (`:406`). `ReadingStats.seconds_per_page(md5)` already reads a book's speed from it
  (`reading_stats.lua:399`).
- The sidecar's `summary.modified` is written on every summary save, a status change or a note or rating
  (`frontend/apps/filemanager/filemanagerutil.lua:111`, `frontend/apps/reader/modules/readerstatus.lua:215`).
  The owner chose (2026-11-02) to show it as "Finished 28 Oct" anyway; without it, "Finished" alone.

## What the reader sees

- **Opening.** Hold a book on the library or the home; the sheet's Book details row opens the page
  over that screen. A book not downloaded (no path, or cwngsync's placeholder) keeps the row greyed.
  Back returns to the screen beneath.
- **Header band.** The back mark and "Book details", as the Series screen's.
- **Page 1, top to bottom:**
  1. **Book.** The cover at about a third of the width; beside it the title (two lines at most),
     the author, "Series · #2", "412 pages" and the subjects as chips.
  2. **Progress.** A bar, "62% · page 255 of 412", "About 3 h 10 min left" (seconds per page ×
     pages to go). A finished book shows "Finished".
  3. **Reading history.** "7 h 40 min over 12 days", "Started 3 Oct · Last read 1 Nov".
  4. **Description.** Plain paragraphs filling the height left; the rest continues full-width on
     page 2, 3 …, turned by a west or east swipe, the pager showing "1 / 3".
- A section with nothing to show is left out, never drawn empty: a new book has no progress or
  history, Statistics off has no history or time left, a book without a blurb has no description,
  a book without a page count has no length line.
- Read-only: no rating, note, status switch or Open button; the chips don't respond to a tap. Every
  action stays in the hold sheet.

## Shape

- **`book_status.lua`, new, pure.** Record, progress, cache row and history in; the page's sections
  out. Leaves out empty sections, computes time left, makes the description plain text, and splits
  it across pages for given heights.
- **`book_status_screen.lua`, new.** A window on `LibraryChrome.Window`, as `series_screen.lua` is.
  Draws the sections from the look, reusing `FeaturedCover`, `Featured.bar` and the shelf's chip;
  pages by swipe; returns to the screen it opened over.
- **`reading_stats.lua`.** `ReadingStats.book_history(md5)` → `{ seconds, days, first, last }` or
  nil, in `seconds_per_page`'s pattern: read-only, only when the database exists, kept while the
  file's stamp holds, never raises.
- **`books.lua`.** One call reading a record's description and page count from its cache row, made
  only when the page opens, so library pages don't hold descriptions.
- **`book_sheet.lua`.** Book details opens the new screen; `show_details` (KOReader's
  `fm.bookinfo:show`) is deleted.
- **No schema key.** Looks reuse the library and shelf tokens; a token enters `looks/base.lua` only
  where none fits.
- **`HOOKS.md`.** The cache's `description` column, the Statistics tables, `util.htmlToPlainTextIfHtml`.

## Failure

- A failed read (cache row, sidecar, Statistics) is logged and leaves out its section; the page
  opens with the rest.
- A build that throws is logged, the screen closes and the screen beneath stands; the row falls back
  to KOReader's own details page.
- A file deleted while its sheet is up reads as not downloaded: the row is greyed, a tap closes the
  sheet.

## Tests

- `spec/unit/book_status_spec.lua`: the sections left out for a new, reading, finished,
  no-statistics and no-description book; time left and its rounding, under a minute included; an
  HTML description as plain text; the description's split, no line lost or repeated and every page
  inside its height.
- `spec/unit/reading_stats_spec.lua`: `book_history` on a fixture database: totals, a day count
  across midnight, a book with no row, a busy or missing database.
- `spec/unit/book_sheet_spec.lua`: Book details opens the screen, and is greyed without a file.
- `spec/emulator/book_status_capture_spec.lua`: opened from a library hold on the fixture library,
  in every look by day and night on the Colorsoft: it renders, pages a long description, returns
  to the library, and keeps the paint budget. No golden; the owner judges it on the emulator.

## Review

About 600 changed lines: one Opus builder and one reviewer. It reads files the plugin didn't write
(the cache row, the Statistics database), so the full review applies: mutation checks on the five
riskiest paths and a re-check after the fix.

## Decided while building (2026-11-02)

- **Where the finished date comes from.** `Books.details` returns `{ description, pages, modified }`: it
  reads the sidecar for the page count already, so it reads `summary.modified` too; `Books.progress` and its
  memo are unchanged. `BookStatus.sections` takes the date only as a calendar `%Y-%m-%d`.
- **Dates in another year** carry the year: "Finished 31 Dec 2025", "Started 1 Dec 2025 · Last read 2 Jan".
- **The time left** is the featured book's sum: seconds per page × (the Statistics row's pages − the pages
  read), so `sections` takes the history with `seconds_per_page`'s rate and pages beside it. A finished book
  shows its bar full and no time left; an abandoned one reads as one being read.
- **The page reached** is `round(percent × pages)`, at least 1, over the details' pages (the cache row's,
  then the sidecar's), else the progress's.
- **A missing Statistics database** reads as no history without a log line, as `seconds_per_page` reads it;
  a locked or corrupt one is logged. A progress read that fails leaves out the history too, its md5 being the
  progress's.
- **Header and foot.** The detail header: the back control labelled with the screen it returns to
  ("Library", "Home", "Series", "Authors", "Subjects", "Search"), the book's title as the aside, "Book
  details" as the title. No nav bar, as on the Go to screen; the pager sits at the foot.
- **Book block.** Title and author two lines each at most; series and length one line each; subjects as
  header chips (`LibraryChrome.chip`), two rows at most, the rest left out. No section labels; sections are
  `book_status.section_gap` apart.
- **Tokens.** `book_status.section_gap`, `book_status.paragraph_gap` and `type.book_description` join
  `looks/base.lua`; everything else reuses the featured book's, the shelf's and the library header's.
- **The description** is one paragraph per line after `htmlToPlainTextIfHtml` (a `<br>` starts one too),
  each trimmed, empty ones dropped; a page never starts with a paragraph gap; page 1 may hold none of it when
  its top leaves no room for a line.
- **The cover** is asked of CoverBrowser at the page's box after the first paint, as the featured cover asks
  for its own: one cached at the library grid's size is too small for a third of the width.
- **A section that doesn't fit page 1** above the pager is left out and logged; none does at any text size on
  the Colorsoft or the Paperwhite.
- **A build that throws** is logged and the screen it was opened from is shown again (the chrome closed it
  before building), then the row falls back to KOReader's own details page over it.
- **A file gone between the hold and the tap** re-lists the screen beneath (the home's refresh, the window's
  re-list), which then reads it as not downloaded; nothing opens.
