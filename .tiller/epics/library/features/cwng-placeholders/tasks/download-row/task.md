# Download on a placeholder's book sheet, through cwngsync, without opening the book

## Approach

The Download row and what follows a download. It starts after `placeholders`, which gives records their
`placeholder` flag. Repo lines are `main` at `1e25e44`; KOReader is relative to `~/Projects/kodev/koreader/`
at `e1fe1ac`; cwngsync is relative to `cwngsync.koplugin/` at `df90d5e`. Covers feature sections "The book
sheet on a placeholder", "Failure behaviour" and "HOOKS.md"; decisions D2, D7, D9, D16, D17 and D18;
criteria C3, C4 and C5.

1. **The row (D16).** `BookSheet.open_record` (`book_sheet.lua:392-420`) inserts a Download row at index 2,
   after Open, for a record with `placeholder`. A path-less record and a downloaded book get none (D7).
   - The row is `{ icon = "download", label = "Download" }`.
   - At build time it reads `FileManager.instance.cwngsync` through `package.loaded`, as `file_manager()` does
     (`book_sheet.lua:37-40`). With no `openLibraryPlaceholder` function there, the row is `muted` with no `run`.
   - `book_sheet.lua` is 422 lines. Put the row's builder and its callback in `cloud_books.lua`
     (`CloudBooks.download_row(record, window)`) if the sheet would pass 500. `cloud_books` may require nothing
     from the sheet.
2. **The tap (feature "The book sheet on a placeholder").** The sheet closes first (`sheet.lua:320-325`). The
   `run` is wrapped as `guarded` wraps a row (`book_sheet.lua:273-280`). It reads the instance again, since it
   can go between the build and the tap, then calls
   `plugin:openLibraryPlaceholder(record.path, on_arrival)` (`cwng_library_runtime.lua:999-1030`):
   - true: nothing more; cwngsync waits for Wi-Fi, shows its notice and downloads (`:1010-1027`);
   - false: `window:refresh()` (D18);
   - no instance or method by then: log it, do nothing.
3. **`on_arrival(file)` (D17)**, cwngsync's `open_real` (`:1017`). Behind a `pcall`, logged:
   - `BookCovers.forget({ file })` (`book_covers.lua:256-280`), so the cover is asked for again, the per-process
     `asked` mark included (`:21`, `:137`, `:266`). CoverBrowser has normally deleted the row on the broadcast already
     (`plugins/coverbrowser.koplugin/main.lua:800-803`); the delete is idempotent.
   - The window's re-list with a cover request, through one name on every window, `window:downloaded(record)`
     (the name may follow what reads best). On the library it is `self:refresh_covers({ record })`
     (`library.lua:216-223`): the kept listing dropped, rebuilt at its page, the record's cover asked for after
     the paint. On the shelf screens it is their `refresh` (`series_screen.lua:312-325`, and the authors'
     at `authors_screen.lua:358-371`), plus a cover request.
   - Open fact: how a shelf window asks again for one record's cover, since `LibraryChrome.request_records`
     runs once per window (`library_chrome.lua:438-442`). There are two candidates:
     - (a) clear `window.records_asked` and let `go` ask for all `window.records` again. `BookCovers.request`
       asks only for a path not asked in this process whose row wants a cover (`book_covers.lua:125-148`), so only the downloaded book may be asked.
     - (b) a one-record request through `BookCovers.request` with the module-local `arrive` (`library_chrome.lua:406-429`), which `library_chrome` would have to expose.

     Tell them apart by reading what (a) asks for on a page of cached covers: take (a) if it asks for that one
     book alone, else (b).
   - Every path first checks that the window is still the one shown (`Library.shown`,
     `library.lua:160-166`; `LibraryChrome.shown`, `library_chrome.lua:656-660`). A closed window does nothing.
   - `on_arrival` never calls `ReaderUI`, `filemanagerutil.openFile` or the window's `open`.
4. **The broadcast's own re-list.** `downloadLibraryBook` broadcasts `InvalidateMetadataCache` and
   `BookMetadataChanged` (`main.lua:1628-1630`, from `cwng_library_runtime.lua:964`) before `on_arrival` runs.
   The library re-lists from the next tick on them (`library.lua:176-198`); the shelf screens re-list at once
   (`library_chrome.lua:662-671`). That is a second re-list beside `on_arrival`'s. Check on the emulator that
   the screen ends showing the book downloaded with its cover. Report to the lead if the two give a visible
   double flash on the Colorsoft profile, before changing either.
5. **`HOOKS.md`**: the download half of "cwngsync's placeholders":
   - `openLibraryPlaceholder` and what it does before and after `open_real` (`cwng_library_runtime.lua:999-1030`);
   - `downloadLibraryBook` (`:940-977`): synchronous, the rename, the `refreshLibraryViews` broadcasts
     (`main.lua:1612-1630`), the `downloaded` record (`cwng_library.lua:346-352`);
   - `NetworkMgr:runWhenConnected` (`frontend/ui/network/manager.lua:713-719`);
   - CoverBrowser's `onInvalidateMetadataCache` (`plugins/coverbrowser.koplugin/main.lua:800-803`) reached
     through the file manager's modules (`frontend/ui/widget/container/widgetcontainer.lua:80-107`), which returns true and so stops it there (`:802`), while `broadcastEvent` still reaches every window (`frontend/ui/uimanager.lua:1042-1061`);
   - the 5 s `reportInventory` (`cwng_library_runtime.lua:1018-1020`).

## Surfaces

- `kopanda.koplugin/book_sheet.lua`, `cloud_books.lua` (if step 1 moves the row there), `library.lua`,
  `series_screen.lua`, `authors_screen.lua`, `library_chrome.lua` (step 3's open fact), `HOOKS.md`.
- `spec/unit/cloud_download_spec.lua` (new).

## Tests

Write each test first and run it failing before the code. All go in `spec/unit/cloud_download_spec.lua`, under
the plugin harness with a real file manager. The stub `cwngsync` is registered on it as `placeholders`' spec
registers it. Its `openLibraryPlaceholder` records its calls and returns what the case sets, and a case calls
the recorded callback itself, after making the stub's state say `downloaded`.

- **C3, the row:**
  - The sheet over a placeholder held on the library, on one series and on one author lists Open, Download,
    Book details, Read status, More by this author, Add to the home and Delete in that order, Download with
    the `download` icon.
  - A downloaded book's and a path-less record's sheets have no Download row.
  - With a stub that has no `openLibraryPlaceholder`, the row is `muted`, has no `run`, and a tap runs nothing.
- **C3, the tap:**
  - A tap closes the sheet and calls `openLibraryPlaceholder` once, with `record.path` and a function. No
    `ReaderUI:showReader` is called; spy on it as `book_sheet_spec.lua`'s open cases watch the open.
  - The stub returns false: the window re-lists once.
  - The stub raises: logged, the window shown and unchanged, the file manager on top.
  - The stub is removed between the build and the tap: logged, nothing runs.
- **C3, the callback:**
  - The library: the window is re-listed at the same page and that book's tile has no badge.
    `BookCovers.forget` got the path. A cover request after the paint includes the record.
  - The same on one series (the row has no badge) and on one author.
  - With the window closed before the callback (another screen shown): nothing re-lists and nothing raises.
  - A raising re-list inside the callback is logged with the file manager on top.
- **C4:** `book_sheet_spec.lua`, `library_screen_spec.lua`, `series_screen_spec.lua`,
  `authors_screen_spec.lua` and `failsafe_spec.lua` pass unchanged.
- **C5:** `hooks_doc_spec.lua` passes.
- **Scope check:** confirm `bin/check spec/unit/cloud_download_spec.lua` runs that file alone.

## Edge cases

- **Wi-Fi off.** `runWhenConnected` hands the callback to `beforeWifiAction` (`manager.lua:717`), which may
  prompt, turn Wi-Fi on, or do nothing, by the owner's KOReader setting. The callback can run much later, or
  never. Only step 3's shown check guards it, and KoPanda keeps no pending state.
- **Held on one screen, arrived on another.** The owner may tap back or change tabs while the download waits
  for Wi-Fi. The callback re-lists only the window it was held on, and only while that one is shown. Any other
  window re-lists on cwngsync's broadcast (step 4).
- **A failed download** shows cwngsync's message over the window (`cwng_library_runtime.lua:1022-1026`). The
  callback never runs and the tile keeps its badge.
- **The real book's metadata.** After the download the record's title and authors come from the sidecar or the
  file name until CoverBrowser extracts again (`books.lua:107-150`), as after Refresh covers (context-menu D9).
  The cover request fixes both on arrival.
- **Sort position.** The "recent" sort keys on history (`library_order.lua:155-170`), and a download adds none,
  so the tile stays in its cell. A title or author sort keys on the same title once the real book's metadata
  arrives, which can move the tile if the server's placeholder metadata differed. That is accepted, not
  re-sorted around.
