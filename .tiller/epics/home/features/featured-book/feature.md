# Featured book with cover and progress

## Summary

The one widget with real plumbing: the most recently opened book that still exists, its cover from
KOReader's bundled CoverBrowser cache, its progress from the sidecar, drawn in the look's cover frame
(design §5 Widgets; direction doc "Featured book", "Covers").

## Behavior

- The featured book is the most recent entry in KOReader's reading history whose file exists, unless
  `featured.pinned` names another.
- Cover and metadata come from `BookInfoManager:getBookInfo(filepath, get_cover)`
  (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325`); when no cover is cached yet the widget shows
  title and author with a typographic placeholder and asks for extraction, repainting when it arrives.
- Progress is the sidecar's `percent_finished` (`frontend/apps/reader/modules/readerrolling.lua:338`,
  `readerpaging.lua:163`), read through `DocSettings`; time left uses the
  Statistics plugin's reading speed and falls back to pages left.
- Covers fit inside the frame, centred, paper showing on the short side; titles cap at two lines.
- Tap opens the book. With no book ever opened the slot shows the first-run state with an Open the
  Library button.
- Goldens for both looks on both profiles with a fixture book.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`; `base/` is the
koreader-base submodule in that checkout. Canvas references are to
`.tiller/design/2026-10-13-kopanda-screens/<board>.dc.html:<line>`; sizes are board pixels, as the looks
use them.

Two dependencies are cited as spec, not code:

- `home-layout` is specced, not built: its row engine, widget contract, keys, default layout, goldens and
  fixture userpatch are cited from `.tiller/epics/home/features/home-layout/feature.md` and its
  `tasks/*/task.md` on `main` (commit `623a46f`).
- `looks-and-schema` is in review: `schema.lua`, `settings.lua`, `looks.lua`, `looks/*.lua`, `fonts.lua`
  and `icons.lua` are cited from its feature review branch `tiller/reviews/features/home/looks-and-schema`
  (head `d56bc42`).

This feature starts after both have merged.

### The key

One key enters the schema, after `stats.show`, the last key `home-layout` adds (seven keys with `look`). `schema.version` stays 1.
The key is new and has a default, so it needs no migration (`migrations.lua` is empty).

| Key | Type | Default | Group | Why it exists |
|---|---|---|---|---|
| `featured.pinned` | path; label "Featured book" | `false` | `featured` | "Feature a different book" on the book's sheet writes it (direction doc "Featured book", "Schema consequences"). The owner wants a book on the home other than the last one opened. |

- `false` means "nothing pinned": the most recent book is featured. The direction doc says "a file path or
  nil", but `schema_spec.lua` requires every entry to have a non-nil default (`schema_spec.lua:61` on the
  review branch). `false` also survives the JSON dump that `bin/schema-json` makes for the studio, where a
  nil default would vanish.
- The `path` type is new. Its validator goes in `Settings.validators` (`settings.lua:18-27` on the review
  branch). It accepts `false`, or a string that starts with `/` and is longer than one character. It never
  raises. It does not touch the disk: a pinned file that has since gone is a valid stored value and is
  handled when it is read (below).
- A stored value the validator rejects reads as `false`, as every key does (`settings.lua:83-103`).
- This feature reads the key and nothing more. `sheets` writes it, through `Settings.set`.

### Which book

`kopanda.koplugin/featured_book.lua` is the one module that knows where the featured book comes from.
`FeaturedBook.current()` returns `nil`, or a record `{ file, title, authors, percent, status, pages,
seconds_left, chapter }`. The stage-5 book model replaces this module's insides and keeps the record
(`library/book-model`).

- **Pinned.** When `featured.pinned` is a path and `lfs.attributes(path, "mode") == "file"`, that file is
  the book. A pinned path that no longer exists is logged and skipped. The setting is left alone, because
  reads never write.
- **Most recent.** Otherwise, take the first entry of `require("readhistory").hist` whose file is still
  on disk.
  - The list is most recent first (`frontend/readhistory.lua:332-333`).
  - Entries carry `file` and `select_enabled` (`:25-36`). `select_enabled` is set only when an entry is
    built or deleted through KOReader (`:226-227`), not when a file vanishes over USB. So each candidate is
    re-checked with `lfs.attributes`, and entries with `select_enabled == false` are skipped.
  - The QuickStart guide is skipped, as `ReaderUI:getLastDirFile` skips it (`frontend/apps/reader/readerui.lua:571-577`,
    `QuickStart.quickstart_filename`).
  - The walk stops at the first hit. History holds at most 500 entries (`readhistory.lua:82`).
- **None.** No pin and no existing history entry means `nil`, and the widget shows the first-run state.
- **Freshness after a book closes.** `ReaderUI:onClose` runs `saveSettings`, which flushes the sidecar
  (`readerui.lua:876-878`, `:850-855`). It then updates the history time (`:882`) and only then
  broadcasts `CloseDocument` (`:887`), where KoPanda pre-builds the home. The book joined the head of the
  history when it opened (`readerui.lua:511`). So the pre-built home features the book just closed, with
  its progress as saved.
  - Exception: with KOReader's `history_freeze_finished_books` on, a finished book doesn't move to the head
    when it is opened again (`readerui.lua:510`). It is not featured then. That is KOReader's setting, honoured.

### Title, authors, cover

- **CoverBrowser.** KoPanda reaches CoverBrowser through `pcall(require, "bookinfomanager")`. The plugin's
  folder joins `package.path` only when CoverBrowser is enabled (`frontend/pluginloader.lua:283-287`;
  disabled plugins load only `_meta.lua`, `:212-216`), so a failed require means it is disabled.
  - CoverBrowser is a built-in plugin and on by default (`pluginloader.lua:37`, `:175`).
  - The capture profile leaves it enabled and seeds its database (`spec/emulator/driver.lua:16-18`,
    `:81-123` on `main`).
  - Whether the owner's Kindle has it enabled is an open fact for the `cover` task: read its
    `settings.reader.lua` `plugins_disabled` over USB. The widget works either way.
- **Metadata.** `BookInfoManager:getBookInfo(file, true)` (`bookinfomanager.lua:325-404`). It returns
  `nil` for a book that has never been indexed or is being indexed (`:359-361`, `in_progress=0` filter
  `:114-115`). On success it returns the columns of `BOOKINFO_COLS_SET` (`:77-103`), with flags `'Y'` or
  nil, and `unsupported` a reason string (`:38`).
  - **Title:** `title` from CoverBrowser when present. Otherwise `doc_props.title` from the sidecar, which
    `ReaderUI` saves on open (`readerui.lua:493`). Otherwise the file name without its extension.
  - **Authors:** `authors`, with any newline replaced by ", ". Otherwise `doc_props.authors`. Otherwise
    nothing, and the author line is omitted.
- **Cover.** With `has_cover` set, the result carries `cover_bb`, a fresh decompressed blitbuffer each call
  (`:388-395`).
  - It is drawn by `ImageWidget{ image = cover_bb, width, height, scale_factor = 0 }`, which fits it inside
    the box keeping its aspect (`frontend/ui/widget/imagewidget.lua:88-89`). `ImageWidget` frees the
    bitmap (`image_disposable` defaults to true, `:62`).
  - It sits centred in a fixed 2:3 box filled with `paper`, so paper shows on the short side (design §1b,
    "Covers fit inside the frame").
- **When to extract.** Only when CoverBrowser is loaded, decided in this order, the way
  `mosaicmenu.lua:471-488` decides:
  1. `getBookInfo` returns nil: ask.
  2. `unsupported` or `ignore_cover` is set, or `cover_fetched` is set and `has_cover` is not (the book
     has no cover): never ask. These draw the typographic placeholder for good.
  3. `cover_fetched` is nil, so the row was indexed without a cover: ask.
  4. `has_cover` is set and the cached cover is too small for the box,
     `BookInfoManager.isCachedCoverInvalid(info, specs)` (`bookinfomanager.lua:1013-1030`): ask.

  The order matters, because `isCachedCoverInvalid` is true for any row with no `cover_w`
  (`:1014-1015`), a no-cover or unsupported row included.
- **How it extracts.** `BookInfoManager:extractInBackground({ { filepath = file, cover_specs = {
  max_cover_w = box_w, max_cover_h = box_h } } })` (`:689-745`), in device pixels of the cover box. It is
  asked at most once per file per KOReader process, and never from `build`, `height` or `paintTo`: from a
  `UIManager:nextTick` scheduled after the home's settled signal (the hook `home-layout`'s weather fetch
  uses, `home-layout/tasks/weather/task.md` §2).
  - BookInfoManager has no completion event. `isExtractingInBackground()` is the only signal (`:685-687`),
    and CoverBrowser itself polls it every second (`covermenu.lua:164-175`).
  - So the widget checks with `UIManager:scheduleIn(1, check)` while `isExtractingInBackground()` is true,
    for at most 30 checks. When `getBookInfo` then has the cover, it calls `ctx.home:refresh()` once.
  - The check is unscheduled when the home closes, and stops early once the cover arrives or extraction
    ends without one.
  - This is the project's one bounded timer: it runs only while an extraction KoPanda asked for is in
    flight, ends in at most one repaint, and leaves nothing queued. See Notes.
- **Typographic placeholder.** Drawn when there is no usable cover:
  - The box is filled with the new palette role `cover`, and the title and author are drawn in `on_cover`,
    the way the boards draw every cover (Main:33-36, HomeRetro:28-31).
  - The title is uppercase, at most four lines, ending in an ellipsis. The author is uppercase on one line
    at the foot.

### Progress, pages, time left

- **Sidecar, read only.** `DocSettings.openSettingsFile(DocSettings:findSidecarFile(file))`
  (`frontend/docsettings.lua:301-315`, `:159-175`), not `DocSettings:open`. `open` deletes candidates it
  finds invalid (`:282-284`), and the home must never write into a book's metadata.
- **Percent:** `percent_finished`, 0 to 1 (`readerrolling.lua:338`, `readerpaging.lua:163`), shown as
  `floor(percent × 100)` "%", so a book reads 100% only when finished. Nil reads as 0%.
- **Status:** `summary.status`. Missing or unknown counts as `reading`, as `BookList` reads it
  (`frontend/ui/widget/booklist.lua:292-296`). A `complete` book shows "100%" and "Finished" in place of the
  time left.
- **Pages:** `pagemap_doc_pages` when `pagemap_use_page_labels` is true, else `doc_pages`, else
  `stats.pages` when it isn't 0 (crengine with Statistics off stores 0). That is the order `BookList`
  uses (`booklist.lua:298-306`). CoverBrowser's `pages` is nil for EPUBs (`bookinfomanager.lua:507-516`), so it
  is not used.
- **Time left** comes from the Statistics database through `home-layout`'s `reading_stats.lua`, which
  already opens it read-only and knows when the plugin is off (`home-layout/tasks/reading-stats/task.md`
  §2). It gains `ReadingStats.seconds_per_page(md5)`:
  - The book's row is `SELECT id, pages FROM book WHERE md5 = ? ORDER BY last_open DESC LIMIT 1`, with
    the sidecar's `partial_md5_checksum` (`plugins/statistics.koplugin/main.lua:2737`;
    `readerui.lua:497-501`). `md5` alone isn't unique (the unique index is on title, authors and md5,
    `main.lua:462-484`), so the latest opened row wins.
  - The rate is the plugin's own capped average: `SELECT count(*), sum(durations) FROM (SELECT
    min(sum(duration), ?) AS durations FROM page_stat WHERE id_book = ? GROUP BY page)`, bound with
    `max_sec` (`main.lua:40-49`). `max_sec` comes from the plugin's `statistics` settings table, read
    without a default; it is 120 when absent (`main.lua:30`, `:83`, `:143`).
  - The seconds per page are `sum / count`. With no row, no pages read or the plugin off, there is no
    rate.
- **Seconds left:** `(book.pages − round(percent × book.pages)) × seconds_per_page`. This is the stats
  popup's sum (`main.lua:1579`) over the book row's pages, the same pages `page_stat` rescales each row's
  `total_pages` to (`main.lua:422-452`).
- **Wording**, the boards' own and not KOReader's `duration_format`:
  - "2 h 10 min left" (Main:50), "45 min left", "1 h left", rounded to the minute.
  - With no rate: "84 pages left", "1 page left", from the sidecar pages.
  - With neither: the percent alone.
- **Freshness:** the Statistics plugin flushes page times on `CloseDocument`. The open fact the
  `reading-stats` task settles (does KoPanda's pre-build run before that flush?) applies here unchanged. If
  that task moves the stats read to show time, the time-left read moves with it.

### Chapter

The boards draw the current chapter: Editorial "Part 3, The Prophet" on its own line (Main:42); Diner
"Susanna Clarke · Part 3" after the author (HomeRetro:36). A closed book's chapter is nowhere on disk, so
KoPanda records it as the book closes.

- In the reader, `KoPanda:onCloseDocument` stores the file and
  `self.ui.toc:getTocTitleOfCurrentPage()` (`frontend/apps/reader/modules/readertoc.lua:476-480`), before
  it pre-builds. The document is still open at that point: the broadcast at `readerui.lua:887` precedes
  `closeDocument()` at `:891`.
  - The lookup fills the TOC itself if it must (`readertoc.lua:383-384`).
  - It returns `""` when no TOC entry covers the page (`:446-453`).
- The values go into `state.lua` as two scalar keys, `featured_chapter_file` and `featured_chapter`.
  `State.set` checks its write with `==`, which a table never passes (`state.lua` on `main`). This is
  runtime state, not a setting.
- The chapter line shows only when `featured_chapter_file` is the featured book and the title isn't
  empty. Both paths are compared through `ffiutil.realpath`: history stores realpaths
  (`readhistory.lua:26`), while `document.file` is the path the book was opened with. Otherwise it is omitted: a pinned book, or a book last read before KoPanda was installed, has none.
- The recording runs inside `pcall`. A failure is logged, and the chapter is absent.

### The widget

`kopanda.koplugin/widgets/featured.lua`, id `featured`, settings prefix `featured`, registered in
`widgets.lua` and required from `main.lua`, by `home-layout`'s widget contract: `{ id, settings_prefix,
height(width, ctx), build(width, ctx), tap(ctx) }`, every visual value from the active look
(`home-layout/feature.md` "The row engine").

The contract gains two things here:

- **`after_show(ctx)`, optional.** `home.lua` calls it on each built slot's widget from the `nextTick`
  after the settled signal, where the weather fetch runs. The featured widget uses it to ask for a
  missing cover.
- **A `tap` that returns `false` falls through** to the home's next gesture step. `home-layout`'s row
  engine consumes every tap in a slot whose widget has `tap` (`home-layout/tasks/row-engine/task.md`
  §5). The first-run slot needs a tap outside its button to reach the home's interim rule.

- **Default layout.** `"featured"` joins `layout.rows`' `widgets` list, and the default gains a
  full-width `featured` row after the header row, as `home-layout` planned (`home-layout/feature.md`
  "Default layout"; direction doc "Layout"):

  ```lua
  default = {
      { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
      { { widget = "featured", share = 1 } },
      { { widget = "quote", share = 1 } },
      { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
  }
  ```

  A stored layout written before this feature doesn't name `featured` and stays as stored. Nothing
  migrates it, since adding an id to `widgets` leaves every stored layout valid.
- **Geometry.** A row of the cover box, a gap, and a text column taking the rest.
  - The cover box is Editorial 150×225 with gap 24 (Main:32-33), Diner 140×210 with gap 20
    (HomeRetro:27-28), scaled by `Screen:scaleBySize`.
  - In a column narrower than the default full width, the box width is at most 40 % of the column, with
    its height 1.5 × its width.
  - The widget's height is the box height plus the cover shadow's y offset, so the shadow is never cut by
    the next row.
- **Cover frame** from the look (direction doc "Covers"; `looks/*.lua` `shadow.cover`, `radius.cover`,
  `stroke.outline` and the palette's `outline` role):
  - A hard or soft shadow of `shadow.cover` when its colour role resolves in the variant.
  - An outline at `stroke.outline` when the variant's `outline` role is a colour. That gives Editorial a
    shadow by day, an outline at night and both in grey, and Diner both always, as the tokens say.
  - The corner radius applies to the shadow, the outline and the placeholder fill. A real cover image is
    drawn square: `FrameContainer` rounds its background and border, not its content
    (`frontend/ui/widget/container/framecontainer.lua:124-139`).
- **Text column, Editorial** (Main:37-52), its top block spaced 6 px apart (Main:38):
  - the label "Continue reading" (label style, `muted`);
  - the title (display 28, line height 1.1, `ink`, two lines, ellipsis);
  - the authors (text 15, `text`, one line);
  - the chapter, 14 px below the authors (6 plus its 8 px margin, Main:42; text 14, `text`, one line).

  The progress block sits at the foot: the bar, 8 px gap, then the percent left and the time left right
  (text 13, `text`).
- **Text column, Diner** (HomeRetro:32-43), padded 6 px top and bottom:
  - the chip "Now reading" in the look's `chip` (`pink` fill, `outline`, uppercase; 2 px outline and
    3/10 padding from the board);
  - the title, 12 px lower (the column's 6 px gap plus its 6 px margin, HomeRetro:33, :35; display 28,
    line height 1.05, `ink`, two lines);
  - 6 px lower, "authors · chapter" (text 15, `muted`, one line, ellipsis).

  At the foot: the bar, 8 px gap, then "62% · 2 h 10 min left" (`strong` 13, `ink`).
- **Progress bar** from the look's `progress` token: height, `fill_color`, `track_color`, `outline_color`
  and `outline_width`, filled to the shown percent.
  - Where `fill_grey` is `hatch_135` (Diner in grey), the fill is a `FrameContainer` with `stripe_color`
    ink over paper (`framecontainer.lua:48-50`, `:127-132`). Its `hatchRect` draws stripes along
    x + y = constant, the board's 135° direction (`base/ffi/blitbuffer.lua:2209-2235`).
    - It only approximates the board. PWRetro:40 is 3 px ink, 4 px paper, measured across the stripe.
      `hatchRect` makes on and off equal and measures `sw` along x (`(x + y) % 2sw < sw`, `:2223`), so the
      width across a stripe is `sw / √2`.
    - `stripe_width` 5 board px, scaled, matches the board's 7 px period.
  - Bars are square-ended. Editorial's board rounds its 4 px bar by 2 px (Main:45); the token has no
    radius.
- **Type tokens.** Each look's `type` block (`home-layout` "Chrome") gains these parts, each
  `{ face, size, uppercase, tracking, line_height, color }` with values from the boards and the board line
  in a comment. Both looks declare every part:
  - text column: `featured_label`, `featured_title`, `featured_authors`, `featured_chapter`,
    `featured_caption`;
  - first-run state: `featured_empty_title`, `featured_empty_body`, `featured_button`;
  - placeholder cover: `cover_title`, `cover_authors`, `cover_empty`.
- **A `featured` token block** joins both looks:
  - the cover: `cover_w`, `cover_h`, `cover_padding` and the dashes;
  - the column: `gap`, `column_padding_y` and `title_gap`;
  - the chip: `chip_outline`, `chip_padding`;
  - the empty-state button. The look files' token rules hold
  (`looks_spec.lua:151-174` on the review branch): colours are palette roles in keys ending `_color`,
  widths are numbers.
- **Palette roles.** `cover` and `on_cover` join all three palettes of both looks:
  - Editorial: day and night `#2b4c6f` / `#f3f1ea` (Main:33, NightA:33), grey `#4a4a4a` / `#f4f4f4`
    (PWEditorial:33; the direction doc's cover grey).
  - Diner: day and night `#2b4c6f` / `#f5f1e6` (HomeRetro:28, NightC:28), grey `#4a4a4a` / `#f4f4f4`
    (PWRetro:28).

  `looks_spec.lua`'s identical-paths and grey-distinctness checks cover them.
- **First run** (`nil` book; direction doc "First run and failures"; EmptyStates:32-40):
  - a dashed frame in the cover box, `muted`, around "No book yet" (`cover_empty`);
  - the label or chip;
  - "Nothing open yet." (`featured_empty_title`, display 24);
  - "Open a book from the Library and it will wait for you here." (`featured_empty_body`, text 15);
  - an "Open the Library" button (`featured_button`).

  The column is centred vertically with a 10 px gap, and 16 px above the button (its 6 px margin,
  EmptyStates:38).

  KOReader has no dashed border, so the frame is drawn as 4 px dashes with 4 px gaps along each edge.
  Editorial's frame and button are 1 px `ink`/`muted` outlines, as the board draws them. Diner has no board
  for this state. It takes its `strong` face for the button, a `mustard` fill with an `outline` at
  `stroke.outline` and the tile's hard shadow, the way its Library tile is drawn (HomeRetro:56), and its
  dashes at `stroke.outline` in `muted`.
- **Tap** (`tap(ctx)`; direction doc "Gestures": "the cover opens the book"), anywhere in the slot:
  - With a book whose file still exists, it calls `FileManager.instance:openFile(file)`
    (`frontend/apps/filemanager/filemanager.lua:1616-1639`), KOReader's own path to `ReaderUI:showReader`.
    That closes the file manager, and with it the home (`KoPanda:onCloseWidget`, `main.lua`).
  - With a book that has since vanished, it calls `ctx.home:refresh()`, so the next book is featured.
  - In the first-run state, a tap on the button closes the home (`Home.close()`, `home.lua`) and calls
    `FileManager.instance:onHome()`, which opens the file browser at the home folder
    (`filemanager.lua:865-870`). Until stage 5 the Library is the file browser (`launcher` "Library reveals
    the file browser"). A tap elsewhere in the empty slot falls through to the home's interim rule.
  - Hold is `sheets`.
- **Errors.** Every KOReader read (history, sidecar, CoverBrowser, Statistics) is inside `pcall`. A
  failure is logged and degrades: no cover means the placeholder, no sidecar means 0%, and no book means the
  first-run state. The row engine's blank-slot rule is the last net (`home-layout` "The row engine").

### Goldens and budget

The populated `home-*` goldens of `home-layout` all change, because the default layout gains this row.
This feature regenerates them, and adds a placeholder-cover pair.

- `home-layout`'s fixture userpatch (`spec/emulator/scenarios/2-scenario-home-fixture.lua`,
  `home-layout/tasks/goldens-and-budget/task.md` §1) gains, in its populated scenario:
  - a reading history of one fixture book, `frankenstein.epub`;
  - its sidecar with `percent_finished = 0.62`, `doc_pages`, `doc_props` and `partial_md5_checksum`.
    It is written under the scratch `KO_HOME` with `document_metadata_folder = "dir"`
    (`docsettings.lua:118-135`), so nothing is written into `spec/fixtures/library/`;
  - a `book` row and page times in its Statistics database that give a known time left;
  - the chapter state keys.
- The empty scenario has no history, so the empty goldens now show the first-run slot.
- The populated goldens must show the real cover. How the capture gets it cached deterministically is an
  open fact for the `goldens` task (see that task).
- Goldens:
  - populated, both looks on both profiles (`home-diner-colorsoft`, `home-diner-paperwhite`,
    `home-editorial-colorsoft`, `home-editorial-paperwhite`), regenerated;
  - empty, both looks on the Colorsoft (`home-empty-diner-colorsoft`, `home-empty-editorial-colorsoft`),
    regenerated;
  - new: the typographic cover, both looks on the Colorsoft (`home-typecover-diner-colorsoft`,
    `home-typecover-editorial-colorsoft`), with CoverBrowser disabled in that scenario's profile.
- The paint budgets of `home-layout` hold with this row:
  - a freshly built populated home paints in at most 250 ms on each profile;
  - after a book close, the home's share is at most 100 ms.

  The featured row adds one SQLite read with a zstd decompress, one sidecar `dofile` and one Statistics
  query to the build.

### HOOKS.md

Every new KOReader surface goes into `kopanda.koplugin/HOOKS.md` with its `file:line`:

- `ReadHistory.hist` and its entry fields;
- `QuickStart.quickstart_filename`;
- `bookinfomanager` and its `require` path, `getBookInfo`, `extractInBackground`,
  `isExtractingInBackground` and `isCachedCoverInvalid`;
- `DocSettings:findSidecarFile` and `openSettingsFile`;
- the sidecar keys `percent_finished`, `summary.status`, `pagemap_doc_pages`, `doc_pages`, `stats.pages`,
  `doc_props` and `partial_md5_checksum`;
- the Statistics `book` table, the `page_stat` view and `max_sec`;
- `ReaderToc:getTocTitleOfCurrentPage`;
- `FileManager:openFile` and `onHome`;
- `ImageWidget` `scale_factor`;
- `FrameContainer`'s stripes.

## Notes

Defaults this spec writes in from the design, the canvas and the reads, without a question:

- **`featured.pinned` defaults to `false`, not nil**, because the schema spec requires a non-nil default
  and the studio reads the schema as JSON.
- **The chapter line is in.** Both looks' boards draw it. Nothing on disk holds a closed book's chapter,
  so KoPanda records it at close in `state.lua`. A book with no record shows no chapter line.
- **Time-left wording is the boards'**, not KOReader's `duration_format`. It matches `home-layout`'s stats
  wording ("23 min today").
- **A finished book** shows 100% and "Finished".
- **Diner's first-run state** has no board. Its button takes the Library tile's style.
- **Square cover images under Editorial's 3 px radius**: KOReader doesn't clip an image to a rounded
  frame.
- **The grey boards' cover frames differ from the tokens.** Diner's grey board shadow is `#c8c8c8`
  (PWRetro:28), but `shadow.cover` names `pink`, which is `#e0e0e0` in grey. Editorial's grey board draws
  a `#bdbdbd` shadow and no outline (PWEditorial:33), but the tokens give `#8c8c8c` for both. The tokens
  win, since `looks-and-schema` owns them; the owner can change a token.
- **Diner's grey hatch is approximate:** KOReader's `hatchRect` can't draw the board's 3 on, 4 off.

For the owner:

- **One bounded timer.** CoverBrowser gives no completion event, so "repainting when it arrives" needs
  polling. The widget checks once a second, only while an extraction it asked for is running, for at most
  30 s, and repaints once. The alternative honours "no background timers" to the letter: never poll, and
  show the cover the next time the home is built (the next book close, wake or return). This spec takes
  the bounded poll because the feature's narrative promises the repaint.
- **`featured.pinned` in the generated menus.** The direction doc says the pin is set from the sheet,
  not a settings screen. `device-menus` and `settings-form` each plan a control per schema key, which would
  give this key a path picker. Whether those features hide the key or show it as a "Featured book" picker
  is theirs to decide. Nothing here adds a hiding flag ahead of that decision.
- **The book model.** `featured_book.lua`'s `current()` and its record are the seam `library/book-model`
  swaps.
