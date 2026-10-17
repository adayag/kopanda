# The folder sheet: Open, Set as library root and Hide, with hidden folders kept in the state file

## Approach

The hold on a folder tile, and the hidden set. Starts after `book-sheet` (`library_sheets.lua` and the hold's
dispatch) and `icons` (`folder_open`, `eye_off`). Repo lines on `main` at `5d8a955`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`; cover-grid's `library.lua` and its counts read as merged. Feature
sections "The folder sheet", "Hidden folders", "Tokens", decisions D1, D6, D11, D12, D16, D17; criteria C1,
C2, C5, C8.

1. **The hidden set in `LibraryOrder` (D1),** pure logic beside the folder memory (`library_order.lua:182-280`):
   - `stored()` (`:192-227`) reads `value.hidden`: a table whose keys are strings and values `true` is kept;
     any other entry, or a non-table, is dropped and logged as the other parts are (`:202-225`).
   - `write()` (`:230-242`) carries `hidden` with the session's changes over the stored set, an unhidden
     path removed; an empty set is written as no key, as an empty `folders` is (`:238-240`).
   - `LibraryOrder.hide(path)`, `unhide(path)`, `is_hidden(path)` and `visible(folders)` (the folders whose
     realpath is not hidden, order kept), each by `real(path)` (`:182-184`); `hide` and `unhide` return
     whether the state file took it and hold for the session either way, as `choose` does (`:251-262`).
2. **The grid's listing:** the library's build passes `Books.folder(dir).folders` through
   `LibraryOrder.visible` before `LibraryOrder.view` (cover-grid screen task.md:16-20), so `view` stays pure
   (`library_order.lua:111-146`) and `Books.folder` and `Books.all` are unchanged (`books.lua:244-292`).
3. **Tokens (feature "Tokens"):** in both looks with identical paths, `sheet.library_folder_band_color`
   (Diner `pink`, HoldFolderC:35; Editorial false) and `sheet.folder_box` (`size`, `outline_width`,
   `outline_color`, `fill_color`, `icon_size`, `icon_color`; Diner 60, 2, `outline`, `paper`, 34, `ink`,
   HoldFolderC:36-37; Editorial 60, 1, `hairline`, `paper`, 34, `ink`, "lead: by analogy with" cover-grid's
   Editorial folder tile, feature.md:226, whose icon is `ink`, `looks/editorial.lua:541`).
4. **The icon box:** a widget with `getSize` and `free` (the header frees its cover, `sheet.lua:463-478`), the
   box filled and edged by the tokens with the registry's `folder` icon centred, built as the tiles build
   their folder box (`library_tiles.lua:281-329`): the icon a `TintedIcon` in `sheet.folder_box.icon_color`,
   as the tile tints its own in `library.folder.icon_color` (`library_tiles.lua:306-310`). Not an
   `IconWidget`: the registry's files are inked black (`icons.lua:4-8`), which night's dark paper would hide.
5. **`LibrarySheets.folder(window, folder, counts, opts)`,** dispatched from `LibrarySheets.hold` for a
   library `folder` hit: band `library_folder`, name `library_folder` (D16), header `{ cover = box, title =
   folder.name, meta }`, no author (the header skips it, `sheet.lua:146-153`).
   - **The meta (D12):** the book count as the tile words it (`library_tiles.lua:267-274`), then "N reading"
     and "N finished" each when not zero, joined with " · " (`book_sheet.lua:30`). Open fact: where the
     tile's counts come from in the merged `library.lua`, and whether `Library.hit`'s folder carries them.
     Candidates: the hit's folder holds the counts the tile was built with (use them, extended with
     `finished` where they are counted); or only the tile has them (read them from the built tile); or they
     are counted at build and kept nowhere (count again at hold time from `Books.folder(folder.path).books`
     and `Books.progress`, the same reads one tile costs). Tell them apart by reading the merged build; prefer
     the first that exists, and extend the counter so `complete` is counted beside `reading` with no further
     read.
   - **Open** (`folder_open`): what the window's tap on that folder tile runs, the folder at its remembered
     page (cover-grid feature.md:256).
   - **Set as library root** (`library`), `sublabel` "The Library tab opens here" (HoldFolderC:52):
     `FileManager.instance:setHome(folder.path)` (`frontend/apps/filemanager/filemanager.lua:873-887`).
     Nothing runs after it in KoPanda: the ConfirmBox runs `ok_callback` and then closes
     (`frontend/ui/widget/confirmbox.lua:115-120`); the close marks the library dirty
     (`frontend/ui/uimanager.lua:290-360`).
   - **The root check (D6):** the library's paint, beside its rebuild on a variant or size change (cover-grid
     feature.md:134-135), compares `filemanagerutil.getHomeFolder()`
     (`frontend/apps/filemanager/filemanagerutil.lua:25-27`) by realpath with the root the library was built
     under; when it differs, the library rebuilds at the new root's page 1 and calls `LibraryOrder.leave(root,
     1)` (`library_order.lua:273-280`). A Cancel leaves `home_dir` alone, so the paint finds the same root.
   - **Hide** (`eye_off`), `sublabel` "Still on the Kindle, gone from the grid" (HoldFolderC:59):
     `LibraryOrder.hide(folder.path)`, then the window's re-list at its page.
   - Open fact: whether cover-grid's `sublabel` draws on a row with an icon. The pickers add it for their
     flush rows (pickers task.md:16, :19-20); if it is drawn only for flush rows, extend it to rows with an
     icon, the label and its second line beside the icon as HoldFolderC:50-53 stacks them, every existing
     sheet unchanged.
6. **`HOOKS.md`** gains `FileManager:setHome` and `home_dir` (`filemanager.lua:873-887`), the ConfirmBox's
   ok-then-close order (`confirmbox.lua:115-120`) and the close's dirty marking (`uimanager.lua:290-360`) the
   root check relies on.

## Surfaces

- `kopanda.koplugin/library_order.lua`, `library_sheets.lua`, `library.lua` (the listing and the root check),
  `sheet.lua` (only for the sublabel beside an icon, if needed), `looks/diner.lua`, `looks/editorial.lua`,
  `HOOKS.md`.
- `spec/unit/library_order_spec.lua`, `spec/unit/library_screen_spec.lua`, `spec/unit/library_sheets_spec.lua`,
  `spec/unit/looks_spec.lua`, `spec/unit/sheet_spec.lua` (if `sheet.lua` changes), `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code:

- `library_order_spec.lua` (C1): a hidden folder read back after the module reloads (as the memory cases
  reload, `spec/unit/library_order_spec.lua:347-451`); hide through a symlink and is_hidden by the realpath;
  unhide removing the key from the file; `folders` and `at` kept across a hide; a malformed `hidden` (a list,
  a non-string key, a non-true value) dropped and logged with the rest kept; a refused write holding for the
  session; `visible` keeping order and leaving out the hidden.
- `library_screen_spec.lua` (C1): a hidden sub-folder's tile is not drawn and the folder count does not
  change; `Books.folder` of the parent still lists it; the root check: `home_dir` changed under a shown
  library rebuilds at the new root's page 1 on the next paint and records it as left; unchanged, no rebuild.
- `schema_spec.lua` (C1) passes unchanged: no key added.
- `library_sheets_spec.lua` (C5, C7): a folder hit shows `library_folder` with the box, the name and the meta
  for 0, 1 and 14 books with and without reading and finished books; Open shows the folder at its remembered
  page; Set as library root shows a ConfirmBox whose OK sets `home_dir` and whose paint after it shows the new
  root at page 1, and whose Cancel leaves both; Hide re-lists without the tile.
- `looks_spec.lua` (C2) over the new tokens.
- `library_sheets_spec.lua` (C5): the box's icon is a `TintedIcon` whose colour is the look's `ink` role in
  both looks, by day and by night (`sheet.folder_box.icon_color` is `ink`, as `library_tiles_spec.lua:657-666`
  pins the tile's folder `icon_color`), so by night it is night's light ink on night's paper, not black.
- `hooks_doc_spec.lua` (C11) passes; review item: the `HOOKS.md` entry for `setHome` and `home_dir`, the
  ConfirmBox's order and the close's dirty marking, each with its file:line (step 6), which the spec does not
  find by name.
- `failsafe_spec.lua` (C8): a raising `setHome` and a raising `hide` logged with the library as it was; a
  raising root check logged and the paint going on, as the variant check's failure does.
- Scope check: confirm `bin/check spec/unit/library_sheets_spec.lua` and `bin/check
  spec/unit/library_order_spec.lua` each run their file alone.

## Edge cases

- A folder reached through a symlink: hidden by realpath, so its other name is hidden too; the grid's
  listing realpaths each folder, as `LibraryOrder.choice` does (`library_order.lua:244-249`).
- A hidden folder that is deleted or renamed on disk: its entry stays in the state file, harmless; a renamed
  one shows again under its new name. No pruning (YAGNI).
- Set as library root on a folder inside a hidden one is impossible from the grid (its parent hides it), but
  through KOReader's browser a root can sit inside a hidden folder; the library then shows that root as
  usual: hiding is a parent's grid filter.
- `lock_home_folder` on: `setHome` refreshes the chooser itself (`filemanager.lua:882-884`); the library is
  on top and rebuilds by its own check.
- The library left inside a folder later hidden (`LibraryOrder.left`, `library_order.lua:264-268`) opens
  there; going up shows the parent without the tile.
