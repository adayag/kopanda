# Series and authors tokens, row widgets and the one-author tile, fitted

## Approach

The look side of both screens: tokens, one widget of each row kind, the one-author tile's chip, and the fit.
No window. Repo lines on `main` at `b05fe55`; boards are `.tiller/design/2026-10-16-kopanda-library-screens/`.
Feature sections "Tokens", "The fit", decisions D5, D14, D19 to D22, D24, D26. Starts once cover-grid has
merged: it uses `LibraryTiles` and cover-grid's `library` tokens.

1. **Tokens.** The feature's `shelf` table and its type parts into `looks/diner.lua` and
   `looks/editorial.lua` with identical paths, each value commented with its board line, or "lead: by analogy
   with <board>:<line>" where the board is undrawn (D26). Colours name existing roles only, never `hairline`
   in Diner nor `outline`, `mustard`, `pink` or `teal` in Editorial, all false there by day
   (`looks/diner.lua:25-26`, `looks/editorial.lua:26-30`); a position is a number (`badge_inset`, negative for
   Diner's overhang). By `looks_spec.lua`'s rules (`spec/unit/looks_spec.lua:83-135`, `:196-240`).
2. **Icons.** `back`, `forward` and `download` gain "series" and "authors" in `used_in` (`icons.lua:52`, and
   the two entries cover-grid adds). Neither the swatch nor the catalog reads `used_in`
   (`swatch.lua:266`, `bin/catalog-json.lua:101`), so no golden or catalog is regenerated.
3. **`kopanda.koplugin/shelf_rows.lua` (`ShelfRows`),** each widget of a fixed height for its kind, text set
   with no `text_size` in its ctx (D22), as cover-grid's tiles are (tiles task.md:22-25):
   - `ShelfRows.series(entry, width, ctx)`: the row box (Diner outline and hard shadow, Editorial a rule
     below), the stack (D21: up to three covers at `shelf.stack`'s size, the first in front, offset as
     SeriesC:29-33), the name and sub-line each one line through `Typeset.line` with `max_width`, which
     ellipsises (`typeset.lua:47-86`), and the chip by state (D3, D10).
   - `ShelfRows.book(record, progress, mark, width, ctx)`: SeriesBooksC's row (D20), `mark` saying whether it
     is the up-next one (its fill, shadow and `shelf.next.text_color`); the bar drawn by cover-grid's strip
     drawing (tiles task.md:32-34) at `shelf.book.bar_*`; the `download` badge on a path-less book's cover
     (SeriesBooksC:53-56).
   - `ShelfRows.group(letter, authors, repeats, width, ctx)`: the letter column and the rows (AuthorsC:28-37),
     with a row's count "N books ›" / "1 book ›".
   - Small covers (D21): `BookCovers.read(record, w, h)` (`book_covers.lua:80-87`) in the look's frame, freed
     with the widget; with none, a plain `cover`-role fill. Reuse cover-grid's generalised `CoverBox`
     (tiles task.md:28-31) with no placeholder lettering, rather than a new box.
   - `ShelfRows.height(kind, width, ctx)` for each kind, so `ShelfOrder.pages` gets heights without building
     a page; a group's `group_cost`.
4. **The one-author tile.** `LibraryTiles.book` gains an optional chip `{ label = "Up next" }` on the cover's
   foot, at the place of cover-grid's "Not downloaded" chip (D5); when both apply the "Up next" chip replaces
   it and the badge stays (D19). `LibraryTiles.geometry` takes an optional cover height so the one-author
   grid uses `shelf.author_grid.cover_h`; the library's tiles and goldens do not change.
5. **The fit (feature "The fit").** At the Colorsoft (`harness.at_colorsoft`, `spec/plugin_harness.lua:154-183`)
   and the Paperwhite (cover-grid's helper, tiles task.md:42-43), both looks: the one-author header (back
   control, aside, title, from `shelf.detail` and the chrome's header frame) + the grid's top padding + two
   rows of tiles and the row gap + the pager + `NavBar.height` ≤ the screen's height; then step
   `shelf.author_grid.cover_h` down by board pixels until it passes, each changed value commented "D14: board
   N". At the Colorsoft the three lists' heights hold at least the boards' counts (five, three, seven rows in
   five groups); a failing count stops the task with the measured heights for the lead.
6. `main.lua` requires `shelf_rows` (`spec/unit/main_requires_spec.lua`).

## Surfaces

- `kopanda.koplugin/looks/diner.lua`, `looks/editorial.lua`, `icons.lua`, `shelf_rows.lua` (new),
  `library_tiles.lua`, `main.lua`.
- `spec/unit/shelf_rows_spec.lua` (new), `spec/unit/library_tiles_spec.lua`, `spec/unit/looks_spec.lua`,
  `spec/unit/icons_spec.lua`.

## Tests

Written first, each run failing before the code:

- `shelf_rows_spec.lua` (C3): a series row for each state with its chip text, and a stack of one, two and
  three covers with the first in front (its box left-most and lowest); a sub-line too long for the row
  ellipsised; a one-series row for `complete` (full bar, Finished), `reading` with a percent (bar, no chip),
  the up-next new book (note, Up next, the fill sampled as `mustard` in Diner), a path-less book (badge,
  line, Not downloaded), the up-next path-less book (fill and Not downloaded, D19), a book with no index (a
  blank index column, the same height); an author group's letter and rows, a `repeats` group; every widget's
  height equal to `ShelfRows.height` for its kind; paint in day, night and grey without error, sampling a
  chip's fill per look; Diner's up-next row text set in `on_accent` at night; the fit cases at both sizes in
  both looks; the lists' counts at the Colorsoft.
- `library_tiles_spec.lua` (C3): a tile with the Up next chip, and with Up next on a path-less record (the
  chip reads Up next, the badge is there), each the same height as a plain tile; a geometry with the
  one-author cover height; every existing case unchanged.
- `looks_spec.lua` (C2): its rules over the new paths; a case that both looks have every `shelf.*` path and
  the new type parts.
- `icons_spec.lua` (C2): `back`, `forward` and `download` name "series" and "authors".
- `schema_spec.lua` passes unchanged (C2); the swatch and library goldens pass unchanged (C10, C14).

## Edge cases

- Typeset's parts carry one colour each: `Typeset.line(part, text, max_width, ctx)` reads the role from
  `part.color` (`typeset.lua:49-51`), so the up-next row sets its text with copies of its parts whose `color`
  is `shelf.next.text_color`, the look's parts left as they are.
- Diner's badge overhang (−10) reaches past the 64-px cover into the row's gap; it is painted inside the
  row, after the cover, as cover-grid's tile paints its own (tiles task.md:37-40).
- A series of one book: a stack of one cover, no offset.
- The Paperwhite is 28 px narrower and 32 px shorter; a token that passes on one profile only is not enough.
- If the one-author cover height needs more than 12 board px off its starting value to fit, stop and bring the
  numbers to the lead, as cover-grid's `tiles` task does.
