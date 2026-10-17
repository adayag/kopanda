# Entry points into the library and the return after a book closes

## Approach

Everything that reaches the library from elsewhere in KoPanda, and the return after reading. Starts after
`screen`. Repo lines on `main` at `4564444`; KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`.
Feature sections "Entry points", "Book close", decisions D4, D6.

1. **The `library` target** (`launcher_entries.lua:123-129`): `Home.close()`, then `Library.show` at
   `LibraryOrder.left()` or the root's first page, through `KoPanda`'s guarded show (below). When the
   library is already shown, a tap on its own Library tab instead goes to the root's first page: the target
   checks `Library.shown`. Every caller follows: the launcher, the Library tab on the home, in the file browser
   and on the library (`nav_bar.lua:65-88`), and the featured first-run button
   (`widgets/featured.lua:466-472`, changed to run the target instead of `fm:onHome()`).
2. **The show:** `KoPanda:showLibrary(opts)` beside `showHome` (`main.lua:123-181`), refusing when there is
   no `FileManager.instance`. The boot guard is armed only on the process's first show (`main.lua:141-142`),
   always the home's, so the library takes no part in it. On a build failure: log, close
   the home, `fm.file_chooser:changeToPath(dir)` (`frontend/ui/widget/filechooser.lua:341-371`).
3. **The return:** `Library.on_open(dir, page)` records `Library.return_to = { dir, page }`.
   `KoPanda:onCloseDocument` (`main.lua:248-257`) pre-builds the library at the return when one is recorded,
   else the home as today. `KoPanda:onShow` (`main.lua:189-212`) shows a pending library, dropping one built
   for another size or variant as `take_pending` does (`home.lua:258-283`); with a return and no pending
   library (a failed open, `readerui.lua:734`, `:754`, `:764`), it builds the library afresh; either way it
   clears the return. Taking a pending library, it re-reads the closed book's progress and rebuilds its
   tile: the reader saves its sidecar after `CloseDocument` (`readerui.lua:887`, then `:874-877` on its
   close at `:893`), as the home refreshes on taking its own (`home.lua:274-281`). A new reader's `init`
   drops a stale pending library as it drops a stale home (`main.lua:99-103`).
4. **Closing with the file manager:** `KoPanda:onCloseWidget` (`main.lua:261-268`) closes the library as it
   closes the home.
5. `HOOKS.md` gains `onShowingReader` (`filemanager.lua:842-849`), the failed-open paths and `changeToPath`.

## Surfaces

- `kopanda.koplugin/launcher_entries.lua`, `main.lua`, `library.lua`, `widgets/featured.lua`, `HOOKS.md`.
- `spec/unit/library_lifecycle_spec.lua`, `spec/unit/launcher_entries_spec.lua`, `spec/unit/nav_bar_spec.lua`,
  `spec/unit/fm_nav_spec.lua`, `spec/unit/featured_widget_spec.lua`, `spec/unit/prebuild_spec.lua`,
  `spec/unit/failsafe_spec.lua`, `spec/emulator/book_close_spec.lua` and its scenario if a case is added there.

## Tests

Written first, each run failing before the code:

- `library_lifecycle_spec.lua` (C8): the target from the home, the file browser and the library; the first
  time at the root; the left folder and page after a close; the Home tab; closing the file manager closes
  the library; a book opened from the library (`filemanagerutil.openFile` stubbed to send `CloseDocument`
  and reopen a file manager through the harness, as `prebuild_spec.lua` drives the home's) shows the library
  pre-built at the same folder, sort, status and page; a pending library of another size or variant
  dropped and rebuilt; the taken library showing the closed book's progress written after `CloseDocument`;
  a failed open shows it afresh; a cancelled open (the stub not running the pre-callback) records no
  return; a book opened from the home closes to the home.
- `launcher_entries_spec.lua`, `nav_bar_spec.lua`, `fm_nav_spec.lua`, `featured_widget_spec.lua` (C8): their
  Library cases change from `onHome` to the library on purpose; every other case unchanged.
- `failsafe_spec.lua` (C11): a library that fails to build leaves the file browser at that folder with the
  home closed.
- `hooks_doc_spec.lua` (C13) passes with the new entries.
- An emulator case in `book_close_spec.lua`, if its scenario can open a book from the library: closing it
  lands on the library in one show, with `KoPandaSettled{ screen = "library" }` and `prebuilt` true. Determine
  whether the existing scenario (`spec/emulator/scenarios/2-scenario-book-close.lua`) can be extended by
  reading it; if it can't without rewriting it, leave the emulator case to `goldens` and say so in the PR.

## Edge cases

- History opened over the library (the History tab) and a book opened from it: KOReader's History closes
  itself and opens the book (`filemanagerhistory.lua:169-171`); no return was recorded, so the book closes to
  the home. That is D4's "opened from anywhere else".
- A book opened from the library, then another opened from inside the reader: the return still stands and
  the library comes back.
- The return in memory only: a restart shows the home (feature "Book close").
- The rotation reset on `showFiles` (`filemanager.lua:1322`) can change the size between the pre-build and
  the show; `take_pending`'s rule handles it.
