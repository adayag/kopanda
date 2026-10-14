# Book index keyed by id with cover and metadata cache

## Summary

The library's data: every book KoPanda knows, identified by an id rather than a path, with an optional
local file, metadata and a cover cache keyed by that id (design §1b, "Noted for after the MVP"). The
featured book widget switches to it.

## Behavior

- A book record has an id, title, authors, series and index, an optional path, read status and
  progress, and cover availability. Books with a path are indexed from the library folder through
  CoverBrowser's cache; a record with no path is legal and renders with its cached cover and a "not
  downloaded" mark, so a later source can add books without changing the grid.
- An index over authors and series is derived from the records and kept current as books change.
- The cover cache stores one scaled cover per id and size; misses ask CoverBrowser's extractor and
  repaint on arrival.
- `home/featured-book` reads through the model; its behaviour and goldens are unchanged.
- Specs cover indexing, a path-less record, the author and series indexes, and cache misses.

## Notes

Where CoverBrowser's metadata lives and what it exposes for series is a specify-time spike with
citations into `bookinfomanager.lua`. The CWNG source itself is not this feature; this feature makes it
possible.
