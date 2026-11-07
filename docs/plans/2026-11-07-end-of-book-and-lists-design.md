# End of book, highlights, Favorites and History (2026-11-07)

Four changes, each chosen by the owner: a KoPanda sheet at the end of a book, highlights and notes in the Bookmarks list, an Add to Favorites row, and KoPanda windows for History and Favorites. No settings key is added.

KOReader citations are at the pinned build `e1fe1ac`, under `frontend/`.

## Why

Focused mode exists so readers never meet KOReader's menus, yet three everyday paths still end in one: the end of a book shows KOReader's pop-up (`apps/reader/modules/readerstatus.lua:57`), a highlight can be made but only found again through KOReader's list, because the Bookmarks list keeps only annotations with no drawer, and the History tab and the Favorites launcher slot open KOReader's list screens (`launcher_entries.lua`). The hold sheet also has no way to add a book to Favorites.

## End of book

`FocusedHooks.install` wraps `ReaderStatus:onEndOfBook` (`readerstatus.lua:38`), as its other hooks are wrapped: on a failure, or with the mode off, the original runs.

The sheet takes over only when all of these hold; otherwise the original runs:

- `Focused.on()`.
- `end_document_action` is unset or `"pop-up"` (`:57`). Any other value is a choice the owner made in KOReader.
- `G_reader_settings:readSetting("lastfile")` isn't `QuickStart.quickstart_filename` (`:41-43`).

A second `EndOfBook` while the sheet is up shows nothing new, as the original's `top_widget.name ~= "end_document"` does (`:58`).

The book is marked finished first, through `ui.status:markBook(true)` (`:212`), unless its summary already reads `complete`, so a re-read keeps its finish date. Then `ui.doc_settings:flush()`, as `deleteFile` does (`:198`), so Book details and the next-book lookup read the new status.

The sheet is `Sheet.show` with `name = "end_of_book"`, the header `{ heading = <book title>, label = "Finished" }`, `beneath = NOOP` as the panel's, and these rows:

1. **Next: \<title\>**, only when the book has a series with a next unread book.
2. **Book details**: `BookStatusScreen.show` with `opener = { screen = "reader" }`. `BookStatusScreen:back` already closes the window with no file manager (`book_status_screen.lua:417-423`), which lands on the book; `LABELS.reader = "Book"` names the back control.
3. **Back to the start**: `ui.gotopage:onGoToBeginning()` (`readerstatus.lua:88`).
4. **Home**: `ui:onClose()` then `ui:showFileManager(file)`, as the panel's Home does.

A tap outside closes the sheet and leaves the reader on the last page, the book still marked.

### The next book

Skipped entirely when the book's record has no `series`, so a book outside a series walks nothing. Otherwise: `Books.all()`, kept to that series' records, through `ShelfOrder.series(records, progress_of)`, whose entry's `next` is the first book neither complete nor abandoned in series order (`shelf_order.lua:38-62`). `progress_of` reads the finished book as `complete` regardless of the sidecar, since the progress memo is keyed by a one-second modification time. A failure anywhere leaves the row out.

- A next book with a real file opens through `filemanagerutil.openFile(ui, file)` on the next tick (`readerstatus.lua:184-188`).
- A next book with no file, or a cwngsync placeholder, can't be opened: its row carries the sublabel "Not downloaded", and a tap clears `Library.return_to`, which `ScreenRoutes.return_window` reads first, sets `LibraryChrome.return_to = { screen = "series", view = { kind = "series", name = <series> }, page = 1 }`, then closes the book. The file manager's show takes that return (`ScreenRoutes.show_return`), and the Series window offers Download.

`CloudBooks.read` finds cwngsync on the file manager's instance, which doesn't exist while a book is open, so in the reader every placeholder would read as a real file. It falls back to `ReaderUI.instance`, on which KOReader registers the same plugin under the same name (`apps/reader/readerui.lua:464-474`, `registerModule` `:94-96`; the file manager's is `apps/filemanager/filemanager.lua:418-424`, `:379-381`).

## Highlights and notes

The Bookmarks list holds every annotation, newest first as now. The panel doesn't change: the cell, the list's title and the Bookmark toggle stay.

`GotoList.bookmarks` drops its `not item.drawer` filter. Each entry gains `kind`, `"bookmark"`, `"highlight"` or `"note"` (a `drawer` with a `note`), and the entry's `text`, `item.text` (`text_orig` exists only inside KOReader's own list, `readerbookmark.lua:676`).

Rows stay the plain one-height rows. A page bookmark reads its chapter, as now. A highlight reads its text in curly quotes on one line, a note the same after `Note · `: a word rather than an icon, so no glyph or icon set changes. The page stays at the right. The empty note becomes "No bookmarks or highlights yet".

A tap jumps as a bookmark does: `ui.bookmark:gotoBookmark(item.page, item.pos0)`.

A hold shows the sheet headed by the chapter and page. A highlight or note also shows its text and its note, wrapped, in a new optional `text` block in the sheet: a list of `{ part, text }` paragraphs under the header, above the rows, in a `TextBoxWidget`, the block's height at most 60% of the screen and the end ellipsised beyond it. The one row is **Remove bookmark**, **Remove highlight** or **Remove note**. `GotoList.remove_bookmark` needs no change: `ReaderBookmark:removeItem` already routes a drawer to `deleteHighlight` (`readerbookmark.lua:446-454`).

## Add to Favorites

`BookSheet` gains a row, in both `BookSheet.open` and `open_record`, beside Add to the home: **Add to Favorites**, or **In Favorites** ticked. A tap toggles: `ReadCollection:addItem(file, "favorites")` then `:write({ favorites = true })` (`readcollection.lua:149`, `:73`), or `:removeItem(file, "favorites")` (`:188`), then the opener's refresh. Muted with no file; a placeholder may be added, since it is a file. The favourites collection always exists (`:44-46`).

The icon is `bookmark`, as the launcher's Favorites entry.

## History and Favorites windows

One window, `book_lists_screen.lua`, `screen = "book_list"`, `view = { list = "history" | "favorites" }`, modelled on `search_screen.lua`: cover tiles, a page at a time, with the nav bar. `SHELVES.book_list` in `screen_routes.lua` gives it the opener and return routes every other shelf has.

`book_lists.lua` is the model, a thin read of KOReader's two lists:

- `history()`: `ReadHistory.hist` in order (`readhistory.lua:25-35`, newest first), skipping `dim` entries (a deleted file).
- `favorites()`: `ReadCollection:getOrderedCollection("favorites")` (`readcollection.lua:366`), KOReader's order, so its screen and ours agree. Under a sort set in KOReader's collection menu (`coll_settings.favorites.collate`) items have no `order` (`:137`, `:82-85`) and that call raises, so the list is `ReadCollection.coll.favorites` sorted by `item.text`, a plain file-name order, not KOReader's sort.
- `records(paths, library)`: those paths mapped onto `LibraryChrome.books()` by id (`"file:" .. path`: both lists hold realpaths, a file's id holds its realpath, a record's `path` may not), a miss falling back to `Books.for_path`, and a path with no record dropped. The history holds up to 500 books (`readhistory.lua:82`), so a per-path sidecar read at each open is what this avoids.
- `add_favorite`, `remove_favorite`, `is_favorite`, `remove_from_history`: `ReadHistory:removeItemByPath` (`:295`).

Header: the title form, as Stats', "History" or "Favorites", with the count at the right, no back control. Empty notes: "No books read yet", "No favorites yet".

The window's `on_open` sets `LibraryChrome.return_to` with its view and page, so closing a book returns to the list.

Holds use `BookSheet.open_record`. History adds one row, **Remove from history**, through a new `opts.extra_rows`. In Favorites, the toggle removes the book and the window refreshes.

### Routing

- `nav_bar.lua`: `id == "history"` shows the window, or its first page when History is up, as Stats does. `where` is the list's name, `ACTIVE.history = "history"`, Favorites lights no tab. `WINDOWS` gains both, so the library's snapshot isn't forgotten on the way in.
- `launcher_entries.lua`: a `koreader` entry with target `history` or `favorites` shows the window. Stored entries don't change, so nothing migrates. If the show returns nil, the dispatcher action runs, so a failure still reaches KOReader's list.
- `KoPanda:showBookList(opts)` in `main.lua` follows `showStats`. `main.lua` is at 504 lines: the addition stays two or three lines.
- Gestures bound to KOReader's history action, and History inside the reader's own menu, stay KOReader's.

## Tests

Unit specs for each pure part: the end-of-book gate and its marking, the next book (a threshold at each of: no series, last of a series, the next abandoned, the next not downloaded), the bookmark kinds and rows, the sheet's text block, the favourites toggle, the order and filtering of both lists, the routes. Emulator: the end-of-book sheet is driven and reported through a scenario patch, and the book-list window gets one view in `series_authors_capture_spec.lua`, with `paint_budget_spec.lua` covering its show.
