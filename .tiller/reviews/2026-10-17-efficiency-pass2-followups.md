# Efficiency pass 2: follow-ups from the item reviews

Findings the independent reviewers raised while reviewing the twelve shelf items merged in PR #42
(2026-10-17), outside each item's contract. Paths are relative to `kopanda.koplugin/` unless they start
with `frontend/`, `base/` or `plugins/` (KOReader, pinned e1fe1ac). Line numbers are at main after
the merge (bf3280f). Not measured on a device.

## 1. Another key's failed state write leaves the chapter stale with the retry flag clear

From the review of B-e2tfz0. `record_chapter` (`main.lua`, the `chapter_unsaved` flag) retries only
after its own write failed. `util.writeToFile` opens the state file with `"wb"` (`frontend/util.lua:1130`),
which truncates it before a write that then fails on a full disk. If another module's `State.set`
fails that way (`library_order.lua`'s `write`, `studio_menu.lua`, `menu_entries.lua`), the
`featured_chapter*` keys are gone from disk but still in LuaSettings' cache, `chapter_unsaved` is
false, and the next close at the same chapter skips the write that would have repaired the file. At
restart `LuaSettings:open` falls back to `state.lua.old` (`frontend/luasettings.lua:31-44`), which
rotates only when the file is older than 60 s (`:255-265`), so it can hold an older chapter. Fix:
`state.lua` remembers whether its last write failed (`State.unsaved()`), and `record_chapter` skips
only when neither flag is set; that could replace the module-local flag. Test: a `State.set("x", 1)`
that fails through a `util.writeToFile` stub that truncates, then a close at the chapter already
recorded writes once and `dofile` shows it.

## 2. A cover arrival evicts the featured book's doc_props anchor

From the reviews of TW-bpvicu and TW-3tfybs and the merge of the two. `Books.with_progress` keeps
the doc_props of the last sidecar it opened in a one-entry `last_props` (`books.lua`, after the
`reads` memo). The library's cover-arrival rebuild reads a file book through `with_progress`
(`library_covers.lua`, `read_again`), so each arrival moves the anchor off the home's featured book,
and the next home build opens the featured sidecar once more for its doc_props. Bounded (one small
open per return home after an arrival) and only while covers are still being extracted. Fix: keep
doc_props per path alongside the progress memo (bounded by the same key), or give the arrival a read
that needs no doc_props (`Books.get` plus the memoised `Books.progress` opens once now that the
memo serves progress, but `record(path, true)` still opens for the title). Test: an arrival, then
`FeaturedBook.current()`, opens 0 sidecars.

## 3. The series and authors screens re-sort every page turn and refresh on every metadata event

From the merge of TW-cypagc onto main and the review of TW-zih0x2. `series_screen.lua` and
`authors_screen.lua` read `Books.all()` once at init into `self.records` and re-read only in
`refresh()`, so a page turn does not re-list; but each build re-runs `ShelfOrder.series` or
`ShelfOrder.authors` with a fresh `progress_once()` memo (`series_screen.lua:51-56`,
`authors_screen.lua:54-60`), so every page turn re-sorts and re-reads progress (the progress now comes
from the shared memo, so no sidecar is reopened; the sort remains). The chrome's `Window` handles
`BookMetadataChanged` and `InvalidateMetadataCache` by refreshing on each (`library_chrome.lua`);
the library overrides them to coalesce (TW-zih0x2), these two screens do not, so one metadata edit
rebuilds them two or three times. Fix: keep the sorted rows across turns as the library keeps its
listing, and share the library's `refresh_soon` (move it to the chrome, or override in both
screens). Tests as the library's: a turn runs `ShelfOrder.*` 0 times; two or three events build once.

## 4. The sheets and device-menus specs do not describe the More-row paging

From the build and review of B-0vcqvc. `.tiller/epics/home/features/sheets/feature.md:143` says of a
sheet overflowing the screen "Only a long folder can do that", and
`.tiller/epics/home/features/device-menus/feature.md:394` (the Plugin row of the picker table) does
not mention paging. Since B-0vcqvc a sheet spec may carry `more = { label, run }`, and the entry
picker pages its Plugin list through a "More…" row. Those are accepted feature texts, so the change is
an amendment, not an edit.
