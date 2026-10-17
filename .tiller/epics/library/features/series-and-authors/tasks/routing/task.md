# Entry points, the Authors tab, More by this author and the return after a book closes

## Approach

Everything that reaches the two windows from elsewhere in KoPanda, the placeholders' end, and the return after
reading. Starts after `authors`. Repo lines on `main` at `b05fe55`; cover-grid's routing as its spec says
(routing task.md:9-30). Feature sections "Entry points", "Book close", decisions D6, D7, D17, D23.

1. **The shows:** `KoPanda:showSeries(opts)` and `KoPanda:showAuthors(opts)` beside cover-grid's
   `showLibrary` (feature.md:328-330), refusing without `FileManager.instance`; a build failure logged, the
   home closed, the file browser left up (feature "Failure behaviour"). The boot guard is the home's alone
   (`main.lua:142-179`).
2. **The targets** (`launcher_entries.lua:122-139`): `series` and `authors` close the home and show their
   window's list at page 1 (D17) through those shows, in place of `note(...)` (`:130-135`); `authors` with an
   Authors window shown goes to its list's first page. The two note strings are deleted; `note` stays for its
   other callers (`:141-151`). The `library` target, cover-grid's, closes these windows too, through the
   chrome's one-window rule.
3. **The Authors tab** runs the `authors` target (`nav_bar.lua:76`), from the home, the file browser, the library
   and these windows. Its Home tab's branch is the screens tasks'.
4. **More by this author** (`book_sheet.lua:232-239`): the row reads the record by `Books.for_path(book.file)`
   (`books.lua:294-301`), then shows `AuthorsScreen` at `{ kind = "author", name = record.authors[1] }`
   through `showAuthors`, or the list when the record is nil or has no author. The sheet is closed by the tap
   before the row runs (`sheet.lua:575-591`); the home closes on the show. A raising row is the sheet's own
   failure path (`sheet.lua:479-483`).
5. **The return (D7):** each window's `on_open(view, page)` records `{ screen, view, page }` as the return,
   the chrome's record extended from the library's `{ dir, page }` (cover-grid routing task.md:19).
   `KoPanda:onCloseDocument` (`main.lua:244-258`) pre-builds the recorded window at that view and page;
   `KoPanda:onShow` (`main.lua:184-213`) shows it, or builds it afresh with no pending one (a failed open),
   dropping one built for another size or variant, and clears the return, as cover-grid's routing does for the
   library. The taken window re-reads the closed book's progress and rebuilds the view (the series' state and
   chip, the book's row or tile): the reader saves its sidecar after `CloseDocument` (cover-grid feature.md
   :315-317). A view gone by then: the list at page 1 (D23).
6. **Closing with the file manager:** `KoPanda:onCloseWidget` (`main.lua:260-269`) closes any chrome window,
   which the chrome refactor already routes for the library.
7. **The placeholder specs change on purpose:** `launcher_entries_spec.lua:362-368` (the notes) and
   `book_sheet_spec.lua:23`, `:428-440` (the note on More by this author) become the new behaviour's cases.
   The design docs and the launcher, sheets and nav-bar specs that quote the notes (`2026-10-13-kopanda-ui-direction.md:26`,
   `home/launcher` feature.md:16, :168, `home/sheets` feature.md:15, :322, `nav-bar/nav-bar` feature.md:74)
   are history of done features and are left as they are.

## Surfaces

- `kopanda.koplugin/launcher_entries.lua`, `book_sheet.lua`, `main.lua`, `library_chrome.lua`,
  `series_screen.lua`, `authors_screen.lua`, `HOOKS.md` (the `CloseDocument` entry names the windows the
  pre-build covers).
- `spec/unit/shelf_lifecycle_spec.lua`, `spec/unit/launcher_entries_spec.lua`, `spec/unit/book_sheet_spec.lua`,
  `spec/unit/nav_bar_spec.lua`, `spec/unit/fm_nav_spec.lua`, `spec/unit/prebuild_spec.lua`,
  `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code:

- `shelf_lifecycle_spec.lua` (C8): the Series and Authors targets from the home, the file browser and the
  library, each leaving one KoPanda window up at the list's first page; the Authors tab on one author going to
  the list's first page; the Library tab from a series window showing the library; Home closing; the file
  manager's close taking the window; a book opened from one series and from one author (`openFile` stubbed to
  send `CloseDocument` and reopen a file manager, as `prebuild_spec.lua` drives the home's) shown pre-built at
  the same view and page with the book's progress written after `CloseDocument`; a pending window of another
  size or variant dropped and rebuilt; a failed open shown afresh; a series renamed between open and close
  showing the list at page 1; a cancelled open recording no return; a book opened from the library still
  returning to the library.
- `launcher_entries_spec.lua` (C8): the Series and Authors cases show their windows and no `InfoMessage`;
  every other case unchanged.
- `book_sheet_spec.lua` (C8): More by this author shows the first author's books for a two-author book, the
  list for a book with no author; `NOTE` and its case go; every other case unchanged.
- `nav_bar_spec.lua`, `fm_nav_spec.lua` (C8): the Authors tab from the home and the file browser shows the
  Authors list.
- `failsafe_spec.lua` (C9): a window that fails to build on a target leaves the file browser up, the home
  closed.
- `prebuild_spec.lua` passes with the home's cases unchanged (C11).
- `hooks_doc_spec.lua` (C12) passes with the `CloseDocument` entry's change.

## Edge cases

- History opened over a series window and a book opened from it: no return recorded, so it closes to the home
  (cover-grid D4's "opened from anywhere else").
- Two authors with the same first author's name written differently on two books ("Mary Shelley", "Mary W.
  Shelley"): the row opens the one this book's record names.
- `Books.for_path` reads the sidecar always (`books.lua:294-301`): one read on a tap, not on the sheet's open.
- A return recorded, then KoPanda restarted: the return is in memory only, so the home shows (D18).
