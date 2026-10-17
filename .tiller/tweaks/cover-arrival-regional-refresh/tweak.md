# A cover arrival refreshes the whole library and parses the tile's sidecar twice

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 5). Traced in code at KOReader
`e1fe1ac`, not measured on a device.

## What

When a cover arrives, `on_arrival` (`kopanda.koplugin/library_covers.lua:46-57`) rebuilds the arrived
tiles and then calls `UIManager:setDirty(library, "ui")` with no region (`:55`). The library's `dimen` is
the whole screen (`library.lua:78`), so the whole panel updates for a change to one tile, about a
twelfth of the screen. CoverBrowser refreshes only each item's rect, with dither
(`plugins/coverbrowser.koplugin/covermenu.lua:144-157`).

The rebuild itself (`library_covers.lua:17-43`) opens the tile's sidecar twice: `Books.get` →
`for_path` → `record(path, true)` is one `dofile`, and `Books.progress(record)` (`:24`) is a second
`dofile` of the same file. `Books.with_progress(record.path)` does both in one open.

Two changes:

1. `setDirty(library, function() return "ui", region, true end)` over the union of the rebuilt tiles'
   rects, widened by the shadow and badge overhang, with the dither flag set.
2. In `rebuild_tiles`, use `Books.with_progress(record.path)` for file books. With the sidecar memo of
   `tweaks/sidecar-progress-memo` this also stops a cover arrival churning the home's one-entry
   `last_read` memo.

## Why

The arrivals come from the 1 s check that runs while an extraction is pending
(`book_covers.lua:176-234`, at most 30 checks). On a library not yet extracted, which is the first days
on the device, every new page brings up to six full-panel "ui" updates within seconds of the turn.
Each one is a visible full flash on colour e-ink plus a redundant sidecar compile.

## Done when

- A unit spec drives `on_arrival` for one record and asserts `setDirty` was called with a region equal
  to that tile's rect plus the overhang, and the dither flag set. It fails on the current code.
- A unit spec counts `DocSettings.openSettingsFile` across `rebuild_tiles` for one file book: 1.
- The dither hint is checked by eye on the device when the plugin is installed (noted in the PR, not a
  gate).
- `bin/check` is green and the library goldens are unchanged.
