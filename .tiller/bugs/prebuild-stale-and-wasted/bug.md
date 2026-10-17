# The prebuilt home shows stale progress and builds on reload, switch and exit

Found by the 2026-10-17 efficiency review (`.tiller/reviews/2026-10-17-efficiency-review.md`, finding 4
and the "Prebuild adjudication" section). Traced in code at KOReader `e1fe1ac`, not reproduced on a
device. The fix reverses a recorded design choice (`.tiller/design/2026-10-13-kopanda-design.md:85-86`)
and the launcher feature's acceptance statement C10 (`.tiller/epics/home/features/launcher/feature.eval.md:50`,
"the pre-built home shown"), so it needs an amendment alongside the fix.

## Reproduction

1. Read a book past an autosave boundary and close it to the file browser. `onCloseDocument`
   (`kopanda.koplugin/main.lua:251-260`) runs `Home.prebuild` (`home.lua:240-247`) inside
   `ReaderUI:onClose` at the `CloseDocument` broadcast (`frontend/apps/reader/readerui.lua:887`). The
   reader's sidecar is saved later, at `:893` through `UIManager:close` → `FlushSettings`
   (`frontend/ui/uimanager.lua:298`), because `dialog == self` skips the earlier save
   (`readerui.lua:126-127`, `:876-878`). The Statistics plugin flushes its session after KoPanda's
   handler as well.
2. The prebuilt featured slot reads the sidecar and the Statistics database at step 1.
   `Home.take_pending` (`home.lua:266-286`) re-runs `refresh` only on slots that define it, and
   `widgets/featured.lua` has none, so the featured percent and time-left are shown as read.
3. Separately: open a book, trigger a reload (`readerui.lua:947-967`, including crengine's seamless
   reload after a background re-render, `frontend/apps/reader/modules/readerrolling.lua:1868`), or
   open the next book from history or a link (`switchDocument`, `readerui.lua:969-980`), or exit.
   Each fires `CloseDocument`, so each builds a full home that the next reader's init drops
   (`main.lua:101-106`) or that nothing ever shows.
4. Close a book that was read rotated. `FileManager:showFiles` resets rotation
   (`frontend/apps/filemanager/filemanager.lua:1322`), so `take_pending` drops the prebuilt home
   (`home.lua:272-274`) and `showHome` builds a second one.

## Expected

The home shown after a book close carries the progress and time-left the reader just saved. A reload,
switch or exit builds no home. A book close builds the home once. The design's goal, closing a book
lands on the home without the file browser ever painting, holds.

## Actual

The featured percent can lag by up to the reader's autosave interval (15 minutes by default,
`frontend/ui/elements/common_settings_menu_table.lua:533-535`) and time-left leaves out the session
just ended. Every reload, switch and exit pays a full home build (stats query, sidecar parse, cover
decode, 11 SVG renders) that is thrown away, delaying the next book's open. A rotated close builds
twice. The Statistics database is read once more than needed on every close, because `take_pending`
always calls `Stats.refresh` (`widgets/stats.lua:153-163`).

The prebuild buys nothing in return. `ReaderUI:onHome` (`readerui.lua:935-940`), the reader menu's
file-browser tab and the end-of-book action each run `onClose` and then `showFileManager` →
`FileManager:showFiles` → `UIManager:show` → the `Show` event → `KoPanda:onShow` (`main.lua:192-205`)
in one synchronous call stack. `UIManager:close` only queues the refresh (`uimanager.lua:290-360`),
and the screen is painted only in `_repaint` (`:1298`), reached after the stack unwinds (`:1537-1564`),
or in `forceRePaint`, which nothing on this path calls. Building at close or at show changes the
order of the work, not the sum, so the user's wait from tap to home is the same. The invariant the
emulator spec checks, the file browser never painted (`spec/emulator/book_close_spec.lua:35-40`), comes
from showing the home synchronously inside `onShow`, not from the widget being prebuilt.

## Fixed when

- `onCloseDocument` records the chapter and sets a "book just closed" flag, skipped when
  `self.ui.tearing_down` is set (reload and switch set it before `onClose`: `readerui.lua:600`, `:609`,
  `:952`, `:973`) and cleared on a reader init as `drop_pending` is today (`main.lua:104-106`). `onShow`
  builds and shows the home synchronously when the flag is set. `Home.prebuild`, `pending` and
  `take_pending`'s refresh loop go away.
- `spec/unit/prebuild_spec.lua`: `CloseDocument` builds no home; a `Show` after it puts the home on the
  stack synchronously; a stubbed `ReadingStats.read` runs once per close-then-show; `CloseDocument`
  with `ui.tearing_down = true` followed by a reader init builds nothing. These fail on the current code.
- A spec asserts the featured percent after a close equals the value the sidecar holds after the
  reader's save.
- `spec/emulator/book_close_spec.lua` keeps `fm_paints == 0`, drops `prebuilt`, and bounds
  `close_to_paint_ms` instead of `home_ms`, since `home_ms` now includes the build.
- The design line and launcher C10 are amended to say the home is built synchronously on show after a
  close, with the file browser never painted.
- `bin/check` is green.
