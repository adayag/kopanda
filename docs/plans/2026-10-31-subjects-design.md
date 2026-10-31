# Subjects (2026-10-31)

Decided on 2026-10-31 with the owner, for two large libraries (116 and 182 books) with almost no
series, many authors and many cookbooks, fitness and self-help titles. A Subjects shelf grouped by
the Calibre tags embedded in each EPUB, ordered by how many books a subject holds. The owner tidies the
tags in Calibre to a short list; KoPanda shows what the files carry and maps nothing.

## Facts

- crengine joins every `dc:subject` of an EPUB with `"\n"` into the document's keywords
  (`base/thirdparty/kpvcrlib/crengine/crengine/src/epubfmt.cpp:1201-1219`, as it joins authors at
  `:1179-1199`), `Document:getProps` passes them on as `keywords`
  (`frontend/document/document.lua:187,196`), and CoverBrowser's cache keeps them in the `keywords`
  column (`plugins/coverbrowser.koplugin/bookinfomanager.lua:58`, read at `:96`). So a record's
  subjects come from the same `getBookInfo` row `books.lua` already reads, split as authors are.
- Calibre embeds tags as `dc:subject` when it sends or converts a book. A book copied another way
  carries whatever subjects it shipped with. An assumption the device check covers.
- Of the two CSVs, 62 % and 59 % of books were untagged and the tagged ones carried up to sixteen
  publisher strings each; the owner tidies them first.

## What the reader sees

- **The shelf.** A Subjects window on the chrome in the Series list's shape: one row per subject
  with a cover stack, the name, and "12 books" as the sub-line, no state chip. Rows ordered by
  count, most books first, then by the library's title order of the name. A book with three
  subjects sits under all three. Header: "14 subjects" over "Subjects" with the inert label "Most
  books first" at the right. Empty: "No subjects yet".
- **One subject.** A tap on a row: the one-author view's grid, the back control "Subjects" over
  "12 books" and the subject's name, cover tiles in the library's title order, paged. Tap opens a
  book with a file, hold opens its sheet, back returns to the list at the page holding that subject.
- **The launcher.** A fourth KoPanda target, `subjects`, labelled Subjects with a tag icon in every
  set. The default launcher becomes Library, Series, Authors, Subjects, History, Settings; Wi-Fi
  leaves the default and stays available to add. A stored launcher is untouched.
- **The data.** Subjects are the EPUB's own, each trimmed, white-space runs made one space, empty
  ones dropped, nothing merged or recased. An untagged book is on no row; nothing counts them.
- **Returns.** A book opened from a subject returns there on close, as from an author.

## Code

| Part | Where |
|---|---|
| The record | `books.lua` `record`: `subjects = names(info and info.keywords)`, the sidecar's `doc_props.keywords` filling it when the row has none, as authors are filled. `HOOKS.md`'s bookinfo entry names the `keywords` column and the subjects separator. |
| The index | `book_index.lua` `BookIndex.subjects(records)`: `{ name, books }` per distinct subject, books in title order, a book under each of its subjects; a `subjects` field of the wrong type skipped as the other parts are. |
| The order | `shelf_order.lua` `ShelfOrder.subjects(records)`: `BookIndex.subjects`' entries with `count`, ordered by count descending then `LibraryOrder.title_key(name)` then name. `ShelfOrder.subject_books(entry)` is the entry's books, already in title order; no up-next marks. |
| The row | `shelf_rows.lua` `ShelfRows.series` draws no chip when `entry.state` is nil, the sub-line then the count text the entry carries (`entry.sub`); the screen passes `sub = "12 books"`. The smallest change that gives a subject row; a new `ShelfRows.subject` only if that proves cleaner. |
| The window | New `subjects_screen.lua`, `SubjectsScreen`, a `LibraryChrome.Window` with `screen = "subjects"`: the list as `series_screen.lua` plans and fills it (rows of `ShelfRows.series`, `LibraryTiles.header_height`, `ShelfOrder.pages`), one subject as `authors_screen.lua` plans and fills one author (`detail_header_height`, `LibraryTiles.geometry` at `shelf.author_grid.cover_h`, `LibraryOrder.page`). `view()` is `{ kind = "list" }` or `{ kind = "subject", name }`. Header band `look.shelf.subjects_fill_color`, a new token in `looks/base.lua` set as each look sets `series_fill_color` and `authors_fill_color` (Diner picks a third colour of its palette; the others follow their pattern). `foot(built, frame, "subjects")`. `on_open` records `LibraryChrome.return_to = { screen = "subjects", view, page }`; `main.lua`'s `SHELVES` gains `subjects` and `KoPanda:showSubjects(opts)` goes through `show_shelf`. `back()` on one subject: the list at `ShelfOrder.page_of` the subject's row. `hit`: `{ kind = "subject", entry }`, `{ kind = "book", record }`, `{ kind = "empty" }`. |
| The launcher | `schema.lua` `launcher.entries`: `targets.kopanda` gains `"subjects"` after `"authors"`; the default becomes library, series, authors, subjects, history, settings. `launcher_entries.lua` `KOPANDA.subjects = { label = "Subjects", icon = "subjects" }` and `KOPANDA_RUN.subjects` as `authors` (in place on the window, else home closed and `showSubjects{}`). `studio/src/schema.json` and `studio/src/catalog.json` regenerated. |
| The icon | `subjects` in `icons.lua`, `used_in = { "launcher", "launcher management" }` plus whatever the sheets use for the other shelves: Lucide `tag.svg`; Phosphor Fill and Bold `tag-fill.svg`/`tag-bold.svg`; MingCute `tag_line.svg`; each recoloured per its `SOURCES.md` section and listed with its hash, from the vendored pack versions. |
| Docs | `HOOKS.md`: the bookinfo entry (keywords), the chrome's window lists (`CloseWidget`, covers, `Window:open`, the metadata events, the returns) name Subjects. `README.md`: the library "with search, series, author and subject views". |

No schema key beyond the target and the default; one look token.

## Tests

Each written first and seen failing.

- `spec/unit/books_spec.lua`: `subjects` split on newlines, trimmed, white-space runs one space,
  empties dropped; none for a missing column; the sidecar fills an empty one.
- `spec/unit/book_index_spec.lua`: `subjects` groups a book under each subject, books in title
  order, a wrong-typed field skipped and logged once.
- `spec/unit/shelf_order_spec.lua`: `subjects` ordered by count then name; `subject_books`.
- `spec/unit/shelf_rows_spec.lua`: a series row with no state draws no chip and the given sub-line.
- `spec/unit/looks_spec.lua`: the new token's path in every look.
- `spec/unit/subjects_screen_spec.lua`, modelled on `series_screen_spec.lua` and
  `authors_screen_spec.lua` with `shelf_screen_cases.lua` where the cases fit: the list's header
  count and label, the rows in count order with their sub-lines, paging; one subject's header,
  six tiles a page, back to the list's page; `hit`; `on_open`'s return; the empty note; refresh.
- `spec/unit/launcher_entries_spec.lua`, `schema_spec.lua`, `settings_spec.lua`,
  `entry_picker_spec.lua`, `entries_edit_spec.lua`, `layout_spec.lua`, `folder_sheet_spec.lua` and
  the studio fixtures `spec/fixtures/studio/validator_cases.lua`, `entries_edit_cases.lua`, plus
  `studio/test`: the new target accepted and the new default; the home fixture scenario
  `2-scenario-home-fixture.lua` and `2-scenario-screens.lua`'s launcher list follow the default.
- `spec/unit/icons_spec.lua`: `subjects` registered and vendored.
- Emulator: `series_authors_capture_spec.lua` gains `subjects-list` and `subject-books`, the
  scenario giving its copies `keywords` through `setBookInfoProperties`; the home captures take
  the new default launcher as they are.

## Tasks, in order

1. The record, the index, the order and the row (`books.lua`, `book_index.lua`, `shelf_order.lua`,
   `shelf_rows.lua`, HOOKS' bookinfo entry), with their specs.
2. The `subjects` icon in the registry and the four sets, with `SOURCES.md` and the catalog.
3. `subjects_screen.lua`, the look token, `main.lua`, the specs, the capture views, HOOKS' lists.
4. The launcher target and the new default: schema, `launcher_entries.lua`, the studio's schema and
   catalog, every spec and fixture that pins the default, `README.md`.

Each lands as its own commit on `main`, test first; no Tiller unless the owner asks.

## Out of scope

A nav tab; a count or list of untagged books; a Subjects row in the empty-space sheet; hiding a
subject; merging or recasing tags; subjects from anything but the EPUB's own metadata.
