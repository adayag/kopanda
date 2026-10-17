# Cover grid with header pickers in both looks

## Summary

KoPanda's library screen: a three-column grid of covers with a progress strip under each, a header with the
count and the sort and status pickers, the nav bar beneath, in both looks (direction doc "Library"; library
direction doc, `2026-10-16-kopanda-library-direction.md`).

## Behavior

- The Library tab and launcher entry open this screen instead of KOReader's file chooser; KOReader's
  file browser stays reachable from the home sheet.
- Covers come from the book model; a record without a path shows the not-downloaded mark; tap on a
  downloaded book opens it.
- Sort (recent, title, author, series) and status (reading, finished, all) pickers filter the grid and
  remember their choice per folder.
- Editorial: hairline header, soft cover shadows. Diner: mustard header with the handwritten count,
  outlined covers with hatched-chip progress.
- Pages by rows; the page position is remembered.
- Goldens for both looks on both profiles with the fixture books.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. Repo paths are on
`main` at `4564444`. Boards are `.tiller/design/2026-10-16-kopanda-library-screens/<board>.dc.html:<line>`:
`Main` is Diner's grid, `GridA` Editorial's, `SortC` Diner's sort sheet. Sizes are board pixels, scaled by
`Screen:scaleBySize` as the looks use them (`layout.lua:4-6`, `:15-17`), ×2.107 on the Colorsoft
(`base/ffi/framebuffer.lua:414-426`); font sizes go to `Font:getFace` unscaled, which scales them itself
(`frontend/ui/font.lua:276`).

This feature builds on `library/book-model` (F-alfeze, done: `books.lua`, `book_covers.lua`,
`book_index.lua`) and `nav-bar/nav-bar` (F-78e5ij, done: `nav_bar.lua`, `fm_nav.lua`). Both edges are recorded.

### Decisions

Owner decisions (owner, 2026-10-16):

- **D1. Its own window.** The library is a full-screen KoPanda window over the file manager, built the way
  the home is (`home.lua:18-22`, `covers_fullscreen`), not a replacement of KOReader's chooser inside the file
  manager. It has its own header, its own per-folder sort and status, and the nav bar with Library lit.
  KOReader's file browser keeps its own list and header, `bars/title-bar`'s (F-iwl43d) when that lands, with
  KOReader's global sort and filter, and stays reachable from the home sheet's "Open the file browser"
  (`home_sheet.lua:61-67`).
- **D2. Two rows of three per page,** as the boards draw (Main:30, GridA:30). Scaled literally, the header,
  two rows, the pager and the nav bar need about 22 device px more than the Colorsoft has in Diner and 42 in
  Editorial, with one-line titles (measured at `harness.at_colorsoft`: header 267 and 253, a row 526 and 541,
  the bar 187 and 191). The looks' library tokens are tightened until two rows fit (The fit, below).
- **D13. One-line titles,** ellipsised, no author line (the boards draw none, Main:47, GridA:47); two-line
  titles would cost about 84 device px more in Diner and 108 in Editorial, covers some 10–12 % shorter.
  **The "Not downloaded" label is a chip on the cover's foot,** beside the download badge, not under the
  title as the boards draw it (Main:71-73, GridA:71-73), so no tile reserves a slot for it and every tile has
  the same height: cover, strip slot, one title line.
- **D3. Recent is the reading history's order:** KOReader's history time (`frontend/readhistory.lua:15-36`;
  set on open, `:322-334`, and on close, `:343-350`), the order of the History list and of the featured
  book's history walk. Books never opened come after, by the title order. Not the file's access time, which
  KOReader's own "last read date" sort uses (`frontend/ui/widget/booklist.lua:43-55`).
- **D4. Closing a book opened from the library returns to the library** at the folder, sort, status and page
  it was opened from, pre-built so it shows in one paint, as the home does after a book closes. A book
  opened from anywhere else closes to the home, as today.
- **D5. The way back up:** inside a sub-folder the title is the folder's name after a back mark, and a tap
  on the title goes up one folder. At the library root the title is "Library" with no mark.

Lead decisions, each overturnable at approval:

- **D6. Where the Library tab and entry land.** From the home, the file browser or the launcher, the library
  opens at the folder and page it was last left at, or the root's first page the first time. A tap on the
  Library tab while the library shows goes to the root's first page, the way nav-bar's D5 sends the file
  browser to the home folder's first page.
- **D7. The library root** is KOReader's home folder, `filemanagerutil.getHomeFolder()`, as `Books.folder`
  already treats it (`books.lua:251-255`). No settings key.
- **D8. Status values:** Reading shows books whose status is `reading`; Finished, `complete`; All, every
  book. New and on-hold (`abandoned`) books show under All only. Folders show under every status.
- **D9. Sort orders.** Folders always come first, by the title order of their names, whatever the sort.
  Recent: D3. Title: lowercase, a leading "The ", "A " or "An " ignored (SortC:55, "ignoring “The” and
  “A”"), then lowercase byte order, ties by id. Author: the first author's surname key, then the title order;
  books with no author last. Series: the series name's title order, then `series_index` ascending, books
  with no index after those with one; books in no series last, by title. The default for a folder never
  picked is Recent and All, as the boards' pickers read (Main:25-26, GridA:25-26).
- **D10. The surname key** belongs to the book index: `BookIndex.surname(name)` gives the name's last word,
  joined with the words before it while each, compared without case, is one of the particles "de", "du",
  "da", "di", "del", "della", "der", "den", "van", "von", "le", "la" (library direction doc, "Authors": "the
  last word, with prefixes such as “Le” and “de” kept with it"). So "Ursula K. Le Guin" keys as "le guin",
  "bell hooks" as "hooks". `library/series-and-authors` reuses it for its own surname sort.
- **D11. Memory.** The sort and status per folder, the folder the library was left at and that folder's page
  live in KoPanda's runtime state file, `settings/kopanda/state.lua`, under one key `library`, never in the
  schema (AGENTS.md: runtime state is not a setting). Sort and status are written when picked; the folder
  and page when the library closes. `State.set` today compares the value it reads back with `==`
  (`state.lua:52`), which a table never passes; it changes to a deep compare, as `Settings.set` already
  makes (`same`, `settings.lua:208-223`, called at `:333`; local to `settings.lua`, so `state.lua` gets its
  own). When a write fails, the library keeps the choice in memory for the session.
- **D12. Fixed size.** The library's text does not follow `text_size`, as nav-bar's labels don't
  (nav-bar feature.md D8), so its page geometry, and the two-row fit, never change with it.
- **D14. Two registry icons:** `forward`, the mirror of the registry's `back` (`icons/back.svg`, already a
  left chevron, `icons.lua:52`), for the next-page arrow; and `download`, the board's arrow to a line
  (Main:66-67), whose Lucide source glyph the `tiles` task confirms against Lucide's files (expected
  `arrow-down-to-line`, not Lucide's `download`, which has a tray), each Lucide (ISC, as the set's other
  files, `icons/LICENSE-lucide.txt`). `back` draws the back mark and the previous-page arrow and gains
  "library" in its `used_in`; the pickers' down mark is the existing `chevron_down`. Consequences, as
  `bars/title-bar`'s D10 lists for its `plus`: the swatch screen draws every registry icon
  (`swatch.lua:265-293`), so its two goldens are regenerated; the studio's catalog lists the registry
  (`bin/catalog-json`; `spec/unit/studio_catalog_spec.lua`), so `npm run catalog` regenerates it; the
  studio's launcher icon picker offers the two as well.
- **D15. Opening a book** uses `filemanagerutil.openFile(fm, path)`
  (`frontend/apps/filemanager/filemanagerutil.lua:498-532`), the file browser's own tap
  (`frontend/apps/filemanager/filemanager.lua:160-169`), so KOReader's "ask before opening" applies here too.
  The featured book's `fm:openFile` is unchanged.
- **D16. The pager always shows,** one page included, so its place never moves. On the first or last page its
  dead arrow is drawn in Editorial's `hairline` (GridA:86) and left out of Diner's box (Main draws no disabled
  state). Paging does not wrap.
- **D17. Empty:** a folder with no book or folder under the status shows the header, a centred note ("No
  books here", or "No finished books here" and "No books being read here" under a status), and the pager at
  page 1 of 1. The library direction doc draws neither the empty library nor this.

### The window

`kopanda.koplugin/library.lua` (`Library`), an `InputContainer` with `covers_fullscreen = true`, shown with
`UIManager:show(library, "full")` and closed with `UIManager:close(library, "full")`, a module-level
`Library.shown` as `Home.shown` (`home.lua:24-25`, `:39-47`, `:207-233`). The name is free: no `library.lua`
under the emulator's `frontend/`, `common/` or `plugins/*.koplugin/` (`spec/unit/hooks_doc_spec.lua:104-122`'s
rule). Its parts:

- **Header** (top), **page** of tiles, **pager**, and the nav bar from `NavBar.new{ where = "library" }` at the
  bottom in its band (`nav_bar.lua:232-243`, `NavBar.height`, `:57-61`).
- `NavBar` gains `where = "library"` with Library active (`ACTIVE`, `nav_bar.lua:33`); its Home tab there
  closes the library and shows the home, as from the file browser (`NavBar.run`, `:65-88`, `:70`).
- **Shown on top of the home or the file browser.** Opening the library closes the home first; closing the
  library (the Home tab, a failure) leaves the file browser under it, or shows the home for the Home tab.
- **Closed with the file manager:** `KoPanda:onCloseWidget` (`main.lua:261-268`) closes it as it closes the
  home. A book opening closes the file manager (`onShowingReader`, `filemanager.lua:842-849`), so the
  library goes with it; a cancelled "open this file?" leaves both up.
- **The settled signal:** after its first paint on top, once per show,
  `UIManager.event_hook:execute("KoPandaSettled", { screen = "library", paint_ms })`, as the home's
  (`home.lua:156-200`); `paint_ms` from the tap or show that started it to the end of that paint.
- **Night and rotation:** the paint rebuilds first when `Looks.variant()` or `Screen:getSize()` changed since
  the build, as the editor does (`editor.lua:360-369`).
- **Kept current:** `onBookMetadataChanged` and `onInvalidateMetadataCache`, both broadcast to every window
  (`filemanagerbookinfo.lua:276-277`, `:556-557`; `uimanager.lua:1042-1061`), re-list the folder and rebuild
  the page. Nothing else signals a file deleted, moved or renamed (KOReader sends no event for those,
  `filemanager.lua:1169-1192`, `:1253-1268`), so the library re-lists on every show it builds. A library
  pre-built when a book closes is the one exception: it re-reads that book's progress when it is shown
  (Book close, below).

### The header

Diner: a mustard band, the count in the handwritten face over the title, the pickers as outlined chips
(Main:19-27). Editorial: no fill, a small-caps count over a serif title, a 2 px rule beneath, the pickers as
plain small caps (GridA:19-27).

- **Count:** the books in this folder under the status, folders not counted: Diner "N books on
  the shelf", Editorial "N books"; "1 book" / "1 book on the shelf"; "No books" / "No books on the shelf"
  (Main:21, GridA:21; `bars/title-bar`'s D2 wording, so the two headers read alike).
- **Title:** "Library" at the root; elsewhere the `back` icon then the folder's own name (D5), cut to the
  width left by the pickers with an ellipsis.
- **Pickers:** the sort's short label ("Recent", "Title", "Author", "Series") and the status's ("Reading",
  "Finished", "All") each followed by `chevron_down`; Diner's sort chip on `paper`, status on `pink`
  (Main:25-26).

### The page

- **Columns:** always three (library direction doc, "Grid density"), by `Layout.columns` with the look's column
  gap (`layout.lua:19-42`); rows two (D2).
- **A book tile,** top to bottom (Main:43-47, GridA:43-47; the strip's place, library direction doc
  "Progress strip"):
  - the cover box: the book's cover read by `BookCovers.read(record, w, h)` (`book_covers.lua:80-87`) in the
    look's frame (Diner: 3 px `outline` and a 5/5 hard shadow; Editorial: radius 3 and the `shadow.cover`
    2/3), or the typographic placeholder `FeaturedCover` draws for a book without one
    (`featured_cover.lua:96-150`), set at the grid's sizes; the frame drawn as `FeaturedCover.build` draws
    its own (`:152-225`), with the grid's tokens;
  - the progress strip: shown when `Books.progress(record)` (`books.lua:358-374`) gives a percent and the
    status is not `complete` or `new`; Diner a 14 px strip with a 2 px `outline` and a `mustard` fill on
    `paper` (Main:46; `progress.fill_grey`'s hatch on grey, as the featured bar, `widgets/featured.lua:246-276`);
    Editorial a 4 px `ink` fill on a `hairline` track (GridA:46); otherwise an empty slot of the same height
    (library direction doc, "Progress strip");
  - the title in one line (D13).
- **A not-downloaded book** (a record with no `path`, the model's only mark for it, book-model "The record"):
  the `download` badge on its cover (Diner: a 38 px circle on `paper` with a 3 px `outline`, overhanging the
  top-right corner, Main:64-67; Editorial: a 30 px circle with a 1 px `ink` edge inside the bottom-right
  corner, GridA:64-67), and "Not downloaded" as a chip on the cover's foot (D13; Diner a `pink` chip with a
  2 px `outline`, Main:71-73; Editorial muted small caps on a `paper` chip, GridA:71-73). Its strip slot is
  empty.
- **A folder tile** (Main:31-41, GridA:31-41): the cover box filled (Diner `pink`, Editorial `paper` with a
  1 px `hairline` edge), the `folder` icon at its top, at its foot the count of books directly in the folder
  ("14 books") and, when any, how many of them are `reading` ("3 reading"); then the empty strip slot and
  the folder's name in the title's place.
- **The cover box** keeps one size per look and screen, set by the fit. Covers are fitted inside it, as the
  featured cover fits its image (`featured_cover.lua:201-212`, `ImageWidget` `scale_factor = 0`).

### The pager

Centred above the nav bar (Main:85-88, GridA:85-88). Diner: two 44×32 boxes with 2 px `outline`, the previous
on `paper`, the next on `mustard`, the label "Page 1 of 24" between. Editorial: borderless arrows and
"1 / 24" in muted small caps. Arrows are `back` and `forward`; D16 for the dead arrow.

### The fit

A unit case computes, at the Colorsoft (1264×1680, `harness.at_colorsoft`, `spec/plugin_harness.lua:154-181`)
and at the Paperwhite (1236×1648, `spec/emulator/profiles.lua:3-6`), in both looks: header + grid top padding
+ two rows of tiles and the row gap + the pager + `NavBar.height` ≤ the screen's height.
The Paperwhite needs the device screen to answer as the Paperwhite's, as `at_colorsoft` does, since text is
measured at the device screen's scale (nav-bar feature.md F1). The tile's width follows the screen; its
height does not depend on what the tile holds (D13).

- **Tightening:** the looks' `library` vertical tokens (cover height first, then the header's and the grid's
  top padding, then the pager's) step down by the smallest board steps that make the case pass on both
  profiles in both looks. Each changed value carries a comment naming D2 and the board value it replaces, and
  the PR lists them beside the goldens the owner looks at.

### Tokens

A `library` block and its type parts in both looks with identical paths, each value with its board line in a
comment, every colour an existing palette role, by `looks_spec.lua`'s rules (`spec/unit/looks_spec.lua:83-129`,
`:189-238`). From the boards (before D2's tightening):

| Token | Editorial (GridA) | Diner (Main) |
|---|---|---|
| `library.header.fill_color` | false (:19) | `mustard` (:19) |
| `library.header.padding` top, side, bottom | 40, 40, 16 (:19) | 28, 40, 18 (:19) |
| `library.header.edge_width`, `edge_color` | 2, `ink` (:19) | 4, `ink` (:19) |
| `library.header.line_gap`, `picker_gap` | 2, 20 (:20, :24) | 2, 10 (:20, :24) |
| `library.header.picker_padding` x, y; `picker_outline_width` | 0, 0; 0 (:25) | 10, 4; 2 (:25) |
| `library.header.sort_fill_color`, `status_fill_color` | false, false | `paper`, `pink` (:25-26) |
| `library.grid.padding_top`, `side`; `row_gap`, `column_gap` | 22, 40; 22, 20 (:30) | 22, 40; 22, 22 (:30) |
| `library.grid.cover_h`; `strip_gap` (cover to strip), `title_gap` (strip to title) | 218; 10, 8 (:32, :43, :46) | 200; 12, 8 (:32, :43, :46) |
| `library.cover.outline_width`, `radius`, `shadow` x, y | 1, 3, 2, 3 (:43; owner: the width 1 is the hairline the cover takes at night and in grey, on the `outline` role, false by day, so the day cover stays borderless as GridA draws it) | 3, 0, 5, 5 (:43) |
| `library.strip.height`, `outline_width` | 4, 0 (:46) | 14, 2 (:46) |
| `library.folder.fill_color`, `outline_width`, `icon_size` | `paper`, 1, 36 (:32-33) | `pink`, 3, 44 (:32-33) |
| `library.folder.padding` x, y; `count_gap` | 14, 16; 4 (:32, :34) | 12, 14; 4 (:32, :34) |
| `library.cover.padding` x, y (the placeholder's) | 12, 16 (:43) | 10, 14 (:43) |
| `library.badge.size`, `outline_width`, `icon_size`, `inset`, `align` | 30, 1, 16, 8, `"bottom"` (:65-67) | 38, 3, 20, −12, `"top"` (:65-67) |
| `library.not_downloaded.fill_color`, `outline_width`, `padding` x, y | `paper`, 0, 4, 2 (lead: on the cover, D13; the board's plain text, :73, would sit on the artwork; owner: x 4, not 6, so the label fits beside the badge) | `pink`, 2, 6, 1 (:73) |
| `library.pager.button_w`, `button_h`, `gap`, `bottom`, `outline_width` | 44, 32, 22, 16, 0 (:85-88) | 44, 32, 18, 16, 2 (:85-88) |
| `library.pager.prev_fill_color`, `next_fill_color`, `dead_color` | false, false, `hairline` (:86-88) | `paper`, `mustard`, false (:86-88) |

Type parts (face, size, uppercase, tracking, line height, colour): `library_count` (Editorial `text` 11
caps 0.14 `muted`, GridA:21; Diner `accent` 24, Main:21), `library_title` (Editorial `display` 34, GridA:22;
Diner `display` 40 −0.01, Main:22), `library_picker` (Editorial `strong` 11 caps 0.12 `text`, GridA:25; Diner
`display` 11 caps 0.08, Main:25), `tile_title` (Editorial `strong` 12, GridA:47; Diner `display` 12 caps 0.04,
Main:47), `folder_count`, `folder_reading` (GridA:35-36, Main:35-36), `not_downloaded` (GridA:73, Main:73; owner: Editorial's untracked, as GridA's 0.14 does not fit beside the badge),
`pager_label` (GridA:87, Main:87), and `tile_cover_title`, the placeholder's title at grid scale
(Editorial `display` 18, GridA:44, :51; Diner `display` 17, Main:44, :51, the display face standing in for
the board's Georgia as `cover_title` does). `library.badge.align` uses the `top`/`bottom` values
`looks_spec.lua:209-210` accepts. Editorial's 500 and 600 map to `strong` and Diner's 800 to `display`, as
`nav_label` does (`looks/editorial.lua:333-337`, `looks/diner.lua:353-358`; faces at `looks/editorial.lua:12-14`,
`looks/diner.lua:11-15`). Where Diner sets text on `mustard` or
`pink` its colour is `on_accent`, the dark text the look puts on accents by night too (`looks/diner.lua:34`, `:53`),
as `nav_label_active` does.

### Gestures

The library takes its gestures through its own touch zones, which KOReader's touch lock filters
(`frontend/ui/widget/container/inputcontainer.lua:299-309`, `:322-350`; as the home, `home_gestures.lua:47-54`),
in this order:

1. **The nav bar's band:** a tap runs its tab, a hold nothing, both consumed (`bar:handle`, `nav_bar.lua:198-215`).
2. **Tap:** on a downloaded book, opens it (D15) after recording the return (Book close, below); on a
   not-downloaded book, nothing; on a folder tile, shows that folder at its remembered page; on the title
   inside a sub-folder, goes up one folder (D5); on a picker, its sheet (The pickers), through a
   `Library.on_picker(kind)` hook the `pickers` task fills; on a live pager arrow, that page. Each consumed.
3. **Swipe west / east:** the next / previous page, no wrap, consumed (as `Menu:onSwipe`'s directions,
   `frontend/ui/widget/menu.lua:1518-1538`, mirrored with `BD.flipDirectionIfMirroredUILayout`), except a
   swipe starting in the top or bottom edge band (`DSWIPE_ZONE_TOP_EDGE`, `DSWIPE_ZONE_BOTTOM_EDGE`), which
   goes on to step 6 for Gestures' bindings, as the home leaves them (`home_gestures.lua:40-45`).
4. **Page keys:** when `Device:hasKeys()`, `Input.group.PgFwd` and `PgBack` page forward and back
   (`menu.lua:984-992`; `frontend/device/input.lua:119-120`). The Colorsoft's class declares no keys
   (`frontend/device/kindle/device.lua:1208-1220`), but Kindle init turns `hasKeys` on when it finds a
   frame-tap input (`:553-556`, `:673-679`); whether the SE has one is an assumption the `screen` task need
   not settle, since the keys are registered only when `hasKeys()` answers yes. The emulator has keys
   (`frontend/device/sdl/device.lua:73`).
5. **Hold:** consumed, nothing runs. `Library.hit(x, y)` gives `{ kind = "book", record }`,
   `{ kind = "folder", folder }` or `{ kind = "empty" }` for a point on the page, the seam
   `library/context-menu` builds its three sheets on.
6. **Everything else,** a tap elsewhere included, goes to the file manager's menu zones and then the file
   manager, as the home forwards (`home_gestures.lua:139-160`), so the top menu's swipe and Gestures' corner
   zones above the bar still work; whatever none of them takes is consumed.

### The pickers

Tap on the sort picker shows the sort sheet (SortC): a header with "for this folder" in the aside face above
"Sort", "Library" at its right; four rows, each a label with a second line: Recent "Last opened first",
Title "A to Z, ignoring “The” and “A”", Author "By surname", Series "Series together, in series order"
(SortC:40-69). The status sheet is the same with "Show": Reading "Books under way", Finished "Read to the
end", All "Every book in this folder". The current choice's row is selected: Diner a `teal` fill, both looks
a `check` at the row's right (SortC:45-50); Editorial's sheet is not drawn and takes its sheet tokens with no
fill.

- A tap on a row stores the choice for this folder (D11), closes the sheet, and shows the folder's first page
  under it.
- `sheet.lua` gains, each optional so every existing sheet draws as today: a header aside stacked above the
  heading, a small-caps label at the header's right (a new field: the existing `header.hint`, `sheet.lua:6`,
  `:190-197`, stays as the folder sheet uses it, `folder_sheet.lua:55`), a row's second line, a selected
  row's fill and right-hand check, and rows with no icon set flush without the icon's indent (today the
  label always indents by the icon and gap, `sheet.lua:242`, `:307`).
- A sheet's failure today closes the home beneath it (`close_all`, `sheet.lua:446-460`); it closes the screen
  the sheet was shown over instead, the library here, the home as before.

### Covers

- After a page shows, from the next tick, `BookCovers.request(page records, { max_cover_w, max_cover_h },
  on_arrival, alive)` (`book_covers.lua:144-235`) with the cover box's size, `alive` testing
  `Library.shown == library`. On arrival the arrived tiles are rebuilt from their re-read records (a title
  that came with the extraction replaces the file name) and the library is set dirty; the page's order is
  not re-sorted until the next show or page.
- A new page replaces the request; closing the library calls `BookCovers.cancel()` (`:110-116`). The home's
  close cancels too (`home.lua:331`, through `featured_cover.lua:233-234`), which comes before the library's request, since opening the library
  closes the home first.

### Book close

- When a tap opens a book, the library records `{ folder, page }` in module state as the return, from
  `filemanagerutil.openFile`'s `caller_pre_callback` (`filemanagerutil.lua:500-502`), which runs only once
  the open goes ahead, so a cancelled "open this file?" (`:523-528`) records none.
- On the reader's `CloseDocument`, `KoPanda:onCloseDocument` (`main.lua:248-257`) pre-builds the library at
  the return instead of the home when a return is recorded; `KoPanda:onShow` (`main.lua:189-212`) shows it
  instead of the home, dropping one built for another screen size or variant as `Home.take_pending` does
  (`home.lua:258-283`), and clears the return. Taking it, the library re-reads the closed book's progress
  and rebuilds its tile, since the reader saves its sidecar after `CloseDocument` (`readerui.lua:887`, then
  `:874-877` on its close at `:893`), as the home refreshes when it takes its own (`home.lua:274-281`).
- A failed open reaches a file manager `Show` with no `CloseDocument` (`frontend/apps/reader/readerui.lua:734`,
  `:754`, `:764`): `onShow` then shows the library built afresh at the return.
- KoPanda's start still shows the home; the return is in memory only.

### Entry points

- `LauncherEntries`' `library` target (`launcher_entries.lua:123-129`), which the Library tab runs everywhere
  (`nav_bar.lua:65-88`), shows the library (D6) instead of `fm:onHome()`. The Library tab in the file browser
  therefore opens the library; it stays the lit tab there, so the file browser's goldens don't change.
- The featured widget's first-run "Open the Library" (`widgets/featured.lua:466-472`) runs the same target.
- The library is shown through `KoPanda:showLibrary`, beside `showHome` (`main.lua:123-181`), which refuses
  without a file manager. The boot guard is armed only on the process's first show (`main.lua:141-142`), the
  home's, so the library takes no part in it.

### Failure behaviour

Every hook fails safe, so KOReader's file browser stays usable, as the home's do (`home.lua:39-47`,
`:299-318`, `:348-362`):

- The library failing to build when asked to show: logged; the file browser is shown at the folder
  (`fm.file_chooser:changeToPath`, `frontend/ui/widget/filechooser.lua:341-371`), the home closed.
- A paint raising: logged; the library closes onto the file browser from the next tick.
- The gesture route raising: logged; the library closes onto the file browser.
- A tap's action raising (an open, a page, a sheet): logged, the tap consumed, the page as it was.
- A state write failing: logged by `State.set` (`state.lua:57-60`); the library keeps the choice for the
  session.
- A cover request or arrival raising: logged; the tiles keep their placeholders.

### HOOKS.md

Gains: `filemanagerutil.openFile` and the file manager's own tap (`filemanagerutil.lua:498-532`,
`filemanager.lua:160-169`), `ReadHistory.hist` and its times (`readhistory.lua:15-36`, `:322-350`),
`BookMetadataChanged` and `InvalidateMetadataCache` (`filemanagerbookinfo.lua:276-277`, `:556-557`),
`onShowingReader` (`filemanager.lua:842-849`), the page keys (`menu.lua:984-992`, `input.lua:119-120`),
`Menu:onSwipe`'s directions (`menu.lua:1518-1538`), the failed-open paths (`readerui.lua:734`, `:754`, `:764`)
and `changeToPath`. `spec/unit/hooks_doc_spec.lua` checks each entry cites a `file:line` and every required
module is named; `main.lua` requires `library` and every other new module at load
(`spec/unit/main_requires_spec.lua:22-53`).

### Goldens and budget

- **New:** `library-diner` and `library-editorial` on `colorsoft` and `paperwhite` (the root), and on
  `colorsoft` `library-folder-{diner,editorial}` (inside the sub-folder, the back mark) and
  `library-sort-{diner,editorial}` (the sort sheet over the root), each shot on `KoPandaSettled` with
  `screen = "library"`, or `screen = "sheet"` for the sheet (`sheet.lua:487-502`).
- **The capture library** is built by the spec in its scratch space, not added to `spec/fixtures/library/`
  (whose three books `spec/unit/fixtures_spec.lua:24-26` counts, and whose file-browser goldens would gain a
  folder): copies of the three fixture books at its root and a sub-folder holding one more copy. A scenario
  userpatch registers one path-less source book with no cover, so the not-downloaded tile shows; writes a
  reading position on one book so a strip shows; extracts every book's cover at the grid's box before the
  library shows, so no capture depends on extraction timing (as the home fixture extracts the featured cover,
  `spec/emulator/scenarios/2-scenario-home-fixture.lua:183-216`); and opens the library once the home settles.
- **Regenerated on purpose:** the two swatch goldens (D14).
- **Unchanged:** the home, night, sheet, editor screen, file-browser and probe goldens.
- **Budget:** each library capture's `paint_ms` is at most 250 ms, the home's tripwire
  (`spec/emulator/home_capture_spec.lua:7-10`).

## Notes

For the owner, besides the lead decisions D6 to D12 and D14 to D17 above:

- **`bars/title-bar` (F-iwl43d) is untouched,** but two of its premises shift. Its header is drawn from the
  2026-10-13 boards with KOReader's global sort and filter; this feature draws a near twin from the 2026-10-16
  boards with per-folder memory. And its D3 drops KOReader's Home button because nav-bar's Library tab ran
  `fm:onHome()`; after this feature that tab opens the library, so the file browser keeps no one-tap way to
  its home folder. Whether title-bar should keep the Home button is title-bar's own question, raised here and
  not changed.
- **Nav-bar's D5 changes forward:** the Library tab in the file browser no longer goes to the home folder's
  first page; it opens the library. `nav_bar_spec.lua` and `fm_nav_spec.lua` change their Library cases on
  purpose.
- The direction doc's "Not drawn yet" items this spec decides without a board: inside a folder (D5), an empty
  folder (D17), the Paperwhite (grey, by the looks' grey rules) and night (by `Looks.palette`), and
  Editorial's sort sheet.
