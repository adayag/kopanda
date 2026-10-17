# KoPanda efficiency review: merged and verified

Paths are relative to `kopanda.koplugin/` unless they start with `frontend/` or `base/` (KOReader, pinned e1fe1ac). Device costs are estimates; nothing has run on the Colorsoft.

What sets the ranking: a **home build** (`HomeRows.build`, `home_rows.lua:84-150`) is the unit of cost. It runs on every home show from the file browser, on every wake while the home is up, on every book close (the prebuild), and after each weather or cover arrival. Findings 2, 3, 5, 6 and 12 are parts of a build, so they multiply with finding 1. Paint itself is already lean: all four reports agree, and I found nothing per-paint worth fixing.

## Ranked findings

### 1. Every refresh trigger rebuilds the whole home and refreshes the whole screen (wake, weather arrival, cover arrival, Wi-Fi, time format)
- **Verdict:** CONFIRMED.
- **Files:** `home.lua:50-56` (`rebuild`), `home.lua:61-73` (`Home:refresh`: `rebuild`, then `setDirty(self, "ui")` with no region). Callers: `home.lua:77-79` (`onResume`), `:83-85` (`onTimeFormatChanged`), `:90-106` (`refresh_if_stale`), `weather.lua:205-213` (`run` → `home:refresh()`), `featured_cover.lua:269-273` (cover arrival → `home:refresh()`). KOReader: `Resume` is broadcast at `frontend/device/generic/device.lua:1125`. On Kindle, `frontend/device/kindle/device.lua:786-788` also queues `setDirty("all", "full")` after the screensaver closes.
- **Path and frequency:** every wake while the home is the top window, which is the hottest path on an e-reader. Also once per process after the first weather success, once per uncached cover arrival, and on each Wi-Fi change that makes the launcher stale. Each one runs a full build: 11 SVG renders (#2), two Statistics DB opens (#3), two sidecar `dofile`s (#5), a cover SQLite read, zstd decode and MuPDF scale (#6, #12), a weather file read (#13), every tracked label one glyph at a time (#10), and the quote `TextBoxWidget` into a fresh RGB32 buffer.
- **Impact:** high. The emulator's non-prebuilt `paint_ms` is 26-70 ms and almost all of it is build. At 10-30× that is roughly 0.3-2 s of CPU between the wake and the home appearing. On wake only clock, date, weather age, stats and (at midnight) the quote change. A weather or cover arrival changes one slot but rebuilds all of them.
- **Fix:** refresh per slot. `Resume` and `TimeFormatChanged` call `module.refresh(built, ctx)` on the time-dependent slots only; the hook already exists and `take_pending` uses it at `home.lua:277-284`. Weather and cover arrival rebuild only their own slot, swap it into `home[1]`, free the old one, and call `setDirty(home, "ui", slot.rect)`. Fall back to a full rebuild when a slot's height would change. Cheaper first step: land #2, #3 and #5 so a full rebuild costs less.
- **Test:** a unit spec with stubbed slot modules. `Home:onResume()` on a shown home builds launcher, featured and `NavBar.new` 0 times and calls clock, date and stats `refresh` once each. A weather success leaves every other slot's `build` uncalled, and `setDirty`'s region equals the weather slot's rect. An emulator golden after a cover arrival equals the fresh-build golden.
- **Size:** medium. No owner decision is needed for wake and time format. A regional refresh of a colour cover on arrival may need a dither hint (`uimanager.lua:659`), so check that on the device.

### 2. TintedIcon re-renders its SVG on every construction, with no cache
- **Verdict:** CONFIRMED.
- **Files:** `tinted_icon.lua:23-37`. Callers: `nav_bar.lua:119` (5 tabs), `widgets/launcher.lua:145` (6 by default), `sheet.lua:237` (one per row), `title_bar.lua:301`, `fm_nav.lua` (via `NavBar.new` on every `FileManager:setupLayout`), plus editors. KOReader: `frontend/ui/renderimage.lua:338-344` dispatches to NanoSVG, which opens and parses the file (`NnSVG.new`) and rasterises into a new RGB32 buffer (`:351-394`). `ImageWidget` caches the same work in `ImageCache` under `file|w|h|alpha` (`frontend/ui/widget/imagewidget.lua:147-160`); TintedIcon bypasses that cache.
- **Path and frequency:** 11 per home build, so on every show, wake, refresh and prebuild. Another 5 per file-manager layout, which runs on every book close. 5-6 per sheet open. About 16 per book close and 11 per wake.
- **Impact:** medium-high. Each icon is a file read, an XML parse, a rasterise, two allocations and three blits, perhaps 2-5 ms each on ARM, or 30-80 ms per close or wake. The mask depends only on `(file, size)`; colour is applied at paint (`tinted_icon.lua:41-51`).
- **Fix:** keep a module-level mask cache keyed `file .. "|" .. size`. It is bounded by the icon registry times a few sizes, a few KB each. `TintedIcon:free` (`:53-58`) must not free a cached mask, and a failed render stays uncached.
- **Test:** spy on `RenderImage.renderSVGImageFile`. Two `TintedIcon:new` with the same file and size render once. Freeing the first still lets the second paint, and a different size renders again. Goldens stay pixel-identical.
- **Size:** small.

### 3. The Statistics database is opened twice per build, with no cache
- **Verdict:** CONFIRMED.
- **Files:** `widgets/stats.lua:121-123` → `ReadingStats.read` (`reading_stats.lua:131-165`, `with_db` opens read-only at `:78-97`, `query` at `:99-113`). `widgets/featured.lua:421` → `FeaturedBook.current` → `ReadingStats.seconds_per_page` (`featured_book.lua:130-133` → `reading_stats.lua:202-224`, `rate` at `:179-196`) opens it again.
- **Path and frequency:** every build, so on every show, wake, refresh and prebuild. On a book close it runs three times (see #4). The SQL per build:
  - minutes today: a `sum`;
  - books this month: `count(DISTINCT id_book)` over a month of rows;
  - the streak: one indexed probe per streak day plus one, up to `MAX_STREAK = 400`, with two `os.time` calls each;
  - reading speed: `GROUP BY page` over the `page_stat` view for the featured book's whole history.
- **Impact:** medium-high. That is two SQLite opens and five statements per build, and the work grows with reading history. The data changes only when Statistics writes (close, save, suspend) or the day rolls over.
- **Fix:** memoise both results keyed on the local date plus the size and mtime of `statistics.sqlite3` and `statistics.sqlite3-wal`, and on md5 for `seconds_per_page`. Open one connection when both miss. Keying on the files is exact invalidation, not staleness, so no owner call is needed.
- **Test:** count `SQ3.open`. A second `read` with nothing changed opens nothing. A touched `-wal` file or a date past midnight opens again. A busy DB still returns `last`.
- **Size:** small to medium.

### 4. The prebuild on `CloseDocument` adds work and saves no wall time (see the adjudication below)
- **Verdict:** CONFIRMED.
- **Files:** `main.lua:251-260` (`onCloseDocument` → `Home.prebuild`), `home.lua:240-247`, `home.lua:266-286` (`take_pending`), `widgets/stats.lua:153-163` (`Stats.refresh`), `main.lua:101-106` (the reader's init drops the pending home).
- **Path and frequency:** every `CloseDocument` in the reader. That includes:
  - a book close to the file browser;
  - `reloadDocument` (`frontend/apps/reader/readerui.lua:947-967`), including crengine's seamless reload after a background re-render while reading (`frontend/apps/reader/modules/readerrolling.lua:1868`);
  - `switchDocument` (`readerui.lua:969-980`);
  - exit.
- **Impact:** medium. It also fixes a correctness bug. The costs:
  1. Every close reads stats one extra time, because `take_pending` always calls `Stats.refresh`.
  2. A book read rotated is built twice: `showFiles` resets rotation (`frontend/apps/filemanager/filemanager.lua:1322`), so `take_pending` drops the home (`home.lua:272-274`) and `showHome` builds again.
  3. A reload, switch or exit builds a whole home that is thrown away. The reload and switch cases delay the next book's open, and the reload case hits mid-reading.
  4. The correctness bug: the prebuilt featured slot reads the sidecar before ReaderUI saves it. `CloseDocument` fires at `readerui.lua:887`; the save happens at `:893` through `UIManager:close` → `FlushSettings` (`frontend/ui/uimanager.lua:298`), because `dialog == self` skips the earlier save (`readerui.lua:126-127`, `:876-878`). Featured has no `refresh` hook (`widgets/featured.lua`), so the percent shown can lag by up to the 15-minute autosave interval (`frontend/ui/elements/common_settings_menu_table.lua:533-535`). Time-left also leaves out the session just ended, since Statistics flushes after KoPanda's handler.
- **Fix:** `onCloseDocument` records the chapter and sets a "book just closed" flag unless `self.ui.tearing_down` is set (it is set on reload and switch at `readerui.lua:600`, `:609`, `:952`, `:973`). `onShow` takes the synchronous branch when the flag is set (today it keys on `Home.pending`) and builds the home there. Drop `Home.prebuild`, `pending`, `take_pending`'s refresh loop and `Stats.refresh`, or keep `refresh` for #1. If the owner keeps the prebuild, the fallback is a `ctx.prebuild` flag that makes `Stats.build` return the sized empty container (`Stats.height` needs no data), plus a `refresh` hook on Featured.
- **Test:** in `spec/unit/prebuild_spec.lua`:
  - `CloseDocument` builds no home;
  - a `Show` after it puts the home on the stack synchronously;
  - `ReadingStats.read` runs once per close-then-show;
  - `CloseDocument` with `ui.tearing_down = true` followed by a reader init builds nothing.

  `spec/emulator/book_close_spec.lua` keeps `fm_paints == 0` and drops `prebuilt`. A new case asserts the featured percent after close equals the sidecar's saved value.
- **Size:** owner decision. It reverses a recorded design choice (`2026-10-13-kopanda-design.md:85-86`, `:154-155`), and the launcher feature's acceptance (`.tiller/epics/home/features/launcher/feature.eval.md:50`) names "the pre-built home shown". The `ctx.prebuild` stats skip on its own is small.

### 5. The featured book's sidecar is found and parsed twice per build, and again on every build
- **Verdict:** CONFIRMED.
- **Files:** `featured_book.lua:94-95` → `Books.for_path` (`books.lua:296-301`, `record(path, true)` always reads the sidecar at `:107-112` via `sidecar()` `:79-85`). Then `featured_book.lua:123` → `Books.progress` → `file_progress` (`books.lua:338-356`) calls `sidecar()` again. KOReader: `DocSettings:findSidecarFile` stats each candidate, and `openSettingsFile` `dofile`s the file (`frontend/docsettings.lua:159-175`, `:301-314`).
- **Path and frequency:** every build.
- **Impact:** medium. A sidecar holds annotations, bookmarks and stats, often tens to hundreds of KB of Lua, and it is compiled twice per build on every show and wake.
- **Fix:** open the sidecar once per build and pass it to both `record` and `progress`. The second step caches `{record, progress}` keyed on the sidecar's path, mtime and size; that is exact invalidation, so no owner call.
- **Test:** count `DocSettings.openSettingsFile` across one `FeaturedBook.current()`: 1. A repeat call with an unchanged mtime: 0. A changed mtime: 1.
- **Size:** small.

### 6. In the default look the cover is MuPDF-rescaled on every build
- **Verdict:** CONFIRMED.
- **Files:** `featured_cover.lua:187-197`. The cover is read and judged at `w × h` (`BookCovers.read(record, w, h)`), but the `ImageWidget` is `inner_w × inner_h = w − 2·outline` with `scale_factor = 0`. `widgets/featured.lua:492-497` asks for extraction at `box_w × box_h`. KOReader: `frontend/ui/widget/imagewidget.lua:320-324` computes `min(inner/bb)`, which is below 1, so `:339-343` → `RenderImage:scaleBlitBuffer` runs a MuPDF scale. Diner is the default look (`schema.lua:16`) with outline 3 (`looks/diner.lua:81`), about 6 px at 300 DPI. Editorial's night and grey variants are affected as well.
- **Path and frequency:** every build that shows a cover, at the first paint. The result is cached in `_bb` across repaints, but every build makes a new `ImageWidget`.
- **Impact:** medium. It is a full-resolution resample of a roughly 317×475 colour bitmap on each show and wake, to shrink the cover by about 12 px.
- **Fix:** read, judge usability and request extraction all at the inner size, so the scale resolves to exactly 1. `read` and `after_show` must change together, or `isCachedCoverInvalid` keeps asking for a new extraction on every show (`bookinfomanager.lua:1013-1030`).
- **Test:** build `FeaturedCover.framed` with Diner tokens and a stub bitmap at the extraction size, spy on `RenderImage.scaleBlitBuffer`, call `getSize`, and expect 0 calls. `BookCovers.wants` is false for that row with the specs `after_show` passes. Goldens will shift by a pixel or so of resampling; regenerate them and eyeball.
- **Size:** medium, because of the extraction coupling and the golden regeneration.

### 7. The home shows and closes with a blocking "full" flash, including plain moves between the home and the file browser
- **Verdict:** CONFIRMED path. The cost on the panel is an assumption.
- **Files:** `home.lua:215` (`UIManager:show(home, "full")`), `home.lua:43` (`UIManager.close(home, "full")`); the choice is recorded in `HOOKS.md:116-121`. KOReader: `full` and `flashui` are both `UPDATE_MODE_FULL` (`base/ffi/framebuffer_mxcfb.lua:388`), and for a FULL update KOReader waits for completion inside the refresh call (`:474-482`).
- **Path and frequency:** every show and close. After a book close it is free, because the reader closes with `"full"` (`readerui.lua:893`) and `_refresh` merges the two (`uimanager.lua:1266-1279`). Every other hop pays a blocking colour GC16 flash:
  - home → Library;
  - the Home tab from the file browser (`main.lua:341-348`, `nav_bar.lua:70-72`);
  - a tap on blank space (`home_gestures.lua:161`);
  - "Open the file browser" (`home_sheet.lua:65`).
- **Impact:** medium. A full colour flash on a Kaleido panel is plausibly 0.5-1 s and blocks the UI loop. KOReader's own full-screen menus close with `"ui"` (`frontend/ui/widget/menu.lua:1472-1489`).
- **Fix:** use `"ui"` for a show or close that does not follow a book close, and keep `"full"` where it merges with the reader's close. Let KOReader's `FULL_REFRESH_COUNT` handle ghosting.
- **Test:** `home_lifecycle_spec` records the refresh type per route. Judge ghosting by eye on the Colorsoft.
- **Size:** owner decision, a trade between ghosting and speed.

### 8. Each process start fetches the weather over HTTPS on the UI thread, however fresh the cache
- **Verdict:** CONFIRMED.
- **Files:** `weather.lua:218-223` (`after_show` checks only `attempted` and `isConnected`, never `fetched_at`), `weather.lua:227-232` (`on_connected`), `weather.lua:74-76` (`set_timeout(5, 10)`). A success then triggers #1's full rebuild and repaint.
- **Path and frequency:** once per process when connected. KOReader restarts on every studio push, crash and reboot.
- **Impact:** medium-low. It blocks the UI for the request (up to 5-10 s on a bad link, and DNS resolution sits outside those timeouts), right after the first paint, and is followed by a full rebuild.
- **Fix:** skip the automatic fetch when the cached reading is younger than a fixed window, a constant and not a setting. A tap always fetches.
- **Test:** `fetched_at = now - 60` makes no request; `now - 3*3600` makes one.
- **Size:** owner decision on the window. The code itself is small.

### 9. Every book close does two fsync'd rewrites of `state.lua`, each read back with `dofile`
- **Verdict:** CONFIRMED.
- **Files:** `main.lua:224-244` (`record_chapter`: two `State.set` calls), `state.lua:62-81` (each call stats the directory twice, flushes, then `dofile`s the file back). KOReader: `LuaSettings:flush` → `util.writeToFile` with fsync, and `backup()` may rename the file and fsync the directory (`frontend/luasettings.lua:251-275`, `frontend/util.lua:1124-1142`).
- **Path and frequency:** every `CloseDocument`, before the home builds. It also runs on reload and switch.
- **Impact:** medium-low. Two or more fsyncs on Kindle flash, roughly 5-50 ms each.
- **Fix:** add a `State.set_many{...}` that does one flush and one read-back, and skip the write when the file and chapter are unchanged.
- **Test:** in `prebuild_spec`'s "recording the chapter" case, stub `util.writeToFile`. One close writes once; a repeat close of the same file and chapter writes zero times.
- **Size:** small.

### 10. Tracked text builds one TextWidget per character
- **Verdict:** CONFIRMED path. The per-glyph cost is an estimate.
- **Files:** `typeset.lua:58-77`. KOReader: each `TextWidget` creates its own xtext and measures at `updateSize` (`frontend/ui/widget/textwidget.lua:90-94`, `:130-131`), then shapes once more at its first paint (`:351-353`).
- **Path and frequency:** every build. The default Diner tracks the date (~19 chars), the clock, the weather (~20), the stats line (built at ~45 chars, freed when it is too wide, then rebuilt, `widgets/stats.lua:62-71`), and 5 nav labels. `NavBar.height` builds 2 probe "HOME" lines (`nav_bar.lua:44-53`) and runs twice per home build (`layout.lua:130-139`, `nav_bar.lua:102`) and twice per file-manager layout.
- **Impact:** medium-low. That is roughly 150-200 xtext objects and twice as many shaping calls per build, against about 15 if each line were shaped once.
- **Fix:** one `TextWidget` per line, with a `paintTo` that adds `gap` to `pen_x` after each glyph, and a width of `w + gap*(n-1)`. Decide whether the line is too wide from that width before building.
- **Test:** a tracked `Typeset.line` returns one widget whose width is the untracked width plus `gap*(n-1)`. Kerning returns, so expect sub-pixel drift: regenerate the goldens and eyeball them.
- **Size:** medium, because of the golden regeneration.

### 11. Each file-manager layout re-measures and rebuilds the bars, though the home covers them
- **Verdict:** CONFIRMED.
- **Files:** `fm_nav.lua:212-245`. `NavBar.height` runs at `:220` and again in `Bar:init` (`nav_bar.lua:102`), plus 5 labels and 5 icons. `KoTitleBar` builds 4 probe lines (`title_bar.lua:75-97`).
- **Path and frequency:** every `FileManager:new`, so every book close, on the critical path.
- **Impact:** low-medium, about 8 throwaway shapings plus 5 renders, which #2 removes.
- **Fix:** memoise `NavBar.height` and the title bar metrics by look id and screen size.
- **Test:** `fm_nav_spec` counts `Typeset.line` across two layouts.
- **Size:** small.

### 12. The featured cover is re-read from SQLite and zstd-decoded on every build, and again on each book-sheet hold
- **Verdict:** CONFIRMED.
- **Files:** `book_covers.lua:58-78` (`getBookInfo(file, true)`); `book_sheet.lua:257` (`FeaturedCover.build` at 127×190, then a MuPDF downscale). KOReader: `bookinfomanager.lua:355`, `:388-396`.
- **Path and frequency:** every build, and every hold of the featured book.
- **Impact:** low-medium. Each pass decompresses about 0.6 MB.
- **Fix:** keep a one-entry memo of the final bitmap keyed `path|w|h`, with `image_disposable = false`, dropped on a path change, an arrival or a reset.
- **Test:** count `getBookInfo(_, true)` across two `Featured.build`s and a `BookSheet.open`: 1.
- **Size:** owner decision. An outside "ignore cover" toggle or a re-extraction goes unseen until the memo is invalidated, unless each build re-checks with `getBookInfo(file, false)`.

### 13. The weather cache file is read from disk on every build and every home-sheet open
- **Verdict:** CONFIRMED.
- **Files:** `weather.lua:135-153` (`LuaSettings:open(cache_path())`), from `widgets/weather.lua:26` and `home_sheet.lua:73`.
- **Impact:** low, one small `dofile` per build.
- **Fix:** hold the reading in a module local, updated in `fetch`. Keep the location and units check on read.
- **Test:** two `reading()` calls open the file once.
- **Size:** small.

## Prebuild adjudication

**The question.** Can a `_repaint`, and so an e-ink refresh of the file browser, happen between `CloseDocument` and KoPanda's `onShow`?

**The trace.**
1. `ReaderUI:onHome` (`readerui.lua:935-940`) calls `self:onClose()` and then `self:showFileManager(file)` in one function. The reader menu's file-browser tab (`readermenu.lua:65-73`) and the end-of-book action (`readerstatus.lua:144-148` → `:169-173`) do the same.
2. `onClose` (`readerui.lua:870-898`) broadcasts `CloseDocument` at `:887` and closes the document at `:891`. At `:893` it calls `UIManager:close(self.dialog, "full")`. `UIManager:close` (`uimanager.lua:290-360`) only marks the uncovered windows dirty and calls `_refresh`, which enqueues the refresh on `_refresh_stack` and returns (`uimanager.lua:1200-1290`). Nothing reaches the panel.
3. `showFileManager` (`readerui.lua:581-596`) → `FileManager:showFiles` (`filemanager.lua:1312-1331`): rotation reset, `FileManager:new`, `UIManager:show(file_manager)`.
4. `UIManager:show` (`uimanager.lua:229-273`) inserts the window, calls `setDirty`, and sends `Show` synchronously at `:259` → `KoPanda:onShow` (`main.lua:192-205`).
5. No `forceRePaint` appears anywhere on this path (grep of `filemanager.lua`, `readerui.lua`, `readermenu.lua`). The one in `readerstatus.lua:134` is on the "next file" branch, not the file-browser branch.
6. The only places the screen is painted and refreshed are `_repaint` (`uimanager.lua:1298-1380`), reached from `handleInput`'s loop after `_checkTasks` (`:1537-1561`), and `forceRePaint`.

So `CloseDocument` and `onShow` run in one synchronous Lua call stack, and no `_repaint` can run between them. Whether the close starts from an input event or from a task inside `_checkTasks` makes no difference. KOReader's Lua side is single-threaded, so nothing else runs between the two handlers either.

**Implication.** The user's wait runs from the tap to the first `_repaint` after the stack unwinds. It includes reader close + Statistics flush + file-manager build + home build in any order. Moving the home build from `CloseDocument` to `onShow` changes the order, not the sum. The prebuild saves no wall time.

**What the emulator spec asserts.** `spec/emulator/book_close_spec.lua:35-40`, with the scenario at `spec/emulator/scenarios/2-scenario-book-close.lua`, asserts four things:
- `fm_paints == 0`: the file browser is never painted;
- `prebuilt == true`;
- `home_ms <= 100`, where `home_ms` is `paint_ms` from `onShow` to the paint (`main.lua:197`);
- `close_to_paint_ms` is reported but not bounded.

The real user-visible figure is `close_to_paint_ms`, and the prebuild does not change it. `home_ms` is small with the prebuild only because the build was moved out of its window. The one invariant that matters, the file browser never painted, comes from showing the home synchronously inside `onShow` instead of from `nextTick`. The `nextTick` branch would run after a `_repaint` when the close runs from a task (`uimanager.lua:413-418`, `:1081-1104`), which is why `main.lua:192-197` shows synchronously when something is pending. That property does not need a prebuilt widget, only a flag saying a book just closed.

**What the prebuild costs.** These are the costs listed under #4:
- an extra stats read on every close;
- a double build when the book was read rotated;
- a wasted full build on every reload (including crengine's seamless re-render reload mid-reading), switch and exit;
- higher peak memory while crengine's document is still open;
- a correctness bug: the prebuilt featured percent and time-left are read before the reader's sidecar save (`readerui.lua:893` → `uimanager.lua:298`) and before Statistics' flush, with no `refresh` hook on Featured to correct them.

**Verdict.** The prebuild is not worth keeping. The lifecycle report is right. The design's goal at `2026-10-13-kopanda-design.md:85-86`, "closing a book must land on it without a visible wait", is met just as well by building synchronously in `onShow` behind a "just closed" flag. The ennUI pattern it copies buys nothing under KOReader's synchronous close-then-show.

**What removing it loses.**
1. The `home_ms <= 100` figure would then include the build: on the Mac, about 26-70 ms plus paint, near the bound. The bound should be rebased onto `close_to_paint_ms`, or `home_ms` redefined.
2. The `prebuilt` flag in the settled signal and in the spec.
3. Two recorded artifacts need a Tiller amendment: the design line, and the launcher feature's acceptance statement (`.tiller/epics/home/features/launcher/feature.eval.md:50`, "the pre-built home shown").
4. Nothing the user can see.

The flag must also be cleared on a reader init, as `drop_pending` is today (`main.lua:104-106`), and skipped when `ui.tearing_down` is set.

## Dropped or downgraded

- **Sheet close repaints the whole home** (lifecycle #5): downgraded to low, not worth fixing. Repainting is blits of already-built widgets; only the sheet's rect is refreshed (`sheet.lua:438`; `uimanager.lua:349-353`). The proposed fix, a 2-8.5 MB screen-buffer cache, costs more memory than the blit saves.
- **Row read three-plus times per show, pulling the cover blob** (images #7): low. The call counts are confirmed. The blob page reads are plausible but unmeasured; CoverBrowser keeps one prepared statement on a unique index.
- **`FeaturedBook.describe` parses the sidecar** (data #7): low. It only runs on a hold or a menu render. A small fix, if wanted, is to read the sidecar only when the row lacks a title or authors.
- **Title bar re-reads its state on every file-browser paint** (lifecycle #7): low. It is two `realpath`s and a loop over the item table per paint, and the rebuild only happens on change (`title_bar.lua:198-219`, `:360-368`).
- **Boot requires every module** (lifecycle #8): low, a one-time parse cost. The package.preload change carries path-shadowing risk for little gain.
- **Layout editor keeps measured widgets alive** (paint #6): low. Edits are rare; the retention is the only reason to fix it.
- **`Stats.height` / `NavBar.height` probe lines**: folded into #10 and #11.
- **Arrival poll timer** (images #8): no fix needed. It runs only while an extraction is pending, the same way CoverBrowser polls (`covermenu.lua:164-175`).
- **CoverBrowser refresh functions firing over the home** (lifecycle, lower): plausible, not traced. It needs a device or emulator check of whether `covermenu.lua:157`'s `refreshfunc` enqueues a refresh while the home covers the file manager.
- **"Every SVG re-render on wake is followed by a second paint from Kindle's `setDirty("all","full")`"** (paint #1): not a separate cost. The Kindle `nextTick` (`kindle/device.lua:786-788`) and the home's `setDirty` land in the same `_repaint` when the wake runs from an input event, so the panel is refreshed once.
- **Prebuild "decodes the cover and renders SVGs while the reader is open"** (images #6): merged into #4. The image share disappears once #2 and #12 land.
- **Merged duplicates:**
  - TintedIcon: paint #2, images #1 and lifecycle #2 → #2.
  - Stats read twice per close: paint #4, data #2 and lifecycle #1.1 → #4.
  - Whole-home rebuild: paint #1, images #2 and data #4 → #1.
  - Full refresh: paint #5 and lifecycle #4 → #7.
  - Weather cache re-read: paint #7 and data #8 → #13.
  - `state.lua` fsync: data #6 and lifecycle #3 → #9.

## Size summary

- **Small** (an afternoon each, one unit spec): #2 TintedIcon cache, #5 sidecar once per build, #9 `State.set_many`, #11 bar metric memo, #13 weather reading memo. #3 stats memo is small to medium.
- **Medium** (behaviour-preserving, but golden regeneration or several modules): #1 per-slot refresh, #6 cover at the inner size, #10 tracked-text single widget.
- **Owner decision:**
  - #4 removing the prebuild (design, acceptance statements and the spec's `prebuilt` and `home_ms`);
  - #7 refresh mode on hops between the home and the file browser;
  - #8 the weather freshness window;
  - #12 cover memo staleness.
- **Suggested order:** #2, #3, #5 and #9 first. They are cheap, cut every build, and leave nothing to decide. Then #1. Raise #4 and #7 with the owner in parallel.
