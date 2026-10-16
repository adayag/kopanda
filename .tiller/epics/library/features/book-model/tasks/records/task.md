# Book records from the library folder, read status and progress, sources, and the featured book reading through them

## Approach

The record half of the model, and `FeaturedBook` moved onto it. Paths into KOReader are relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`; the feature's Specification carries every rule and its
citation, so this lists only how the work goes.

1. **The CoverBrowser spec gets a real `bookinfomanager` under the unit harness** (verified by the
   plan review's probe under `bin/check`). `disable_plugins()` then `load_plugin("coverbrowser.koplugin")`
   (`spec/unit/commonrequire.lua:57-62`, `:64-75`) loads the plugin through `PluginLoader:_load`, which
   `dofile`s its `main.lua` with the plugin root on `package.path` and then restores the path
   (`frontend/pluginloader.lua:231-271`); CoverBrowser's `main.lua` requires `bookinfomanager` at its top
   (`plugins/coverbrowser.koplugin/main.lua:6`), and it stays in `package.loaded`. `disable_plugins()`
   must come first: without it `_load` raises at `pluginloader.lua:264`, where `enabled_plugins` is
   still nil (`:168`). `extractBookInfo(file, specs)` then runs in-process (`bookinfomanager.lua:422-570`)
   and gave all three fixture rows a title, authors, `has_cover = "Y"` and a 150×225 `cover_bb`. So
   `books_coverbrowser_spec.lua` is a unit spec.
2. **`kopanda.koplugin/books.lua`.** Module state: the list of sources, and nothing else.
   - **Reads** (local functions, each caught, logged, absent on failure):
     - `row(path)`: `pcall(require, "bookinfomanager")`, then `getBookInfo(path, false)`; nil when
       CoverBrowser is off or has no row.
     - `sidecar(path)`: `DocSettings.openSettingsFile((DocSettings:findSidecarFile(path)))`, the read
       `featured_book.lua:82-84` makes now, moved here; plus whether the sidecar file exists.
   - **`record(path)`**: the record from `row` then `sidecar` then the file name, by the Specification's
     rules: id `"file:" .. (ffiutil.realpath(path) or path)`, `authors` split, trimmed and squeezed,
     `cover` from the row's flags. One `getBookInfo` call per record. Each field resolves CoverBrowser
     first, so whether the sidecar was read never changes the record. `record` takes whether to read
     the sidecar always or only when the row is missing or has no title or authors:
     - `for_path` always reads it, as `featured_book.lua:153` and `:202` do now, so a raising sidecar is
       still logged when CoverBrowser's row is complete (`spec/unit/featured_book_spec.lua:485`);
     - the listing reads it only for an incomplete row, so a listing of indexed books opens no sidecar.

     The featured book then reads its sidecar twice per build (record, then progress): one more `dofile`
     inside the 250 ms budget that C9 re-measures.
   - **`Books.for_path(path)`**: `record(path)`, sidecar always read, when
     `lfs.attributes(path, "mode") == "file"`, else nil.
   - **`Books.folder(dir)`** (`{ books, folders }`, `folders` as `{ name, path }`) and **`Books.all()`**
     (a list of records), by the Specification's shapes and orders: one walker over `lfs.dir` inside
     `pcall`, applying the
     file chooser's filters read from `require("ui/widget/filechooser")` at call time (`show_hidden`,
     `show_dir`, `exclude_files`, the `._` rule) and `DocumentRegistry:hasProvider`. `all()` keeps a set
     of visited folder realpaths and a set of ids. The root is
     `require("apps/filemanager/filemanagerutil").getHomeFolder()`. Source records are appended for the
     root.
   - **`Books.get(id)`**: a `file:` id by `for_path` of the rest; another id from its source's `books()`.
   - **`Books.progress(record)`**: the Specification's status, percent, pages and md5. The pages order is
     `featured_book.lua:117-127`'s `sidecar_pages`, moved here.
   - **`Books.add_source(source)`** appends; **`Books.reset()`** clears the sources, for specs.
3. **`featured_book.lua` reads through it.** `current()` and `describe()` keep choosing the file (pin,
   history, QuickStart, the gone-pin log, the chapter) and take title, authors, status, percent, pages
   and md5 from `Books.for_path(file)` and `Books.progress(record)`: authors joined with ", " (nil when
   empty), `"new"` read as `"reading"`, a nil percent as 0 with `has_percent` false so no time left is
   asked. `recent(n)` is unchanged. The module's now-unused locals go.
   - The `describe` contract stays `{ file, title, authors }` exactly
     (`spec/unit/featured_book_spec.lua:465-467`), and a raising sidecar read still keeps CoverBrowser's
     title and authors and is logged (`:470-486`, the log asserted at `:485`).
4. **`main.lua`** requires `books`. **`HOOKS.md`** gains a "Book records" section: `getHomeFolder`
   (`frontend/apps/filemanager/filemanagerutil.lua:25-27`), `FileChooser.show_hidden` and
   `toggleShowFilesMode` (`frontend/ui/widget/filechooser.lua:24`, `:414-419`), `exclude_dirs`,
   `exclude_files`, `show_dir`, `getPathList`'s `pcall(lfs.dir)` and `._` rule (`:28-54`, `:55-72`,
   `:81-86`, `:116`, `:135`), `DocumentRegistry:hasProvider` (`frontend/document/documentregistry.lua:63-85`,
   noting its sidecar branch at `:81-82` calls `DocSettings:open` for a file whose suffix has no
   provider, as the file browser's own filter does, `frontend/apps/filemanager/filemanager.lua:143`), the
   `bookinfo` columns `title`, `authors`, `series`, `series_index` (`bookinfomanager.lua:53-56`) and the
   flags (`:37-47`), the unique key (`:68`), the authors separator
   (`base/thirdparty/kpvcrlib/crengine/crengine/src/epubfmt.cpp:1179-1199`;
   `frontend/apps/filemanager/filemanagerbookinfo.lua:287-301`), the series split
   (`frontend/document/document.lua:169-185`), `DocSettings:hasSidecarFile` (`frontend/docsettings.lua:151-153`),
   `BookList`'s status rules (`frontend/ui/widget/booklist.lua:292-296`, `:366-369`, `:371-378`), and
   `setBookInfoProperties` and `deleteBookInfo` (`bookinfomanager.lua:572-600`) with `disable_plugins`
   and `load_plugin` (`spec/unit/commonrequire.lua:57-62`, `:64-75`) as what
   `spec/unit/books_coverbrowser_spec.lua` reads. The section sits under "## Plugin", where HOOKS.md
   already names the unit specs' reads beside the module they test; "## Capture harness" is
   `spec/emulator/`'s. The featured book's existing entries for `getBookInfo` and the sidecar keys point at
   `books.lua` where the read moved.

## Surfaces

- `kopanda.koplugin/books.lua` (new)
- `kopanda.koplugin/featured_book.lua`
- `kopanda.koplugin/main.lua`
- `kopanda.koplugin/HOOKS.md`
- `spec/unit/books_spec.lua` (new), `spec/unit/books_source_spec.lua` (new),
  `spec/unit/books_coverbrowser_spec.lua` (new)

## Tests

Written first and run failing, then the module. Run through `bin/check <spec>` with its output filtered to
the summary and failures.

- **`spec/unit/books_spec.lua`** (C1, C2, C3), on a scratch library under `DataStorage:getDataDir()` with
  `home_dir` set to it, `document_metadata_folder = "dir"`, and `bookinfomanager` stubbed or unrequirable
  per case as `featured_book_spec.lua` does:
  - the listing: a nested folder, a `.hidden` folder and `.dot.epub` with `show_hidden` off then on, a
    `book.sdr` folder holding an `.epub`, `._x.epub`, `notes.xyz`, `BookReader.sqlite.epub` (an
    `exclude_files` match, `^BookReader%.sqlite` being unanchored at the end, `filechooser.lua:57`,
    yet a suffix with a provider), an unreadable folder (mode 000) logged, a
    symlink from a sub-folder back to the root visited once, a missing root logged; byte order of names;
  - the record: id from realpath (a book reached through a symlinked folder has the target's id), the
    title and authors fallbacks, `"A\n  B  \n\nC"` giving `{ "A", "B", "C" }`, series and a fractional
    index from the row, every `cover` state including CoverBrowser unrequirable, a raising `getBookInfo`
    and a raising sidecar each logged with the other source still read; `for_path` on a directory and a
    missing path; `get` on both id kinds;
  - progress: every status case, the percent clamp and nil, the three pages sources, md5, a changed
    sidecar read again;
  - never writes: `DocSettings.open` spied and never called, the sidecar, settings file and a stub's
    write methods untouched, `extractInBackground` never called.
- **`spec/unit/books_source_spec.lua`** (C4, its listing and progress parts; the `covers` and `index`
  tasks add their parts to this file).
- **`spec/unit/books_coverbrowser_spec.lua`** (C7, its record parts; `covers` adds the cover read): the
  real `bookinfomanager` per step 1 on the fixture library as the root, records before and after
  `extractBookInfo`, then `setBookInfoProperties` writing `authors = "Mary Shelley\nPercy Shelley"`,
  `series = "Gothic"`, `series_index = 1.5`, then `deleteBookInfo`.
- The featured specs (C8) pass unchanged: `featured_book_spec.lua`, `featured_widget_spec.lua`,
  `book_sheet_spec.lua`, `prebuild_spec.lua`, `menu_spec.lua`, `failsafe_spec.lua`. `hooks_doc_spec.lua`
  and `main_requires_spec.lua` (C10) and `schema_spec.lua` (C11) pass.

## Edge cases

- **The featured spec counts calls.** `featured_book_spec.lua:265-276` asserts one `getBookInfo` call,
  with `get_cover` false, on the path given. `record` makes exactly that call and no other.
- **`hasProvider` can open a sidecar.** Only for a suffix without a provider that has a sidecar
  (`documentregistry.lua:81-82`). The listing accepts that, as KOReader's file browser does on every
  listing. `for_path` doesn't call `hasProvider` itself, but the real CoverBrowser's `getBookInfo` does
  (`bookinfomanager.lua:332-333`), the same call the featured book makes through it today. The
  featured spec's "no `DocSettings:open`" holds because that spec stubs `getBookInfo`.
- **The sidecar on a complete row.** `for_path` reads the sidecar even when CoverBrowser gives a title
  and authors, so a raising sidecar is logged as today (`featured_book_spec.lua:470-486`); the listing
  skips it there. The record is the same either way, since CoverBrowser's fields come first.
- **realpath fails** for a file removed mid-walk: the id falls back to the path, and `for_path` of a
  vanished file gives nil.
- **A huge library.** No cap and no memo; the screens' paint budgets judge it (feature Notes).
- **`show_hidden` read at load.** It is a class field set from `G_reader_settings` at load
  (`filechooser.lua:24`) and by the toggle; reading the class field at call time follows both.
