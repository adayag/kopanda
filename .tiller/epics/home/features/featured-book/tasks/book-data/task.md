# Featured book, progress, time left and chapter from KOReader's own records

## Approach

The data half of the feature, with no drawing: which book, its text, its progress, its time left and
its chapter. Paths into KOReader are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **Schema and validator.** In `kopanda.koplugin/schema.lua`, after `stats.show`, add
   `featured.pinned`: `type = "path"`, `default = false`, `label = "Featured book"`, `group = "featured"`.
   In `settings.lua`, add `Settings.validators.path`. It returns true for `false`, and for a string whose
   first character is `/` and whose length is over 1. It returns false for anything else and never raises
   (`Settings.get` calls validators outside their own `pcall`, `settings.lua:89-94` on the review branch).
   `schema.version` stays 1.
2. **`kopanda.koplugin/featured_book.lua`**, the one module that reads KOReader for the featured book.
   `FeaturedBook.current()` returns `nil` or `{ file, title, authors, percent, status, pages,
   seconds_left, chapter }`. Every KOReader read is inside `pcall`; a failure is logged and degrades as
   the feature says.
   - **Which file.**
     - `Settings.get("featured.pinned")`: a string naming an existing file (`lfs.attributes(p, "mode") ==
       "file"`) wins. A string naming a missing file is logged once per process.
     - Otherwise walk `require("readhistory").hist` (`frontend/readhistory.lua:25-36`, `:332-333`). Skip
       entries with `select_enabled == false`, entries whose `file` is not a file now, and
       `require("ui/quickstart").quickstart_filename` (`frontend/apps/reader/readerui.lua:571-577`).
       The first hit wins.
     - Otherwise nil.
   - **Sidecar.** `DocSettings.openSettingsFile(DocSettings:findSidecarFile(file))`
     (`frontend/docsettings.lua:301-315`, `:159-175`). With no sidecar file, `openSettingsFile(nil)` gives
     empty data. Never `DocSettings:open`, which removes candidates it finds invalid (`:282-284`). Read:
     - `percent_finished`;
     - `summary.status`, unknown as `reading` (`frontend/ui/widget/booklist.lua:292-296`);
     - pages: `pagemap_doc_pages` when `pagemap_use_page_labels` is true, else `doc_pages`, else
       `stats.pages` when it isn't 0 (`booklist.lua:298-306`);
     - `doc_props.title` and `doc_props.authors` (`readerui.lua:493`);
     - `partial_md5_checksum` (`readerui.lua:497-501`).
   - **Title and authors.**
     - First CoverBrowser's, through `pcall(require, "bookinfomanager")` and `getBookInfo(file, false)`
       (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325-404`), with `\n` in `authors` replaced by
       ", ".
     - Then the sidecar's `doc_props`.
     - Then the file name without its extension for the title, and no authors.

     The cover task owns the `get_cover = true` call. This one passes false so it never decompresses a
     bitmap.
   - **Seconds left.** When there is an md5 and a percent, call
     `ReadingStats.seconds_per_page(md5)`. That returns `rate, book_pages` or nil. Seconds left is
     `(book_pages − math.floor(percent × book_pages + 0.5)) × rate`. With no rate it is nil, and the
     widget falls back to pages left.
   - **Chapter.** `State.get("featured_chapter_file")` names the same file as `file` once both go through
     `ffiutil.realpath`, and `State.get("featured_chapter")` is non-empty: that gives the chapter.
     Otherwise nil. History stores realpaths (`frontend/readhistory.lua:26`); `document.file` is the path
     the book was opened with.
   - `FeaturedBook.reset()` for specs: forget the once-per-process log flag.
3. **`kopanda.koplugin/reading_stats.lua`** (from `home-layout`'s `reading-stats` task) gains
   `ReadingStats.seconds_per_page(md5)`. It uses the same read-only open, the same missing-file and
   plugin-off checks, and the same `pcall` and logging:
   - `SELECT id, pages FROM book WHERE md5 = ? ORDER BY last_open DESC LIMIT 1`
     (`plugins/statistics.koplugin/main.lua:462-482`).
   - `SELECT count(*), sum(durations) FROM (SELECT min(sum(duration), ?) AS durations FROM page_stat
     WHERE id_book = ? GROUP BY page)` (`main.lua:40-49`). The bound is `max_sec` from
     `G_reader_settings:readSetting("statistics")`, read without a default, 120 when absent (`main.lua:30`,
     `:83`, `:143`).
   - A count of 0 or a nil row gives nil. Otherwise it returns `sum / count` and the row's `pages`, both
     through `tonumber`.
4. **Chapter at close.** In `main.lua`'s `KoPanda:onCloseDocument`, before `Home.prebuild()` and before
   the plugin-shell guards that skip the pre-build, when `self.ui` and `self.ui.document` and `self.ui.toc`
   exist:
   - inside `pcall`, `State.set("featured_chapter_file", self.ui.document.file)` and
     `State.set("featured_chapter", self.ui.toc:getTocTitleOfCurrentPage() or "")`
     (`frontend/apps/reader/modules/readertoc.lua:476-480`, `:446-453`);
   - a failure is logged and the pre-build still runs.

   The TOC lookup fills an unfilled TOC itself (`readertoc.lua:383-384`); C10's close budget measures the
   whole close path.
5. **HOOKS.md:** `ReadHistory.hist` and its fields, `QuickStart.quickstart_filename`,
   `DocSettings:findSidecarFile` and `openSettingsFile`, the sidecar keys read, `bookinfomanager`
   `getBookInfo`, the Statistics `book` table, `page_stat` and `max_sec`, and
   `ReaderToc:getTocTitleOfCurrentPage`.

## Surfaces

`kopanda.koplugin/schema.lua`, `settings.lua`, `featured_book.lua` (new), `reading_stats.lua`,
`main.lua` (`onCloseDocument`), `HOOKS.md`; specs `spec/unit/schema_spec.lua`, `settings_spec.lua`,
`featured_book_spec.lua` (new), `reading_stats_spec.lua`, `prebuild_spec.lua`.

## Tests

Written first and run failing.

- `schema_spec.lua` (C1, key part): the eight-key order ending in `featured.pinned` with its fields; the
  `path` validator exists and accepts the default.
- `settings_spec.lua` (C2): each refusal in C2 leaves the file byte-identical. `false`, `/mnt/us/a.epub`
  and a path to a missing file are accepted and survive a reopen. A stored `true` or `"rel/a.epub"` reads
  as `false` without raising.
- `featured_book_spec.lua` (C3), in the plugin harness:
  - **Which file.** `readhistory` is replaced in `package.loaded` with a table holding a `hist` list, and
    real temporary files stand for books. Cases:
    - the pin wins;
    - a gone pin falls back, the settings file is byte-identical afterwards, and the log line appears once
      across two calls;
    - the walk skips a vanished file, a `select_enabled = false` entry and the QuickStart path;
    - empty history gives nil.
  - **Sidecar fallbacks.** Sidecars are written under a scratch `KO_HOME` with
    `document_metadata_folder = "dir"` (`docsettings.lua:118-135`) so `findSidecarFile` finds them. Cases:
    no sidecar; `pagemap_doc_pages` with `pagemap_use_page_labels` on and with it off; `doc_pages` alone;
    `stats.pages` alone and `stats.pages = 0`; status `complete`, `abandoned` and missing; `doc_props` only;
    `bookinfomanager` stubbed with a title and two newline-separated authors; `bookinfomanager`
    unrequirable.
  - **Never writes.** `DocSettings.open` is stubbed to fail the test if called. The sidecar files' bytes
    and mtimes are unchanged.
  - **Seconds left** with `ReadingStats.seconds_per_page` stubbed: 2 s/page over 100 pages at 0.62 is
    76 s; with nil it is nil.
  - **Chapter:** shown for the matching file, including when the state holds a symlinked path to it;
    absent for another file or an empty title.
- `reading_stats_spec.lua` (C4): fixture databases with the plugin's DDL, as that spec already builds
  them. Two rows share an md5 and the later `last_open` wins. A page read for 300 s with `max_sec` unset
  counts as 120, and as 60 with `max_sec = 60`. Also: an unknown md5, a book with no `page_stat_data`, a
  missing file (not created afterwards) and `plugins_disabled`. SQLite stays in this one spec file.
- `prebuild_spec.lua` (C3, recording part): with a stub `ui` whose `toc` returns "Letter IV", a
  `CloseDocument` writes both state keys before `Home.prebuild` runs (the stub records the order). A `toc`
  that raises leaves the keys unwritten, logs, and still pre-builds. With no `ui.document` nothing is
  written.

## Edge cases

- `percent_finished` above 1 or below 0 (a corrupt sidecar) is clamped to 0–1.
- `book_pages` from the Statistics row may differ from the sidecar's pages after a font change. Seconds
  left uses the Statistics row's pages consistently, the pages `page_stat` rescales to
  (`main.lua:422-452`). The pages-left fallback uses the sidecar's.
- A history entry for a file on an unmounted SD card fails the `lfs` check and is skipped, as a vanished
  file is.
- Two `State.set` calls flush twice per close. Each write is small, and C10 measures the close path.
