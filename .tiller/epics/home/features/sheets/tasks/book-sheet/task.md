# The book sheet, its read status sub-sheet and the featured-book picker

## Approach

What a hold on the featured book opens, and its two sub-sheets. Paths into KOReader are relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`; repo lines are on `main` at `f2ef10b`. This task starts after
`home/sheets/hold-and-home-sheet`, so the hold step calls a widget's `hold(ctx, ges, built)`.

1. **`Featured.hold(ctx, ges, built)`** in `widgets/featured.lua`. The file is 508 lines, past AGENTS.md's
   500-line signal, so the hold is a few lines:
   - with no book on the built widget (`built.book`, `widgets/featured.lua:453-466`), return `false`, so
     the home sheet opens;
   - otherwise `require("book_sheet").open(ctx, built, { started = started })` and return true, with
     `started = time.monotonic()` taken on the hold's entry (`ui/time`), so the sheet's `paint_ms` counts
     the cover build and status read before the show. It is required at call time, since `book_sheet`
     requires this module.

   `shown_percent` (`:133-138`) becomes `Featured.shown_percent`, so the sheet's meta reads the percent the
   home shows. Raise the file's length with the owner in the PR; the tweak TW-a7nfpr
   (`.tiller/tweaks/shared-paint-helpers`) would take about 60 lines out of it (its `tweak.md`).
2. **`FeaturedBook.recent(n)`** in `featured_book.lua`:
   - up to `n` entries `{ file, title, authors }` from `require("readhistory").hist`, most recent first,
     by `most_recent`'s filter (`featured_book.lua:41-49`: `select_enabled ~= false`, not the QuickStart
     guide, still a file);
   - each entry from a new `FeaturedBook.describe(file)`, `{ file, title, authors }` by the same reads
     `current()` uses (`cached_info`, the sidecar's `doc_props`, `file_title`; `:69-99`, `:140-171`).
     The picker calls `describe` itself for a pinned book older than the six.

   Neither raises. `describe` logs a raising read and falls back as `current()` does: a raising sidecar
   read leaves `openSettingsFile(nil)`'s empty data (`featured_book.lua:140`), so the title is
   CoverBrowser's, else the file name. `recent` calls `describe` under `pcall` and skips only an entry
   whose call raises, logged. Neither writes. `FeaturedBook.current` is left as it is.
3. **`kopanda.koplugin/book_sheet.lua`**, `BookSheet.open(ctx, built, opts)`, which passes `opts` on to
   `Sheet.show(spec, ctx, opts)`:
   - **A gone book.** When `lfs.attributes(book.file, "mode") ~= "file"`, `ctx.home:refresh()` and return,
     as `Featured.tap` does (`widgets/featured.lua:478-487`).
   - **The header:**
     - `cover = FeaturedCover.build(book, scale(sheet.cover_w), scale(sheet.cover_h), ctx)`
       (`featured_cover.lua:209-212`, never extracting);
     - `title = book.title` and `author = book.authors`;
     - `meta` joined by " · " from `Featured.shown_percent(book) .. "%"`, `book.chapter` when set, and
       `opened(file, now)` when the history has the file. `now` is `os.time()` when the sheet opens,
       not `ctx.now` (the home's build time, `home.lua:181` at `f2ef10b`), as the home sheet reads the
       weather's age.
   - **`opened(file, now)`** finds the `ReadHistory.hist` entry whose `file` equals the book's realpath
     (`ffiutil.realpath(file) or file`, as `featured_book.lua:125` does; history holds realpaths,
     `frontend/readhistory.lua:26`). From its `time` it counts local calendar days, the difference of
     `os.time{ year, month, day, hour = 12 }` for each date's `os.date("*t")`, divided by 86400 and
     rounded. 0 gives "opened today", 1 "opened yesterday", n "opened n days ago". A time in the future
     reads as today. No entry gives nil.
   - **The rows**, `name = "book"`, `band = "book"`:
     - **Open**, `open_book`: `run` calls `Featured.tap(ctx, nil, built)`, which opens the book with
       `fm:openFile` (`widgets/featured.lua:475-488`; `frontend/apps/filemanager/filemanager.lua:1616-1639`),
       or refreshes when the file went in between.
     - **Book details**, `info`: `run` calls
       `require("apps/filemanager/filemanager").instance.bookinfo:show(book.file)`
       (`filemanager.lua:406`; `frontend/apps/filemanager/filemanagerbookinfo.lua:71-87`). With no file
       manager, it does nothing, logged.
     - **Read status**, `bookmark`, `chip = "status"`: the detail is
       `BookList.getBookStatusString(BookList.getBookStatus(book.file), false, true) .. " ›"`
       (`frontend/ui/widget/booklist.lua:366-369`, `:386-389`). `run` opens the status sub-sheet with
       `{ started = time.monotonic() }` taken on its entry.
     - **More by this author**, `authors`, detail "›" plain: `run` is
       `LauncherEntries.run({ kind = "kopanda", target = "authors" }, ctx)` (`launcher_entries.lua:131-133`).
     - **Feature a different book**, `list`: `run` opens the picker, with `started` taken the same way.
     - **This widget's settings**, `settings`: `run` is `SettingsMenu.open()`.
4. **The status sub-sheet**, `name = "status"`, `band = "book"`, header `{ heading = "Read status",
   aside = book.title }`:
   - `local doc = BookList.hasBookBeenOpened(file) and BookList.getDocSettings(file) or file`, as the file
     dialog chooses (`filemanager.lua:255-270`; `booklist.lua:348-364`);
   - `local buttons = filemanagerutil.genStatusButtonsRow(doc, after)`
     (`frontend/apps/filemanager/filemanagerutil.lua:118-146`), and `STATUSES = { "reading", "abandoned",
     "complete" }` in the order it builds them (`:141-145`);
   - row `i`: label `BookList.getBookStatusString(STATUSES[i], false, true)`, no icon, `tick` when
     `buttons[i].enabled == false` (`:132`), `run = buttons[i].callback`;
   - `after` is the callback KoPanda passes: `ctx.home:refresh()` (`Home:refresh`, `home.lua:245-261` at
     `f2ef10b`). The button's own callback writes first: `saveSummary` (`:106-115`), then
     `BookList.setBookInfoCacheProperty(file, "status", s)` (`booklist.lua:318-326`).

   The sheet component closes the sub-sheet before `run`, so the refresh repaints the home with no sheet.
5. **The picker**, `name = "picker"`, `band = "book"`, header `{ heading = "Feature a book" }`:
   - `pinned = Settings.get("featured.pinned")`; `pinned_real = pinned and (ffiutil.realpath(pinned) or
     pinned)`; `pin_is_file = pinned and lfs.attributes(pinned, "mode") == "file"`;
   - the first row, "The last one opened": `tick` when not `pin_is_file`; `run` is
     `pin(false)`;
   - one row per `FeaturedBook.recent(6)` entry: label `title`, detail `authors` plain, `tick` when
     `pin_is_file` and the entry's file equals `pinned_real`; `run` is `pin(entry.file)`;
   - when `pin_is_file` and no row was ticked, one more row for the pinned book,
     `FeaturedBook.describe(pinned)`, ticked;
   - `pin(value)`: `local ok, err = Settings.set("featured.pinned", value)` (`settings.lua:307-315`);
     logged and stopped on a refusal. Then `ctx.home:refresh()`. Then, for the home's slot whose
     `widget == "featured"`, `slot.module.after_show(ctx.home.ctx, slot.built)`, inside `pcall`, logged on
     failure (`widgets/featured.lua:501-506`; `home.lua:356-375` at `f2ef10b` runs it only after a show).
     The refresh rebuilt the slots, so the slot is looked up after it.
6. **`main.lua`** requires `book_sheet` (`main.lua:22-46`). `book_sheet.lua` requires
   `ui/widget/booklist` and `apps/filemanager/filemanagerutil`, which `HOOKS.md` names in step 7.
7. **HOOKS.md:**
   - the modules `apps/filemanager/filemanagerutil` and `ui/widget/booklist`, new requires;
   - `filemanagerutil.genStatusButtonsRow` and `saveSummary` (`filemanagerutil.lua:106-146`), and the file
     dialog's choice of argument (`filemanager.lua:255-270`);
   - `DocSettings:open`'s removal of invalid candidates (`docsettings.lua:283-284`), reached through
     `BookList.getBookInfo` (`booklist.lua:337-346`) and `getDocSettings` (`:358-364`);
   - `BookList.hasBookBeenOpened`, `getDocSettings`, `getBookStatus`, `getBookStatusString` and
     `setBookInfoCacheProperty` (`booklist.lua:318-389`), with the status strings (`:371-384`);
   - `FileManager.instance.bookinfo:show` (`filemanager.lua:406`; `filemanagerbookinfo.lua:71-87`) and its
     close broadcasts (`:267-285`);
   - `ReadHistory.hist[i].time` (`readhistory.lua:25-35`), set by `addItem` (`:313-339`,
     `frontend/apps/reader/readerui.lua:511`) and `updateLastBookTime` (`:342-350`, `readerui.lua:882`);
   - `BookInfoManager.isCachedCoverInvalid`, for the small cover
     (`plugins/coverbrowser.koplugin/bookinfomanager.lua:1013-1030`).

## Surfaces

`kopanda.koplugin/widgets/featured.lua` (`hold`, `shown_percent`), `featured_book.lua` (`recent`),
`book_sheet.lua` (new), `main.lua`, `HOOKS.md`. Specs: `spec/unit/book_sheet_spec.lua` (new),
`spec/unit/featured_widget_spec.lua`, `spec/unit/featured_book_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines. Books are the fixture library's EPUBs
(`spec/fixtures/library/`) copied under `KO_HOME`, with history and sidecars written as
`featured_book_spec.lua` writes them.

- `featured_widget_spec.lua` (C5):
  - `hold` on a built widget with a book opens a sheet named `book` and returns true;
  - on the first run it returns `false` and opens nothing;
  - through the real home, a hold on the featured slot with a book shows the book sheet, and with none
    the home sheet.
- `featured_book_spec.lua` (C7): `recent(6)` with eight history entries, one a gone file, one
  unselectable and one the QuickStart guide, gives the first six that remain, most recent first, with
  titles and authors from the sidecar. `describe` of a file with no sidecar gives its file name as the
  title and no authors. A raising sidecar read gives that entry its CoverBrowser title, or its file
  name with CoverBrowser unrequirable, keeps the entry, and logs. With `describe` stubbed to raise for
  one file, `recent` skips only that entry and logs. The history file and every sidecar are
  byte-identical after.
- `book_sheet_spec.lua`, on a shown home over a real file manager:
  - **C5, the sheet:**
    - the header's title and author are the book's;
    - the meta reads "62% · Letter IV · opened today" for a history time an hour before `os.time()`,
      "opened yesterday" for one the previous calendar day at 23:59 when now is 00:01, and "opened 3 days
      ago". The 00:01 case stubs `os.time` to return that instant when called with no argument and to
      pass a table argument through to the real one, restored in `finally`, since `opened` calls
      `os.time{ … }` for each date. It leaves out the chapter when there is none, and the "opened" part for a pinned book with no
      history entry;
    - the six rows' labels and icons are in order;
    - the Read status detail reads "Reading ›" for a sidecar with `summary.status = "reading"`, "On hold ›"
      for `abandoned`, and "New ›" with no sidecar;
    - **Open** calls `fm.openFile` once with the file (spied);
    - **Book details** calls `fm.bookinfo.show` once with the file (spied);
    - **More by this author** shows an `InfoMessage` "Authors are coming with the library." with a nil
      `timeout`;
    - **This widget's settings** calls `SettingsMenu.open` once;
    - a hold whose book's file was removed after the build refreshes the home once and shows no sheet;
    - the header's cover is built by `FeaturedCover.build` at the token size, and
      `BookInfoManager.extractInBackground` is never called (spied, with CoverBrowser loaded);
    - **where `paint_ms` starts:** with `Sheet.show` and `FeaturedCover.build` spied, the hold passes
      `opts.started`, a number no later than the `time.monotonic()` recorded on entry to the cover build.
      For a book with a sidecar, the status sub-sheet's and the picker's `opts.started` are no later
      than the first `BookList.getDocSettings` or `FeaturedBook.recent` call their rows make (spied).
  - **C6, the status sub-sheet:**
    - its three rows read Reading, On hold, Finished, the current one ticked;
    - a tap on Finished leaves the sidecar with `summary.status = "complete"` and a `summary.modified`
      date, `BookList.book_info_cache[file].status == "complete"`, the sub-sheet closed, and the home
      refreshed once;
    - a tap on the ticked row writes nothing (sidecar byte-identical) and closes the sub-sheet;
    - for a book with no sidecar, no row is ticked, and a tap on On hold creates the sidecar with
      `abandoned`;
    - other summary fields in an existing sidecar (a `note`, a `rating`) survive a status change.
  - **C7, the picker:**
    - the first row "The last one opened", then six books in history order;
    - with no pin the first row is ticked;
    - a tap on the third book stores `featured.pinned` as that entry's realpath (read back through
      `Settings.get` after a reopen), closes the picker, refreshes the home once, and calls the featured
      module's `after_show` once with the rebuilt slot's built widget;
    - with that pin, the picker ticks that book and not the first row, and a tap on "The last one opened"
      stores `false`;
    - a pin naming a book older than the six adds a seventh, ticked row;
    - a pin to a gone file ticks the first row;
    - a tap on a ticked row leaves the settings file byte-identical;
    - with `Settings.set` stubbed to refuse, nothing refreshes and the refusal is logged.
- `hooks_doc_spec.lua` (C14) passes with the new requires: `ui/widget/booklist` and
  `apps/filemanager/filemanagerutil` from `book_sheet.lua`, and `ui/time` from `widgets/featured.lua`
  (named already), each named in `HOOKS.md`; `book_sheet` collides with no KOReader module path.

## Edge cases

- `genStatusButtonsRow` with a bare path starts from an empty `summary` (`filemanagerutil.lua:124-127`).
  That is why the opened-book case passes the `DocSettings`, as the file dialog does: an existing
  sidecar's other summary fields survive. The test proves it.
- `DocSettings:open` removes a sidecar candidate it finds invalid (`frontend/docsettings.lua:283-284`),
  and the book sheet reaches it on open, not only on a write. The Read status detail's
  `BookList.getBookStatus` calls `getBookInfo`, which opens the sidecar with `DocSettings:open` whenever
  one exists and BookList's cache lacks the book (`booklist.lua:337-346`, `:366-369`), when the book
  sheet opens. The sub-sheet's `BookList.getDocSettings` opens it again when the sub-sheet opens
  (`:358-364`). That is the path KOReader's own file dialog takes on a hold (`onFileHold`,
  `filemanager.lua:171-177`, then `:255-264`).
  `featured_book.lua`'s rule of opening sidecars light so nothing is removed (`:66-68`) covers that module
  only; it does not extend to `book_sheet.lua`.
- A sidecar with no `summary.status` shows "Reading ›", because `setBookInfoCache` maps a missing status
  to reading (`booklist.lua:293-296`), but the sub-sheet ticks nothing, because `genStatusButtonsRow` reads
  the raw `summary.status` from the `DocSettings` (`filemanagerutil.lua:120-123`). That is KOReader's own
  behaviour in its file dialog too. It is rare: `ReaderUI` sets `reading` on open when the status is
  missing (`frontend/apps/reader/readerui.lua:504-507`).
- The featured book's status in `FeaturedBook.current()` maps a missing status to "reading"
  (`featured_book.lua:151-155`), while the sheet's detail shows KOReader's "New" for a book with no
  sidecar. KOReader's label is the one the sub-sheet writes against, so the detail uses it.
- The small cover: when CoverBrowser has no cached cover, `FeaturedCover.build` draws the typographic
  placeholder at the small size, its title cut to fit (`featured_cover.lua:170-206`).
- Book details over the home: closing KOReader's page broadcasts `BookMetadataChanged` when something was
  edited (`filemanagerbookinfo.lua:272-281`). The home doesn't handle it, so an edited title shows on the
  next rebuild (feature Notes).
- Open: `fm:openFile` closes the file manager, and the home with it, as the tap does. The sheet is closed
  first, and the home's close closes any sheet too.
- Calendar days across a DST change: noon on each date keeps the day difference whole.
