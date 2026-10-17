# Sidecars are parsed for every book on every library build under a filter or a folder tile

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 2). Traced in code at KOReader
`e1fe1ac`, not measured on a device.

## What

Two paths parse a book's whole sidecar on every library build, with no memo across builds:

- **The status filter.** `LibraryOrder.view` asks each record's progress (`library_order.lua:126`)
  through the per-build memo in `fill` (`library_view.lua:278-283`) → `Books.progress`
  (`books.lua:404-406`) → `file_progress` (`:369-371`) → `sidecar` (`:83-89`). Each call runs
  `DocSettings:findSidecarFile` (two or three stats, `frontend/docsettings.lua:159-175`) and
  `openSettingsFile`, which `dofile`s the file (`:301-314`). Under Reading or Finished that is every
  book in the folder, on every build.
- **The folder tiles.** `folder_counts` (`library_view.lua:207-216`, called at `:307`) runs a full
  `Books.folder(sub)` on each sub-folder shown, so a scan plus `record()` per book (a CoverBrowser row
  read and a `realpath`, neither of which a count needs), and then `Books.progress` per book only to
  count `reading`. The per-build memo is keyed by record table, and these are fresh tables, so it never
  hits. Folders sort first (`library_order.lua:119-123`), so page 1 of a folder with sub-folders shows
  up to six of them, each listed and parsed on every show of the root, every return to it, every turn
  back to page 1 and every picker choice.

The only cross-build memo today is `last_read` (`books.lua:20-22`, `:377-399`), one entry for the
home's featured book, from TW-wghsy7.

Two changes:

1. Folder counts from the scan alone: a `Books.folder` variant or a `Books.count(dir)` that returns
   the file list without `record()`, then progress per file path.
2. A library-wide progress memo keyed by sidecar file path, mtime and size, holding only
   `{ status, percent, pages, md5 }`, not `doc_props`, whose description is unbounded. A repeat then
   costs `findSidecarFile`'s stats plus one `lfs.attributes`, not a `dofile`. This generalises
   TW-wghsy7's one-entry memo with the same exact-invalidation key. Return copies, or document the
   entries as read-only: `books.lua:430` already returns a cached table by reference, which matters
   more once every tile shares the memo.

## Why

A read book's sidecar holds its stats, annotations and bookmarks, often 5 to 50 KB of Lua, an
estimated 2 to 10 ms each to compile on the Kindle. Six sub-folders of 30 books is 180 `dofile`s on
every build of the root. A flat folder under All pays nothing today, so the gain depends on the
owner's folder layout and filter use, which are unknown.

## Done when

- A unit spec spies on `DocSettings.openSettingsFile` and `bim.getBookInfo`: two builds of a root with
  two folder tiles of 10 books each open 20 sidecars on the first build and 0 on the second; re-dating
  one sidecar opens exactly 1; `folder_counts` calls `getBookInfo` 0 times. The spec fails on the
  current code.
- A unit spec builds a Reading-filter library over 10 books twice: 10 sidecars opened, then 0.
- The memo holds no `doc_props`, and a spec shows a caller cannot change a memoised entry (copies, or
  the read-only contract is documented at the function).
- `bin/check` is green and the library goldens are unchanged.
