# Book index keyed by id with cover and metadata cache

## Summary

The library's data: every book KoPanda knows, identified by an id rather than a path, with an optional
local file, its metadata and its cover cache keyed by that id (design §1b, "Noted for after the MVP").
The featured book widget switches to it.

## Behavior

- A book record has an id, a title, its authors, its series and index, an optional path, and its cover
  availability; its read status and progress are read from it on request. Books with a path are listed
  from the library folder, with metadata from CoverBrowser's cache. A record with no path is legal: it is
  listed, indexed and drawn with the cover its source supplies, so a later source can add books without
  changing the screens.
- An index over authors and series is derived from the records on every read, so it is current whenever
  it is asked for.
- Covers come from CoverBrowser's cache, one scaled cover per book. A miss asks CoverBrowser's extractor
  once, and the caller is told when covers arrive, so it can repaint.
- `home/featured-book` reads through the model; its behaviour and goldens are unchanged.
- Specs cover the listing, a path-less record, the author and series indexes, cover misses and arrival,
  and a run against the real CoverBrowser on the fixture books.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`; `base/` is the
koreader-base submodule there (`eeabdaa`), and crengine is `base/thirdparty/kpvcrlib/crengine/` (`f4a8be93`).
KoPanda paths are at `main` `52f7ad0`.

### Modules

Three new modules, all pure reads plus one bounded extraction path, none with a hook into KOReader:

- `books.lua`, the records: the library listing, a record for one path, a record by id, read status and
  progress, and the sources that supply path-less books.
- `book_index.lua`, the author and series index over a list of records.
- `book_covers.lua`, the cover reads and the one path that asks CoverBrowser to extract.

`main.lua` requires all three at load (its rule, `main.lua:5-7`). No settings key is added: nothing here
is something the owner has wanted to change on a device.

### The record

`{ id, source, path, title, authors, series, series_index, cover }`:

- `id` is a string unique across sources. A book with a file is `"file:" .. realpath(path)`
  (`ffi/util`'s `realpath`, `base/ffi/util.lua:162-177`), the identity KOReader's history already uses
  (`frontend/readhistory.lua:26`). A source's book is `"<source name>:<its own id>"`. CoverBrowser's row
  key, `bcid`, is not an id: its schema says it may change (`plugins/coverbrowser.koplugin/bookinfomanager.lua:27-28`).
- `source` is `"file"` or the source's name.
- `path` is the file as the listing reached it, or nil. A book without a path is a book not downloaded;
  the record carries no other flag for it. The grid's badge is `library/cover-grid`'s.
- `title` is a non-empty string. `authors` is a list of names, possibly empty. `series` is a name or nil;
  `series_index` a number or nil.
- `cover` is `"cached"`, `"missing"` or `"none"` (below).

### Metadata for a book with a file

Each book's metadata comes from CoverBrowser's `bookinfo` table, then its sidecar, then its file name.

- **CoverBrowser.** `pcall(require, "bookinfomanager")`, as the featured book reaches it now; a failed
  require means CoverBrowser is disabled (`frontend/pluginloader.lua:283-287`, `HOOKS.md` "The featured
  cover"). `BookInfoManager:getBookInfo(path, false)` (`bookinfomanager.lua:325-404`), one call per record,
  without a cover bitmap. It is nil for a book never indexed or being indexed (`:359-361`; the select
  requires `in_progress=0`, `:114-115`). Rows are keyed by directory and file name (`:68`), so the model
  asks with the path exactly as listed, the way KOReader's file browser asks.
- **Columns read:** `title`, `authors`, `series` and `series_index` (`:53-56`), `has_cover`,
  `cover_fetched`, `unsupported` and `ignore_cover` (`:37-47`).
  - `authors` holds several authors separated by newlines: crengine joins every `dc:creator` with `"\n"`
    (`base/thirdparty/kpvcrlib/crengine/crengine/src/epubfmt.cpp:1179-1199`), and KOReader splits them on
    it (`frontend/apps/filemanager/filemanagerbookinfo.lua:287-301`). The record's `authors` is that text
    split on newlines, each name trimmed with runs of white space made one space, empty names dropped.
  - `series` is the name alone and `series_index` a number: `Document:getProps` splits a trailing
    `" #N"` off the series (`frontend/document/document.lua:169-185`), and CoverBrowser's list shows them
    as two fields (`plugins/coverbrowser.koplugin/listmenu.lua:458-460`). The column is `REAL`, so an
    index may be fractional.
  - `ignore_meta` is not honoured, as the featured book doesn't honour it now.
- **Sidecar.** Where CoverBrowser gives no title or no authors (no row, disabled, or an empty column),
  `doc_props.title` or `doc_props.authors` from the sidecar, field by field as the featured book takes
  them now (`featured_book.lua:183-184`), read light: `DocSettings.openSettingsFile(DocSettings:findSidecarFile(path))`
  (`frontend/docsettings.lua:301-315`, `:159-175`), never `DocSettings:open`, which removes candidates it
  finds invalid (`:282-284`). No series comes from the sidecar.
- **File name.** The title falls back to the file name without its extension; authors to none.
- Each read (CoverBrowser, sidecar) is caught on its own; a failure is logged and that source reads as
  absent, as `featured_book.lua` does now (`featured_book.lua:27-35`).

### Cover availability

From the same row, in the order `featured_cover.lua` decides extraction (`featured_cover.lua:298-313`,
after `plugins/coverbrowser.koplugin/mosaicmenu.lua:471-488`):

- `"none"`, never worth asking: CoverBrowser disabled; or `unsupported`, `ignore_cover`, or
  `cover_fetched` without `has_cover` (the book has no cover).
- `"missing"`, worth asking: no row, or a row with `cover_fetched` unset.
- `"cached"`: `has_cover` is set. Whether the cached thumbnail is big enough depends on the box, so that
  test belongs to the cover read, not the record.

A path-less record's `cover` is what its source says, `"cached"` or `"none"`.

### The library listing

The library root is KOReader's home folder, `filemanagerutil.getHomeFolder()`
(`frontend/apps/filemanager/filemanagerutil.lua:25-27`). "Set as library root" in `library/context-menu`
therefore needs no key of KoPanda's.

- `Books.folder(dir)` gives `{ books, folders }`: `books` the records of the files directly in `dir`, and
  `folders` one `{ name, path }` per sub-folder the filters below keep, books or none inside; each list
  in byte order of name, and the root's path-less records after its local books (below). `Books.all()` gives a list of records, every book under the root,
  walking sub-folders. Neither asks for an extraction or writes anything, and neither calls
  `DocSettings:open` itself; KOReader's `hasProvider` may, for a suffix with no provider that has a
  sidecar (`frontend/document/documentregistry.lua:81-82`), as the file browser's own filter does.
- They list what KOReader's file browser lists (`frontend/ui/widget/filechooser.lua:114-143`):
  - names starting with `.` only when `FileChooser.show_hidden` is on (`:120`; the live class field,
    which `toggleShowFilesMode` sets, `:414-419`);
  - no folder matching `FileChooser.exclude_dirs` (`:28-54`, `.sdr` folders among them), checked through
    `FileChooser:show_dir` (`:81-86`); no file matching `exclude_files` (`:55-72`); no `._` file (`:135`);
  - only files `DocumentRegistry:hasProvider` accepts (`frontend/document/documentregistry.lua:63-85`),
    the file manager's own filter (`frontend/apps/filemanager/filemanager.lua:143`). The file browser's
    status filter and `show_unsupported` don't apply: the grid has its own status picker.
  - A folder that can't be read is skipped and logged, as `getPathList` pcalls `lfs.dir` (`:116`).
- `Books.all()` visits each folder once by its realpath, so a folder linked into itself can't loop, and
  lists each id once.
- Path-less records from every source belong to the library root: `Books.folder(root)` and `Books.all()`
  list them after the local books; no other folder holds them.
- A missing root lists the sources' books alone, logged.

### One book

- `Books.for_path(path)` gives the record for one file, built by the same rules, or nil when the path is
  not a file. It doesn't check for a document provider: the caller chose the file. The featured book
  uses it.
- `Books.get(id)` gives the record for an id or nil: a `file:` id by its path, a source's id from that
  source.

### Read status and progress

`Books.progress(record)` reads them when asked, never at listing, since they change each time a book is
read. For a book with a file, from the sidecar read light as above:

- `status`: `"new"` when the book has no sidecar (`DocSettings:hasSidecarFile`, `docsettings.lua:151-153`,
  is false), as `BookList.getBookStatus` answers (`frontend/ui/widget/booklist.lua:366-369`); otherwise
  `summary.status` when it is `reading`, `abandoned` or `complete`, and `reading` for anything else,
  the featured book's rule now (`featured_book.lua:19`, `:164-168`). That narrows KOReader's: its book
  list keeps any `summary.status` that has a status string (`booklist.lua:293-296`, through
  `getBookStatusString`, `:386-389`), which is any of the six keys of `:371-378`, `new`, `deleted` and
  `all` among them. A sidecar that exists but can't be read counts as opened.
- `percent`: `percent_finished` clamped to 0–1, or nil when it isn't a number.
- `pages`: `pagemap_doc_pages` when `pagemap_use_page_labels` is true, else `doc_pages`, else `stats.pages`
  when it isn't 0 (`booklist.lua:298-306`).
- `md5`: `partial_md5_checksum`, which the featured book's time left needs (`HOOKS.md`).

For a path-less record, what its source's `progress` gives, or `{ status = "new" }`.

### Sources

The seam a later Calibre-Web-NextGen source plugs into, and nothing more. No source ships with this
feature; only the specs register one.

- `Books.add_source{ name, books, cover, progress }`: `books()` gives the source's records, each with an
  `id` prefixed by the source's name and a `title`, no `path`; `cover(record, w, h)` gives a bitmap the
  caller owns, or nil; `progress(record)` is optional.
- Every call into a source is caught: a raising source is logged and leaves the local books listed. A
  record without an id or title is dropped and logged.
- Reconciling a source's book with a downloaded copy of it, and a disk cache for a source's covers, belong
  to the source's own feature.

### The author and series index

`book_index.lua` derives both lists from the records it is given, so they are as current as the listing
they came from; nothing is kept between calls.

- `BookIndex.authors(records)`: one entry `{ name, books }` per distinct name, the name as written (after
  the trimming above). A book with two authors is in both entries, and each entry's count is its number
  of books, so a two-author book counts for both (owner, 2026-10-16). A book with no authors is in no
  entry.
- `BookIndex.series(records)`: one entry `{ name, books }` per distinct series. Books are in series order:
  ascending `series_index`, books with no index after those with one, ties by title.
- Entries are in lowercase byte order of name; books inside an author's entry by lowercase title; ties
  last by id. These orders only make the output deterministic: the screens apply their own.

Kept for `library/series-and-authors`, which applies them on screen (direction doc "Decisions"): the
surname sort (the last word, with prefixes such as "Le" and "de" kept with it), the letter dividers,
series under way first then A to Z, and the next unread mark, which it reads from `Books.progress`.

### Covers

`book_covers.lua` generalises `featured_cover.lua`'s read and extraction (`featured_cover.lua:36-90`,
`:294-390`) from one file to a list, unchanged for one file.

- **The cache.** For a book with a file the cache is CoverBrowser's `bookinfo` row: one thumbnail per
  file (`bookinfomanager.lua:68`), scaled down to the box it was extracted for (`:533-540`) and replaced
  only when a bigger box needs a bigger one (`isCachedCoverInvalid`, `:1013-1030`). So a book keeps one
  cover, at the largest size any screen has asked for, and smaller boxes fit it down
  (`ImageWidget` `scale_factor = 0`, `HOOKS.md`). KoPanda keeps no second copy.
- **`BookCovers.read(record, w, h)`** gives a bitmap the caller owns, or nil: the row's `cover_bb` read with
  `getBookInfo(path, true)` when it has a cover, isn't ignored and isn't too small for the box; an
  unusable bitmap is freed. A path-less record's cover comes from its source. It never asks for an
  extraction.
- **`BookCovers.wants(info, specs)`** is `FeaturedCover.wants_extraction`'s rule, moved.
- **`BookCovers.request(records, specs, on_arrival, alive)`** asks for the covers that are wanted:
  - It skips path-less records and files already asked for in this process, reads each remaining row
    without a cover, and keeps those `wants` says yes to. With none, it returns, scheduling nothing.
  - It marks them asked, then asks once: `extractInBackground` with every wanted file and `specs`
    (`bookinfomanager.lua:689-745`).
  - Then a check each second (`UIManager:scheduleIn(1, …)`) while extraction runs, at most 30 checks,
    as now. Each check stops at once when `alive()` is false. It reads each pending file's row without a
    cover, and a row with a cover that fits has arrived. A check that finds arrivals calls
    `on_arrival(records)` once with them. Checking ends when nothing is pending, or at the check where
    extraction has ended or 30 have run. That last check reads each still-pending file with its cover,
    frees the bitmap, and counts the usable ones as arrived.
  - One request is in flight at a time. A new request replaces it: `extractInBackground` terminates the
    running extraction (`:695`), so the replaced request's check is dropped and its files that hadn't
    arrived are no longer marked asked, and a later request may ask for them again.
  - `BookCovers.cancel()` drops the check and keeps the marks, since the extraction itself goes on.
  - A fork that fails (`:724`) schedules nothing, logged, and its files stay marked asked, so this
    process doesn't ask for them again, as the featured cover marks its file before forking now
    (`featured_cover.lua:342-347`).
- This is still the project's one bounded timer (featured-book's Notes): it runs only while an
  extraction KoPanda asked for is in flight, and leaves nothing queued when it ends.

### The featured book through the model

`featured_book.lua` and `featured_cover.lua` keep every public function, record and behaviour, and their
specs pass with their assertions unchanged:

- `FeaturedBook` still chooses the book: the pin, the history walk and the chapter are its own. Its title,
  authors, status, percent, pages and md5 now come from `Books.for_path` and `Books.progress`. It joins
  `authors` with ", ", maps `"new"` to `"reading"` and a nil percent to 0, as it does now.
- `FeaturedCover.build` reads through `BookCovers.read`. `wants_extraction`, `after_show`, `cancel` and
  `reset` delegate to `BookCovers`, with `on_arrival` refreshing the home and `alive` testing
  `Home.shown == home`.
- Two behaviours differ, each only where the old code could not reach a better answer, and no featured
  spec exercises either:
  - An author name padded with spaces, or a blank line in the authors, is trimmed or dropped. crengine
    already trims each creator (`epubfmt.cpp:1190`), so only hand-edited metadata shows a difference.
  - A featured cover whose extraction a later request replaced may be asked for again.
- The home goldens, the sheet goldens and the paint budgets are unchanged; no golden is regenerated.

### HOOKS.md

Every surface above joins `kopanda.koplugin/HOOKS.md` with its `file:line`: `getHomeFolder`,
`FileChooser.show_hidden`, `exclude_dirs`, `exclude_files`, `show_dir` and the `._` rule,
`DocumentRegistry:hasProvider`, the `bookinfo` columns `series`, `series_index` and the authors
separator, `Document:getProps`' series split, `DocSettings:hasSidecarFile`, the status rules of
`BookList`, and `setBookInfoProperties` and `deleteBookInfo` for the CoverBrowser spec. The entries the
featured book added move under the model where the model now reads them.

## Notes

Defaults this spec writes in, without a question:

- **The id is the realpath**, prefixed. Nothing in this feature stores an id, so it only has to be unique
  and stable within a run. A moved file gets a new id, as its CoverBrowser row and its history entry
  already do.
- **No index is kept between calls.** The listing reads CoverBrowser's row per book and the disk per
  folder. Whether that is fast enough for a full library on the Kindle is measured where a screen pays
  for it: `library/series-and-authors` and `library/cover-grid` carry the paint budgets, and a memo
  invalidated by KOReader's `InvalidateMetadataCache` and `BookMetadataChanged` broadcasts
  (`filemanagerbookinfo.lua:276-277`, `:556-557`) would be their change.
- **Status `"new"`** is KOReader's word for a book never opened. The featured book maps it to reading, as
  it shows a book from the history.
- **Who asks for metadata.** Metadata arrives with the cover extraction. The grid asks for its page;
  `library/series-and-authors` asks for the books whose rows are missing when its screens need them.
- **Not honoured:** CoverBrowser's "Ignore metadata". The featured book doesn't honour it now either.

For the owner:

- **No cover or metadata store of KoPanda's own.** The narrative's "cover cache keyed by id" is, for books
  with a file, CoverBrowser's cache, one cover per book at the largest size asked for, not one per size.
  A path-less book's cover comes from its source. A disk store keyed by id would have no writer until a
  remote source exists, so it is left to that source's feature.
