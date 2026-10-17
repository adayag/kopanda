# The Authors window: the letter-grouped list and one author's grid

## Approach

The Authors window, on the chrome and the extraction helper the `series` task adds. Starts after `series`.
Repo lines on `main` at `b05fe55`. Feature sections "Authors", "The fit", decisions D5, D6, D9, D10, D11,
D13, D14, D16, D17, D19, D23.

1. **`kopanda.koplugin/authors_screen.lua` (`AuthorsScreen`),** a window on `LibraryChrome` with
   `screen = "authors"` and `where = "authors"`. `AuthorsScreen.show{ view, page, started }` with `view`
   `{ kind = "list" }` or `{ kind = "author", name }`; `screen:go(view, page)`.
2. **Build:** `Books.all()` once per show, `ShelfOrder.authors(records)`, and for one author
   `ShelfOrder.series(records, progress_of)` (the up-next marks over whole series, D16) and
   `ShelfOrder.author_books(entry, series, progress_of)`, a progress table read once per book per build.
   - The list: the header (D10's count, "Authors", the `shelf_label` "By surname",
     `shelf.authors_fill_color`), `ShelfOrder.pages` over each author row's height with each letter group's
     cost, the page's `ShelfRows.group`s (a group continued from the page before drawn with its letter,
     `repeats`), the pager.
   - One author: the header with the back control "Authors" and D10's count over the name; the page's
     `LibraryTiles.book` tiles in three columns and two rows at `LibraryTiles.geometry` with
     `shelf.author_grid.cover_h`, the up-next ones with the "Up next" chip (D5, D19); `LibraryOrder.page`'s
     six-a-page slicing (order task.md:20-21), or the same slice by hand if it is not exported; the pager.
   - The empty note (D23); an author view whose name no entry has any more shows the list at page 1.
3. **`NavBar`:** `ACTIVE.authors = "authors"` (`nav_bar.lua:32-33`, its comment changed); the Home branch
   (`:70-72`) as for the other chrome windows.
4. **Taps:** an author row shows that author at page 1; back shows the list at the page holding that author
   (D17); a book tile as the series window's book rows (open with the `on_open` hook, path-less nothing).
   `AuthorsScreen.hit(x, y)` gives `author`, `book` or `empty` (D9).
5. **Extraction:** the chrome's helper, as the series window calls it.
6. `main.lua` requires `authors_screen` (`spec/unit/main_requires_spec.lua`).

## Surfaces

- `kopanda.koplugin/authors_screen.lua` (new), `nav_bar.lua`, `main.lua`; `library_order.lua` only for an
  export of the page slicing.
- `spec/unit/authors_screen_spec.lua` (new), `spec/unit/shelf_gestures_spec.lua`,
  `spec/unit/shelf_lifecycle_spec.lua`, `spec/unit/nav_bar_spec.lua`, `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code, with `Books.all`, `Books.progress` and `BookCovers` stubbed
where needed:

- `authors_screen_spec.lua` (C5): the list's header for 0, 1 and 38 authors in each look; the groups in D13's
  order with their counts; a group split across pages repeating its letter; "#" after "Z"; the pager; Authors
  lit; one author's header ("9 books · 4 finished", and with none finished), six tiles in three columns and
  two rows in D16's order, the up-next tile's chip and a path-less up-next tile's chip and badge; the empty
  note; an author gone showing the list; a rebuild after a variant or size change; the metadata events;
  one `KoPandaSettled{ screen = "authors" }` per show.
- `shelf_gestures_spec.lua` (C6), the authors half: a row tap, back to the page holding the author, a tile tap
  opening a downloaded book, a path-less tile doing nothing, "By surname" reaching the menu zones, paging,
  hold, `AuthorsScreen.hit` for each kind.
- `shelf_lifecycle_spec.lua` (C7): the authors window's request after its first paint; an arrival giving a
  book an author adding that author to the list; close cancelling.
- `nav_bar_spec.lua` (C5): `where = "authors"` lights Authors; Home from it closes the window and shows the
  home.
- `failsafe_spec.lua` (C9): the authors window's raising build, paint, route, tap action and arrival.
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C12) pass with `authors_screen`.

## Edge cases

- An author whose every book is path-less: the grid shows their tiles with badges; nothing opens.
- An author whose name differs only by case from another ("bell hooks", "Bell Hooks"): two entries, adjacent
  by D13's ties.
- One author's series whose next unread is by a co-author: none of this author's tiles is marked (D16).
- The one-author grid's six-a-page slicing ignores D14's height filling: the grid's rows are fixed by the
  fit, as the library's are.
