# The featured book's sidecar is parsed twice per home build

Found by the 2026-10-17 efficiency review (`.tiller/reviews/2026-10-17-efficiency-review.md`, finding 5).
Not measured on a device.

## What

`FeaturedBook.current` reads the featured book's `metadata.epub.lua` sidecar twice per build:

- `featured_book.lua:94-95` → `Books.for_path` (`kopanda.koplugin/books.lua:296-301`) → `record(path, true)`,
  which always opens the sidecar (`:107-112` via `sidecar()` at `:79-85`);
- `featured_book.lua:123` → `Books.progress` → `file_progress` (`books.lua:338-356`), which calls
  `sidecar()` again.

Each `sidecar()` runs `DocSettings:findSidecarFile` (one stat per candidate location) and
`openSettingsFile`, which `dofile`s the file (`frontend/docsettings.lua:159-175`, `:301-314` at
`e1fe1ac`). A build runs on every home show, wake and book close, and the sidecar is re-parsed every
time though it changes only when the reader saves.

Open the sidecar once per build and pass it to both the record and the progress. Then cache
`{ record, progress }` keyed on the sidecar's path, mtime and size, which is exact invalidation.
KOReader's `BookList.getBookInfo` cache is not a drop-in replacement: it goes through
`DocSettings:open`, which can remove files (`docsettings.lua:282-284`), and it carries no md5 or
`doc_props`.

## Why

A sidecar holds the book's annotations, bookmarks and reading stats, often tens to hundreds of KB of
Lua, compiled twice by LuaJIT on the Kindle for every build.

## Done when

- A unit spec counts `DocSettings.openSettingsFile` across one `FeaturedBook.current()`: 1. A repeat
  call with the sidecar's mtime and size unchanged: 0. A changed mtime: 1. The spec fails on the
  current code.
- `bin/check` is green and the home goldens are unchanged.
