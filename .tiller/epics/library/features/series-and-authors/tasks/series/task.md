# The Series window: the list and one series, on the shared chrome

## Approach

The Series window, shown and closed by direct calls; how the rest of KoPanda reaches it is `routing`'s. Starts
after `chrome`, `index` and `rows`. Repo lines on `main` at `b05fe55`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. Feature sections "Series", "Extraction", "Failure behaviour",
decisions D2, D3, D8 to D12, D14, D15, D17, D20, D21, D23.

1. **`kopanda.koplugin/series_screen.lua` (`SeriesScreen`),** a window on `LibraryChrome` with
   `screen = "series"` and `where = "series"`. `SeriesScreen.show{ view, page, started }` with `view`
   `{ kind = "list" }` or `{ kind = "series", name }`; `screen:go(view, page)`.
2. **Build:** `Books.all()` (`books.lua:263-292`) once per show (D8), `ShelfOrder.series(records,
   Books.progress)`, a progress table read once per book per build and shared by both views; then the view:
   - the list: the header (D10's count, "Series", the `shelf_label` "Under way first", `shelf.series_fill_color`),
     `ShelfOrder.pages` over `ShelfRows.height("series", …)` with the space between the header and the pager,
     the page's `ShelfRows.series` rows, the pager;
   - one series: the header with the back control "Series" and D10's aside over the name, the series' books
     as `ShelfRows.book` rows with the next unread marked, paged the same way;
   - the empty note (D23) for no series; a series view whose name no entry has any more shows the list at
     page 1 (D23).
3. **`NavBar`:** `where = "series"` lights no tab (`ACTIVE`, `nav_bar.lua:32-33`, has no `series` key, so the
   bar draws none active, `:114-117`); `NavBar.run`'s Home branch (`:70-72`) closes it before `goHome`, as the
   chrome's windows do.
4. **Taps:** a series row shows that series at page 1; back shows the list at
   `ShelfOrder.page_of(pages, <that series>)` (D17); a downloaded book opens through the chrome's open (cover-grid
   D15, `filemanagerutil.openFile`) with the window's `on_open(view, page)` hook, which `routing` fills (here a
   no-op); a path-less book, nothing. `SeriesScreen.hit(x, y)` gives `series`, `book` or `empty` (D9).
5. **Extraction (D2):** from the next tick after the first paint, `BookCovers.request(records, specs,
   on_arrival, alive)` (`book_covers.lua:144-235`) with every record and the library grid's cover box
   (`LibraryTiles.geometry`); put the request and its arrival handling in `LibraryChrome` as a helper both
   windows call, `alive` testing the window is still shown. `on_arrival` re-reads each record by `Books.get(id)`
   (`books.lua:303-322`), replaces it, rebuilds the index and the view's pages, and sets the window dirty only
   when the shown page's ids, order or covers changed. Closing cancels the check.
6. **The cap in `book_covers.lua`:** the last check (`book_covers.lua:209-223`) clears `asked` for each pending
   file that did not arrive, as a replacing request clears its pending files (`:160-164`), so a later request
   asks for it again. The comment at `:144-150` and `HOOKS.md`'s `extractInBackground` entry gain the cap and
   the screens as askers.
7. `main.lua` requires `series_screen` (`spec/unit/main_requires_spec.lua`).

## Surfaces

- `kopanda.koplugin/series_screen.lua` (new), `library_chrome.lua`, `nav_bar.lua`, `book_covers.lua`,
  `main.lua`, `HOOKS.md`.
- `spec/unit/series_screen_spec.lua` (new), `spec/unit/shelf_gestures_spec.lua` (new),
  `spec/unit/shelf_lifecycle_spec.lua` (new), `spec/unit/book_covers_spec.lua`, `spec/unit/nav_bar_spec.lua`,
  `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code, with `Books.all`, `Books.progress` and `BookCovers` stubbed
where a case needs records the fixture library lacks:

- `series_screen_spec.lua` (C4): the list's header for 0, 1 and 12 series with 0 and 3 under way, in each
  look; the rows in D12's order on page 1 and the rest on page 2; the pager's label and dead arrows; no tab lit;
  one series' header, rows in series order, the next unread marked; the empty note; a series view for a name
  gone showing the list; a rebuild after `Looks.variant` and after the screen size changes; the metadata
  events re-listing; one `KoPandaSettled{ screen = "series" }` per show with a numeric `paint_ms`.
- `shelf_gestures_spec.lua` (C6), the series half: a row tap, back to the page holding the series (a series on
  page 2), a downloaded book through a stubbed `filemanagerutil.openFile` whose pre-callback runs, a path-less
  book doing nothing, a tap on "Under way first" reaching the file manager's menu zones, pager taps, swipes with
  the edge bands exempt, page keys, a hold running nothing, `SeriesScreen.hit` for each kind, the bar first, a
  corner zone on the file manager firing, the touch lock.
- `shelf_lifecycle_spec.lua` (C7): the request's records and specs after the first paint; an arrival that
  gives a book its series rebuilding the list with that series; an arrival changing nothing on the shown page
  leaving the window clean (`UIManager:setDirty` not called); close cancelling.
- `book_covers_spec.lua` (C7): after 30 checks with an extraction still running, a file that did not arrive is
  asked again by the next request; a file that arrived is not; the existing cases unchanged.
- `featured_cover_spec.lua` passes unchanged (C7).
- `nav_bar_spec.lua` (C4): `where = "series"` lights no tab; Home from it closes the window and shows the home.
- `failsafe_spec.lua` (C9, C11): a raising build, paint, gesture route, tap action, progress read, request and
  arrival, each as the feature says; the existing cases unchanged.
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C12) pass with `series_screen` and the HOOKS.md change.

## Edge cases

- Opening a series screen while the library's request is in flight: showing the window closes the library
  (one window at a time), whose close cancels its check; this window's request then replaces that extraction.
- A library with a thousand books: the index build reads each series book's progress once (one sidecar each,
  `books.lua:338-356`); books in no series are not read. Report `paint_ms` on the fixture and on the
  owner's library in the PR.
- An arrival while a book row's tap is pending: the tap uses the page built at that moment; rows have fixed
  heights per kind, so a rebuilt page keeps its boxes unless items moved, and then the next tap hits the new
  page.
- The chrome's extraction helper is shared with `authors`; its tests live here, and `authors` adds only its
  own cases.
