# A library page turn re-lists the folder

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, findings 1 and 8). Traced in code at KOReader
`e1fe1ac`, not measured on a device.

## What

A page turn rebuilds the library from scratch. `Library:turn` → `go` → `rebuild`
(`kopanda.koplugin/library.lua:113-118`, `:105-110`, `:91-100`) calls `LibraryView.build`, whose `fill`
(`library_view.lua:273-325`) lists the folder again (`Books.folder`, `:284`), sorts and filters it again
with a fresh history map (`LibraryOrder.view` and `history_times()`, `:286`), and only then slices the
page (`:288`). A turn changes nothing but the slice and the pager.

The listing is the expensive part and it grows with the folder. `Books.folder` (`books.lua:254-271`)
scans with `lfs.dir`, `lfs.attributes` and `hasProvider` per entry (`:208-250`), then `record` per file
(`:118-141`): one CoverBrowser row read (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325-333`,
which stats and calls `hasProvider` again) and one `realpath` (`:132`, a 4 KB `ffi.new` each,
`base/ffi/util.lua:171-176`). `history_times` (`library_order.lua:152-164`) runs one `realpath` per
history entry on top. The picker rows (`library_pickers.lua:49-53`) build the same way, even when the
row tapped is the choice already in force.

Keep the listing, the history times and the per-build progress memo on the library from the build that
listed that folder. A turn slices the kept items. A picker choice re-filters and re-sorts the kept
listing. A show, a folder change and `refresh()` list again, which keeps the cover-grid design's rule
that the library re-lists on every show it builds
(`.tiller/epics/library/features/cover-grid/feature.md:136-141`): a turn is not a show, and a metadata
event still lists again.

The `realpath` in `history_times` stays: KOReader's `updateItem`, `updateItems` and `updateItemsByPath`
(`frontend/readhistory.lua:173-204`) store the path as given, so dropping it would miss renamed or moved
entries. Once the listing is kept it runs once per listing, not per turn.

Rebuilding only the tiles and the pager on a turn, with a regional refresh, is a separate medium step
and not part of this tweak.

## Why

Paging is the library's most frequent action. For a folder of N books a turn today costs about 3N stats,
2N `hasProvider` calls, N SQLite row reads, N plus the history length `realpath`s and a sort, before
the six tiles are even built. At 150 books that is an estimated 100 to 300 ms per turn on the Kindle,
more under a status filter. The emulator fixture has three books, so neither the goldens nor the paint
budget can see it.

## Done when

- A unit spec over a stubbed folder of at least 13 books (three pages) counts `Books.folder` and
  `getBookInfo(_, false)` calls: `turn(1)` and `turn(-1)` make 0 of each. `go` to another folder, a
  picker choice followed by `go(dir, 1)`, and `refresh()` each list exactly once. The spec fails on the
  current code.
- A unit spec asserts that page 2 reached by a turn shows the same tiles (ids, order, page count) as a
  library built directly at page 2.
- A unit spec counts `ffiutil.realpath` over a stubbed history of 50 entries: two builds call it 50
  times in total, and a turn 0 times.
- `bin/check` is green and the library goldens are unchanged.
