# The series and authors screens re-sort every page turn and refresh on every metadata event

Found by the merge of TW-cypagc onto main and the review of TW-zih0x2
(`.tiller/reviews/2026-10-17-efficiency-pass2-followups.md`, finding 3). Traced in code at KOReader
`e1fe1ac`, not measured on a device. The series-and-authors feature landed the same day these
library tweaks were built, so it did not get them.

## What

`series_screen.lua` and `authors_screen.lua` read `Books.all()` once at init into `self.records`
and re-read only in `refresh()`, so a page turn does not re-list. But each build re-runs
`ShelfOrder.series` or `ShelfOrder.authors` with a fresh `progress_once()` memo
(`series_screen.lua:51-56`, `authors_screen.lua:54-60`), so every page turn re-sorts the whole set
and re-reads every book's progress (from the shared memo since TW-3tfybs, so no sidecar reopens; the
sort and the memo walk remain). And the chrome's `Window` handles `BookMetadataChanged` and
`InvalidateMetadataCache` by refreshing on each (`library_chrome.lua`); the library overrides them to
mark itself stale and rebuild once from one `nextTick` (TW-zih0x2), these two screens do not, so one
metadata edit rebuilds each of them two or three times.

Keep the sorted rows across page turns as the library keeps its listing (a show, `refresh()` and
the metadata events sort again), and give both screens the library's coalesced refresh: move
`refresh_soon` into the chrome's `Window`, with `Library` no longer overriding, or override in both
screens the same way. Decide in the PR which.

## Why

The same two shapes the library just lost: paging is the most frequent action on these screens too,
and a sort over every book plus a progress read per book runs on each turn; a metadata edit costs
two or three builds.

## Done when

- A unit spec per screen: a page turn runs `ShelfOrder.series`/`authors` 0 times and `Books.progress`
  0 times; a show, `refresh()` and a metadata event run the sort once. It fails on the current code.
- A unit spec per screen: `InvalidateMetadataCache` then `BookMetadataChanged` (and the three-event
  case) build the screen once; a screen closed before the tick builds 0 times.
- `bin/check` is green and the series and authors goldens are unchanged.
