# The library prebuilt on close shows a stale count and filter and builds on reload, switch and exit

Found by the 2026-10-17 efficiency review, second pass (`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`,
finding 4 and the "Library prebuild adjudication"). Traced in code at KOReader `e1fe1ac`, not
reproduced on a device. The owner answered Q-14rjkm on 2026-10-17: remove the prebuild, as B-2o8ya3
did for the home. Since the series-and-authors feature the prebuild is the chrome's, shared by the
library, Series and Authors windows (`kopanda.koplugin/library_chrome.lua:552-597`), so the fix
covers all three.

## Reproduction

1. Open a book from a library tile (or a Series or Authors row), read on, and close it. `onCloseDocument`
   (`main.lua:353-370`) runs `LibraryChrome.prebuild(cls, fields, file)` (`library_chrome.lua:555-564`)
   inside `ReaderUI:onClose` at the `CloseDocument` broadcast (`frontend/apps/reader/readerui.lua:887`),
   while crengine's document is still open (`:891`) and before the reader saves its sidecar
   (`UIManager:close` at `:893` → `FlushSettings`, `frontend/ui/uimanager.lua:298`). The prebuilt
   window's tiles, header count and filter membership read the sidecars as they were before the save.
2. `showFileManager` → `FileManager:showFiles` → `UIManager:show` → `Show` → `KoPanda:onShow` →
   `show_return` (`main.lua:247-260`) → `LibraryChrome.take_pending` (`library_chrome.lua:583-598`)
   runs in the same synchronous call stack with no `_repaint` between (the first pass's trace,
   `uimanager.lua:1537-1564`; nothing on the path calls `forceRePaint`). `take_pending` rebuilds the
   closed book's tile (`book_closed`), so that tile is current, but the header count and the filter
   are not: under Reading, a book finished in that session is still listed on return; under
   Finished, it is missing.
3. Reload a book (`readerui.lua:947-962`, including crengine's seamless reload after a background
   re-render, `readerrolling.lua:1868`), open the next book from history or a link (`switchDocument`,
   `:969-980`), or exit: each fires `CloseDocument`, so each builds a full window (listing, sidecars,
   folder counts, six cover decodes) that the next reader's init drops (`main.lua:119`) or nothing
   shows.
4. Close a book read rotated: `showFiles` resets the rotation (`filemanager.lua:1322`), `take_pending`
   drops the pending window (`library_chrome.lua:589-591`) and the show builds a second one.

## Expected

The window shown after a book close carries the count, filter membership and progress the reader
just saved. A reload, switch or exit builds no window. A book close builds the window once. The file
browser never paints (`fm_paints == 0`), which comes from showing synchronously inside `onShow`, not
from the widget being prebuilt.

## Actual

Stale count and filter on return; a wasted full build on every reload, switch and exit; a double
build after a rotated close; six cover bitmaps held while the document is still open; and four
functions and a module slot (`prebuild`, `drop_pending`, `take_pending`, the `pending` hold) that
buy no wall time, since building at close or at show changes the order of the work, not the sum.

## Fixed when

- `onCloseDocument`'s chrome branch records nothing but the return (`return_to` stays as the open
  recorded it) and respects `tearing_down` like the home branch; `show_return` builds and shows the
  window synchronously at the file manager's `Show`, as it already does when `take_pending` returns
  nil. `LibraryChrome.prebuild`, `drop_pending`, `take_pending` and the `pending` hold go, along with
  `main.lua:119`'s drop and `book_closed`'s pending-only path if nothing else uses it. The `return_to`
  check stays ahead of the `Home.just_closed` mark.
- `spec/unit/library_lifecycle_spec.lua` and `shelf_lifecycle_spec.lua`: `CloseDocument` with a
  recorded return builds 0 windows (spy `LibraryView.build` and the Series/Authors builds); a reload
  with `tearing_down` builds 0; the file manager's `Show` builds once and shows the closed book's
  progress as saved after the close; a book marked complete in the closing session is absent on
  return under the Reading filter and present under Finished. These fail on the current code.
- `spec/emulator/library_golden_spec.lua:151`'s `assert.is_true(sidecar.prebuilt)` becomes
  `is_false` or the `prebuilt` field goes from `2-scenario-library.lua:272`; `fm_paints == 0`,
  `same_dir`, `same_page` and the paint budget stay, `paint_ms` now including the build.
- `HOOKS.md`'s pending-window entries (`library_chrome.lua`'s `prebuild`/`take_pending` citations,
  the `CloseDocument` paragraph) are rewritten for the synchronous build at `Show`.
- `.tiller/design/2026-10-13-kopanda-design.md:85-86` ("ennUI's prebuild-on-close pattern") is
  reworded in the same PR to "built synchronously at the file manager's Show, the file browser never
  painted"; it is a design input, not a Tiller node. The done features' acceptance statements that
  name a pre-built home or library (cover-grid D4 `feature.md:58`, `:140`, C8 `feature.eval.md:40`;
  launcher C10; sheets `:63`; home-layout `:65`; night-mode C4) stay as the record of what shipped:
  Tiller does not re-pin done work, and this bug is the forward work that replaces it. The PR names
  them.
- `bin/check` is green.
