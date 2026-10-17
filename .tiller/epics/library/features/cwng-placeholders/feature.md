# cwngsync placeholders read as not downloaded and download from the sheet

## Summary

The owner syncs books with the cwngsync plugin. A book cwngsync knows but the Kindle doesn't hold yet sits in
the library folder as a placeholder: a small EPUB the server generates (cover, metadata, one page) at the
book's real path (`cwng_library.lua:1-20`). KoPanda lists a placeholder as a downloaded book. With this
feature it reads as not downloaded wherever KoPanda draws a book, and its book sheet gains a Download row that
fetches the book through cwngsync without opening it. The library direction doc kept the not-downloaded badge
"as the design target... Nothing shows it until a remote source exists"
(`2026-10-16-kopanda-library-direction.md:32`); cwngsync is that source.

## Behavior

- A placeholder's tile on the library grid and on the one-author grid, and its row on the one-series list, take
  the download badge and the Not downloaded chip a book with no file takes; the one-series row's "Not on the
  Kindle yet" note too.
- Holding a placeholder opens the book sheet with the meta "Not downloaded" and the rows Open, Download, Book
  details, Read status ›, More by this author ›, Add to the home and Delete…, Delete greyed.
- Download asks cwngsync to fetch the book. The screen stays where it is and the book is not opened; once the
  book has arrived, its tile or row redraws without the badge and with its cover.
- Open, and a tap on the tile or row, still download and then open the book: cwngsync's open hook does it.
- A book with no file keeps today's sheet and gets no Download row. Without cwngsync loaded or configured,
  nothing changes anywhere.
- No settings key.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. cwngsync paths are
relative to `cwngsync.koplugin/` of `new-usemame/cwngsync.koplugin` at `df90d5e` (v4.1.46, `main.lua:46`),
read from a read-only clone. Repo paths are on `main` at `1e25e44`.

This feature builds on `library/context-menu` (F-l0kw8m, done): the book sheet over a record
(`book_sheet.lua:385-420`), its greyed rows for a book with no file (context-menu D2; `book_sheet.lua:230-268`,
`:282-332`), the holds that open it on the library and the shelf screens (`library_sheets.lua:250-284`).
`library/cover-grid` and `library/series-and-authors` drew the badge and chip (`library_tiles.lua:240-310`,
`shelf_rows.lua:357-483`). All three are on `main`.

### Decisions

Owner decisions (owner, 2026-10-17):

- **D1. A placeholder reads as not downloaded wherever KoPanda draws a book.** It takes the path-less
  record's badge and chip on the library grid (`library_tiles.lua:307-308`; `library_view.lua:226-230`), the
  one-author grid (`authors_screen.lua:243`), and the one-series list's badge, chip and note
  (`shelf_rows.lua:381-389`, `:464-466`, `:477-483`). Those are every place `LibraryTiles.book` and
  `ShelfRows.book` are called (`library_view.lua:229`, `library_covers.lua:41`, `authors_screen.lua:243`,
  `series_screen.lua:218`).
- **D2. Download** is a new row directly under Open on a placeholder's book sheet. It downloads through
  cwngsync. The book is not opened and the screen stays where it is. Once the book has arrived, its tile or row
  redraws without the badge (D17).
- **D3. Open is unchanged:** it downloads, then opens. KoPanda's Open runs the window's open
  (`book_sheet.lua:398-401`), `filemanagerutil.openFile` (`library.lua:65-76`), which reaches
  `FileManager:openFile` (`frontend/apps/filemanager/filemanagerutil.lua:518-520`) and then
  `ReaderUI:showReader` (`frontend/apps/filemanager/filemanager.lua:1637`). cwngsync replaces
  `ReaderUI.showReader` with a hook that hands a placeholder to `openLibraryPlaceholder`
  (`cwng_library_runtime.lua:1034-1050`). A tap on the tile or row keeps opening it the same way
  (`library.lua:97-101`, `series_screen.lua:277`, `authors_screen.lua:321`).
- **D4. Book details, Read status ›, More by this author › and Add to the home** work as for any book with a
  file (`book_sheet.lua:257-266`, `:288-308`). With its auto sync on (`cwng_auto_sync.lua:187`), cwngsync sends a status written from Read status to its server:
  it wraps `filemanagerutil.saveSummary` (`cwng_auto_sync.lua:214-229`) and queues the status by book id for a
  placeholder (`:186-212`, `:198-201`).
- **D5. Delete… is greyed** on a placeholder (`muted`, no `run`; a tap closes the sheet and runs nothing,
  context-menu D14). cwngsync's next sync would put a deleted placeholder back: a recorded placeholder whose
  file is gone gets `create_placeholder` (`cwng_library.lua:259-262`).
- **D6. The meta line reads "Not downloaded"**, as for a path-less record (`book_sheet.lua:94-97`).
- **D7. A path-less record is unchanged** (context-menu D2). It gets no Download row, since nothing can fetch it.
- **D8. Without cwngsync loaded or configured, nothing changes anywhere** (D12).
- **D9. KoPanda calls cwngsync's internal methods** rather than waiting for a public API. Every call is
  wrapped, so a failure leaves KOReader usable (AGENTS.md "Principles"). Each one is recorded in
  `kopanda.koplugin/HOOKS.md` with its file:line at `df90d5e`. When the state can't be read, nothing is badged
  (D12). When the download method is missing, the Download row is greyed (D16).
- **D10. The scope line narrows.** `AGENTS.md:46` puts "the CWNG library folder" out of scope. It now says
  KoPanda never manages or syncs that folder itself: it only reads cwngsync's placeholders and asks cwngsync to
  download one.
- **D11. No new settings key** (AGENTS.md "Few settings, strong defaults"); no timer or animation (E-ink
  rules). The only timer is cwngsync's own (D18).

Lead decisions, each overturnable at approval:

- **D12. What counts as a placeholder** is the same test `openLibraryPlaceholder` makes before it takes a file
  over (`cwng_library_runtime.lua:999-1009`), so whatever is badged, Download can fetch. All three must hold:
  - the plugin `isConfigured()` (`:144-149`);
  - its library state records the path as `kind = "placeholder"` (`cwng_library.lua:404-412`; state shape
    `:17-20`);
  - the file's size still equals the recorded `size`.

  The paths are compared as plain strings, as `placeholderAt` compares them (`:406`), so the badge holds for
  exactly the `record.path` that Open and Download hand to cwngsync. The size check is what `isLibraryPlaceholder`
  checks too (`cwng_library_runtime.lua:234-239`). It also makes a re-list during a download read the
  downloaded book right. cwngsync renames the real book over the placeholder and broadcasts
  `InvalidateMetadataCache` and `BookMetadataChanged` (`cwng_library_runtime.lua:957-964`; `main.lua:1612-1630`)
  before it records the book as `downloaded` (`cwng_library_runtime.lua:973`; `cwng_library.lua:346-352`).
  The shelf screens re-list at once on those events (`library_chrome.lua:662-671`), so at that moment the record
  still says placeholder but the size no longer matches. `libraryEnabled()` (`cwng_library_runtime.lua:154-156`)
  is not required, since `openLibraryPlaceholder` asks only `isConfigured()` (`:1000`).
- **D13. KoPanda reaches cwngsync as `FileManager.instance.cwngsync`.** The file manager registers each plugin
  instance under its plugin's name (`filemanager.lua:418-429`, `:379-384`); the name is `cwngsync`
  (`main.lua:43`). This is how KoPanda already reaches its own instance (`HOOKS.md:52-56`). With no file
  manager (in the reader), nothing is badged; the library windows only show over the file manager. The methods
  are on the instance: the runtime's functions are mixed into the plugin class (`main.lua:2555-2565`). KoPanda
  reads `getLibraryState().books` itself rather than requiring `cwng_library`. That module would be requireable
  only while cwngsync is enabled (`frontend/pluginloader.lua:283-287`), and reading the books is what its
  `placeholderIndex` does in five lines (`cwng_library.lua:420-426`). Two other methods are not used:
  - `isLibraryPlaceholder` (`cwng_library_runtime.lua:234-239`) walks every record per path through `placeholderAt` (`cwng_library.lua:404-412`), which would make
    `Books.all` quadratic.
  - `libraryPlaceholderTest` (`cwng_library_runtime.lua:245-260`) opens the zip of each small unrecorded file
    under the root (`:187-210`), which is per-tile disk work on a paint, and it accepts files that
    `openLibraryPlaceholder` refuses for lack of a record (`:1002-1003`).
- **D14. The flag rides on the record.** `books.lua`'s `record()` (`books.lua:127-150`) sets
  `placeholder = true` on a file's record that D12 says is a placeholder, and keeps its `path`. Every surface
  reads records, so they all follow it: the listing (`Books.folder`, `:263-280`), `Books.all` (`:302-329`) and
  the re-reads (`Books.for_path`, `Books.get`, `Books.with_progress`, `:333-359`, `:466-475`, which the arrivals
  and the closed book's rebuild use, `library_covers.lua:18-27`, `library_chrome.lua:413`). The placeholder set
  is made once per public `Books` call from the in-memory state, and each recorded path then costs one `stat`
  for its size. No zip is opened and no state is read per tile. `Books.files` (the folder counts,
  `books.lua:285-298`) is unchanged: a placeholder counts as a book of its folder.
- **D15. The strip and the bar follow the sidecar,** as for any file. A tile draws its strip from
  `record.path` and a percent (`library_tiles.lua:300`); a one-series row draws its bar from the progress
  (`shelf_rows.lua:457-460`). cwngsync writes the server's status and progress into a placeholder's sidecar so
  that a cover grid shows them (`cwng_library_runtime.lua:281-309`). So a placeholder read elsewhere can show
  its strip beside the badge and chip. A path-less record never shows a strip.
- **D16. The Download row:** label "Download", the registry's `download` icon (`icons.lua:74-77`), no
  detail, no sub-line. No board draws it. The icon's `used_in` names where the canvas draws an icon
  (`icons.lua:7-8`), so it stays as it is and the studio's catalog is unchanged. The row is greyed when the
  instance has no `openLibraryPlaceholder` function at hold time.
- **D17. Download hands cwngsync the window's re-list in place of the open.**
  - The row calls `plugin:openLibraryPlaceholder(record.path, on_arrival)` (`cwng_library_runtime.lua:999-1030`).
    cwngsync then waits for Wi-Fi (`NetworkMgr:runWhenConnected`, `:1010`; `frontend/ui/network/manager.lua:713-719`),
    shows "Downloading %1…", downloads synchronously (`:940-977`), and calls `on_arrival(file)` where it would
    have opened the book (`:1017`).
  - `on_arrival` asks for the book's cover afresh and re-lists the window it was held on at its page, if that
    window is still shown. The cover has to be asked for again because the download's `InvalidateMetadataCache`
    reaches CoverBrowser through the file manager's modules (`frontend/ui/widget/container/widgetcontainer.lua:80-107`),
    and CoverBrowser deletes the book's row (`plugins/coverbrowser.koplugin/main.lua:800-803`). Its handler returns true (`:802`), so the event stops inside the file manager there, but `UIManager:broadcastEvent` still hands it to every window, KoPanda's included (`frontend/ui/uimanager.lua:1042-1061`).
  - The library's re-list with a cover request is `Library:refresh_covers` (`library.lua:216-223`). The shelf
    screens ask for covers once per window (`library_chrome.lua:438-442`), so they get the same (the task's open
    fact).
  - The "recent" sort reads the reading history (`library_order.lua:155-170`), and a download writes none, so
    the book keeps its place.
- **D18. cwngsync's own messages and timer stay its own.** A failed download shows cwngsync's "Could not
  download…" (`:1022-1026`). With auto sync off, a success schedules cwngsync's inventory report 5 s later
  (`:1018-1020`). When `openLibraryPlaceholder` returns false (the file was replaced or its record is gone,
  `:1000-1009`), KoPanda re-lists the window, so the tile shows what the file now is.
- **D19. The module is `cloud_books.lua` (`CloudBooks`).** That name is free under the emulator's `frontend/`,
  `common/` and bundled plugins (`spec/unit/hooks_doc_spec.lua:104-122`'s rule) and among cwngsync's files.
  cwngsync's folder joins `package.path` on the Kindle (`frontend/pluginloader.lua:285`). "Placeholder"
  already names KoPanda's typographic cover (`featured_cover.lua:203-211`), so the module avoids it. The record
  field keeps cwngsync's word, `placeholder`.
- **D20. One new golden, in Diner** (owner's goldens rule, `.tiller/chores/fewer-goldens-per-feature/chore.md`,
  CH-58w77v, approved at `1e25e44`): the library grid with a placeholder at its root, the badge and chip as
  `.tiller/design/2026-10-16-kopanda-library-screens/Main.dc.html:66-73` draws them. Editorial draws the same tile in its own tokens, which needs no second golden.
  No board draws the Download row or a placeholder's sheet, so they get no golden; the owner judges them on the
  emulator in both looks (C11).

### Detection

`CloudBooks.index()` returns the set `{ [path] = size }` of recorded placeholders, or nil:

- nil with no file manager instance, no `cwngsync` module on it, or `isConfigured()` false. Each of these is
  silent: cwngsync absent or unconfigured is a normal state.
- nil, logged, when a needed method is missing, any call raises, or the state has no `books` table.
- Otherwise every `books` entry with `kind == "placeholder"`, a string `path` and a number `size`. An entry
  missing any of those is skipped.

`CloudBooks.is(index, path)` is true when `index[path]` equals `lfs.attributes(path, "size")`. `books.lua`
builds the index once per public call and hands it to `record()`. `record()` gives `placeholder = true` to a
file record that matches; every other record is unchanged.

`getLibraryState()` reads cwngsync's state files the first time anything asks for them in the process
(`cwng_library_runtime.lua:104-118`, `:86-102`). cwngsync asks on its first sync (`:766-790`), which runs only
when connected, so KoPanda's first listing may be the first to ask.

### The surfaces

"Not downloaded" means `not record.path or record.placeholder` everywhere a book is drawn as not on the
Kindle:

- the tile's foot and badge (`library_tiles.lua:307-308`), the Up next label still taking the chip's place
  (`:242-264`);
- the one-series row's chip, note and badge (`shelf_rows.lua:381-389`, `:464-466`, `:477-483`);
- the book sheet's meta (`book_sheet.lua:94-97`).

What needs a file still keys on `record.path`, so a placeholder keeps it: the strip (D15), the tap's open
(D3), Open, Book details, Read status, Add to the home (D4), the cover reads (`book_covers.lua:88-92`) and
Refresh covers (`library_sheets.lua:166-175`).

### The book sheet on a placeholder

Rows in order: Open, **Download** (D16, D17), Book details, Read status ›, More by this author ›, Add to the
home, Delete… (greyed, D5). Meta "Not downloaded" (D6). The header's cover is the placeholder's cached cover,
as for any file. A path-less record's sheet and a downloaded book's sheet keep their rows (D7).

The Download row's tap:

1. The sheet closes first, as every row's tap does (`sheet.lua:320-325`).
2. The row reads `FileManager.instance.cwngsync`. With no instance, or no `openLibraryPlaceholder`, it logs and
   does nothing.
3. It calls `openLibraryPlaceholder(record.path, on_arrival)`.
   - It returns true: cwngsync owns the rest.
   - It returns false: the window re-lists (D18).
   - It raises: logged, window as it was.
4. `on_arrival` runs only if the window it was held on is still the one shown (`library.lua:160-166`,
   `library_chrome.lua:656-660`). It never opens a reader.

### Failure behaviour

As the sheets' and the library's (context-menu "Failure behaviour"): a detection that raises is logged and the
listing goes on with no placeholders, as today. A raising Download row is logged and leaves the window shown.
A raising `on_arrival` is logged. cwngsync's own failures are reported by cwngsync (D18). In every case the file
manager stays on top and handles input.

### HOOKS.md

A new Plugin-section entry, "cwngsync's placeholders", cites:

- `FileManager.instance.cwngsync` and the registration it relies on (`filemanager.lua:379-384`, `:424`);
- `isConfigured` (`cwng_library_runtime.lua:144-149`);
- `getLibraryState` and its one-time disk read (`:104-118`), and the state shape (`cwng_library.lua:17-20`);
- the placeholder test KoPanda mirrors (`cwng_library.lua:404-412`; `cwng_library_runtime.lua:999-1009`, `:234-239`);
- `openLibraryPlaceholder` and `downloadLibraryBook` (`:940-977`, `:999-1030`), and the broadcasts and
  CoverBrowser's row deletion D17 relies on (`main.lua:1612-1630`; `plugins/coverbrowser.koplugin/main.lua:800-803`);
- the re-creation behind D5 (`cwng_library.lua:259-262`);
- the open hook behind D3 (`cwng_library_runtime.lua:1034-1050`) and the status hook behind D4
  (`cwng_auto_sync.lua:186-229`).

`main.lua` requires `cloud_books` at load (`spec/unit/main_requires_spec.lua`).

### Goldens and budget

- **New:** `library-placeholder-diner-colorsoft`, over cover-grid's capture library (`spec/emulator/capture_library.lua`)
  at its root. A scenario patch registers a stub `cwngsync` on the file manager whose state names
  `a-christmas-carol.epub` at the root as a placeholder of its own size. The library's settled signal is the
  shot; `paint_ms` is within the paint budget (`spec/emulator/paint_budget.lua:15`).
- **Unchanged:** every existing golden. Their captures load no cwngsync.

## Notes

For the owner, besides the lead decisions D12 to D20 above:

- **D20 follows the goldens rule** (CH-58w77v): one look unless the structure differs, and no golden for an
  undrawn state. No board draws the Download row, so the plan has one Diner grid golden and you judge the held
  sheet on the emulator.
- **`books.lua` is 500 lines** and D14 adds a few. AGENTS.md treats 500 as a signal to plan a split; not split
  here.
- **The home's featured book draws no not-downloaded state** (owner, 2026-10-17). A pinned placeholder (D4's
  Add to the home) is featured as a book with a file, and its tap downloads and opens it through cwngsync's
  hook. The home stays outside the three surfaces of D1.
- **The design doc says the same scope line.** `2026-10-13-kopanda-design.md:139-141` lists "the CWNG library
  folder" as out of scope. D10 narrows `AGENTS.md:46` only; the design input is left as written.
- **cwngsync is pinned at `df90d5e` here, not by KoPanda.** An update on the Kindle can rename what D12, D13
  and D17 call. The wrapping (D9) keeps KOReader usable, but the badge or the row would quietly go. HOOKS.md's
  entry is the place to re-check on an update.
