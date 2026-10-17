# The empty-space sheet: Sort, Show, Refresh covers and Hidden folders

## Approach

The hold on empty space, and the cover refresh. Starts after `folder-sheet` (the hidden set) and `icons`
(`sort`, `filter`, `refresh`, `eye_off`). Repo lines on `main` at `5d8a955`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`; cover-grid's `library.lua` and `library_pickers.lua` read as merged.
Feature sections "The empty-space sheet", "Tokens", decisions D1, D9, D10, D15 to D17; criteria C2, C6, C7, C8.

1. **Tokens and a part:** `sheet.library_empty_band_color` (Diner `mustard`, HoldEmptyC:35; Editorial false),
   `sheet.sort_chip_color` (Diner `paper`, :47) and `sheet.show_chip_color` (Diner `pink`, :54; Editorial
   false for both, as `status_chip_color`, `looks/editorial.lua:141`), and the part `sheet_chip_plain`
   (Diner `display` 11 caps 0.08 `ink`, :47; Editorial as its `sheet_chip`). `sheet.lua` sets a chip's text in
   `sheet_chip_plain` when the chip's fill role is `paper` (today every chip takes `sheet_chip`,
   `sheet.lua:243-253`); every existing chip is mustard or teal (`looks/diner.lua:143-144`), so none moves.
2. **`LibrarySheets.empty(library, opts)`,** dispatched for a library `empty` hit and for a hold with no kind
   (the header, the pager; D15): band and name `library_empty` (D16); header `{ aside_above = "this folder",
   heading = <the folder's name, "Library" at the root>, label = <the count> }` (HoldEmptyC:36-40), the count
   the very text the library's header draws (cover-grid feature.md:149-151; read the merged function and call
   it, not a copy). Rows:
   - **Sort** (`sort`), `detail` the sort's short label and " ›", `chip = "sort"`: `LibraryPickers.sort(library)`
     (pickers task.md:27-30). The short labels are the header pickers' ("Recent", "Title", "Author",
     "Series"; cover-grid feature.md:154-156).
   - **Show** (`filter`), `detail` the status's short label and " ›", `chip = "show"`:
     `LibraryPickers.status(library)`.
   - **Refresh covers** (`refresh`), `sublabel` "Re-reads covers for this folder" (:60): step 3. Greyed
     (`muted`, no `run`) when CoverBrowser is disabled, by the same test `BookCovers` makes
     (`book_covers.lua:25-31`), exposed for it.
   - **Hidden folders** (`eye_off`), `detail` "›", only when `LibraryOrder.is_hidden` names a sub-folder
     `Books.folder(dir).folders` lists: step 4.
3. **Refresh covers (D9):**
   - `BookCovers.forget(paths)` (new, `book_covers.lua`): for each path, `bim:deleteBookInfo(path)`
     (`plugins/coverbrowser.koplugin/bookinfomanager.lua:592-600`), `BookList.resetBookInfoCache(path)`
     (`frontend/ui/widget/booklist.lua:328-330`), as CoverBrowser's own refresh pairs them
     (`plugins/coverbrowser.koplugin/main.lua:596-606`, `:533-546`), and `asked[path] = nil`
     (`book_covers.lua:20`); a path in the request in flight is dropped from `pending` too, so its check does
     not report the deleted row. A raising delete is logged and that path left as it was.
   - The row's `run`: the paths of `Books.folder(dir).books` with a `path` (sources have none,
     `books.lua:141-151`), `BookCovers.forget(paths)`, then the library re-lists at its page and, from the
     tick after that paint, `BookCovers.request(those records, the grid's cover specs, the library's
     on_arrival, alive)` (cover-grid feature.md:298-302). `BookCovers.wants` asks for every row now missing
     (`book_covers.lua:98-100`), so all of them go in one batch.
   - Open fact: whether the library's own after-paint request for the page (cover-grid feature.md:298-300)
     runs before this one. If it does, this request replaces it, forgetting its pending files and asking
     again for those it repeats (`book_covers.lua:156-164`); if this one runs first, the page's request finds
     its paths in flight and asks nothing new (`:123-142`). Either order ends in one batch for the folder;
     the test asserts that end state, and the code makes the order explicit rather than relying on the tick.
   - Open fact: whether the library's arrival handler tolerates arrived records that are not on the page
     shown. Read it from the merged `library.lua`; if it assumes every arrival is on the page, filter the
     arrivals to the page's tiles before rebuilding, the others landing in CoverBrowser's cache for a later
     page.
4. **Hidden folders:** `LibrarySheets.hidden(library, opts)`, band `library_empty`, name `library_hidden`,
   header `{ aside_above = "tap one to show it again", heading = "Hidden folders", label = <the folder's
   name> }`, flush rows (no icon), one per hidden sub-folder, its name the label, in the grid's folder order
   (`library_order.lua:103-109`). A tap: `LibraryOrder.unhide(path)`, then the library re-lists at its page.
5. **`HOOKS.md`** gains `BookInfoManager:deleteBookInfo` and `BookList.resetBookInfoCache`, with CoverBrowser's
   own refresh as the model and the `ignore_cover` and `ignore_meta` flags lost with the row
   (`bookinfomanager.lua:592-600`; the flags set at `main.lua:567-592`); the extraction entry
   (`HOOKS.md:1050`) gains Refresh covers as an asker.

## Surfaces

- `kopanda.koplugin/library_sheets.lua`, `book_covers.lua`, `sheet.lua` (the plain chip part),
  `looks/diner.lua`, `looks/editorial.lua`, `library.lua` (only if the arrival handler needs step 3's filter),
  `HOOKS.md`.
- `spec/unit/library_sheets_spec.lua`, `spec/unit/book_covers_spec.lua`, `spec/unit/sheet_spec.lua`,
  `spec/unit/looks_spec.lua`, `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code:

- `library_sheets_spec.lua` (C6, C7): an `empty` hit and a header hold show `library_empty` with "this folder",
  "Library" at the root and the folder's name below it, and the header's count in each look; Sort and Show
  carrying the folder's choices and opening the pickers' sheets (their `KoPandaSettled` names); Refresh covers
  greyed with CoverBrowser disabled; with it enabled, a tap deleting the rows of the folder's books (a scratch
  CoverBrowser database, as `spec/unit/books_coverbrowser_spec.lua:105-124` writes rows), re-listing, and
  making one request whose records are every book of the folder, a sub-folder's books not among them; no
  Hidden folders row with none hidden; with one, the row and its sub-sheet listing it, a tap unhiding it and
  the grid showing its tile again.
- `book_covers_spec.lua` (C6): `forget` deletes the row and the cache entry and lets a later `request` ask for
  the path again in the same process; a forgotten pending path is not reported by the check; with
  CoverBrowser disabled, `forget` does nothing and logs nothing; every existing case unchanged.
- `sheet_spec.lua` (C2, C9): a chip on `paper` sets its text in `sheet_chip_plain`; the existing sheets'
  boxes and parts unchanged.
- `looks_spec.lua` (C2) over the new tokens and part.
- `failsafe_spec.lua` (C8): a raising `deleteBookInfo`, a raising request and a raising unhide logged with the
  library as it was.
- `hooks_doc_spec.lua` (C11) passes; review item: the `HOOKS.md` entries for `deleteBookInfo` and
  `resetBookInfoCache` with the lost ignore flags, and Refresh covers on the extraction entry, each with its
  file:line (step 5), which the spec does not find by name.
- Scope check: confirm `bin/check spec/unit/book_covers_spec.lua` runs that file alone.

## Edge cases

- A large folder: the 30-check cap (`book_covers.lua:17-18`) ends the polling while CoverBrowser goes on
  extracting; rows that land later show on the next show or page. Series-and-authors makes the last check
  forget what did not arrive (its feature.md:271-278), so a later request asks again.
- Between the delete and the extraction the tiles show the sidecar's title or the file name
  (`books.lua:107-133`) on the typographic placeholder: visible on e-ink for a moment, and what KOReader's own
  refresh shows in its browser.
- A book CoverBrowser marks unsupported loses that mark with its row and is asked once more; the extraction
  marks it again (`bookinfomanager.lua:422-570`).
- Refresh covers at the root also lists the sources' books (`books.lua:252-256`); they have no `path` and are
  skipped.
- The sort and show chips read the folder's choice at hold time; a pick in the pickers' sheet re-lists, and
  the next hold shows the new choice.
