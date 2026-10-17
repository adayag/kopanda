# Hold on a book, a folder or empty space

## Summary

The gesture rule applied to the library (direction doc "Context menu"): hold opens a sheet whose actions
depend on what was held. A book gives the book's sheet, a folder tile the folder's, empty space this
folder's own (library direction doc, `2026-10-16-kopanda-library-direction.md:18-20`).

## Behavior

- Hold on a book in the library: Open, Book details, Read status ›, More by this author ›, Add to the home,
  and Delete… behind KOReader's own confirm. A book not downloaded gets the same sheet with the rows that
  need a file greyed. The same sheet opens for a book held on the one-series and one-author screens.
- Hold on a folder tile: Open, Set as library root, Hide.
- Hold on empty space: this folder's Sort › and Show ›, Refresh covers, and Hidden folders › when the folder
  has any.
- Drawn with the sheet component in both looks; goldens on the Colorsoft profile.
- No grid density row: the library direction doc drops it (`2026-10-16-kopanda-library-direction.md:31`,
  `:40`).

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. Repo paths are on
`main` at `5d8a955`. Boards are `.tiller/design/2026-10-16-kopanda-library-screens/<board>.dc.html:<line>`:
`HoldBookC` and `HoldBookA` are Diner's and Editorial's book sheets, `HoldFolderC` Diner's folder sheet,
`HoldEmptyC` Diner's empty-space sheet. The existing sheet tokens cite the 2026-10-13 canvas's boards of the
same names (`looks/diner.lua:122-146`); a board here always means the 2026-10-16 one. Sizes are board pixels,
scaled as cover-grid's spec says (cover-grid feature.md:24-29).

This feature builds on `library/cover-grid` (F-2nt0fx, approved, `order` and `tiles` done, the rest not
built), `home/sheets` (F-3ct1xn, done: `sheet.lua`, `book_sheet.lua`) and `library/series-and-authors`
(F-yaihx9, specced, not built). All three edges are recorded; the last is added by this spec (D5). What the
two unbuilt features will provide is cited from their specs, not from code:

- cover-grid: `library.lua` and its window (feature.md:114-141), the hold step and `Library.hit` (:269-271),
  the folder tile's counts (:181-184), the header's count wording (:149-151), a tap's open of a book (D15,
  :103-106; screen task.md:26-29), the cover request (:296-305), the failure rules (:332-344), the pickers'
  sheets and `sheet.lua`'s additions (`aside_above`, `label`, `sublabel`, `selected`, flush rows,
  `opts.beneath`; pickers task.md:8-30), the capture scenario `2-scenario-library.lua` (goldens
  task.md:12-29);
- series-and-authors: `library_chrome.lua` and the window's re-list (D1, feature.md:40-48; chrome
  task.md:8-36), the shelf screens' `hit` kinds (D9, :72-76; series task.md:28, authors task.md:28), the
  More by this author entry from a book's first author (D6, :64-66; routing task.md:20-24).

Where their code, once built, names a thing differently from their specs, the task reads the code and
follows it.

### Decisions

Owner decisions (owner, 2026-10-16):

- **D1. Hide lives in the runtime state file,** never the schema: under `LibraryOrder`'s one key `library`
  (`library_order.lua:1-8`), a sub-key `hidden = { [realpath] = true }`, beside the per-folder sort and status
  of cover-grid's D11 (feature.md:84-90). The studio never sees it. A hidden folder leaves the grid only: its
  books stay in `Books.all()` (`books.lua:265-292`), so in Series, Authors and their counts. When a folder
  has hidden sub-folders, its empty-space sheet gains a "Hidden folders ›" row opening a sub-sheet whose tap
  unhides one.
- **D2. A book not downloaded** (a record with no `path`, `books.lua:141-151`; cover-grid feature.md:175)
  gets the same book sheet. Open, Book details, Read status, Add to the home and Delete are greyed (`muted`,
  no `run`); More by this author still works; the meta line reads "Not downloaded".
- **D3. Beyond the grid:** holding a book on the one-series list and the one-author grid (series-and-authors'
  `hit` kind `book`, D9) opens the same book sheet. A hold on a series row, an author row or empty space on
  those screens stays inert, as series-and-authors built it. The library grid's three holds are the main scope.
- **D4. Seven new registry icons** from the boards: `home_plus` (HoldBookC:66), `trash` (:70), `folder_open`
  (HoldFolderC:45), `eye_off` (:56), `sort` (HoldEmptyC:44), `filter` (:51) and `refresh` (:57). The registry
  goes from 31 to 38 (`icons.lua:13-74`); the swatch screen's icon grid grows a fourth row; the two swatch
  goldens and the studio's catalog are regenerated inside this feature.

Lead decisions, each overturnable at approval:

- **D5. More by this author opens that author** through series-and-authors' own entry, the one its `routing`
  task gives the home's book sheet (routing task.md:20-24): the record's first author's books, or the Authors
  list for a record with no author. The edge to `library/series-and-authors` (F-yaihx9) is recorded for it;
  it also orders this work after that feature's `chrome` move of `library.lua`. Label "More by this author",
  detail "›", no count, as the home sheet decided (home/sheets feature.md:330-332); the board's "More by
  Kazuo Ishiguro" with "4 ›" (HoldBookC:61-63) would need the author index over `Books.all()` at hold time.
- **D6. Set as library root is KOReader's own `FileManager:setHome(path)`**
  (`frontend/apps/filemanager/filemanager.lua:873-887`): its ConfirmBox "Set '%1' as HOME folder?", "Set as
  HOME", and on OK the folder shortcut, `home_dir` and the title bar. No KoPanda key: book-model and
  cover-grid already settle the root as `home_dir` (book-model feature.md:102-104; cover-grid D7,
  feature.md:69-70). Once the root has changed, the library shows the new root at page 1 and records it as
  where the library was left, so the board's sub-line "The Library tab opens here" (HoldFolderC:52) holds
  under cover-grid's D6 (feature.md:65-68). A Cancel changes nothing.
- **D7. Delete is KOReader's `FileManager:showDeleteFileDialog(path, post_cb)`**
  (`filemanager.lua:1121-1152`): its ConfirmBox "Delete file permanently?" with the path and "Delete", and its
  metadata-archive check for a book with `doc_props` and an md5 (`:1146-1151`). No KoPanda confirm sheet and
  no destructive row style; the row is drawn as the board draws it, last and plain (HoldBookC:69-72). Its
  `post_cb` re-lists the window, which runs only when `deleteFile` succeeded (`:1141-1142`). What it cleans
  and doesn't is in Delete, below.
- **D8. Add to the home pins the book** as the home's picker does: `Settings.set("featured.pinned", realpath)`
  (`book_sheet.lua:123-128`, `:151`, `:162`; the key at `schema.lua:88-96`). The library stays shown. When
  `featured.pinned` already names this book (by realpath, a file), the row reads "On the home" and is ticked,
  so a tap runs nothing (`sheet.lua:578-591`), as the picker ticks the pinned book (`book_sheet.lua:156-163`).
  The book the home features only as the last one opened, with no pin, still reads "Add to the home".
- **D9. Refresh covers re-reads every book directly in this folder,** through CoverBrowser's own "Refresh
  cached book information" path: `BookInfoManager:deleteBookInfo(file)` and the cache reset per file
  (`plugins/coverbrowser.koplugin/main.lua:596-606`; several files, `:533-546`), then one extraction request
  for the folder. Deleting the row drops CoverBrowser's `ignore_cover` and `ignore_meta` flags with it
  (`bookinfomanager.lua:592-600`), as KOReader's own refresh does. The bounded check gives up after 30 checks
  (`book_covers.lua:17-18`), so a large folder's covers land on a later show.
- **D10. The empty-space sheet** (HoldEmptyC): the aside "this folder" above the heading, the folder's name
  ("Library" at the root), and at the right the grid header's own count in each look's wording (Diner "142
  books on the shelf", Editorial "142 books"; cover-grid feature.md:149-151), not the board's "142 books" on
  Diner (HoldEmptyC:40). Sort › and Show › open cover-grid's own Sort and Show sheets
  (`LibraryPickers.sort/status`, pickers task.md:27-30), not new ones. Then Refresh covers, then Hidden folders
  › when D1 applies.
- **D11. The folder sheet's band is pink,** as HoldFolderC:35 draws it, under a new band name: the existing
  `folder` band is teal and belongs to the launcher-folder sheet (`looks/diner.lua:126`,
  `folder_sheet.lua:1-6`).
- **D12. The folder sheet's meta** reads the board's "14 books · 3 reading · 6 finished" (HoldFolderC:41).
  The folder tile's reading count already needs one status per book of the folder: `LibraryTiles.folder`
  takes `{ books, reading }` (`library_tiles.lua:276-281`, `:313-315`), and a book's status comes only from
  `Books.progress` (`books.lua:338-376`). Counting `complete` beside `reading` costs no further read. Each
  part after the book count shows only when not zero, as the tile's reading count (`library_tiles.lua:314`);
  the book count reads as the tile's ("No books", "1 book", "14 books", `:267-274`).
- **D13. The book sheet takes a record.** `book_sheet.lua` is bound to the home today: the featured widget's
  `built.book`, `Featured.tap` on Open, `ctx.home:refresh()` after a status write, and the featured table's
  `shown_percent` and `chapter` in the meta (`book_sheet.lua:66-78`, `:97-118`, `:198-260`). It is
  generalised so the library and the shelf screens hand it a book record (`books.lua:107-133`) and their own
  open and re-list. The home's book sheet renders and behaves as series-and-authors leaves it (C9).
- **D14. A greyed row's tap** closes the sheet and runs nothing, the component's rule for a row with no
  `run` (`sheet.lua:578-591`).
- **D15. Where a hold lands.** On the library, a hold the nav bar's band does not take (cover-grid
  feature.md:254) opens the book sheet on a book tile, the folder sheet on a folder tile, and the empty-space
  sheet anywhere else, the header and the pager included. A Gestures hold corner bound on the file manager
  still wins, as cover-grid orders the steps (feature.md:269-274).
- **D16. The sheets' settled names:** the book sheet keeps `book` wherever it opens, its status sub-sheet
  `status`; the folder sheet is `library_folder`, the empty-space sheet `library_empty`, the hidden-folders
  sub-sheet `library_hidden`. `folder` stays the launcher-folder sheet's (`folder_sheet.lua`).
- **D17. Undrawn states by the looks' rules:** Editorial's folder and empty-space sheets take Editorial's
  sheet tokens (no band, `looks/editorial.lua:113-145`) with each new token's comment "lead: by analogy with
  <board>:<line>"; the hidden-folders sub-sheet, in both looks, takes the empty-space sheet's band and the
  pickers' header parts and flush rows (The empty-space sheet, below); night by `Looks.palette`; the
  Paperwhite by the grey palette. The delete confirm is KOReader's (D7). None is drawn by a board; of them the
  direction doc's "Not drawn yet" names the delete confirm, night and the Paperwhite
  (`2026-10-16-kopanda-library-direction.md:43-46`).

### Holds

The hold step cover-grid leaves consumed with nothing run (feature.md:269-271), on the library and, after
series-and-authors' `chrome` move, on every chrome window (series-and-authors D9), takes `started =
time.monotonic()` at its entry, as the home's hold does (`home_gestures.lua:100-115`), and hands the window's
`hit(x, y)` to `library_sheets.lua` (`LibrarySheets`, new; the name is free under the emulator's `frontend/`,
`common/` and bundled plugins, `spec/unit/hooks_doc_spec.lua:104-122`'s rule):

| Window | `hit` kind | Sheet |
|---|---|---|
| Library | `book` | The book sheet (D13) |
| Library | `folder` | The folder sheet |
| Library | `empty`, or no kind (the header, the pager) | The empty-space sheet (D15) |
| Series, one series; Authors, one author | `book` | The book sheet (D3) |
| Series, Authors | `series`, `author`, `empty` | Nothing, consumed (D3) |

Every sheet is shown with `opts.beneath` the window it was held on, so a sheet's failure closes that window
onto the file browser and not the home (pickers task.md:24-26), and with `opts.started` for its `paint_ms`.

### The book sheet

`BookSheet.open(ctx, built, opts)` stays the home's entry with its rows and behaviour unchanged. A second entry
takes `(record, window, ctx, opts)`. Both build from the same parts:

- **Header** (HoldBookC:35-41): the cover, the title, the authors joined with ", " as the featured book
  joins them (`featured_book.lua:88-90`), and the meta line. The cover is `FeaturedCover.framed(record, …)`
  in the frame `FeaturedCover.build` uses (`featured_cover.lua:155-251`), at the sheet's `cover_w` by
  `cover_h` (60×90, HoldBookC:36); `BookCovers.read` reaches a path-less book's source cover
  (`book_covers.lua:82`; `books.lua:378-385`). The record's meta (HoldBookC:40, "40% · opened 3 days ago"):
  the percent when `Books.progress(record)` (`books.lua:361-376`) gives one or the status is `complete`
  (100%), as `Featured.shown_percent` reads a progress (`widgets/featured.lua:111-116`; the tiles call it so,
  `library_tiles.lua:257`); then "opened …" by the history's time, the existing helper (`book_sheet.lua:45-62`);
  each part left out when unknown, the line left out when both are (`sheet.lua:146-153`). No chapter: a
  record has none and the board draws none. A path-less record's meta is "Not downloaded" (D2).
- **Rows, the library's and the shelf screens',** each with its board icon (HoldBookC:43-72):
  - **Open** (`open_book`): the window's own open of that record, the one its tap on the book runs, so the
    return after the book closes is recorded as a tap records it (cover-grid D4 and D15; series-and-authors
    D7).
  - **Book details** (`info`): `fm.bookinfo:show(record.path)` (`filemanagerbookinfo.lua:71-87`; registered at
    `filemanager.lua:406`), as today (`book_sheet.lua:81-88`).
  - **Read status** (`bookmark`), detail KOReader's label and chip `status` (`book_sheet.lua:222-231`): the
    sub-sheet of KOReader's status buttons (`:97-118`), whose callback re-lists the window instead of
    refreshing the home.
  - **More by this author** (`authors`), detail "›" (D5).
  - **Add to the home** (`home_plus`), or "On the home" ticked (D8).
  - **Delete…** (`trash`), last (D7).
- **A file gone since the window was built:** a hold on a record whose `path` is no longer a file re-lists the
  window and shows no sheet, as the home's sheet refreshes the home (`book_sheet.lua:198-203`).
- The home's rows stay: Open (`Featured.tap`), Book details, Read status (refreshing the home), More by this
  author, Feature a different book, This widget's settings (`book_sheet.lua:207-254`).

### Delete

`FileManager.instance:showDeleteFileDialog(record.path, post_cb)`, as the file browser's own Delete calls it
(`filemanager.lua:228-233`); the file branch reads no instance field (`:1169-1177`), and History and the reader
call it on the class (`filemanagerhistory.lua:235-236`, `apps/reader/modules/readerstatus.lua:197-207`). Its
`deleteFile` removes the file, resets `BookList`'s cache entry, deletes the sidecar folder (archiving its
metadata when that is on, `frontend/docsettings.lua:433`), marks the history entry deleted
(`frontend/readhistory.lua:214-234`: removed only under `autoremove_deleted_items_from_history`, else dimmed
with `select_enabled = false`) and removes it from collections (`frontend/readcollection.lua:188`). It does
not touch CoverBrowser's row, which `removeNonExistantEntries` prunes later (`bookinfomanager.lua:602-625`),
and KOReader sends no event for a delete (cover-grid feature.md:138-139). So:

- `post_cb` re-lists the window at its page, which the listing clamps (`LibraryOrder.page`,
  `library_order.lua:168-180`). A failed delete shows KOReader's "Failed to delete" and runs no `post_cb`.
- A deleted book that was pinned stays in `featured.pinned`; the home then features the last book opened
  (`featured_book.lua:59-71`), whose walk skips a dimmed entry (`:39-47`).
- The stale CoverBrowser row is left for KOReader's prune: the library lists the disk (`books.lua:198-261`),
  so it never shows.

### The folder sheet

HoldFolderC, the `library_folder` band (D11):

- **Header:** the book header's shape (`sheet.lua:134-166`) with an icon box as its cover: a 60×60 box on
  `paper` with a 2 px `outline` edge holding the `folder` icon at 34 in `ink` (HoldFolderC:36-37), drawn with
  `TintedIcon` as the folder tile draws its icon in `library.folder.icon_color` (`library_tiles.lua:306-310`),
  since the registry's files are inked black (`icons.lua:4-8`) and would vanish on night's paper; the
  folder's name as the title (:40); no author; the meta of D12 (:41).
- **Open** (`folder_open`, :45): what a tap on the folder tile does, the folder at its remembered page
  (cover-grid feature.md:256).
- **Set as library root** (`library`, the board's icon is the registry's, :49), sub-line "The Library tab
  opens here" (:52): `FileManager.instance:setHome(folder.path)` (D6). The ConfirmBox runs `ok_callback`
  before it closes (`frontend/ui/widget/confirmbox.lua:115-120`), and its close marks the library beneath it
  dirty (`frontend/ui/uimanager.lua:290-360`); the library's paint, which already rebuilds on a variant or
  size change (cover-grid feature.md:134-135), also rebuilds when `filemanagerutil.getHomeFolder()`
  (`filemanagerutil.lua:25-27`) differs from the root it was built under: the new root at page 1, recorded by
  `LibraryOrder.leave(root, 1)` (`library_order.lua:273-280`).
- **Hide** (`eye_off`, :56), sub-line "Still on the Kindle, gone from the grid" (:59): stores the folder's
  realpath as hidden (D1) and re-lists the library at its page.

### The empty-space sheet

HoldEmptyC, the `library_empty` band (mustard, :35), the header of D10 (`aside_above`, heading, `label`):

- **Sort** (`sort`, :44), chip the folder's sort short label with "›" on `paper` (:47): cover-grid's sort
  sheet.
- **Show** (`filter`, :51), chip the status's short label with "›" on `pink` (:54): cover-grid's Show sheet.
- **Refresh covers** (`refresh`, :57), sub-line "Re-reads covers for this folder" (:60): D9. For each book
  directly in the folder with a `path` (`Books.folder`, `books.lua:244-261`), `BookCovers.forget(paths)`, new:
  CoverBrowser's row deleted (`bookinfomanager.lua:592-600`), `BookList.resetBookInfoCache(path)`
  (`frontend/ui/widget/booklist.lua:328-330`), and the path dropped from the files asked this process
  (`book_covers.lua:20`, `:131`), so `BookCovers.wants` asks again for the missing row (`:98-100`). Then the
  library re-lists at its page (titles fall back to the sidecar's or the file name, `books.lua:107-120`) and,
  after that paint, one `BookCovers.request` for every such record at the grid's cover box with the library's
  own arrival handler (cover-grid feature.md:298-302). Greyed when CoverBrowser is disabled, the test
  `book_covers.lua:25-31` makes.
- **Hidden folders** (`eye_off`), detail "›", only when a sub-folder `Books.folder(dir)` lists is hidden: a
  `library_hidden` sub-sheet on the same band, the aside "tap one to show it again" above the heading "Hidden
  folders", the folder's name at the right; flush rows, one per hidden sub-folder by name in the grid's
  folder order (`library_order.lua:103-109`). A tap unhides it and re-lists the library at its page.

### Hidden folders

- `LibraryOrder` gains the hidden set, read and written beside `folders` and `at`: `stored()` keeps a
  well-formed `hidden` (a table of realpath strings to `true`) and drops and logs a malformed one, and
  `write()` carries it, since today it keeps only `folders` and `at` (`library_order.lua:192-242`). Hide and
  unhide hold for the session when the write fails, as `choose` does (`:251-262`).
- The library's listing leaves out the folders hidden by realpath before `LibraryOrder.view`, which stays
  pure (`:111-146`). `Books.folder` and `Books.all` are unchanged (D1).
- A hidden folder is still reachable when the library was left inside it (`LibraryOrder.left`, `:264-268`)
  or through KOReader's file browser; it is hidden from its parent's grid, not locked.

### Tokens

In both looks with identical paths, every colour an existing palette role, each value with its board line or
"lead: by analogy" (D17), by `looks_spec.lua`'s rules (`spec/unit/looks_spec.lua:83-135`, `:196-240`):

| Token | Editorial | Diner |
|---|---|---|
| `sheet.library_folder_band_color`, `library_empty_band_color` | false, false (`looks/editorial.lua:122-124`) | `pink` (HoldFolderC:35), `mustard` (HoldEmptyC:35) |
| `sheet.folder_box.size`, `outline_width`, `outline_color`, `fill_color`, `icon_size`, `icon_color` | 60, 1, `hairline`, `paper`, 34, `ink` (lead: by analogy with cover-grid's Editorial folder tile, feature.md:226; its icon `ink`, `looks/editorial.lua:541`) | 60, 2, `outline`, `paper`, 34, `ink` (HoldFolderC:36-37) |
| `sheet.sort_chip_color`, `show_chip_color` | false, false (as `status_chip_color`, `looks/editorial.lua:141`) | `paper` (HoldEmptyC:47), `pink` (:54) |

A chip on `paper` sets its text in a new `sheet_chip_plain` part (Diner `display` 11 caps 0.08 `ink`,
HoldEmptyC:47; Editorial as its `sheet_chip`), since `sheet_chip`'s `on_accent` (`looks/diner.lua:310-312`)
is the night paper's own colour by night (`:39`, `:52-53`), as series-and-authors parts `shelf_chip_plain`
(feature.md:240). The heading, aside, label and sub-line use the parts cover-grid's pickers add or keep
(pickers task.md:10-23).

### Failure behaviour

As the sheets' and the library's (`sheet.lua:446-483`; cover-grid feature.md:332-344): a sheet that fails to
build or paint is logged and closes the window it was shown over (`opts.beneath`); a raising row (a delete,
a pin, a hide, a refresh, a status write) is logged with the window as it was; a raising `setHome` or
`showDeleteFileDialog` is logged and leaves the window shown; a raising `hit` or hold dispatch is logged and
the hold consumed. In every case the file manager stays on top and handles input.

### HOOKS.md

Gains: `FileManager:showDeleteFileDialog` and the file branch of `deleteFile`, what they clean and don't
(`filemanager.lua:1121-1192`, Delete above); `FileManager:setHome` and `home_dir` (`:873-887`) with the
ConfirmBox's order (`confirmbox.lua:107-122`) and the close's dirty marking (`uimanager.lua:290-360`) the root
check relies on; `BookInfoManager:deleteBookInfo` (`bookinfomanager.lua:592-600`) and
`BookList.resetBookInfoCache` (`booklist.lua:328-330`) with the lost ignore flags; the book sheet's entry for
`fm.bookinfo:show` and the status buttons gains the library and the shelf screens as callers. `main.lua`
requires `library_sheets` at load (`spec/unit/main_requires_spec.lua`).

### Goldens and budget

- **New,** on `colorsoft`, each shot on `KoPandaSettled` with `screen = "sheet"` and the sheet's name:
  `library-hold-book-{diner,editorial}`, `library-hold-remote-{diner,editorial}` (the not-downloaded book),
  `library-hold-folder-{diner,editorial}`, `library-hold-empty-{diner,editorial}`, over cover-grid's capture
  library (goldens task.md:8-29), which holds a folder tile, downloaded books, a path-less source book and an
  empty sixth cell.
- **Regenerated on purpose:** the two swatch goldens (D4).
- **Unchanged:** the home, night, sheet (the home's book and home sheets), editor screen, file-browser, probe,
  library and series and authors goldens.
- **Budget:** each new capture's `paint_ms` is at most 250 ms, the sheets' tripwire
  (`spec/emulator/sheet_golden_spec.lua:15-18`).

## Notes

For the owner, besides the lead decisions D5 to D17 above:

- **The preserve baselines are captured at `5d8a955`,** the last commit this spec can name, before
  cover-grid's remaining tasks and series-and-authors are built, so C9, C10 and C14 hold their surfaces as
  those features leave them on `main` when this feature's first task starts. Series-and-authors' `routing`
  changes `book_sheet_spec.lua`'s More by this author case on purpose (routing task.md:35-36); the library and
  shelf specs C1, C7 and C10 run (`library_screen_spec.lua`, `library_gestures_spec.lua`,
  `shelf_gestures_spec.lua`) and the library and series and authors goldens C14 runs are those features'.
- **`sheet.lua` is 631 lines** today and cover-grid's pickers add to it; this feature adds the chip part and
  the bands' tokens, not new layout code. `looks/diner.lua` (601) and `looks/editorial.lua` (575) are past 500
  too (AGENTS.md: a signal to plan a split). Not split here; each is its own chore.
- **The swatch's fourth row is a fit risk.** Cover-grid's `tiles` tightened the icon grid's gap to keep 31
  icons in three rows after Diner's palette panels overflowed (tiles task.md:49-54; `swatch.lua:38`). A
  fourth row takes height from the panels again; the `icons` task measures it and brings the numbers to the
  lead before shrinking anything but the gap.
- **The board's More by row shows the author's name and a count** (HoldBookC:61-63); D5 keeps the home's
  label. Say if the library's row should name the author: the label is free, the count is not.
- **Cover-grid's D6 and a changed root.** The Library tab opens at the folder last left (cover-grid
  feature.md:65-68). D6 records the new root when it is set from this sheet, but a root changed from
  KOReader's own menu while the library is closed leaves the stored folder as it was, possibly outside the
  new root. That is cover-grid's entry rule; raised here, not changed.
- **Refresh covers and the ignore flags.** A book whose cover the owner set to ignored in CoverBrowser's file
  dialog (`plugins/coverbrowser.koplugin/main.lua:567-579`) shows that cover again after a refresh (D9), as
  KOReader's own refresh does. Keeping the flags would mean reading and re-writing them around the
  extraction, which the boards don't ask for.
- Undrawn states this spec decides without a board: the delete confirm (D7), Editorial's folder and
  empty-space sheets, the hidden-folders sub-sheet, night and the Paperwhite (D17), and the not-downloaded
  book's sheet (D2).
