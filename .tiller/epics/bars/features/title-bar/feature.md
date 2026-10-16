# File manager title bar in look tokens

## Summary

KOReader's file manager title bar redrawn from the look, as the library board draws its header: a count
over the folder's name in the display face, the sort and status pickers on the right, and KOReader's plus
button kept as a small icon. Editorial: a hairline under a serif title with a small-caps count. Diner: a
mustard band with the count in the handwritten face and outlined chips for the pickers.

## Behavior

- KoPanda's bar is built in place of KOReader's for the file manager only, by a one-shot `TitleBar.new`
  swap inside nav-bar's `FileManager.setupLayout` wrapper; every other title bar (the reader's, History's,
  Collections', any `Menu`'s) is KOReader's.
- Title: "Library" at the home folder, the folder's own name elsewhere. Count: the books the chooser shows
  in this folder after the status filter.
- The pickers open KOReader's own sort and book-status items in a one-tab menu; their labels show the
  current sort and filter.
- KOReader's Home button is dropped (nav-bar's Library tab covers it); its plus button stays.
- A hold on the title opens KOReader's folder menu, anchored under the title.
- `HOOKS.md` gains the swap and every consumer of the bar it keeps working; the file browser's goldens are
  regenerated in both looks on both profiles.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. SimpleUI paths
are relative to the reference clone, read at commit `61b71da` with `git show 61b71da:<path>` (the clone's
checkout has moved on to `36e7430`; SimpleUI is MIT, its `LICENSE` in the clone). Repo paths are on `main`
at `6443f03`. Planned names from `nav-bar/nav-bar` (F-78e5ij), specced and not yet built, are cited to its
plan: `.tiller/epics/nav-bar/features/nav-bar/feature.md` ("nav-bar feature.md") and its tasks
`file-browser` (T-9h0fhs) and `goldens` (T-1r8qb2). Boards are
`.tiller/design/2026-10-13-kopanda-screens/<board>.dc.html:<line>`; sizes are board pixels, scaled by
`Screen:scaleBySize` as the looks use them (`layout.lua:4-6`, `:15-17`), ×2.107 on the Colorsoft, the
conversion nav-bar uses (nav-bar feature.md:27-28); font sizes go to `Font:getFace` unscaled, which scales
them itself (`looks/editorial.lua:6-7`; `frontend/ui/font.lua:276`).

This feature builds on nav-bar: its `FmNav` module (`kopanda.koplugin/fm_nav.lua`), the one
`FileManager.setupLayout` wrapper with its failsafe, tripwire and harness restore (nav-bar feature.md:206-253,
:289-326; task `file-browser` steps 1-3), the `KoPandaSettled{ screen = "file_browser" }` signal (nav-bar
feature.md:279-287), and the scenario `2-scenario-file-browser.lua` with the `filebrowser-{diner,editorial}`
goldens on both profiles and their 250 ms budget (nav-bar feature.md:328-341; task `goldens` steps 3-4).
The edge is recorded: `bars/title-bar` depends on `nav-bar/nav-bar`.

### Decisions

Owner decisions (owner, 2026-10-16):

- **D1. The title** is "Library" when the chooser shows the home folder, and the folder's own name
  (its last path component) in any other folder. KOReader's abbreviated path is not shown. This removes
  nav-bar's open fact F3 for the title bar's text (nav-bar feature.md:339-341): once this feature lands, no
  path is drawn in the file browser's header, so no golden depends on where the checkout lives through it.
- **D2. The count**, above the title, is the number of files the chooser shows in this folder after the
  status filter; folders and the go-up entry are not counted. Editorial reads "142 books", Diner "142 books
  on the shelf" (the boards' wording, Library:21, LibraryC:21). One is "1 book" / "1 book on the shelf";
  none is "No books" / "No books on the shelf".
- **D3. KOReader's Home button is dropped; a hold on the title opens its folder menu.** Nav-bar's Library
  tab runs `fm:onHome()` (nav-bar feature.md:73, D5), so the Home tap is covered. The Home button's hold,
  the folder menu (`FileManager:onShowFolderMenu`, `frontend/apps/filemanager/filemanager.lua:1351-1438`),
  moves to a hold on the title area, a menu for the thing held: its one caller is that hold (`:131`); no
  Dispatcher action, menu entry or bundled module sends `ShowFolderMenu` (a search of `frontend/` and
  `plugins/` at `e1fe1ac` finds only `:131` and `:1351`). The bar keeps KOReader's
  `left_icon_hold_callback` from the copied attributes (`:131`, `self:onShowFolderMenu()`) and runs it on
  that hold. The menu's anchor is a function returning `self.title_bar.left_button.image.dimen`
  (`:1430-1437`, `:1433-1435`), which `ButtonDialog` hands to its `MovableContainer`
  (`frontend/ui/widget/buttondialog.lua:248`) and which is read when the menu first paints
  (`frontend/ui/widget/container/movablecontainer.lua:195-198`, `ensureAnchor`, `:124-170`). `ensureAnchor`
  fills only the anchor's nil fields, in place (`:137-140`; a `Geom`'s are never nil,
  `frontend/ui/geometry.lua:31-34`), and puts the menu above the anchor when it fits there, else below it
  (`:152-161`). The bar's `left_button.image.dimen` is the title column's box with its top at the bar's
  top (The bar, below), so no menu fits above it and the menu sits under the title. The plus button stays
  as a small icon at the header's right: `plus`, or `check` in select mode, running KOReader's own
  callbacks. (Owner, 2026-10-16, after the draft.)
- **D4. Both pickers ship now.** The status picker opens KOReader's own "Book status" filter and its label
  shows the current filter; the sort picker opens KOReader's own sort items and shows the current sort's
  short label ("Recent" for `access`, as the boards draw it, Library:25, LibraryC:25). The direction doc
  listed the status picker as a candidate not promised by a stage
  (`.tiller/design/2026-10-13-kopanda-ui-direction.md:111-113`); it is in scope here.

Lead decisions, each overturnable at approval:

- **D5. The pickers open a one-tab `TouchMenu`** hosting KOReader's own items, inside a full-screen
  container, as `SettingsMenu.open` opens KoPanda's settings (`settings_menu.lua:18-35`), not KOReader's full
  main menu. Sort: the `sub_item_table` of `fm.menu:getSortingMenuTable()`
  (`frontend/apps/filemanager/filemanagermenu.lua:931-957`). Status: the `sub_item_table` of
  `fm.menu:getShowFilterMenuTable()` (`:873-929`). Both are built fresh on each open, so their callbacks reach
  the current chooser (`:943-945` calls `self.ui:onSetSortBy`; `:883-885`, `:896-903` call
  `self.ui.file_chooser:refreshPath()`). "Reverse sorting" and "Folders and files mixed" stay in KOReader's
  main menu only: they exist only as cached `menu_items` (`:449-473`) whose callbacks hold the chooser of
  the moment the cache was built (`:130`), and the cache survives a re-layout (`:1120-1129`), so hosting them
  could refresh a stale chooser. Neither changes the sort picker's label.
- **D6. Editorial's pickers** are the board's plain small-caps text with a down mark and no box; **Diner's**
  are outlined chips, sort on paper and status on pink (Library:24-27, LibraryC:24-27).
- **D7. The down mark** is the boards' "▾" set in the picker's face when KoPanda's by-path faces render it,
  else the registry's `chevron_down` icon at the picker line's height; open fact F1 settles which.
- **D8. Fixed size.** The bar does not follow `text_size`: its lines are set with no `text_size` in their
  ctx, as nav-bar's labels are (nav-bar feature.md:49, D8), so its height per look never changes and
  KOReader's chooser and CoverBrowser, which read it at every re-measure (below), see one value.
- **D9. No settings key.** Sort and filter are KOReader's own state: `G_reader_settings` `collate`
  (`frontend/ui/widget/filechooser.lua:206-215`) and `show_filter` (`:22`). No schema change.
- **D10. The plus icon is a registry icon,** Lucide's `plus` (ISC, as the set's other files,
  `icons/LICENSE-lucide.txt`), added as `plus` with `used_in = { "title bar" }`, drawn with `TintedIcon` in
  the token colour like every other icon the shell draws (`tinted_icon.lua:1-5`); `check` gains `"title bar"`
  in its `used_in`. Consequences: the swatch screen, which draws every registry icon (`swatch.lua:265-293`),
  gains a cell, so its two goldens are regenerated on purpose; the studio's catalog, which lists the
  registry (`bin/catalog-json`; `spec/unit/studio_catalog_spec.lua:205-214`), is regenerated with
  `npm run catalog`; and the studio's launcher `IconPicker`, which offers every catalog icon
  (`studio/src/ui/launcher/icons.tsx:31`), offers `plus` as a launcher icon too, which breaks no studio
  test, since the picker's test counts by the catalog's length (`studio/test/ui/launcher-editor.test.tsx:227`).
  The alternative, KOReader's own `plus` (`resources/icons/mdlight/plus.svg`) through an
  `IconButton`, avoids all three but draws black and inverts with night mode, off-colour on Diner's night band.
- **D11. The bar re-reads its state when it paints** (the seam, below), instead of a second hook on
  `FileChooser:refreshPath`.
- **D12. No new night golden.** The four regenerated goldens cover day (Colorsoft) and grey (Paperwhite,
  `spec/emulator/profiles.lua`; `Looks.variant`, `looks.lua:30-43`); night is the same paint with
  `Looks.palette(look, "night")`, sampled by the unit paint cases and checked by the owner on the emulator.
- **SimpleUI: ideas only.** SimpleUI swaps `TitleBar.new` for one call inside its `FileManager.setupLayout`
  wrap (`infra/sui_patches.lua:423`, `:608`; `screens/sui_titlebar.lua:1344-1368`, the one-shot restoring
  `rawget(TitleBar, "new")`). KoPanda takes that idea and copies no code, so no MIT notice is needed. The
  draft's `infra/sui_patches.lua:1491` is inside SimpleUI's `SortWidget.new` patch (`:1481-1500`), not the
  file manager's bar.

### What KOReader does with the file manager's bar

- `FileManager:setupLayout` (`filemanager.lua:116`) builds the bar first, `TitleBar:new{ ... }` (`:118-136`):
  title `self.title`, `_("KOReader")` (`:48`); `left_icon = "home"`, tap `self:onHome()`, hold
  `self:onShowFolderMenu()` (`:128-131`); `right_icon = self.selected_files and "check" or "plus"`, tap
  `self:onShowPlusMenu()` (`:132-134`, `:778`), `right_icon_hold_callback = false` so a hold propagates
  (`:135`); `show_parent = self.show_parent` (`:117`, `:119`). Then `FileChooser:new{ ..., custom_title_bar =
  self.title_bar }` (`:138-154`, `:150`). No other `TitleBar` is built in `setupLayout`: `Menu:init` builds
  one only when `custom_title_bar` is nil (`frontend/ui/widget/menu.lua:721`).
- `TitleBar` (`frontend/ui/widget/titlebar.lua:20-84`) is an `OverlapGroup` extension with no `new` of its
  own, so `TitleBar:new` is `Widget:new` through the metatable (`frontend/ui/widget/widget.lua:26-47`) and
  `rawget(TitleBar, "new")` is nil. Both `filemanager.lua:34` and `menu.lua:22` hold the module table, so a
  `new` field set on it is what `TitleBar:new` finds.
- **Every `Menu` builds a `TitleBar`** (`menu.lua:717-745`), FM-styled ones included
  (`title_bar_fm_style`, `:637`, `:735-741`: Collections, `filemanagercollection.lua:702`, `:868`, `:1154`;
  shortcuts, `filemanagershortcuts.lua:220`), and the reader's lists are `Menu`s too. A global patch on
  `TitleBar` would restyle all of them; the swap touches one call.
- **What the chooser and KOReader call on the bar** (the interface KoPanda's bar keeps):

| Member | Caller |
|---|---|
| `getHeight()` | `Menu:_recalculateDimen`, the items' available height (`menu.lua:666-669`), on every `updateItems` (`:1085`) and at init (`:909`) |
| `dimen.h` | CoverBrowser's `_recalculateDimen`, list and mosaic (`plugins/coverbrowser.koplugin/listmenu.lua:836-845`, `mosaicmenu.lua:782-803`), installed on `FileChooser` (`main.lua:687`, `:696`): on every re-measure, not only at init |
| `getSize()` | the chooser's `VerticalGroup` header (`menu.lua:891`; `OverlapGroup:getSize`, `frontend/ui/widget/overlapgroup.lua:22-39`) |
| `setTitle(text, no_refresh)` | `Menu:switchItemTable` with a new title (`menu.lua:1208-1214`); the file chooser passes none (`filechooser.lua:338`) |
| `setSubTitle(text, no_refresh)` | `FileManager:updateTitleBarPath` (`filemanager.lua:108-112`): on `PathChanged` (`:114`), setting home (`:881`), the home-folder menu items (`filemanagermenu.lua:326`, `:338`), a shortcut rename (`filemanagershortcuts.lua:88`) |
| `setRightIcon(icon)` | select mode on and off (`filemanager.lua:514-530`, `:518`, `:526`); "Select in file browser" from search and collections (`filemanagerfilesearcher.lua:621`, `filemanagercollection.lua:472`) |
| `setLeftIcon(icon)` | `Menu:setTitleBarLeftIcon` (`menu.lua:1564-1566`) |
| `generateVerticalLayout()` | `Menu:mergeTitleBarIntoLayout` (`menu.lua:1167-1183`) from `updateItems` (`:1156`) and CoverBrowser's (`covermenu.lua:89`), on devices without keys, the Colorsoft among them (`:1169-1172`) |
| `generateHorizontalLayout()` | no caller at `e1fe1ac`; kept for completeness |
| `left_icon_hold_callback` | the folder menu, `self:onShowFolderMenu()` (`filemanager.lua:131`, `:1351-1438`), run by the title hold |
| `left_button.image.dimen` | read by the anchor function when the title hold shows the folder menu (`filemanager.lua:1433-1435`; `movablecontainer.lua:124-161`) |

- **The item table.** `FileChooser:refreshPath` (`filechooser.lua:327-339`) builds it with `genItemTable`
  (`:244-296`): folders, then files, then a go-up entry first unless at `/`, hidden by
  `show_parent_folder`, or at a locked home (`:265-276`, `is_go_up`). Files carry `is_file = true`
  (`:174`); folders don't. A file is listed only when `show_file` passes, the status filter among its tests
  (`:88-96`, `:93-94`, `FileChooser.show_filter.status`, `:22`). The chooser's own `init` runs
  `refreshPath` before `setupLayout` returns (`:98-106`).
- **When it changes.** `changeToPath` sends `PathChanged` and then refreshes (`:366-369`), so a handler on
  `PathChanged` sees the old items. A sort change (`FileManager:onSetSortBy`, `filemanager.lua:1685-1690`)
  and a filter change (`filemanagermenu.lua:883-885`, `:896-903`, `:923-925`) refresh with no `PathChanged`.
  Every refresh ends in `switchItemTable` → `updateItems` (`menu.lua:1199-1242`, `:1241`), which marks the
  chooser's whole `dimen`, header included, dirty (`:1158-1163`); CoverBrowser's `updateItems` does the same
  (`covermenu.lua:92-100`).
- **Sort ids** are `BookList.collates`' keys (`frontend/ui/widget/booklist.lua:20-270`), read by
  `FileChooser:getCollate`, which falls back to `strcoll` for an unknown id (`filechooser.lua:206-215`).
  **Status strings** are `booklist.lua:371-378`, through `BookList.getBookStatusString` (`:386-389`).
- **The home folder** is `filemanagerutil.getHomeFolder()`
  (`frontend/apps/filemanager/filemanagerutil.lua:25-27`); KOReader treats a path as home when it equals it
  or it plus "/" (`:33`). The chooser's path is a realpath: `changeToPath` resolves it
  (`filechooser.lua:341-348`), as do the file manager's `root_path` writes (`filemanager.lua:795`, `:1320`);
  the stored `home_dir` is kept as written.

### The bar

`kopanda.koplugin/title_bar.lua` returns `KoTitleBar`, KoPanda's subclass of KOReader's `TitleBar`
(`TitleBar:extend{}`); no module named `title_bar` exists in KOReader's `frontend/`, `common/` or an
emulator plugin, as `spec/unit/hooks_doc_spec.lua:104-122` requires.

- **Built from** KOReader's attributes (a copy; the original table is left untouched) plus `fm` (the file
  manager), `look` (the look nav-bar's before step read, the seam below) and the callbacks `on_sort` and
  `on_status`. It keeps `show_parent`, `right_icon_tap_callback` and `left_icon_hold_callback`, and starts
  with `right_icon` (`plus` or `check`). It ignores `title`, `subtitle`, the left icon and its tap.
- **Reading its state, at paint:** before each paint it reads, under `pcall`, the variant
  (`Looks.variant()`), the title (D1, from `fm.file_chooser.path` against the home folder, each through
  `ffiUtil.realpath` and the raw string when that gives nil, then compared as `filemanagerutil.lua:33`
  compares, so a `home_dir` stored through a symlink still reads Library), the count (D2, the entries of
  `fm.file_chooser.item_table` with `is_file`), the sort label (from
  `getCollate`'s id) and the status label (from `FileChooser.show_filter.status`). When any differs from what
  it last built, it rebuilds its lines; otherwise it paints what it has. With no `fm.file_chooser` yet, the
  count line is empty. When a read raises it paints its last build; when the very first read raises there
  is no build yet, and it paints its fill and edge only, in `Looks.variant()`'s palette, day if that raises
  too.
- **Why at paint (D11):** every change to what the bar shows reaches it through a repaint already: an item
  change through `updateItems`' dirty mark over the chooser, header included (above); a night toggle through
  KOReader's full repaint (`HOOKS.md:397-433`); a home change through `setSubTitle`, which marks the bar dirty
  as KOReader's does (`titlebar.lua:443-454`); select mode through `setRightIcon` (`:463-468`). It needs no
  second hook into KOReader and no event, and the first build needs no special case. It costs a pass over the
  item table per paint of the file manager, cheaper than painting one row.
- **Labels.** Sort, by collate id: `strcoll` and `natural` Name; `access` Recent; `date` Modified; `size`
  Size; `type` Type; `percent_unopened_first`, `percent_unopened_last` and `percent_natural` Progress;
  `title` Title; `authors` Author; `series` Series; `keywords` Keywords; `rating` Rating; any other id (a
  user patch's collate) its own `text`. Status: no filter, `getBookStatusString("all")` ("All"); one status,
  its string ("New", "Reading", "On hold", "Finished"); two or three, the first in KOReader's order (`new`,
  `reading`, `abandoned`, `complete`, `filemanagermenu.lua:875`) and "+n" for the rest ("Reading +1").
  Both pickers are uppercase in both looks (Library:24, LibraryC:25-26).
- **The interface** (table above): `getHeight()` and `dimen.h` are the fixed height; `getSize()` is
  `{ w = width, h = height }`; `setTitle` and `setSubTitle` keep no text and mark the bar dirty unless
  `no_refresh`; `setRightIcon("check")` shows `check` and any other id `plus`, then marks the bar dirty;
  `setLeftIcon` does nothing; both layout generators return `{}`, so key navigation stays the chooser's
  (nav-bar task `file-browser`, Edge cases); `left_button.image.dimen` is a `Geom` kept equal, at each
  paint, to the title column's box on screen: the count and title lines' left edge and width, from the
  bar's top to the title line's bottom, which the title hold opens the folder menu under (D3).
- **Taps and holds:** the bar holds one `InputContainer` over its `dimen` whose `ges_events` take `tap`,
  `hold` and `hold_release`; its handler calls `bar:handle(ges)` under `pcall`. Every area runs the bar's
  full height: the title area from the bar's left edge to half a gap left of the sort picker, so it covers
  the count too; the sort picker's from half a gap left of it to half a gap right, the status picker's
  likewise, the plus's from half a gap left of it to the bar's right edge. A tap in the sort area runs
  `on_sort`, in the status area `on_status`, in the plus area `right_icon_tap_callback` (KOReader's
  `onShowPlusMenu`), each consumed. A tap in the title area is not consumed, so it reaches KOReader as a
  tap on its title does today (`FileChooser` is no popout, `booklist.lua:14`, `menu.lua:939-950`; the file
  manager's menu zones, `filemanagermenu.lua:71-124`). A hold in the title area runs
  `left_icon_hold_callback` once and is consumed, and so is the `hold_release` that follows it, as
  KOReader's `IconButton` handles a hold it took (`frontend/ui/widget/iconbutton.lua:146-170`), so the
  release reaches no `MovableContainer`. Holds on the pickers and the plus are not taken: they propagate,
  as KOReader's plus hold does (`filemanager.lua:135`). Under KOReader's touch lock the container's
  `ges_events` don't run (`frontend/ui/widget/container/inputcontainer.lua:299-309`), as for KOReader's own
  buttons.

### Tokens

A `title_bar` block and four type parts in both looks, with identical paths, each value's comment naming
its board line, by `looks_spec.lua`'s rules (`spec/unit/looks_spec.lua:83-125`, `:185-212`, `:214-233`):
numbers, booleans, palette roles and faces only. Every colour names an existing role; none is added.

| Token | Editorial (Library) | Diner (LibraryC) |
|---|---|---|
| `title_bar.fill_color` | `paper` (:17, the page under the header) | `mustard` (:19) |
| `title_bar.padding.top`, `.side`, `.bottom` | 40, 40, 16 (:19) | 30, 40, 20 (:19) |
| `title_bar.edge_width`, `edge_color` | 1, `ink` (:19) | 4, `ink` (:19) |
| `title_bar.line_gap` (count to title) | 2 (:20) | 2 (:20) |
| `title_bar.picker_gap` | 20 (:24) | 10 (:24) |
| `title_bar.sort_fill_color`, `status_fill_color` | false, false (:25-26) | `paper`, `pink` (:25-26) |
| `title_bar.picker_outline_width`, `picker_outline_color` | 0, false | 2, `outline` (:25-26; the look's chip outline, `looks/diner.lua:155`) |
| `title_bar.picker_padding.x`, `.y` | 0, 0 | 10, 4 (:25) |
| `title_bar.icon_size`, `icon_color` | 16, `text` (no board draws the plus; the pickers' colour, :24) | 16, `on_accent` (no board; the band's text) |
| `title_bar.count_on_shelf` | false (:21 "142 books") | true (:21 "142 books on the shelf") |

| Part | Editorial | Diner |
|---|---|---|
| `type.title_bar_count` | `text` 11, uppercase, 0.14, 0, `muted` (:21) | `accent` 24, not uppercase, 0, 0, `on_accent` (:21; CSS line height 1) |
| `type.title_bar_title` | `display` 34, not uppercase, 0, 0, `ink` (:22; CSS line height 1, as the date's 0, `looks/editorial.lua:203-204`) | `display` 40, not uppercase, −0.01, −0.05, `on_accent` (:22; CSS 0.95, as the clock's −0.1 for 0.9, `looks/diner.lua:213-216`) |
| `type.title_bar_sort` | `strong` 11, uppercase, 0.12, 0, `text` (:24) | `display` 11, uppercase, 0.08, 0, `ink` (:25, on paper) |
| `type.title_bar_status` | `strong` 11, uppercase, 0.12, 0, `text` (:24) | `display` 11, uppercase, 0.08, 0, `on_accent` (:26, on pink) |

- Weights: Editorial's 600 pickers are `strong`, IBM Plex Sans Medium, since the look ships Regular and
  Medium only (`looks/editorial.lua:12-14`), as nav-bar maps 600 (nav-bar feature.md:119-121); no font file
  is added. Editorial's 400 count is `text`, its 500 title `display` (Newsreader Medium). Diner's 800 title
  and chips are `display` (Bricolage ExtraBold, `looks/diner.lua:11-12`); its count is `accent`, Caveat
  Regular (`:14`), the board's Caveat at its default weight and the direction doc's "the library count"
  (`2026-10-13-kopanda-ui-direction.md:46`).
- Diner's text on the mustard band is `on_accent`, the boards' ink by day and dark at night
  (`looks/diner.lua:34`, `:53`), as nav-bar's Diner active label (nav-bar feature.md:122-123). The sort
  chip's text on paper is `ink`, the status chip's on pink `on_accent`; the chip outline is `outline`, ink by
  day and cream at night, as the look's chips (`looks/diner.lua:31`, `:155`).
- Editorial's 1 px edge stays 1 px on the Paperwhite, as nav-bar's does (nav-bar feature.md:127-130).

### Geometry

- **Height** (device px), per look: `edge_width + padding.top + max(column, row) + padding.bottom`, lengths
  scaled; `column` is one `title_bar_count` line + `line_gap` + one `title_bar_title` line; `row` is the
  taller picker part's line + 2 × (`picker_padding.y` + `picker_outline_width`). Lines are measured with
  `Typeset.line` on a fixed sample (`"0 books"`, `"Library"`, `"Name"`) with no `text_size` (D8), since a
  line's height is its face's or its forced height, not its text's (`typeset.lua:31-45`). Roughly 120 board
  px in both looks against KOReader's bar, so the list loses about as much again as KOReader's title bar
  took; rows shrink and keep their count per page (`menu.lua:666-681`).
- **Left column**, from `padding.side`: the count line, `line_gap`, the title line, its bottom on the
  content's bottom (the boards' `align-items: flex-end`, Library:19, LibraryC:19). Both lines are cut to
  the width left after the right group and one `picker_gap`, by `Typeset.line`'s `max_width`
  (`typeset.lua:47-86`).
- **Right group**, ending at `width − padding.side`, its bottom on the content's bottom: the sort picker,
  `picker_gap`, the status picker, `picker_gap`, the plus icon centred on the pickers' row. A picker is its
  label and the down mark (D7) inside `picker_padding` and, for Diner, a `picker_outline_width` outline
  with its fill. The pickers never shrink.
- **Drawing:** `fill_color` over the bar above the edge; the edge across the full width at the bar's
  bottom; the lines; each Diner chip's fill and outline (`Paint.fill`, `Paint.border`, `paint.lua:10-32`)
  under its label; the icon through `TintedIcon` in `icon_color`. Colours come from
  `Looks.palette(look, variant)` through `Looks.color` (`looks.lua:63-89`); the module never names the
  palettes, which `night_mode_spec.lua`'s scan keeps true (`spec/unit/night_mode_spec.lua:70`). Not mirrored
  for a right-to-left UI, as the home isn't.

### The seam: one call of `TitleBar.new` inside nav-bar's wrapper

Nav-bar's wrapper runs, in order, a guard (KoPanda's instance present and not refused, else the original
alone), a "before" step, the original under `pcall` with `FileChooser.height` set on the class for the call
and put back on every path, then an "after" step (nav-bar feature.md:236-246). This feature adds, in
`fm_nav.lua`:

1. **Before:** nav-bar's step already reads `Looks.active()`, in its `pcall`, for the band's height
   (nav-bar feature.md:239; nav-bar task `file-browser` step 3, its lines 28-29). This feature keeps that look in
   a local and hands the same one to the bar, so there is one read and the band and the bar share a look. A
   raising look is nav-bar's failure, unchanged: the original runs alone, KOReader's own layout with its
   own `TitleBar` and no band (nav-bar feature.md:295).
2. **During**, beside `FileChooser.height`: `TitleBar.new` is set to a one-shot that first puts
   `rawget(TitleBar, "new")`'s prior value (nil) back, then builds `KoTitleBar:new` from a copy of the
   attributes it was called with plus `fm`, the look and `on_sort`/`on_status`, under `pcall`. On success the
   KoPanda bar is returned, so `fm.title_bar` and the chooser's `title_bar` are it (`filemanager.lua:118`,
   `:150`; `menu.lua:721`) and the chooser sizes its rows from its height. On failure the error is logged
   and `TitleBar:new(attrs)` builds KOReader's own bar from the untouched attributes. After the original
   returns or raises, `TitleBar.new` is put back too, so it is nil on every path even when the call never
   came.
3. **The pickers' callbacks**, `FmNav`'s: `on_sort` shows the one-tab menu of D5 over
   `fm.menu:getSortingMenuTable().sub_item_table`, `on_status` over
   `fm.menu:getShowFilterMenuTable().sub_item_table`, the tab's icon `appbar.filebrowser`, KOReader's file
   manager settings tab's (`filemanagermenu.lua:36`), `fm.menu` being the registered module (`filemanager.lua:404`,
   `:379-389`). Each is in `pcall`; a failure is logged and shows nothing. A pick runs KOReader's callback,
   which refreshes the chooser; the bar's next paint shows the new label and count. The menu stays open after
   a pick, as KOReader's checked items do (`frontend/ui/widget/touchmenu.lua:913-927`), and closes on a tap
   outside it (`settings_menu.lua:1-6`).

A look change re-runs the wrapped `setupLayout` through nav-bar's `FmNav.relayout()` and `fm:reinit()`
(nav-bar feature.md:270-275), and rotation through `reinit` (`filemanager.lua:71-79`, `:789-812`), so the bar is
rebuilt in the new look and width with nothing more here.

### Failure behaviour

Every step fails safe, so KOReader's file browser stays usable:

- **The look raising** (before, nav-bar's read): logged; the original alone, KOReader's own layout, its
  `TitleBar` included, with no band.
- **`KoTitleBar:new` raising** (during): logged; KOReader's own `TitleBar` from the original attributes, its
  Home and plus buttons working.
- **The original `setupLayout` raising:** `TitleBar.new` and `FileChooser.height` put back, the error
  re-raised unchanged (nav-bar feature.md:296-297).
- **Reading state raising** at paint: logged once per bar; it paints what it built last, or, on the very
  first read, its fill and edge only.
- **Painting raising:** logged once per bar; the rest of the bar's paint is skipped and the chooser still
  paints its rows.
- **A tap's or hold's handling raising:** logged, not consumed, so KOReader's zones still see it.
- **A picker's menu raising:** logged; nothing shown.

### Upgrade tripwire and HOOKS.md

- **A tripwire**, in `spec/unit/fm_title_bar_spec.lua`, against the emulator's KOReader with the unwrapped
  `setupLayout` (`harness.fm_setup_layout`, nav-bar task `file-browser` step 2): `rawget(TitleBar, "new")` is
  nil; during the original `setupLayout` the first `TitleBar.new` call comes before any `FileChooser:new`,
  with `left_icon = "home"`, `right_icon = "plus"`, and `right_icon_tap_callback` and
  `left_icon_hold_callback` functions; afterwards
  `fm.title_bar` is that bar and `fm.file_chooser.title_bar` is the same table; the chooser's available
  height is its inner height less the bar's `getHeight()` and its page footer. With KoPanda loaded, it
  asserts `fm.title_bar` is a `KoTitleBar` after a layout. An upgrade that moves the bar's construction or
  the chooser's use of it fails here, and the upgrade chore walks this entry before changing the pin.
- **`HOOKS.md`** gains a section for the swap: `TitleBar`'s class and lack of `new` (`titlebar.lua:20-84`,
  `widget.lua:26-47`), its methods KoPanda's bar replaces (`:395-494`), the file manager's construction and
  callbacks (`filemanager.lua:34`, `:48`, `:116-154`, `:131`, `:778`, `:865-871`, `:1351-1438`), the folder
  menu's anchor and how it is placed (`filemanager.lua:1430-1437`; `movablecontainer.lua:124-161`), the
  hold-and-release pairing the title hold copies (`iconbutton.lua:146-170`), every consumer in the
  interface table with its line, `genItemTable` and `is_file` (`filechooser.lua:174`, `:244-296`), the status
  filter (`:22`, `:88-96`), `getCollate` (`:206-215`), the refresh path and `PathChanged`'s order (`:327-339`,
  `:366-369`; `menu.lua:1158-1163`, `:1199-1242`), the collates and status strings (`booklist.lua:20-270`,
  `:371-378`, `:386-389`), the two menu tables (`filemanagermenu.lua:873-957`) and why the cached ones are
  avoided (`:130`, `:449-473`, `:1120-1129`), `getHomeFolder` (`filemanagerutil.lua:25-33`) and the menu
  zones a title tap reaches (`filemanagermenu.lua:71-124`; KOReader's `defaults.lua:59-60`).
  `spec/unit/hooks_doc_spec.lua:86-102` checks each entry cites a `file:line` and every required module is
  named.

### Goldens and budget

- The four file-browser goldens nav-bar adds (`filebrowser-diner` and `filebrowser-editorial` on
  `colorsoft` and `paperwhite`) are regenerated with the bar, not joined by new ones (D12). The scenario shows
  the home folder, so the title reads "Library" as the boards draw it: unless nav-bar's scenario already
  stores the fixture library as `home_dir` (its F3 route, nav-bar task `goldens` step 1), `goldens` makes it
  do so. The fixture library holds three books (`spec/unit/fixtures_spec.lua`), so the count reads "3 books"
  / "3 books on the shelf"; the pickers read "Name" and "All", KOReader's defaults (`filechooser.lua:207`;
  `:22`).
- The two swatch goldens are regenerated for the `plus` cell (D10).
- Unchanged: the home, night, sheet, editor screen and probe goldens. Nothing here draws on the home or the
  editors.
- **Budget:** each file-browser capture's `paint_ms` stays at most 250 ms with the bar (nav-bar's budget,
  nav-bar feature.md:337-338).

### Open facts

- **F1, the down mark** (task `bar`): does "▾" (U+25BE) render in Editorial's `strong` and Diner's `display`
  faces as Typeset sets them, by the face or KOReader's fallback fonts (`frontend/ui/font.lua:106-136`)?
  Candidates: (a) it renders in both; (b) it renders in neither or one. How to tell: in the harness, paint
  `Typeset.line(part, "▾", ...)` and the same part with an unassigned private-use code point (U+E000, which no
  face covers) at the Colorsoft, and compare the two bitmaps: identical means the missing-glyph box. For (a)
  the mark is the text " ▾" after the label; for (b) it is `chevron_down`, tinted in the label's colour, at
  the label line's height after a space's width, in both looks so they match.

## Notes

The draft's question, "the status picker is KOReader's own status filter if it exposes one, else absent
until stage 5", is settled: KOReader exposes it (`filemanagermenu.lua:873-929`) and the owner put it in
scope (D4).

For the owner, each a default the lead chose that you can overturn at approval:

- **Reverse sorting and mixed folders** stay in KOReader's main menu only (D5).
- **Two or three statuses** read "Reading +1" (Labels).
- **A registry `plus` icon** (D10), which regenerates the swatch goldens and the studio catalog.
- **No night golden** (D12).
- **The bar is taller than KOReader's** (Geometry): the list's rows shrink to make room, as with nav-bar's
  band.
