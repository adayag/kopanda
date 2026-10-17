# Series and Authors screens replace the placeholders

## Summary

The two screens the home screen has pointed at since stage 1 (direction doc "Placeholder entries"),
built from the book model's indexes.

## Behavior

- Series: a list of series with counts, under way first; tapping one shows its books in series order as a
  list in both looks, with the next unread marked.
- Authors: a list of authors under surname letters with counts; tapping one shows their books as a grid.
- The launcher entries, the nav bar's Authors tab and the book sheet's "More by this author" row all
  resolve to these screens, and the placeholder note is deleted.
- Both screens draw with the look and carry the nav bar; goldens in both looks on the Colorsoft profile.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. Repo paths are on
`main` at `b05fe55`. Boards are `.tiller/design/2026-10-16-kopanda-library-screens/<board>.dc.html:<line>`:
`SeriesC` is Diner's series list, `SeriesBooksC` Diner's one series, `AuthorsC` Diner's authors list,
`AuthorBooksA` Editorial's one author; `Main` and `GridA` are the library grids cover-grid is drawn from.
Sizes are board pixels, scaled as cover-grid's spec says (cover-grid feature.md:24-29).

This feature builds on `library/book-model` (F-alfeze, done: `books.lua`, `book_covers.lua`,
`book_index.lua`), `home/launcher` (F-ydcqb0, done: the `series` and `authors` targets) and
`library/cover-grid` (F-2nt0fx, approved, not built). All three edges are recorded. What cover-grid will
provide is cited from its spec (`.tiller/epics/library/features/cover-grid/feature.md:<line>`, its tasks'
`task.md:<line>`), not from code: `library.lua` and its window (feature.md:114-141), `LibraryOrder` and its
title order (order task.md:11-22), `LibraryTiles` and the fit (tiles task.md:21-48), `BookIndex.surname`
(D10, feature.md:79-83), the pager (feature.md:188-192, D16 :107-109), the `forward` and `download` icons
(D14, :93-102), the gesture order (:248-274), `KoPanda:showLibrary` (:328-330) and the book-close return
(:307-320). Where cover-grid's code, once built, names a thing differently from its spec, the task reads
the code and follows it.

### Decisions

Owner decisions (owner, 2026-10-16):

- **D1. Shared chrome.** The window chrome cover-grid builds into `library.lua` (the header frame, the pager,
  the nav bar's band, the gesture route, and the lifecycle: show and close, the settled signal, the rebuild
  on a variant or size change, a failure closing onto the file browser, the forwarding to the file
  manager's menu zones) moves into one shared module, `library_chrome.lua` (`LibraryChrome`), under
  cover-grid's existing tests, before any new screen is built. The library behaves the same after the move
  and its goldens do not change. `series_screen.lua` (`SeriesScreen`) and `authors_screen.lua`
  (`AuthorsScreen`) are their own windows on it. The three names are free: no such file under the
  emulator's `frontend/`, `common/` or any bundled `plugins/*.koplugin/` (`spec/unit/hooks_doc_spec.lua:104-122`'s
  rule).
- **D2. Extract on show.** Each screen, after its first paint, asks CoverBrowser to extract every record of
  the whole library whose row is missing, and rebuilds on arrival (Extraction, below). The bounded check
  stops after 30 checks (`book_covers.lua:17-18`), so on a large library the rows still missing then arrive
  for a later show; the cap is documented in the code and `HOOKS.md`.
- **D3. Series state.** The **next unread** is the first book in series order whose status
  (`Books.progress`, `books.lua:358-374`; statuses `:15-16`, `:338-356`) is not `complete`: a `reading` book
  is the one marked when it comes first, an `abandoned` book is skipped, and a not-downloaded book can be
  marked. A series is **under way** when at least one book is `complete` or `reading` and at least one is
  not `complete`; **finished** when every book is `complete`; **not started** otherwise. The "N of M" chip
  counts the `complete` books of the series' M.
- **D4. One series is a list in both looks.** Editorial's list is designed from SeriesBooksC by the looks'
  rules (Tokens, below); no board draws it.
- **D5. "Up next" on the one-author grid is a chip on the cover's foot,** where cover-grid puts "Not
  downloaded" (cover-grid D13, feature.md:48-52), not a second line under the title as AuthorBooksA:50-53
  draws it; every tile keeps one height.
- **D6. "More by this author" opens the first-listed author's own books** directly, from the book's record
  (`Books.for_path`, `books.lua:294-301`; the featured book's `authors` is a joined string,
  `featured_book.lua:88-90`, `:141`). A co-author stays reachable from the Authors list.
- **D7. Closing a book returns to the screen it was opened from:** the series or author screen, its view
  (the list, one series, one author) and its page, extending cover-grid's return (D4, feature.md:57-59,
  :307-320) with the screen.
- **D8. The whole library:** both screens list `Books.all()` (`books.lua:263-292`), every folder under the
  library root and every source's books.
- **D9. Hold is inert, with a seam.** A hold on either screen is consumed and runs nothing. Each screen
  gives `hit(x, y)`: `{ kind = "series", entry }`, `{ kind = "book", record }`, `{ kind = "author", entry }`
  or `{ kind = "empty" }`, the seam `library/context-menu` (F-l0kw8m) builds on, as cover-grid's
  `Library.hit` is (feature.md:269-271). The boards' hold sheets (HoldBookC, HoldBookA) are drawn over the
  library only.

Lead decisions, each overturnable at approval:

- **D10. Header wording,** digits throughout. Series list: Diner "12 series, 3 under way", Editorial "12
  series · 3 under way" (SeriesC:21; the Editorial join as cover-grid's counts, feature.md:149-151); with
  none under way, "12 series"; one, "1 series". Authors list: Diner "38 authors on the shelf", Editorial "38
  authors"; "1 author" (AuthorsC:21). One series: Diner "N. K. Jemisin, 3 books", Editorial "N. K. Jemisin ·
  3 books" (SeriesBooksC:26 writes "three"); "1 book"; the author part as D15. One author: Diner "9 books, 4
  finished", Editorial "9 books · 4 finished" (AuthorBooksA:25); with none finished, "9 books".
- **D11. The static header labels** "Under way first" (SeriesC:24) and "By surname" (AuthorsC:24) are
  drawn and inert: a tap on one is a tap on the header's empty space.
- **D12. Series list order:** the under-way series, then every other series (finished and not started
  together), each part by cover-grid's title order of the series name (lowercase, one leading "the ", "a "
  or "an " dropped, byte order; order task.md:22), ties by name. SeriesC:35-85 draws exactly this.
- **D13. Authors order:** by `BookIndex.surname(name)` (cover-grid D10), then the lowercase full name, then
  the name. The **letter** of an author is the first ASCII letter of the surname key, uppercased, or "#" when
  the key starts with anything else (a digit, punctuation, a non-ASCII letter); "#" sorts after Z. Each
  letter is one group. A book with two authors is under both (`BookIndex.authors`, `book_index.lua:66-91`);
  a book with no author is under none.
- **D14. Paging by rows,** the pager always shown (cover-grid D16). The three lists hold on a page as many
  whole rows as fit between the header and the pager at the screen's size, at least one; the one-author
  grid holds two rows of three, as the library (cover-grid D2). An author group split by a page break
  starts the next page with its letter again. Paging does not wrap.
- **D15. A series' author** is the first author of the first book in series order that has one, followed by
  " and others" when any book of the series has a first author different from it; a series none of whose
  books has an author shows no author part. Sub-lines: under way "N. K. Jemisin · next: The Obelisk Gate"
  (SeriesC:36); finished and not started "Martha Wells · 7 books" (SeriesC:74, :86).
- **D16. One author's books** are in cover-grid's Series order (D9, feature.md:76-77: the series name's title
  order, then `series_index`, books with no index after; books in no series last, by title). A book is
  marked up next when it is its series' next unread (D3), the series taken whole, not only this author's
  books of it.
- **D17. Where entries and back land.** The launcher's Series and Authors entries, the Authors tab from any
  other screen and the book sheet's row open their screen at the list's first page, or the author's first
  page (D6). The Authors tab on an Authors screen goes to the list's first page. Back, from one series or one author, returns to the list at
  the page holding that series or author.
- **D18. No stored state.** Nothing these screens do is written to the state file or the settings file;
  the return (D7) and the list position for back live in memory. The schema gains no key.
- **D19. Not downloaded and up next together.** On the one-author grid the chip reads "Up next" and the
  `download` badge stays on the cover, so the badge alone says not downloaded there. On the one-series
  list the row is marked up next (its fill and note) and its chip reads "Not downloaded".
- **D20. A one-series row** (SeriesBooksC:33-63; the reading state is not drawn): its index number (the
  `series_index`, a whole number without decimals, else as written; none, a blank column), its cover, its
  title, then one of: the progress bar, full for `complete` (:38) and at its percent for `reading` or
  `abandoned` with a percent; the note "read this one next" for the up-next book with no percent (:47); "Not
  on the Kindle yet" for a path-less book (:60); nothing else. The chip: "Finished" for `complete` (:40), "Up
  next" for the up-next book (:49), "Not downloaded" for a path-less one (:62, and D19), none otherwise. The
  up-next row takes the marked fill and shadow (:42).
- **D21. Small covers.** The series list's stacked covers (SeriesC:29-33, the first three books in series
  order, the first in front; fewer when the series has fewer) and the one-series list's covers
  (SeriesBooksC:35) draw the cached cover through `BookCovers.read` (`book_covers.lua:80-87`) in the look's
  frame, or, without one, a plain `cover` fill with no lettering: the placeholder's title would be
  illegible at that size and the title is beside it.
- **D22. Fixed size.** Text does not follow `text_size`, as the library's doesn't (cover-grid D12).
- **D23. Empty:** no series shows the header ("No series"), a centred note "No books in a series yet" and
  the pager at page 1 of 1; no authors, "No authors" / "No authors on the shelf" and "No authors yet".
  A series or author that has gone when its view is shown (a back, a book-close return) shows the list at
  its first page instead.
- **D24. Night and the Paperwhite** follow the looks' rules (`Looks.palette`, the grey palette), as the
  library's do; neither is drawn.
- **D25. Goldens on the Colorsoft only,** both looks, all four views: eight captures (Goldens and budget).
- **D26. Undrawn tokens by analogy.** Editorial's series list, one series and authors list, and Diner's one
  author, take their tokens from the drawn boards by the looks' rules; each such token's comment says
  "lead: by analogy with <board>:<line>" (Tokens).

### The chrome

`library_chrome.lua` holds what the three windows share; each window supplies what is its own. Read from
`library.lua` as cover-grid built it:

- **The chrome's:** the `InputContainer` with `covers_fullscreen` and its `shown` slot, show and close
  (`UIManager:show(…, "full")`), the build on show and the rebuild in place (`go`), the paint guarded and a
  failed paint closing onto the file browser from the next tick, the rebuild on a `Looks.variant()` or
  `Screen:getSize()` change (cover-grid feature.md:131-135), the settled signal
  (`KoPandaSettled{ screen, paint_ms }`, once per show), the header frame (band fill, padding, the bottom
  edge, a left column of an optional back control, aside and title, and a right-hand slot), the pager
  (feature.md:188-192), the nav bar in its band (`NavBar.new{ where }`), the gesture route in cover-grid's
  order (feature.md:250-274: the bar, the window's own taps, west and east swipes with the edge bands
  exempt, the page keys, hold consumed, everything else forwarded to the file manager's menu zones and the
  file manager), the metadata events re-listing, closing with the file manager, and the pending window for a
  book's close.
- **The window's:** what it lists, its header's parts, its page of rows or tiles, its taps on them,
  `hit(x, y)`, and its page count.
- **One window at a time.** Showing any chrome window closes the home and any other chrome window first, so
  the Library tab from a series screen, or the Authors tab from the library, leaves one KoPanda window up.

### Series

- **The list** (SeriesC): the header on Diner's `pink` band (:19; Editorial no fill), the count (D10) over
  "Series" (:21-22), "Under way first" at the right (:24, D11); a page of series rows (:27-89) in D12's
  order; the pager; the nav bar with no tab lit (`where = "series"`, library direction doc "Series list").
- **A series row** (SeriesC:28-40): the stack (D21), the series name in one line, ellipsised, the sub-line
  (D15) in one line, ellipsised, and the chip: "N of M" (D3) on `mustard` for under way (:39, :52), "Finished"
  on `teal` (:76), "Not started" on `paper` (:88). Tap shows that series.
- **One series** (SeriesBooksC): the header on the same band with the back control "Series" (:20-23), the
  aside (D10) over the series name (:26-27); a page of book rows (D20) in series order
  (`BookIndex.series`, `book_index.lua:93-112`: ascending `series_index`, no index after, then title); the
  pager; no tab lit. A path-less book's cover carries the `download` badge (:53-56). Tap on a downloaded
  book opens it (cover-grid D15, `filemanagerutil.openFile`) after recording the return (D7); on a
  path-less one, nothing; on back, the list (D17).

### Authors

- **The list** (AuthorsC): the header on Diner's `teal` band (:19; Editorial no fill), the count (D10) over
  "Authors" (:21-22), "By surname" at the right (:24); a page of letter groups (:27-75) in D13's order, each
  a letter column (:29) beside its authors' rows: the name as written, in one line, ellipsised, and "4 books ›"
  or "1 book ›" (:31-37, :59), the count of the author's books in `BookIndex.authors`; the pager; the nav bar
  with Authors lit (`where = "authors"`, :92). Tap on a row shows that author.
- **One author** (AuthorBooksA): the header with the back control "Authors" (:20-23), the count (D10) over the
  author's name (:25-26); a page of cover-grid's book tiles (`LibraryTiles.book`) in three columns and two
  rows (D14) in D16's order, an up-next book's tile carrying the "Up next" chip on its cover's foot (D5,
  D19); the pager; Authors lit (:99). Its cover box is its own, shorter than the library's, as AuthorBooksA:32
  (206) is shorter than GridA:32 (218) under its taller header; the fit sets it (The fit). Tap as one
  series.

### The fit

At the Colorsoft (`harness.at_colorsoft`, `spec/plugin_harness.lua:154-183`) and at the Paperwhite size
(1236×1648, `spec/emulator/profiles.lua:3-6`, the helper cover-grid's `tiles` task adds, tiles task.md:42-43),
in both looks:

- **One author:** its header + the grid's top padding + two rows of tiles and the row gap + the pager +
  `NavBar.height` ≤ the screen's height. The one-author cover height starts at the analogy of D26 (Editorial
  206, AuthorBooksA:32; Diner Main's `cover_h` less the one-author header's extra height over the library
  header, in board px) and steps down by board pixels until the case passes, each changed value commented
  "D14: board N", as cover-grid's D2 tightening.
- **The lists** hold at the Colorsoft at least the boards' counts per page: five series rows (SeriesC), three
  book rows (SeriesBooksC), seven author rows in five groups (AuthorsC). A failing count is reported to the
  lead with the measured heights before any token changes.

### Tokens

A `shelf` block and its type parts in both looks with identical paths, each value with its board line or its
"lead: by analogy" note (D26), every colour an existing palette role, by `looks_spec.lua`'s rules
(`spec/unit/looks_spec.lua:83-135`, `:196-240`). The headers reuse cover-grid's `library.header.*` tokens
and its `library_count` and `library_title` parts, which SeriesC:19-22 and AuthorsC:19-22
match (Main:19-22); the pager is cover-grid's. Diner's text on `mustard`, `pink` or `teal` is `on_accent`;
on `paper`, `ink` (cover-grid feature.md:244-246).

| Token | Editorial | Diner |
|---|---|---|
| `shelf.series_fill_color`, `authors_fill_color` | false, false | `pink` (SeriesC:19), `teal` (AuthorsC:19) |
| `shelf.detail.padding` top, side, bottom; `back_gap` | 26, 40, 16; 14 (AuthorBooksA:19) | 22, 40, 18; 10 (SeriesBooksC:19) |
| `shelf.back.fill_color`, `outline_width`, `padding` l, r, y, `icon_size`, `gap` | false, 0, 0, 0, 0, 14, 6 (AuthorBooksA:20-21) | `paper`, 2, 6, 10, 4, 14, 6 (SeriesBooksC:20-21) |
| `shelf.list.padding_top`, `side`, `row_gap` | 22, 40, 0 (lead: by analogy, rows ruled not boxed) | 22, 40, 14 (SeriesC:27) |
| `shelf.row.padding` x, y; `gap`; `outline_width`; `shadow` x, y; `rule_width`, `rule_color` | 0, 14; 18; 0; 0, 0; 1, `hairline` (lead: by analogy with GridA's hairlines) | 16, 12; 18; 3; 4, 4; 0, `ink` (SeriesC:28) |
| `shelf.stack.cover_w`, `cover_h`, `offset_x`, `offset_y`, `outline_width`, `outline_color` | 38, 56, 10, 2, 1, `paper` (lead: an edge to part the overlapped covers) | 38, 56, 10, 2, 2, `outline` (SeriesC:29-33) |
| `shelf.chip.padding` x, y; `outline_width`; `under_way_fill_color`, `finished_fill_color`, `not_started_fill_color`, `up_next_fill_color`, `not_downloaded_fill_color` | 0, 0; 0; false × 5 (lead: small caps, as GridA:73) | 7, 1; 2; `mustard`, `teal`, `paper`, `paper`, `pink` (SeriesC:39, :76, :88; SeriesBooksC:49, :62) |
| `shelf.books.padding_top`, `row_gap` | 24, 0 (lead: ruled rows) | 24, 18 (SeriesBooksC:32) |
| `shelf.book.index_w`, `cover_w`, `cover_h`, `cover_outline_width`, `line_gap` | 40, 64, 96, 0, 6 (lead: Editorial's covers unoutlined, GridA:43) | 40, 64, 96, 2, 6 (SeriesBooksC:34-36) |
| `shelf.book.bar_height`, `bar_outline_width` | 4, 0 (GridA:46's strip) | 10, 2 (SeriesBooksC:38) |
| `shelf.next.fill_color`, `shadow` x, y; `line_gap`; `text_color` | false, 0, 0; 4; `ink` (lead: Editorial marks by type, AuthorBooksA:52) | `mustard`, 6, 6; 4; `on_accent` (SeriesBooksC:42, :45) |
| `shelf.book.badge_size`, `badge_outline_width`, `badge_icon_size`, `badge_inset` | 24, 1, 14, 6 (lead: GridA:66 scaled to the cover) | 28, 2, 14, −10 (SeriesBooksC:54-55) |
| `shelf.groups.padding_top`, `gap` | 22, 0 (lead: ruled groups) | 22, 12 (AuthorsC:27) |
| `shelf.group.outline_width`, `shadow` x, y; `rule_width`, `rule_color`; `letter_w`, `letter_fill_color`, `letter_rule_width` | 0, 0, 0; 1, `hairline`; 48, false, 0 (lead) | 3, 4, 4; 0, `ink`; 48, `mustard`, 3 (AuthorsC:28-29) |
| `shelf.author.padding` x, y; `rule_width`, `rule_color` | 16, 11; 1, `hairline_light` (lead: Editorial's row rules) | 16, 11; 2, `outline` (AuthorsC:31) |
| `shelf.author_grid.cover_h` | 206 (AuthorBooksA:32), then The fit | Main's `cover_h` less the header's growth (lead), then The fit |
| `shelf.up_next.fill_color`, `outline_width` | `paper`, 0 (as cover-grid's not-downloaded chip) | `paper`, 2 (SeriesBooksC:49) |

Type parts: `shelf_detail_title` (Editorial `display` 34, AuthorBooksA:26; Diner `display` 36 −0.01,
SeriesBooksC:27), `shelf_back` (Editorial `strong` 11 caps 0.14 `text`, AuthorBooksA:20; Diner `display` 11
caps 0.08 `ink`, SeriesBooksC:20), `series_name` (Editorial `display` 20, lead; Diner `display` 19,
SeriesC:35), `series_sub` (Editorial `text` 12 `muted`, lead; Diner `text` 13, SeriesC:36), `shelf_chip` (on a
fill: Editorial `strong` 10 caps 0.14 `muted`, AuthorBooksA:79; Diner `display` 10 caps 0.08 `on_accent`,
SeriesC:39), `shelf_chip_plain` (on paper: Editorial `strong` 10 caps 0.14 `ink`, AuthorBooksA:52; Diner
`display` 10 caps 0.08 `ink`, SeriesC:88), `book_index` (Editorial `display` 30, lead; Diner `display` 40,
SeriesBooksC:34), `book_row_title` (Editorial `display` 18, lead; Diner `display` 20, SeriesBooksC:37),
`book_next_note` (Editorial `strong` 10 caps 0.14 `ink`, AuthorBooksA:52, no accent face; Diner `accent` 22
`on_accent`, SeriesBooksC:47), `book_row_note` (Editorial `text` 12 `muted`, lead; Diner `text` 13,
SeriesBooksC:60), `author_letter` (Editorial `display` 24 `ink`, lead; Diner `display` 24 `on_accent`,
AuthorsC:29), `author_name` (Editorial `strong` 15, lead; Diner `strong` 17, AuthorsC:31), `author_count`
(Editorial `strong` 11 caps 0.12 `muted`, lead; Diner `display` 11 caps 0.08, AuthorsC:33), `shelf_empty`
(as cover-grid's empty note), `shelf_label`, the static header label (Editorial `strong` 11 caps 0.12
`text`, GridA:25; Diner `display` 11 caps 0.08 `on_accent`, SeriesC:24, AuthorsC:24). The up-next row sets its
parts in `shelf.next.text_color`, since Diner fills it with `mustard`. Editorial's 500 and 600 map to `strong`, Diner's 700 to `strong` and 800 to
`display`, as cover-grid maps them (feature.md:242-244).

The registry's `back`, `forward` and `download` gain "series" and "authors" in their `used_in`
(`icons.lua:52`; the two cover-grid adds). `used_in` reaches neither the swatch screen, which labels by id
(`swatch.lua:266`), nor the studio's catalog, which carries id, label and file (`bin/catalog-json.lua:101`),
so neither changes.

### Extraction

- After a screen's first paint, from the next tick, `BookCovers.request(records, specs, on_arrival, alive)`
  (`book_covers.lua:144-235`) with every record of `Books.all()` and `specs` the library grid's cover box
  (`LibraryTiles.geometry`, tiles task.md:22-25), the largest box these screens and the library draw, so a
  row extracted here serves the grid without a second extraction (a smaller box would be replaced by a bigger
  one, `book_covers.lua:4-5`). `alive` tests that the window is still the one shown. `BookCovers.wants`
  (`:89-108`) asks for every record with no row (`:98-100`) and for any whose cover is not yet fetched or
  too small for the box, so the request also brings covers.
- **On arrival** each arrived record is re-read (`Books.get`, `books.lua:303-322`) and replaced in the
  window's records, the index is rebuilt (a book may have gained its series or authors), and the window is
  set dirty only when the page shown would change: its items, their order or a cover on it. E-ink redraws
  stay with what the reader can see.
- **The cap.** The check stops after 30 checks (`book_covers.lua:17-18`, `:200-223`) while CoverBrowser's
  extraction goes on (`BookCovers.cancel` drops only the check, `:110-116`). Today its last check leaves the
  files that did not arrive marked as asked (`:209-220`) and a later request skips them (`:131`), so when
  another request ends that extraction (`extractInBackground` terminates the one before,
  `plugins/coverbrowser.koplugin/bookinfomanager.lua:695`) they are never asked again in the process. The
  last check therefore forgets them as asked, as a replaced request already forgets its pending files
  (`book_covers.lua:160-164`), so a later show asks again. `HOOKS.md`'s extraction entry gains the screens as
  askers and the cap.
- Closing the window cancels the check; the home's and the library's requests replace this one, as one
  request is in flight at a time (`book_covers.lua:148-150`).

### Book close

- A tap that opens a book records `{ screen = "series" | "authors", view, page }`, `view` being the list, a
  series' name or an author's name, from `filemanagerutil.openFile`'s pre-callback, as the library records
  its own (cover-grid feature.md:309-311).
- `KoPanda:onCloseDocument` (`main.lua:244-258`) pre-builds that window at that view and page;
  `KoPanda:onShow` (`main.lua:184-213`) shows it, or builds it afresh after a failed open, as cover-grid's
  routing does for the library (routing task.md:19-27). The taken window re-reads the closed book's progress
  and rebuilds what shows it: the series' state and chip, the book's row or tile.
- A series or author gone by then: D23.

### Entry points

- `LauncherEntries`' `series` and `authors` targets (`launcher_entries.lua:130-135`), which show the notes
  "Series are coming with the library." and "Authors are coming with the library.", show the screens (D17)
  instead; the notes are deleted, and the spec cases asserting them (`spec/unit/launcher_entries_spec.lua:362-368`,
  `spec/unit/book_sheet_spec.lua:23`, `:428-440`) change on purpose.
- The nav bar: `ACTIVE` (`nav_bar.lua:32-33`) gains `authors = "authors"`; `where = "series"` lights no tab.
  `NavBar.run`'s Home branch (`:70-72`) closes these windows and shows the home, as it does for the library.
  The Authors tab runs the `authors` target (`:76`).
- The book sheet's "More by this author" (`book_sheet.lua:232-239`) shows the first author's books (D6); a
  book whose record has no author shows the Authors list. The sheet closes before the row runs
  (`sheet.lua:575-591`).
- The windows are shown through `KoPanda:showSeries(opts)` and `KoPanda:showAuthors(opts)` beside cover-grid's
  `showLibrary` (feature.md:328-330), refusing without a file manager; the boot guard is the home's alone.

### Failure behaviour

As the library's (cover-grid feature.md:332-344), through the chrome: a window failing to build when asked to
show is logged and leaves the file browser up with the home closed; a raising paint or gesture route closes
the window onto the file browser; a raising tap action (an open, a page, a view), an index build, a
progress read, a cover request or an arrival is logged with the page as it was. In every case the file
manager stays on top and handles input.

### HOOKS.md

Gains the screens as `BookCovers.request` askers and the cap (Extraction). Every KOReader internal these
windows reach is reached through the chrome and already listed by cover-grid. `main.lua` requires
`library_chrome`, `shelf_order`, `shelf_rows`, `series_screen` and `authors_screen` at load
(`spec/unit/main_requires_spec.lua`).

### Goldens and budget

- **New,** on `colorsoft`, each shot on `KoPandaSettled` with `screen = "series"` or `"authors"`:
  `series-list-{diner,editorial}`, `series-books-{diner,editorial}`, `authors-list-{diner,editorial}`,
  `author-books-{diner,editorial}`.
- **The capture library** is built by the spec in its scratch space, never in `spec/fixtures/library/` (whose
  three books `spec/unit/fixtures_spec.lua` counts): copies of the three fixture EPUBs, each copy's
  CoverBrowser row extracted and then given a public-domain title, author, series and index by
  `BookInfoManager:setBookInfoProperties` (`plugins/coverbrowser.koplugin/bookinfomanager.lua:572-588`, as
  `spec/unit/books_coverbrowser_spec.lua:105-124` does), with `ignore_cover = "Y"` (`:47`) so their tiles draw
  the typographic placeholder of the scripted title (`books.lua:95`); sidecars for `complete` and `reading`
  books; one path-less source book in a series (`Books.add_source`, `books.lua:387-390`; a source record keeps
  its fields, `:141-151`). Enough to draw an under-way, a finished and a not-started series, an up-next book
  that is reading and one not downloaded, a two-author book, at least three letters, and one author whose
  books fill two rows across a series and outside one.
- **Unchanged:** every existing golden, the library's included (D1).
- **Budget:** each capture's `paint_ms` is at most 250 ms, the home's tripwire
  (`spec/emulator/home_capture_spec.lua:7-10`).

## Notes

For the owner, besides the lead decisions D10 to D26 above:

- **The chrome refactor touches cover-grid's freshly built code.** `chrome` moves code cover-grid's tasks
  will have just written and reviewed. It runs under cover-grid's tests and goldens unchanged, and it is
  the first task here; if cover-grid's `library.lua` already splits these parts cleanly, the move is small.
  The preserve criteria are baselined at `b05fe55`, before cover-grid is built; the library specs and
  goldens they run are cover-grid's, so their real comparison point is cover-grid's merge. Re-pinning the
  baseline then is a `--refresh-basis` on this feature.
- **Cover-grid's D13 against AuthorBooksA.** The board draws "Up next in Earthsea" and "Not downloaded" as
  lines under the title (AuthorBooksA:50-53, :77-80); cover-grid's tiles have one title line and the chip on
  the cover's foot. D5 follows cover-grid, and D19 decides the case of both at once. The chip reads "Up next",
  not "Up next in Earthsea": the series name would not fit the chip beside the badge.
- **The strip on finished books.** AuthorBooksA:35, :42, :59 and SeriesBooksC:38 draw a full bar under a
  finished book; cover-grid's strip shows only for a book neither new nor complete (feature.md:169-173).
  The one-author grid keeps cover-grid's tile as it is; the one-series row draws the full bar as its board
  does (D20). Say if the grid should draw it too: that is a change to cover-grid's tile.
- **`book_covers.lua` changes** (Extraction, the cap): its last check forgets the files that did not arrive,
  shared with the featured cover and the library. Without it, D2's "a later show" fails whenever another
  request ends the long extraction.
- **The looks pass 500 lines.** `looks/diner.lua` is 487 lines and `looks/editorial.lua` 462 today;
  cover-grid's `library` block and this `shelf` block take both past 500 (AGENTS.md: a signal to plan a
  split). Not split here; a split of the looks' data is its own chore.
- **Hold on these screens** offers nothing until `library/context-menu` (F-l0kw8m) lands (D9); that
  feature's spec should name the series and authors screens' `hit` kinds when it is specified.
- **Extraction at whole-library scale.** On a first show over a library CoverBrowser never indexed, every
  book is asked in one batch and each check reads every pending row; the paint budget covers the first
  paint, not this. The device check (C17) is where it shows.
- The direction doc's "Not drawn yet" items this spec decides without a board: Editorial's series list,
  one series and authors list, Diner's one author (D4, D26), the empty states (D23), a reading book in a
  series (D20), a book with no index (D20), long lists (D14), night and the Paperwhite (D24).
