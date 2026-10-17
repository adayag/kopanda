# Add to the home and Delete on the library's book sheet

## Approach

The two rows only the record entry has, after More by this author, in the board's order (HoldBookC:65-72).
Starts after `book-sheet` (the record entry) and `icons` (`home_plus`, `trash`). Repo lines on `main` at
`5d8a955`; KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Feature sections "The book sheet",
"Delete", decisions D2, D7, D8; criteria C4, C8, C11.

1. **Add to the home (D8),** icon `home_plus`:
   - The realpath is `ffiutil.realpath(record.path) or record.path`, as the picker writes the history's
     realpath (`book_sheet.lua:151`, `:162`; history holds realpaths, `readhistory.lua:26`).
   - Already pinned: `Settings.get("featured.pinned")` is a file whose realpath equals it, read as the picker
     reads the pin (`book_sheet.lua:161-163`). Then the label is "On the home" and the row `tick = true`, so
     a tap closes the sheet and runs nothing (`sheet.lua:578-591`).
   - Otherwise label "Add to the home"; `run` calls `Settings.set("featured.pinned", real)`
     (`settings.lua:307`; the `path` validator, `:198-203`, takes any absolute path). A refused write is
     logged and changes nothing, as `pin` logs it (`book_sheet.lua:123-128`). The window stays shown: no
     `home:refresh()`, no `after_show`, since the home is closed while a library window is up
     (cover-grid feature.md:126-127) and builds afresh on its next show.
   - Greyed (`muted`, no `run`) for a record with no `path` (D2).
2. **Delete… (D7),** icon `trash`, label "Delete…", last:
   - `run`: `FileManager.instance:showDeleteFileDialog(record.path, post_cb)`
     (`frontend/apps/filemanager/filemanager.lua:1121-1152`), as the file browser's own Delete calls it on the
     instance (`:228-233`); without a file manager instance, logged and nothing shown, as `show_details`
     refuses (`book_sheet.lua:81-88`). `post_cb` is the window's re-list (the `book-sheet` task's
     `refresh`), which `showDeleteFileDialog` runs only after `deleteFile` returned true (`:1141-1142`).
   - KOReader's dialog carries its own wording, path, "Delete" and archive check (`:1130-1151`) and its own
     "File not found" (`:1123-1129`) and "Failed to delete" (`:1188-1191`) notices; KoPanda adds none.
   - Greyed for a record with no `path` (D2).
3. **`HOOKS.md`** gains an entry: `FileManager:showDeleteFileDialog(filepath, post_delete_callback,
   pre_delete_callback)` and the file branch of `deleteFile` (`filemanager.lua:1121-1192`), what it cleans
   (`BookList.resetBookInfoCache`, `DocSettings.updateLocation`, `ReadHistory:fileDeleted`,
   `ReadCollection:removeItem`: `frontend/ui/widget/booklist.lua:328-330`, `frontend/docsettings.lua:433`,
   `frontend/readhistory.lua:214-234`, `frontend/readcollection.lua:188`) and what it leaves (CoverBrowser's
   row, pruned by `removeNonExistantEntries`, `plugins/coverbrowser.koplugin/bookinfomanager.lua:602-625`;
   no event, so KoPanda re-lists through `post_cb`).

## Surfaces

- `kopanda.koplugin/book_sheet.lua` (or the record entry's module if `book-sheet` split it out),
  `kopanda.koplugin/HOOKS.md`.
- `spec/unit/book_sheet_spec.lua`, `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code:

- `book_sheet_spec.lua` (C4), Add to the home: the row after More by this author with `home_plus`; a tap
  stores the realpath of a book reached through a symlink, leaves the settings file otherwise as it was, and
  calls no home refresh; with `featured.pinned` naming that book, the row reads "On the home", ticked, and a
  tap leaves the settings file byte-identical (as `book_sheet_spec.lua:830-839` checks the picker); with a pin
  to a file that has gone, it reads "Add to the home"; a refused write (`Settings.set` stubbed to refuse)
  logged and nothing changed; greyed for a path-less record.
- `book_sheet_spec.lua` (C4), Delete: the last row with `trash`; a tap shows KOReader's ConfirmBox for the
  realpath; its OK removes the file from a scratch copy, then re-lists the window once; Cancel re-lists
  nothing and the file stays; a `deleteFile` stubbed to fail shows KOReader's notice and re-lists nothing; the
  book pinned before the delete leaves `FeaturedBook.current()` featuring the history's next book
  (`featured_book.lua:59-71`); greyed for a path-less record; without a file manager instance, logged and no
  dialog.
- `failsafe_spec.lua` (C8): a raising `Settings.set` and a raising `showDeleteFileDialog` are logged with the
  window as it was.
- `hooks_doc_spec.lua` (C11) passes with the new entry; review item: the entry names `showDeleteFileDialog`
  and the file branch of `deleteFile`, what they clean and leave, each with its file:line (step 3), which the
  spec does not find by name.
- Scope check: confirm `bin/check spec/unit/book_sheet_spec.lua` runs that file alone and its summary names
  only its cases.

## Edge cases

- The ConfirmBox is modal over the library, which is `covers_fullscreen`; its close marks the library dirty
  (`frontend/ui/uimanager.lua:290-360`), so the re-listed grid paints with no repaint of KoPanda's own.
- KOReader's History disables Delete for the book open in the reader (`filemanagerhistory.lua:233`); no
  library window is up while a book is open (a book's open closes the file manager, cover-grid
  feature.md:128-130), so the case cannot arise here.
- A record whose file went between the sheet's open and the tap: `showDeleteFileDialog` shows "File not
  found" (`filemanager.lua:1123-1129`) and runs no `post_cb`; the next show re-lists.
- The metadata archive check appears only for a book with `doc_props` and an md5 (`:1146-1151`); the spec's
  cases cover a book without a sidecar and one with a full sidecar, so both dialogs are exercised.
