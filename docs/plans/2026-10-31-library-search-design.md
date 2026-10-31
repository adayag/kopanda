# Library search (2026-10-31)

Decided on 2026-10-31 with the owner. A search over every book KoPanda knows, started from the
library's header and shown as a results window on the library chrome. SimpleUI was read for the
shape (`features/library/sui_library_search.lua`, read-only): a modal input, a word-and match over
title, authors, series and file name, a results list. KoPanda's own pieces cover each part: `Books.all()`
lists every record, `location_search.lua` already runs a typed input, the one-author view already
draws a paged grid of books on the chrome.

## What the reader sees

- **The chip.** A magnifier chip at the library header's right, before the status and sort pickers,
  in the sort picker's fill and outline, no label, no chevron. Its tap target reaches as the pickers'
  do. Hold on it opens nothing. No new setting, no new token.
- **The input.** A tap opens KOReader's input dialog titled "Search library", keyboard up, with
  Cancel and Search. Cancel, or Search on an empty or blank query, closes the dialog and nothing else
  happens.
- **The match.** The query splits on whitespace. Every word must appear, as a case-insensitive plain
  substring, in the book's title, one of its authors, its series or its file name. Books without a
  file (the sources') count too. No toggles.
- **The results.** A window on the chrome, in the one-author view's form: the back control over the
  count ("12 books", "1 book", "No books") and the query in curly quotes as the title; the matches as
  cover tiles in the library's title order, paged; the nav bar with the Library tab lit. No match
  shows "No books match" centred where the tiles would be. Tap opens a book with a file; hold opens
  its sheet as everywhere. Back returns to the folder and page the search started from. A book opened
  from the results returns, on close, to that same folder and page.
- **Limits.** Case folding is Lua's, ASCII only, so a word with a diacritic matches only as typed. No
  history, no filtering as you type, no result cap (the library is the owner's).

## Code

| Part | Where |
|---|---|
| The match | New `book_search.lua`: `BookSearch.words(query)` (the lowered words, none for a blank query) and `BookSearch.match(records, query)` (the matching records in the library's title order, every record for a query with no words). Pure, nothing kept. |
| The icon | `search` in `icons.lua`, `used_in = { "library" }`: Lucide `search.svg` as the default (stroke 2, black), Phosphor Fill `magnifying-glass-fill.svg`, Phosphor Bold `magnifying-glass-bold.svg`, MingCute `search_line.svg`, each recoloured as its set's section of `icons/SOURCES.md` says and listed there with its hash, from the pack versions already vendored. |
| The chip | `library_view.lua` `header`: a third chip in `spec.right`, last in the list (the chrome lays the list out from the right edge), so it sits left of the sort picker; built like `picker` with a `TintedIcon` of the label's line height in place of text and no mark, on `sort_fill_color`. `parts.search = { rect, hit }` with the pickers' reach. `Library:action_at` routes a tap inside it to `require("search_screen").ask({ dir, page })`, required at the tap. |
| The dialog | `search_screen.lua` `SearchScreen.ask(from)`: the input dialog as `entry_picker.lua`'s `ask_label`, guarded the same way; Search with words shows the window. |
| The window | `search_screen.lua` `SearchScreen`, a `LibraryChrome.Window` with `screen = "search"`, fields `query`, `from` ({ dir, page }), `records` (`Books.all()`, re-read on refresh through `LibraryChrome.keep_downloaded`). `view()` is `{ query }`. `build` plans as `authors_screen.lua`'s `plan_author` does: `LibraryChrome.detail_header_height`, `LibraryTiles.geometry` at `shelf.author_grid.cover_h` in `LibraryTiles.room`, `LibraryOrder.page`; the header through `LibraryChrome.header` with `back_label = "Library"`, the count in `library_count`, the query in `shelf_detail_title`; `LibraryChrome.foot(built, frame, "library")`. `back()` shows the library at `from`. `on_open` sets `Library.return_to = from`. `hit` answers book or empty. `page_keys`, `request_covers` and `refresh` as the authors screen's. |
| Sheets | Nothing: `library_sheets.lua`'s book sheet already opens on every window; empty opens only on the library. |
| Docs | `HOOKS.md`: the input dialog line names the search too. `README.md`: the library gains "search". |

No schema key, no token, no studio change.

## Tests

Each written first and seen failing.

- `spec/unit/book_search_spec.lua`: words split and lower; a blank query has none; every word must
  match; matching across title, each author, series and file name; a word matched in one field and
  another in a different field; case; a record with fields of the wrong type skipped for that field;
  title order; a record without a path.
- `spec/unit/icons_spec.lua`: `search` used in the library; the set files and hashes pass the
  existing checks.
- `spec/unit/library_screen_spec.lua`: the header holds the search chip left of the sort picker, its
  icon the label's line height; its hit reaches as the pickers'; a tap inside it runs the ask with
  the folder and page shown; a tap just outside it does not.
- `spec/unit/search_screen_spec.lua`: the count and the quoted query in the header; tiles for the
  matches in title order, paged by the rows that fit; the empty note; back shows the library at
  `from`; `on_open` records `from`; `hit` answers book and empty; a tile tap opens a book with a
  file and nothing for one without; the Library tab lit; the dialog's Cancel and a blank Search show
  nothing, a query shows the window.
- Emulator: `series_authors_capture_spec.lua` gains a fifth view, the search results for "the" on
  the scenario's catalogue, under the same paint budget.

## Tasks, in order

1. `book_search.lua` and its spec.
2. The `search` icon in the registry and the four sets, with `SOURCES.md`.
3. `search_screen.lua`: the window, the dialog, the specs, the capture, `HOOKS.md` and `README.md`.
4. The chip and its tap in `library_view.lua` and `library.lua`, with the specs.

Each lands as its own commit on `main`, test first; no Tiller unless the owner asks.

## Out of scope

A search tab in the nav bar; a launcher target; searching by tag, year or status; fuzzy or
accent-folding matches; remembering past queries; searching KOReader's file browser.
