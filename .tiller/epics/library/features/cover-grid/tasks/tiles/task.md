# Library tokens, three icons and the tile widgets fitted to two rows

## Approach

The look side of the grid: tokens, icons and one tile of each kind, measured so two rows fit. No window.
Repo lines on `main` at `4564444`; boards are `.tiller/design/2026-10-16-kopanda-library-screens/`. Feature
sections "Tokens", "The page", "The fit", decisions D2, D12, D13, D14.

1. **Tokens.** The feature's `library` table and type parts into `looks/diner.lua` and `looks/editorial.lua`
   with identical paths, each value commented with its board line (`looks_spec.lua:83-129`, `:189-238`).
   Colours name existing roles only. A token holding a position is a number (`badge.inset`, negative for
   Diner's overhang), never a string, which `looks_spec.lua:200-212` refuses.
2. **Icons.** `forward`, Lucide's `chevron-right` (the mirror of `icons/back.svg`, `M15 5l-7 7 7 7`), and
   `download`, the board's arrow to a line (Main:67, `M12 4v12M6 11l6 6 6-6M5 20h14`); find the Lucide glyph
   it matches by reading Lucide's source at the version the set came from (expected `arrow-down-to-line`,
   not Lucide's `download`, which has a tray) and name it in the commit. Both into `kopanda.koplugin/icons/`
   at stroke 2 as the set (`spec/unit/icons_spec.lua:95`), registered in `icons.lua` with `used_in` naming
   "library"; `back` and `chevron_down` gain "library". Then `npm run catalog` in `studio/` regenerates
   `studio/src/catalog.json`, and the swatch goldens are regenerated with `KOPANDA_UPDATE_GOLDENS=1 bin/check
   spec/emulator/swatch_golden_spec.lua` and opened before commit.
3. **`kopanda.koplugin/library_tiles.lua` (`LibraryTiles`):**
   - `LibraryTiles.geometry(screen_w, ctx)`: the column boxes (`Layout.columns`, `layout.lua:19-42`, three
     slots, the look's column gap, inside the grid's side padding), the cover box's size, and the tile's
     height: cover + strip gap + strip + title gap + one `tile_title` line (D13). Text is set with no `text_size`
     in its ctx (D12), as `NavBar.height` sets its label (`nav_bar.lua:42-63`).
   - `LibraryTiles.book(record, progress, box, ctx)`, `LibraryTiles.folder(folder, counts, box, ctx)`: one
     widget each, of the geometry's height.
   - The cover: generalise `FeaturedCover`'s `CoverBox` and placeholder (`featured_cover.lua:27-39`,
     `:96-150`) to take a record (`path`, `title`, `authors` list) and the frame's tokens, leaving
     `FeaturedCover.build`'s own output unchanged; the cached cover through `BookCovers.read(record, w, h)`
     (`book_covers.lua:80-87`), freed with the widget.
   - The strip: Diner's outlined mustard strip with `progress.fill_grey`'s hatch on grey, Editorial's ink on
     a hairline track. Factor the featured bar's drawing (`widgets/featured.lua:65-90`, `:246-276`) so both
     use it, the featured bar's look unchanged.
   - Titles in one line through `Typeset.line` with the tile's width as `max_width`, which ellipsises
     (`typeset.lua:47-86`).
   - The badge: a circle (`Paint`, `paint.lua:8-51`) with `download` drawn by `TintedIcon`
     (`tinted_icon.lua:12-58`, freed after), at the corner `library.badge.align` names, `inset` from it.
     Diner's overhang may reach past the tile's column box into the gap; the badge is painted after the
     cover, inside the tile's paint, clipped to nothing.
   - The "Not downloaded" chip on the cover's foot, left of the badge's corner (D13).
4. **The fit and its tightening.** A unit case at the Colorsoft and at the Paperwhite (a helper beside
   `at_colorsoft`, `spec/plugin_harness.lua:154-181`, generalised to take a size, or an `at_paperwhite`),
   both looks: header + grid top padding + 2 × tile height + row gap + pager + `NavBar.height` ≤ screen
   height. The header and pager heights come from `LibraryTiles.header_height(ctx)` and
   `pager_height(ctx)` here, so the screen task builds to the same numbers. Then step the `library` vertical
   tokens down by board pixels, cover height first, header and grid top padding next, the pager last, until
   it passes in both looks on both profiles; each changed value gets a comment "D2: board N".
5. **The swatch's icon grid.** The two icons bring the registry to 31, which wraps the swatch's icon grid
   (`swatch.lua:259-299`, ten cells a row) onto a fourth row, and Diner's palette panels then overflow
   (`spec/unit/swatch_spec.lua:440`, "content 414 in 398" at the Colorsoft). Tighten the grid's cell gap so
   31 icons fit three rows at the Colorsoft and the Paperwhite, leaving icon and label sizes as they are
   (if the gap alone cannot, bring the numbers to the lead before changing anything else);
   the swatch spec passes unchanged, and the swatch goldens are regenerated after this step.

## Surfaces

- `kopanda.koplugin/looks/diner.lua`, `looks/editorial.lua`, `icons.lua`, `icons/` (three SVGs),
  `library_tiles.lua` (new), `featured_cover.lua`, `widgets/featured.lua`, `swatch.lua`, `main.lua`, `HOOKS.md`.
- `studio/src/catalog.json` (regenerated), `spec/goldens/swatch-*` (regenerated).
- `spec/unit/library_tiles_spec.lua` (new), `spec/unit/looks_spec.lua`, `spec/unit/icons_spec.lua`,
  `spec/plugin_harness.lua`.

## Tests

Written first, each run failing before the code:

- `library_tiles_spec.lua` (C4, C5): the fit at both sizes in both looks; a tile's height equal for a
  one-word title, a title too long for one line, a book in progress, a complete book, a path-less record
  and a folder; the strip present for `reading` with a percent and for `abandoned` with one, absent for
  `new` and `complete` and for a path-less record, its slot the same height; the badge and label only on a
  path-less record; a folder's counts with and without reading books; paint in day, night and grey without
  error, sampling the strip's fill colour per look as `nav_bar_spec.lua` samples the bar's.
- `looks_spec.lua` (C3): its existing rules over the new paths; a case that both looks have every
  `library.*` path.
- `icons_spec.lua` (C3): the two files exist at stroke 2 with their `used_in`.
- The swatch goldens (C14), regenerated and opened.
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C13) pass with `library_tiles`.
- `studio_catalog_spec.lua` (C3) passes after `npm run catalog`.
- `featured_cover_spec.lua`, `featured_widget_spec.lua` and the home goldens pass unchanged (the featured
  output is not changed by the factoring).

## Edge cases

- A cover much wider than the box (a landscape image): fitted inside, the frame around the box as the
  featured cover draws it.
- The Paperwhite is 28 px narrower and 32 px shorter than the Colorsoft; the fit runs on both, so a token
  that passes on one only is not enough.
- Diner's `on_accent` for text on mustard and pink keeps dark text at night (`looks/diner.lua:34`).
- The owner's expectation is a cut of about 6–10 board px in all (D13). If the fit needs more than 12 board
  px off the cover height, stop and bring the numbers to the lead before cutting further.
