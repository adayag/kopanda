# KoPanda efficiency review, second pass: merged and verified

Paths are relative to `kopanda.koplugin/` unless they start with `frontend/`, `base/` or `plugins/` (KOReader, pinned e1fe1ac). Repo `main` at a1f043a; the plugin tree is the same as 7d0f64c apart from TW-hmdt1d (`reading_stats.lua`). Device costs are estimates, since nothing has run on the Colorsoft. "First-pass #n" refers to `.tiller/reviews/2026-10-17-efficiency-review.md`.

The ranking unit is the **library build** (`LibraryView.build`, `library_view.lua:330-345` → `fill` `:273-325`). The library is now the file browser's screen, so a build runs on every library show, every page turn, every folder hop, every picker choice, every metadata event and every return from a book. Its cost grows with the folder and the reading history. The emulator fixture has 3 books in one folder, so neither the goldens nor the 250 ms budget can see findings 1, 2 or 8.

## Ranked findings

### 1. A page turn re-lists the folder and re-reads every book's row, then rebuilds and fully refreshes the whole screen
- **Verdict:** CONFIRMED.
- **Where:**
  - the turn: `library.lua:113-118` → `go` `:105-110` → `rebuild` `:91-100`, with `setDirty(library, "ui")` and no region at `:98`;
  - the build: `library_view.lua:284` (`Books.folder`), `:286` (`LibraryOrder.view` plus `history_times()`), `:288` (the slice);
  - the listing: `books.lua:254-271` → `scan` `:208-250` (`lfs.dir`, `lfs.attributes` and `hasProvider` per entry), then `record` `:118-141` per file. Each record makes one CoverBrowser row read (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325-333`, which runs `lfs.attributes` and `hasProvider` again) and one `realpath` (`books.lua:132`, a 4 KB `ffi.new` each at `base/ffi/util.lua:171-176`).
- **Path and frequency:** every swipe, pager tap and page key (`library_gestures.lua:50-51`, `library.lua:167-172`, `:373-381`), and every picker row (`library_pickers.lua:49-53`). The picker builds again even when the row tapped is the one already chosen.
- **Impact:** high, and it scales with the folder. A turn changes only the six-item slice and the pager. Per turn, a folder of N books costs about 3N stats, 2N `hasProvider` calls, N SQLite row reads, N+H `realpath`s (H = history length) and a sort. On top of that come the header (two chips, the count, the title and the probe lines), `NavBar.new` and a full-screen "ui" update. At 150 books that is an estimated 100-300 ms per turn on the ARM core under All, and more under a status filter (#2). Paging is the library's most frequent action.
- **Fix:**
  1. Keep `Books.folder`'s listing, the history times and the build's progress memo on the library, from the build that listed that folder. A turn slices the kept items. A picker choice re-filters and re-sorts the kept listing. A show, a folder change and `refresh()` list again.
  2. (Second step, separate) On a turn, rebuild only the tiles and the pager, keep the header and the nav bar, and refresh the band from the grid's top to the pager's foot.

  Step 1 keeps the design's rule, "re-lists on every show it builds" (`feature.md:136-141`): a turn is not a show, and a metadata event still lists again.
- **Test:** a unit spec with a stubbed 13-book folder. `turn(1)` calls `Books.folder` 0 times and `getBookInfo(_, false)` 0 times. `go` to another folder, a picker choice followed by `go(dir, 1)`, or `refresh()` each list exactly once. Page 2 reached by a turn has the same tiles (ids, order, pages) as a library built directly at page 2.
- **Size:** step 1 small. Step 2 medium, because it needs regional refresh and a golden check of the page-2 capture.
- **Relation:** the same shape as first-pass #1 (whole screen rebuilt for a change to one part), on the library.

### 2. Sidecars are parsed whole for every book under a status filter, and for every book in each sub-folder whose tile is shown, on every build, with no memo
- **Verdict:** CONFIRMED.
- **Where:**
  - the filter: `library_order.lua:126` → the per-build memo `library_view.lua:278-283` → `Books.progress` `books.lua:404-406` → `file_progress` `:369-371` → `sidecar` `:83-89`. In KOReader, `findSidecarFile` stats 2-3 candidates (`frontend/docsettings.lua:159-175`) and `openSettingsFile` `dofile`s the file (`:301-314`).
  - the folder tiles: `library_view.lua:207-216` (`folder_counts`, called at `:307`) runs a full `Books.folder(sub)` (a scan plus `record()` per book: a CoverBrowser row and a `realpath`, neither of which a count needs), then a `Books.progress` per book only to count `reading`. The per-build memo is keyed by record table, and these are fresh tables, so it never hits.
- **Path and frequency:**
  - Under Reading or Finished: every book in the folder, on every build (#1's list).
  - Folders sort first (`library_order.lua:119-123`), so page 1 of any folder with sub-folders shows up to six folder tiles. Each one lists and parses its whole sub-folder on every show of the root, every return to it, every turn back to page 1 and every picker choice.
  - The only cross-build memo is `last_read` (`books.lua:20-22`, `:377-399`): one entry, for the home's featured book.
- **Impact:** high where the library has sub-folders or a filter is used; nil for a flat folder under All. A read book's sidecar holds stats, annotations and bookmarks, often 5-50 KB of Lua, an estimated 2-10 ms each on device. Six sub-folders of 30 books is 180 `dofile`s per root build. The owner's folder layout on the Kindle is unknown, so this is the question to ask before weighting it.
- **Fix:**
  1. Folder counts from the scan alone: a `Books.folder` variant, or a `Books.count(dir)`, that returns the file list without `record()`. Then progress per file path.
  2. A library-wide progress memo keyed by sidecar file path, mtime and size, holding only `{ status, percent, pages, md5 }`. Do not hold `doc_props`, whose description is unbounded. A repeat then costs `findSidecarFile`'s stats plus one `lfs.attributes`, not a `dofile`. This generalises TW-wghsy7's one-entry `last_read` with the same exact-invalidation key, so no owner call is needed. Return copies, or document the entries as read-only: verify-sidecar's nit 2 (`books.lua:430`, a cached table returned by reference) matters more once every tile shares the memo.
- **Test:** spy on `DocSettings.openSettingsFile` and `bim.getBookInfo`.
  - Two builds of a root with two folder tiles of 10 books open 20 sidecars on the first build and 0 on the second.
  - Re-dating one sidecar opens exactly 1.
  - `folder_counts` calls `getBookInfo` 0 times.
  - A Reading-filter build over 10 books, built twice, opens 10 and then 0.
- **Size:** small (fix 1), small (fix 2). One tweak or two.

### 3. Each tile reads and zstd-decodes its cover from SQLite on every build, and in Diner MuPDF-rescales it; a turn does six
- **Verdict:** CONFIRMED (Diner's scale and the double row read). The larger-thumbnail case is PLAUSIBLE: it depends on which box extracted the cover first on the device.
- **Where:**
  - `library_tiles.lua:253` → `FeaturedCover.framed` (`featured_cover.lua:162-199`): it reads at `w × h` (`:187`) but draws an `ImageWidget` at `inner_w × inner_h` with `scale_factor = 0` (`:197`), which leads to `RenderImage:scaleBlitBuffer` (`frontend/ui/widget/imagewidget.lua:320-343`);
  - the read: `book_covers.lua:58-78` → `getBookInfo(file, true)` (blob, `zstd_uncompress_ctx`, a new Blitbuffer);
  - extraction is asked at the outer box (`library_covers.lua:76`), and Diner's library cover outline is 3 (`looks/diner.lua:618`), about 7 px at 1264 wide.
- **Path and frequency:** six reads, six decompressions and up to six scales per build, so per turn, per show and per return. Paging back redoes the same six.
- **Impact:** medium. An estimated 10-30 ms per tile on ARM, so 60-180 ms per turn.
- **Fix:** read, judge and extract at the inner size, so the scale resolves to 1. This is first-pass #6's fix; do it once in `FeaturedCover.framed` and `BookCovers` for both screens. A tile-bitmap LRU (12-18 tiles is about 5-8 MB at RGB32) is first-pass #12's decision, made for both screens at once.
- **Test:** spy on `RenderImage.scaleBlitBuffer`. A Diner build of a page whose thumbnails were extracted at the library's request scales 0 times. `BookCovers.wants` stays false for those rows.
- **Size:** medium (extraction coupling, golden regeneration). The LRU is an owner decision.
- **Relation:** a new instance of first-pass #6 and #12, multiplied by six and by the paging rate.

### 4. The library's prebuild on close saves no wall time, costs a tile rebuild on every return, and runs a full wasted build on every reload, switch and exit of a book opened from the library
- **Verdict:** CONFIRMED. See the adjudication below. Merged with verify-bug finding 2, the reload waste.
- **Where:** `main.lua:298-317` (`onCloseDocument`; the library branch `:306-312` runs before the `tearing_down` check `:313`) → `library.lua:263-272` → `Library:new` → `init` `:77-87` (a full build). The return is `main.lua:203-209` → `take_pending` `library.lua:291-308` → `Library.show` `:232-252`.
- **Path and frequency:**
  - every book closed to the library;
  - every `reloadDocument` (`frontend/apps/reader/readerui.lua:947-962`), which includes crengine's seamless reload after a background re-render (`frontend/apps/reader/modules/readerrolling.lua:1868`), `:330`, `:1603`, `readertoc.lua:1356` and `readerpagemap.lua:522`;
  - every `switchDocument` (`readerui.lua:969-980`);
  - exit.
- **Impact:** medium. Details in the adjudication.
- **Fix:** remove `Library.prebuild`, `pending`, `drop_pending` and `take_pending`. `show_return` calls `showLibrary{ dir, page, started }`, as B-2o8ya3 did for the home. That is an owner decision because it amends D4 and C8. Until the owner decides, a small interim tweak: check `self.ui.tearing_down` before the library branch in `onCloseDocument`. Verify-bug's mutation B made exactly this move and passed all 141 lifecycle tests; a switch keeps `return_to`, so the next real close still returns to the library. Update `HOOKS.md:98-100` to match.
- **Test:** see the adjudication. For the interim: open from the library, set `reader.tearing_down = true`, `onClose(false)`, then `Library.pending` is nil and `Library.return_to` is kept.
- **Size:** owner decision (removal). The interim is small.
- **Relation:** the library's copy of first-pass #4, which B-2o8ya3 fixed for the home.

### 5. A cover arrival refreshes the whole screen, and the rebuilt tile parses its sidecar twice
- **Verdict:** CONFIRMED.
- **Where:** `library_covers.lua:46-57` → `setDirty(library, "ui")` at `:55` with no region, so the library's `dimen` is the whole screen (`library.lua:78`). The rebuild is `library_covers.lua:17-43`: `Books.get` → `for_path` → `record(path, true)` (one `dofile`), then `Books.progress` (`:24`, a second `dofile` of the same sidecar), then the cover decode (#3).
- **Path and frequency:** each 1 s check that finds arrivals (`book_covers.lua:176-234`, at most 30 checks, only while an extraction is pending). On a library not yet extracted, which is the first days on the device, every new page brings up to six full-screen updates within seconds of the turn.
- **Impact:** medium-low. A visible full-panel "ui" update on colour e-ink, plus CPU, for a change to about 1/12 of the screen. CoverBrowser refreshes only each item's rect, with dither (`plugins/coverbrowser.koplugin/covermenu.lua:144-157`).
- **Fix:** `setDirty(library, function() return "ui", union, true end)` over the rebuilt tiles' rects, widened by the shadow and badge overhang. In `rebuild_tiles`, use `Books.with_progress(record.path)` for file books: one open. With #2's memo this also stops it churning the home's one-entry `last_read`.
- **Test:** `on_arrival` for one record calls `setDirty` with a region equal to that tile's rect plus overhang, and the dither flag set. `openSettingsFile` is called once per rebuilt tile.
- **Size:** small. Check the dither hint by eye on the device.
- **Relation:** the library's copy of first-pass #1's cover-arrival leg.

### 6. The home's quote is shaped and rendered into a fresh full-width RGB32 buffer on every home build, though it changes once a day
- **Verdict:** CONFIRMED path. The buffer size is an estimate.
- **Where:** `widgets/quote.lua:73-137` (`compose` makes a new `TextBoxWidget` each build), `:141` (`Typeset.measured` keeps it only from `height` to `build` within one build). KOReader: `TextBoxWidget` shapes and renders at construction (`frontend/ui/widget/textboxwidget.lua:986`) into `Blitbuffer.new(width, h, TYPE_BBRGB32)` when a colour is in play on a colour screen (`:855-860`).
- **Path and frequency:** every home build, so every show from the file browser, every book close, every wake and every refresh (first-pass #1's triggers), plus every Edit layout measurement (#10).
- **Impact:** medium-low. About 160 characters shaped with xtext and line-broken, then a buffer of roughly 1100 × 190 px × 4 B, about 0.8 MB, allocated and filled each build. The inputs (day index, width, look, variant, text size, source) are fixed for a day.
- **Fix:** a one-entry module memo of the composed text box, keyed on those inputs. `QuoteBox:free` must not free the memoised box; the memo frees the old box when the key changes. Mind `Typeset.measured`'s own `kept.widget:free()` (`typeset.lua:108-111`), which would free a memoised child unless the QuoteBox's `free` skips it.
- **Test:** spy on `TextBoxWidget.new`. Two `Quote.build`s with the same key construct once. After freeing the first home, the second still paints into a scratch buffer with ink. The next day, or another width, constructs again. Goldens unchanged.
- **Size:** small.
- **Relation:** part of first-pass #1's build cost, which that finding only listed. It still pays on the show and close routes that #1's per-slot fix keeps.

### 7. Quick settings re-lays out the whole sheet on every light step; Night lays out twice and Wi-Fi up to three times
- **Verdict:** CONFIRMED for each step and for Night (`act`'s `redraw` uses the old `sheet.variant`, `sheet.lua:154-166`, then `paint` rebuilds because `Looks.variant()` changed, `:242-246`). The Wi-Fi triple is PLAUSIBLE: it depends on `NetworkMgr` calling the callback in the same pass as its broadcast (`frontend/ui/network/manager.lua:109`, `:116`), which was not run.
- **Where:**
  - `sheet.lua:281-292` (`act` → `redraw`) → `SheetLayout.build` → `QuickSettings.body` (`quick_settings.lua:278-413`): every tracked label re-set, one TextWidget per glyph in Diner (`looks/diner.lua:362-372`);
  - Wi-Fi: the `refresh_on` handlers (`sheet.lua:92-96`) plus `redraw_later` (`quick_settings.lua:179-197`).
- **Path and frequency:** every −/+ tap and hold on brightness or warmth, which is what the sheet is mostly for, so many taps in a row.
- **Impact:** medium-low. About 75 glyph widgets re-set per step to change one number and one fill width, an estimated 0.1-0.27 s on device per step (the open-to-paint golden is 9 ms on the Mac).
- **Fix:**
  - (small) In `act`, skip `redraw` when `Looks.variant() ~= sheet.variant`, because the paint rebuilds.
  - (small) For Wi-Fi, drop the immediate redraw or `redraw_later`, after checking that a toggle which never connects (prompt cancelled, Wi-Fi off) still redraws.
  - (medium) Keep handles on each bar's value line and fill, so a step swaps the value and sets the fill width with a regional `setDirty`, falling back to `redraw` when the row's width changes.
- **Test:** spy on `SheetLayout.build`. A Night tap and its paint give exactly 1. A Wi-Fi-on tap, its `NetworkConnected` broadcast and its callback give exactly 1. For the medium step, a `brightness_plus` tap makes at most 1 `Typeset.line` call.
- **Size:** small for the first two, medium for the third.

### 8. `history_times` realpaths every history entry on every build
- **Verdict:** CONFIRMED cost. The fix is amended: the first report's "use `entry.file` directly" is not safe as stated.
- **Where:** `library_order.lua:152-164`, called from `library_view.lua:286` on every build.
- **Path and frequency:** H `realpath`s (each a chain of `lstat`s plus a 4 KB `ffi.new`) per build, so per turn until #1 lands. H grows with every book ever opened.
- **Impact:** low-medium.
- **Why not drop the realpath:** `buildEntry` and `addItem` store realpaths (`frontend/readhistory.lua:26`, `:314`). But `updateItem`, `updateItems` and `updateItemsByPath` (`:173-177`, `:183-189`, `:199-204`, run on rename and move) write the new path as given, without `realpath`. An entry then might not match the record id, which is built with `realpath` (`books.lua:132`).
- **Fix:** with #1 it runs once per listing, which is most of the win. If more is wanted, memo `realpath` by the entry's file string in a session table, bounded by H.
- **Test:** spy on `ffiutil.realpath`. Two builds over a 50-entry history call it 50 times in total, not 100. A turn calls it 0 times once #1 lands.
- **Size:** small. It folds into #1's tweak.

### 9. Every library close rewrites `state.lua` with fsync and a read-back, even when where it was left hasn't changed
- **Verdict:** CONFIRMED.
- **Where:** `library.lua:399` → `LibraryOrder.leave` (`library_order.lua:273-280`) → `write` (`:230-242`) → `State.set` → `state.lua:62-87`: two directory stats, `LuaSettings:flush` (backup rename and directory fsync when the file is older than 60 s, `frontend/luasettings.lua:251-275`; write with fsync, `frontend/util.lua:1124-1142`), then a `dofile` read-back.
- **Path and frequency:**
  - every book opened from the library: `readerui.lua:793-794` closes the file manager → `main.lua:323-335` → `Library.close`;
  - every library→home hop;
  - every show that replaces a shown library (`library.lua:237`).

  Page turns don't write.
- **Impact:** low-medium. One or two fsyncs plus a parse, an estimated 10-50 ms, on the way into a book and on each hop.
- **Fix:** skip the write when `dir` and `page` equal the last value written *successfully*. Do not compare against the in-memory `session.at` or the State cache: both run ahead of the disk after a failed flush, which is the trap in #13.
- **Test:** spy on `State.set`. Closing at the stored folder and page writes 0 times. Closing after a turn writes once. After a failed write, the next close at the same place writes again.
- **Size:** small.
- **Relation:** the same shape as first-pass #9.

### 10. Each edit in Edit layout or Launcher management rebuilds the hidden home under the full-screen editor
- **Verdict:** CONFIRMED.
- **Where:** `edit_layout.lua:112-136` (two `Layout.overflow` passes at `:120`, then `Home.shown:refresh()` at `:132-134`); `launcher_manage.lua:121-141` (`:132-135`). The editor is `covers_fullscreen` (`editor.lua:57`), so `_repaint` never paints the rebuilt home (`frontend/ui/uimanager.lua:1305-1316`), and the editor's `"full"` close (`editor.lua:68`) repaints it anyway.
- **Path and frequency:** every accepted edit (move, add, remove, width, reset). Editing is rare, but each session is many taps in a row.
- **Impact:** medium per tap, low overall. A full home build (stats, sidecar, cover, quote, tracked text, `NavBar.new`) plus a measurement pass (`layout.lua:182-226`) of both the new rows and the previous rows. `Editor` builds a new ctx per rebuild (`editor.lua:240-246`), so `Typeset.measured`'s identity check never carries a measurement across edits. That is an estimated 0.4-1.5 s per tap on device.
- **Fix:** while an editor is shown, mark the home stale and rebuild it once when the editor closes. Keep the accepted rows' overflow in `state`, so each edit measures only the new rows.
- **Test:** with a shown home and `HomeRows.build` stubbed, three moves in each editor build the home 0 times while it is up and once after Done. `Layout.overflow` runs once per accepted layout edit after the first.
- **Size:** small (two modules, unit specs only, goldens unchanged).
- **Relation:** another trigger of first-pass #1.

### 11. One metadata change rebuilds the library two or three times
- **Verdict:** CONFIRMED.
- **Where:** `frontend/apps/filemanager/filemanagerbookinfo.lua:276-277` broadcasts `InvalidateMetadataCache` and then `BookMetadataChanged`, and `:280` adds a third `BookMetadataChanged` when the summary changed too. `:556-557` (custom cover) does the first two. `library.lua:364-370` turns each into `refresh()`, a full build.
- **Impact:** low today, since the library's hold opens nothing yet. Each extra event is a whole #1 build: listing, sidecars, folder counts and six cover decodes.
- **Fix:** both handlers set `self.stale = true` and schedule one `nextTick` that rebuilds once if still stale.
- **Test:** broadcasting the two events (and the three-event case) calls `LibraryView.build` once.
- **Size:** small.

### 12. A pull makes one HTTP connection per file and hashes every file twice in pure Lua, all on the UI thread
- **Verdict:** CONFIRMED for the double read and hash (`push_bundle.lua:170-187`: `sha256_file` at `:180`, then `bundle_hash` `:147-166` reads every file again) and for one request per file (`push_pull.lua:179-194`). The Wi-Fi latency and hash throughput on device are PLAUSIBLE.
- **Path and frequency:** every studio→device pull, which is the owner's tuning loop. That is about 118 files, 2.4 MB.
- **Impact:** low-medium. Plausibly several seconds frozen behind the "Pulling…" note, mostly round trips. The second hash pass is about 0.3-1 s.
- **Fix:**
  - (small) Verify in one pass: walk the manifest in byte order (`check_manifest` already requires it, `push_bundle.lua:93-95`) and feed each block to both hashers.
  - (owner decision, touches the studio) Serve the bundle as one framed stream.
- **Test:** spy on `io.open` in `verify_files`: one open per file. `push_bundle_spec`'s tampered-file and tampered-hash fixtures still refuse.
- **Size:** small. It is still security-sensitive code (it verifies files from outside), so per AGENTS.md it gets the full review with mutations.

### 13. The chapter write's skip can stop a later close from retrying a failed write (correctness regression from TW-soxspy)
- **Verdict:** CONFIRMED. I read the code; the verifier reproduced it by hand.
- **Where:** `main.lua:274-277` compares against the State cache. `state.lua:73-75` `saveSetting`s into the cache before `flush`, so a failed flush leaves the cache ahead of the disk. After `set_many` and the clearing `State.set` (`main.lua:280`) both fail, a later close of the same file and chapter skips, and the disk keeps the older chapter. A restart then shows it (`featured_book.lua:104-114`). That breaks `HOOKS.md:976-977`'s "no earlier chapter survives".
- **Impact:** low, a narrow window: a full or failing disk that recovers, and no other `State.set` flushing the cache before a restart. Any library close does flush it (`library_order.lua:241`).
- **Fix:** a module-local `chapter_unsaved` in `main.lua`, set whenever `set_many` or the clearing `set` returns false and cleared on a successful `set_many`. Skip only when it is false.
- **Test:** the verifier's repro in `prebuild_spec`: write, then both writes failing, then a restored write. The third close writes once, and `dofile` of `state.lua` gives `featured_chapter == ""`.
- **Size:** small (bug).

### 14. The first home build after a book close still opens the Statistics database twice (TW-hmdt1d)
- **Verdict:** CONFIRMED.
- **Where:** `reading_stats.lua:172` and `:218` cross-refresh only when `key` is truthy. The post-close build runs in the same stack as Statistics' `insertDB` (`plugins/statistics.koplugin/main.lua:912-981`), so `stamp` is nil (`reading_stats.lua:48-49`). `read` and `seconds_per_page` then each open. The comment at `:166-167` and the PR say "once".
- **Impact:** low. One extra read-only open per close. The rate query runs either way, and nothing is stale.
- **Fix:** correct the comment and the HOOKS note to "once when the files are settled". Sharing the connection in-window would need a per-build scratch memo and isn't worth it.
- **Test:** none for the wording. If the code route is chosen: a `read` then `seconds_per_page` with the db dated now opens once.
- **Size:** small (chore).

### 15. Stale docs and names left by today's items
- **Verdict:** CONFIRMED.
- **Items:**
  - `HOOKS.md:1631-1633` says freeing a tile frees "its icons' masks … and `TintedIcon` its mask". Since TW-9atgka, `TintedIcon:free` only drops its reference (`tinted_icon.lua:65-68`).
  - `spec/unit/library_tiles_spec.lua:449`'s title, "frees its cover's bitmap and its icons' masks", is stale the same way. The comment at `:447-448` is right.
  - `HOOKS.md:975`'s "skipped when they hold those values already" means the in-memory copy. Reword it with #13.
  - `books.lua:4-5`'s header now has `with_progress`'s cached exception (verify-sidecar nit 3).
  - `State.set_many({})` does a full flush (`state.lua:96-106`). There is no caller today; return early.
  - `spec/unit/prebuild_spec.lua` keeps its old name (verify-bug nit 5; optional).
- **Size:** small (one chore).

## Library prebuild adjudication

**The trace.**
1. A book opened from a library tile records `Library.return_to` through `openFile`'s pre-callback (`library.lua:123-133`, `:37-40`).
2. Closing it: `ReaderUI:onHome` (`frontend/apps/reader/readerui.lua:935-940`), the reader menu's file-browser tab (`readermenu.lua:65-73`) and the end-of-book action (`readerstatus.lua:144-148` → `:169-173`) each call `onClose()` and then `showFileManager(file)` in one function.
3. `onClose` (`readerui.lua:870-900`) broadcasts `CloseDocument` at `:887` → `KoPanda:onCloseDocument` (`main.lua:298-317`). That records the chapter, finds `return_to` and calls `Library.prebuild` (`library.lua:263-272`) → `Library:new` → `init` (`:77-87`) → `LibraryView.build`: the full build of #1-#3, while crengine's document is still open (`closeDocument` is at `:891`). Then the reader's save (`UIManager:close` at `:893` → `FlushSettings`) runs, and so does Statistics' flush, whose `CloseDocument` handler runs after KoPanda's.
4. `showFileManager` (`readerui.lua:581-596`) → `FileManager:showFiles` (`frontend/apps/filemanager/filemanager.lua:1312-1331`): rotation reset at `:1322`, `FileManager:new`, `UIManager:show` → `Show` sent synchronously (`frontend/ui/uimanager.lua:229-259`) → `KoPanda:onShow` (`main.lua:222-235`) → `show_return` (`:203-209`) → `Library.take_pending` (`library.lua:291-308`):
   - drops the pending library if its size or variant differs, and the show builds afresh;
   - else one `realpath` of the closed file (`:304`) and `LibraryCovers.rebuild_tiles` for its tile (`library_covers.lua:17-43`): `Books.get` → `record(path, true)` (stat, CoverBrowser row, `findSidecarFile`, `dofile`), `Books.progress` (`dofile` again), and `LibraryTiles.book` (blob, zstd and, in Diner, a MuPDF scale; strip; title line). That runs only if the closed book is on the returned page.
5. `Library.show{ widget = pending }` (`library.lua:232-252`) puts it on the stack. No `_repaint` runs anywhere in steps 2-5. The first-pass trace (`uimanager.lua:1537-1564`; no `forceRePaint` on the path) applies unchanged.

**What it saves.** No wall time. The user waits from the tap to the first `_repaint` after the stack unwinds, and that window includes the library build wherever it sits. Building in `onShow` changes the order, not the sum. The property that matters, the file browser never painted (`fm_paints == 0`), comes from showing synchronously inside `onShow`. `show_return` already does that when `take_pending` returns nil: the failed-open path (`HOOKS.md:1678-1683`) and the size and variant drops prove the non-prebuilt route works and is tested. The scenario's `paint_ms` runs from `show_return`'s `started` (`main.lua:206`), so it leaves the prebuild out. That is the same accounting artefact the home's `home_ms` had.

**What it costs.**
- **Every return:** `take_pending`'s tile rebuild: the closed book's sidecar parsed twice more (three times in all, the first stale) and its cover decoded twice. That is an estimated 20-60 ms on device. It also means more code: `pending`, `drop_pending`, `take_pending` and the init drop in `main.lua:113-116`.
- **Reload, switch and exit:** a full library build, thrown away by the next reader's init. That includes crengine's seamless reload after a background re-render (`readerrolling.lua:1868`), which lands mid-reading, so it delays the reopened book by an estimated few hundred ms. `HOOKS.md:98-100` and `main.lua:290-291` accept this.
- **Rotated reading:** the prebuild is dropped (`library.lua:296-300`) and a second full build runs.
- **Peak memory:** six cover bitmaps (about 0.45 MB each) are held while crengine's document is still open.
- **Correctness:** the build reads sidecars before the reader saves (`readerui.lua:893`). `take_pending` fixes only the closed book's tile. The header count and the filter membership stay stale: under Reading, a book finished in that session is still listed on return; under Finished, it is missing. `spec/unit/library_lifecycle_spec.lua:454` even pins that the pending tile has no strip before the take.

**What the contracts assert.**
- **D4** (`.tiller/epics/library/features/cover-grid/feature.md:57-58`): "pre-built so it shows in one paint, as the home does after a book closes". The comparison to the home is now false, since B-2o8ya3 removed the home's prebuild. "One paint" holds without the prebuild.
- The same file's "Kept current" (`:139-141`) and "Book close" (`:313-318`) describe the pre-built library and `take_pending`'s re-read.
- **C8** (`feature.eval.md:40`): "shows the library pre-built at the same folder, sort, status and page in one show, one built for another size or variant is dropped and rebuilt, … and the pre-built library shows the closed book's progress as saved after the close". It is bound to `library_lifecycle_spec.lua` (its pending block, about `:440-570`).
- **`spec/emulator/library_golden_spec.lua:151`:** `assert.is_true(sidecar.prebuilt)`, beside `fm_paints == 0`, `same_dir`, `same_page` and `within_budget(paint_ms)` (`:152-155`). The scenario reports `prebuilt` from the settled signal (`spec/emulator/scenarios/2-scenario-library.lua:272`).

**Verdict: remove it.** It is the same pattern, on the same synchronous stack, that B-2o8ya3 removed from the home, and every argument there carries over. Removing it:
- saves the tile rebuild on every return;
- saves a full build on every reload, switch and exit;
- saves the double build when reading rotated;
- lowers peak memory while the book closes;
- makes the returned library's count and filter correct;
- deletes four functions and a module field.

`paint_ms` then includes the build. That is 9-21 ms on the Mac fixture, far inside 250 ms.

**What removing it needs.**
- One Tiller amendment rewriting D4 (and `feature.md:139-141`, `:313-318`) and C8 to "built at the file manager's Show after the close, synchronously, in one show, the file browser never painted, showing the closed book's progress as saved after the close". C8 loses the dropped-and-rebuilt clause.
- Fold into the same amendment B-2o8ya3's unmet one (verify-bug finding 1): `2026-10-13-kopanda-design.md:85-86`, launcher C10, sheets `:63`, home-layout `:65` and night-mode C4. These are the same claim on the home side, so one amendment covers both.
- Code: `show_return` calls `showLibrary{ dir, page, started }`; `onCloseDocument`'s library branch only returns. The `return_to` check must stay ahead of the `just_closed` mark, so a library return never marks the home.
- Specs:
  - the `library_golden_spec.lua:151` assertion becomes `is_false`, or the `prebuilt` field goes;
  - `library_lifecycle_spec`'s pending cases become: `onCloseDocument` with `return_to` builds 0 times (spy `LibraryView.build`); a reload with `tearing_down` builds 0 times; the file manager's `Show` builds once and shows the closed book's saved percent;
  - a new case: a book marked complete in the closing session is absent on return under the Reading filter.
- `HOOKS.md:71-73`, `:80` and `:98-100` updated.

If the owner keeps the prebuild, take #4's interim (`tearing_down` first), and make `take_pending` refresh the header count as well as the tile.

## Dropped, downgraded or folded

- **History realpath "use `entry.file` directly"** (pass2-library #7): the fix is downgraded. KOReader's `updateItem*` (`readhistory.lua:173-204`) store unrealpathed paths, so the realpath is a real guard. It is kept as #8 with a session memo, and mostly solved by #1.
- **Header, nav bar and probe lines per turn; page-turn full refresh** (pass2-library lower): folded into #1's step 2. The probe lines are first-pass #10 and #11.
- **Library show and close with `"full"`** (`library.lua:71`, `:240`): a new instance of first-pass #7. Decide them together.
- **Sheet close `"flashui"`** (`sheet.lua:104`, pass2-rest lower): an owner decision of first-pass #7's kind. Raise it with #7.
- **Editor selection tap rebuilds every card and refreshes the whole screen** (`editor.lua:339-350`): low and rare. Not worth a tweak now.
- **Entry picker's Plugin sheet builds every row before the fit check** (`sheet_layout.lua:251-323`): the cost is low. The functional side is not: the sheet drops rows that don't fit with no scroll (accepted generally at `sheets/feature.md:143`), but the Plugin list is unbounded (`entry_picker.lua:218-241`). The headless catalog lists 28 bundled plugins (`studio/src/catalog.json`), so plugins late in the alphabet are probably unpickable on the device. PLAUSIBLE: the row-height count was not run. This is a behaviour gap, not efficiency; see the capture plan.
- **`Typeset.measured` keeping an unbuilt widget** (`typeset.lua:103-117`): low; it only follows a dropped row or a refused edit.
- **Book sheet "Read status" parses the sidecar and refreshes the whole home** (`book_sheet.lua:97-118`): a hold-only path and another trigger of first-pass #1. Nothing new.
- **Launcher management kind buttons building foot lines to count room** (`launcher_manage.lua:379-393`): low and rare.
- **Boot guard's two `state.lua` writes** (`main.lua:171`, `:175`): needed for the guard. Accepted.
- **Extraction restarts on a page turn** (`book_covers.lua:160-164`): the design's intent ("a new page replaces the request").
- **Cover poll timer** (`book_covers.lua:176-234`): bounded, runs only while an extraction is pending, and is cancelled on close. Not a finding (as in the first pass).
- **`Books.all`**: no production caller. Give it #1's listing memo before Series or Authors use it.
- **Stats `last` fallback ignores the date; the vfat mtime assumption** (verify-stats 2, 3): pre-existing or already marked as an assumption. Settle the vfat one with `mount` on the device.
- **Fixture blind spot:** not a finding, but #1, #2 and #8 need a stubbed 150-book unit fixture that counts `getBookInfo`, `openSettingsFile` and `realpath` per turn. The emulator budget will never see them.

## Capture plan

**Raise now as owner decisions:**
- **D-a: remove the library prebuild** (#4). Stage one amendment that also carries B-2o8ya3's unmet home-side rewrites (design `:85-86`, launcher C10, sheets `:63`, home-layout `:65`, night-mode C4). This is the one decision blocking the most cleanup.
- **D-b: the owner's library shape on the Kindle** (sub-folders? status filters in use?). This only re-weights #2, so ask it as a question and don't block on it.
- **Fold into first-pass decisions already open:** the tile-bitmap LRU (#3) goes with first-pass #12. The library's `"full"` show and close and the sheet's `"flashui"` close go with first-pass #7. Pull as a single stream (#12, studio side) is separate and low priority.

**Capture now as tweaks** (small, no decision, a unit spec each), in this order:
1. **Library listing kept across turns and picker choices** (#1 step 1, with #8's realpath memo). Hottest path, biggest win.
2. **Folder counts without records, and a library-wide sidecar progress memo** (#2).
3. **Cover arrival: regional refresh with dither, one sidecar open per tile** (#5).
4. **Library leave skips an unchanged write** (#9), tracking the last successful write.
5. **Quote memo across builds** (#6).
6. **Editors defer the home's refresh to their close and keep the accepted overflow** (#10).
7. **Quick settings: no redraw in the old variant on Night; one redraw per Wi-Fi toggle** (#7's small part).
8. **Metadata events coalesced into one library rebuild** (#11).
9. **Pull verifies in one hashing pass** (#12, small part). Full review with mutations, since it handles files from outside.
10. **Only if D-a keeps the prebuild:** check `tearing_down` before the library prebuild (#4 interim).

**Capture as bugs:**
- **The chapter write's skip blocks the retry after a failed write** (#13).
- **The entry picker's Plugin sheet can't reach plugins past the screen's foot** (Dropped list). Verify the row count on the emulator first, then capture. It's a behaviour gap whose fix (paging or a KOReader `Menu`) may need an owner call.

**Capture as one chore:** #14's comment and HOOKS wording, plus #15's stale `HOOKS.md:1631-1633`, the test title at `library_tiles_spec.lua:449`, `HOOKS.md:975`, the `books.lua:4-5` header and `State.set_many({})`'s early return.

**Medium, later (no decision, golden or multi-module work):** #1 step 2 (regional page-turn refresh, header and nav kept); #3 together with first-pass #6 (cover at the inner size for both screens, goldens regenerated); #7's partial bar redraw.
