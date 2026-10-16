# KoPanda — library direction (2026-10-16)

Decided on 2026-10-16 from a design canvas of the stage 5 library screens (`library` epic). The canvas
is published at https://claude.ai/artifact/Bynh1vEYJoCabpaPyUtE6G; a snapshot of its files is in
`2026-10-16-kopanda-library-screens/` beside this doc. It extends `2026-10-13-kopanda-ui-direction.md`:
the looks, tokens, gestures and sheet styles there still govern, and the 2026-10-13 canvas's two library
boards are superseded by this canvas's grids. Where a feature spec and this doc disagree on behaviour,
the spec wins.

Every board is the Kindle Colorsoft at half size (632×840 for 1264×1680). C is Diner, A is Editorial.

## Boards

| Board | Shows |
|---|---|
| C · Library grid, A · Library grid | Header with count and the sort and status pickers, a folder tile, five books (one not downloaded), a pager, the nav bar |
| C · Tap the sort picker | Sort sheet: Recent, Title, Author, Series, remembered for this folder |
| C · Hold on a book, A · Hold on a book | Open, Book details, Read status ›, More by this author ›, Add to the home, Delete… |
| C · Hold on a folder tile | Open, Set as library root, Hide |
| C · Hold on empty space | Sort ›, Show ›, Refresh covers |
| C · Series, C · One series | Series list with progress chips; one series in series order, next unread marked, a not-downloaded book |
| C · Authors, A · One author | Authors under surname letter dividers with counts; one author's books as a grid |

## Decisions (owner, 2026-10-16)

| Topic | Decision |
|---|---|
| Covers | The boards' solid blocks are placeholders; the device draws each book's real cover in the look's frame. |
| Progress strip | Under the cover, between the cover and the title, never over the artwork. Diner: 14 px, 2 px ink outline, mustard fill on paper. Editorial: 4 px ink on a hairline track. Tiles without progress (folders, books not downloaded) keep an empty slot of the same height so titles align. |
| Sub-folders | A folder tile in the grid, not the file browser. Inside a folder the header needs a way back up (not yet drawn). |
| Grid density | Always three columns. No density setting, so "Display (grid density)" leaves the empty-space menu and no schema key is added. |
| Not-downloaded badge | Kept as the design target and built with the grid: a download badge on the cover and a "Not downloaded" label. Nothing shows it until a remote source exists. |
| Authors | Sorted by surname (the last word, with prefixes such as "Le" and "de" kept with it), shown as written. A book with two authors appears under both and counts for both. |
| Series list | Series under way first, then the rest A to Z. One series lists its books in series order with the next unread marked. Series is not a nav tab, so no tab is lit there. |

## Consequences for the features

- `library/cover-grid` (F-2nt0fx): folder tiles and navigation into folders are in scope; the progress
  strip sits under the cover; the not-downloaded badge is built.
- `library/context-menu` (F-l0kw8m): the empty-space sheet drops "Display (grid density)".
- `library/series-and-authors` (F-yaihx9): the surname, multi-author and series-order rules above.

## Not drawn yet

Inside a folder (the way back up), the delete confirm, an empty library, and the Paperwhite and night
variants.
