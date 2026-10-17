# cwngsync's placeholders read as not downloaded on every surface that draws a book

## Approach

Detecting placeholders, flagging their records, and drawing every surface from the flag. Repo lines are
`main` at `1e25e44`; KOReader is relative to `~/Projects/kodev/koreader/` at `e1fe1ac`; cwngsync is relative to
`cwngsync.koplugin/` at `df90d5e`. Covers feature sections "Detection", "The surfaces", "Failure behaviour" and
"HOOKS.md"; decisions D1, D5, D6, D8 to D15 and D19; criteria C1, C2, C4, C5 and C6.

1. **`kopanda.koplugin/cloud_books.lua` (`CloudBooks`, new; D19).**
   - `CloudBooks.index()`:
     - reads `package.loaded["apps/filemanager/filemanager"]`, as `book_sheet.lua:37-40` does, then its
       `instance`, then `instance.cwngsync` (D13);
     - returns nil silently when there is no instance or no module, or when `plugin:isConfigured()` is false;
     - returns nil and logs when either method isn't a function, when a call raises, or when
       `getLibraryState()` gives no table `books`;
     - otherwise returns `{ [path] = size }` for each `books` entry with `kind == "placeholder"`, a string
       `path` and a number `size` (`cwng_library.lua:17-20`, `:420-426`). Every call is inside one `pcall`.
   - `CloudBooks.is(index, path)`: `index ~= nil`, `index[path] ~= nil` and
     `lfs.attributes(path, "size") == index[path]` (D12).
   - The module holds no state, so a download, a sync or a reconfigure shows at the next `Books` call.
2. **`books.lua`.**
   - `record(path, always_sidecar, props_of)` (`books.lua:127-150`) takes a fourth argument, the index. It sets
     `placeholder = true` on the returned table when `CloudBooks.is(index, path)`, and leaves the field out
     otherwise, so every record without cwngsync is byte-for-byte what it is today.
   - Each public entry builds the index once and passes it down: `Books.folder` (`:263-280`), `Books.all`
     (`:302-329`, once for the whole walk), `Books.for_path` (`:333-338`, and through it `Books.get`'s file
     branch, `:345-348`) and `Books.with_progress` (`:466-475`).
   - `Books.files` (`:285-298`) and the source records (`:154-177`) don't change.
   - The file's header comment names the new source of a record's field.
3. **The surfaces (D1).** One test, `not record.path or record.placeholder`, at each place a book is drawn as
   not on the Kindle:
   - `library_tiles.lua:307-308`: the foot and the badge. The `badged` argument becomes that test, and the Up
     next chip still replaces the Not downloaded one (`:242-264`).
   - `shelf_rows.lua:384` (the chip), `:464` (the note) and `:477` (the badge).
   - `book_sheet.lua:95`, the meta (D6).
   - The strip's `record.path` (`library_tiles.lua:300`) stays as it is (D15). Update the comments that say
     "path-less" at those places to say "not downloaded".
   A small shared predicate, if one reads better than three copies, goes in `books.lua` as
   `Books.downloaded(record)` (the name may follow what reads best). The surfaces must not require
   `cloud_books`.
4. **Delete greyed (D5).** `delete_row(file, window)` (`book_sheet.lua:315-332`) takes the record, or a
   `placeholder` flag beside the file, and returns the row `muted` with no `run` for a placeholder. The other
   rows stay as `book_rows` and `home_row` build them for a file (`:237-268`, `:288-308`).
5. **`main.lua`** requires `cloud_books` (`spec/unit/main_requires_spec.lua`).
6. **`HOOKS.md`**: the new Plugin-section entry "cwngsync's placeholders" (feature "HOOKS.md"), the detection
   half:
   - `FileManager.instance.cwngsync` and its registration (`filemanager.lua:379-384`, `:424`);
   - `isConfigured` (`cwng_library_runtime.lua:144-149`);
   - `getLibraryState` and its one-time read (`:86-118`), and the state shape (`cwng_library.lua:17-20`);
   - the test it mirrors (`cwng_library.lua:404-412`; `cwng_library_runtime.lua:234-239`, `:999-1009`);
   - why it is not `libraryPlaceholderTest` (`:245-260`, `:187-210`);
   - the re-creation behind D5 (`cwng_library.lua:259-262`);
   - the open hook behind D3 (`cwng_library_runtime.lua:1034-1050`) and the status hook behind D4
     (`cwng_auto_sync.lua:186-229`).
   Every cwngsync citation names `new-usemame/cwngsync.koplugin` at `df90d5e`.
7. **`AGENTS.md:46` (D10).** Replace "the CWNG library folder" with a clause saying KoPanda never manages or
   syncs the CWNG library folder itself, and only reads cwngsync's placeholders and asks cwngsync to download
   one. The rest of the line is unchanged.

## Surfaces

- `kopanda.koplugin/cloud_books.lua` (new), `books.lua`, `library_tiles.lua`, `shelf_rows.lua`,
  `book_sheet.lua`, `main.lua`, `HOOKS.md`.
- `AGENTS.md`.
- `spec/unit/cloud_books_spec.lua` (new).

## Tests

Write each test first and run it failing before the code. All go in `spec/unit/cloud_books_spec.lua`, under
the plugin harness with a real file manager (`harness.show_fm`, as `book_sheet_spec.lua:104-106` uses it). The
stub `cwngsync` is registered with `fm:registerModule("cwngsync", stub)` and removed after each case, as
`quick_settings_controls_spec.lua:597-606` does. Its state names files the case writes to a scratch home folder.

- **C1, detection and records:**
  - A configured stub whose state records `<home>/a.epub` as a placeholder of a.epub's size: `Books.folder(home)`
    gives a.epub's record `placeholder = true` with its `path`, and b.epub's none. `Books.all`,
    `Books.for_path`, `Books.get("file:" .. realpath)` and `Books.with_progress` give the same.
  - Each of these gives no `placeholder` field: a recorded size one byte off; `kind = "downloaded"`; a path
    recorded with a trailing `//` or through a symlink; `isConfigured()` false; no module; no file manager
    instance.
  - Each of these gives no flag and one logged error, with the listing otherwise identical: `getLibraryState`
    missing, raising, or returning `{}` or `{ books = "x" }`.
  - `getLibraryState` called once by one `Books.all` over a folder of three books, and once by one
    `Books.folder`.
  - Path-less source records and `Books.files` are unchanged with the stub registered.
- **C2, surfaces:**
  - `LibraryTiles.book` for a placeholder record: `tile.badge` and `tile.chip` set, the chip "Not downloaded";
    with `{ label = "Up next" }`, the chip Up next and the badge kept; with a progress of 40 % reading, `tile.strip`
    set beside them.
  - `ShelfRows.book` for a placeholder: `row.badge` set, the chip "Not downloaded" (or "Finished" for complete),
    the note "Not on the Kindle yet" with no progress, the bar and no note at 40 % reading, and "read this one next" in the note's place when marked (`shelf_rows.lua:461-466`).
  - The library's, the one-series list's and the one-author grid's tap on a placeholder calls the window's open
    with that record (`library.lua:90-101`; `series_screen.lua:268-280`; `authors_screen.lua:310-325`).
  - `BookSheet.open_record` over a placeholder: meta "Not downloaded"; Delete `muted` with no `run`, and a tap on
    it runs nothing; Open, Book details, Read status, More by this author and Add to the home have a `run`, and
    Book details calls `fm.bookinfo:show(record.path)`.
  - The same tile, row and sheet built for that file without the stub carry no badge and no Not downloaded
    meta, and Delete runs.
- **C4:** `books_spec.lua`, `library_tiles_spec.lua`, `shelf_rows_spec.lua`, `book_sheet_spec.lua`,
  `library_screen_spec.lua`, `series_screen_spec.lua`, `authors_screen_spec.lua`, `library_sheets_spec.lua`
  and `failsafe_spec.lua` pass unchanged.
- **C5:** `hooks_doc_spec.lua` and `main_requires_spec.lua` pass with `cloud_books`.
- **Scope check:** confirm `bin/check spec/unit/cloud_books_spec.lua` runs that file alone and its summary
  names only its cases.

## Edge cases

- **Path forms.** cwngsync records `join(root, book.filename)` (`cwng_library.lua:41-43`, `:187`). KoPanda's scanned path is
  `join(dir, name)` from `home_dir` trimmed (`books.lua:190-201`, `:229`). When the owner's `home_dir` is the
  CWNG root or a parent of it, given the same way, the strings match. When it is given another way (a symlink,
  another mount name), nothing is badged and the book reads as downloaded, as today. cwngsync's own open hook
  would then miss the same path from KoPanda's Open (D12), so the badge never claims what Download can't do.
  Say so in `HOOKS.md`.
- **The first state read.** On the first listing in a process where cwngsync hasn't synced yet,
  `getLibraryState()` reads `cwngsync_library.lua` and, when the revisions match, `cwngsync_library_list.lua`
  (`cwng_library_runtime.lua:86-118`), once. Its cost on the Kindle is unknown here. The owner's C12 notes the
  first open; if it is slow, bring it to the lead, not a cache.
- **A sync in flight** changes the state one action per tick (`cwng_library_runtime.lua:657-760`). A listing
  reads it as it stands. cwngsync's own `refreshLibraryViews` broadcasts after it changes files
  (`main.lua:1612-1630`), and the windows re-list on those events (`library.lua:192-198`,
  `library_chrome.lua:662-671`).
- **A placeholder's sidecar.** cwngsync writes status and progress there (`cwng_library_runtime.lua:285-309`), so
  `Books.progress` reads it as any file's. The Show filter and the shelf chips follow it (D15).
- **`books.lua` is 500 lines.** It passes 500 with this change; if it nears 520, move the index plumbing into
  `cloud_books.lua` and say so in the PR.
- **`hooks_doc_spec`'s collision check** doesn't see cwngsync's files. Check by hand that no KoPanda module
  name, `cloud_books` included, is a file in the cwngsync clone.
