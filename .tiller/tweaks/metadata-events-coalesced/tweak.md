# One metadata change rebuilds the library two or three times

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 11). Traced in code at KOReader
`e1fe1ac`, not measured on a device.

## What

KOReader's book-info editor broadcasts `InvalidateMetadataCache` and then `BookMetadataChanged` for one
change (`frontend/apps/filemanager/filemanagerbookinfo.lua:276-277`), and a third `BookMetadataChanged`
when the summary changed too (`:280`). A custom cover does the first two (`:556-557`). The library
turns each into `refresh()` (`library.lua:364-370`), a full build: listing, sidecars, folder counts and
six cover decodes.

Both handlers set `self.stale = true` and schedule one `nextTick` that rebuilds once if still stale.

## Why

Low today, since the library's hold opens nothing yet. Each extra event is a whole library build
(`tweaks/library-listing-kept`'s cost), and the context menu feature will make metadata edits
reachable from the library.

## Done when

- A unit spec broadcasts `InvalidateMetadataCache` then `BookMetadataChanged` (and the three-event
  case) to a shown library and counts `LibraryView.build`: 1. It fails on the current code.
- `bin/check` is green and the library goldens are unchanged.
