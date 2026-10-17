# Series state, author order, letter groups and the pagings as pure logic

## Approach

The pure half of both screens: what each view lists, in what order, in what state, on which page. No widget,
no window. Repo lines on `main` at `b05fe55`; cover-grid's names from its spec. Feature decisions D3, D8,
D12 to D16, D23.

1. **`kopanda.koplugin/shelf_order.lua` (`ShelfOrder`),** over records from `Books.all()`
   (`books.lua:263-292`) and the indexes `BookIndex.series` and `BookIndex.authors` (`book_index.lua:66-112`),
   whose own orders are for determinism only (`:1-4`):
   - `ShelfOrder.series(records, progress_of)`: one entry per series `{ name, books, state, complete, total,
     next, author, others }`. `books` in `BookIndex.series`' order (ascending `series_index`, no index after,
     then title); `progress_of(record)` is `Books.progress` (`books.lua:358-374`), passed in so specs stub it,
     called once per book per call; `state` is `under_way`, `finished` or `not_started` (D3); `complete` and
     `total` the chip's N and M; `next` the next unread record or nil (D3); `author` and `others` D15's
     line. Entries ordered by D12.
   - The title order is cover-grid's (lowercase, one leading "the ", "a " or "an " dropped, byte order;
     order task.md:22). Use `LibraryOrder`'s if it is exported; if it is local to `library_order.lua`, export
     it there (`LibraryOrder.title_key`) rather than copying it.
   - `ShelfOrder.authors(records)`: `BookIndex.authors`' entries ordered by D13 (`BookIndex.surname`, cover-grid
     D10, then lowercase name, then name), each with `letter` (D13) and `count`.
   - `ShelfOrder.author_books(entry, series_entries, progress_of)`: the entry's books in cover-grid's Series
     order (D9), through `LibraryOrder.view({ books = entry.books, folders = {} }, "series", "all",
     progress_of, {})` (order task.md:12-16), and the set of their ids that are their series' `next` in
     `series_entries` (D16).
   - **Pagings (D14):** `ShelfOrder.pages(rows, available)` where each row is `{ h, group }`: pages as runs of
     rows that fit whole in `available`, at least one row a page, each page's cost the rows' heights, the
     gaps between them, and per group started or continued on that page its overhead (a row carries
     `group_cost` with its group: the authors' box edges and the gap between groups; zero for the series
     lists). A group continued from the page before is marked `repeats` on the new page, so the screen draws
     its letter again. `ShelfOrder.page_of(pages, predicate)` gives the page holding the first row the
     predicate matches, 1 when none does (D17's back).
   - Count wordings are the screens' (D10), not this module's.
2. `main.lua` requires `shelf_order` at load (`spec/unit/main_requires_spec.lua`).

## Surfaces

- `kopanda.koplugin/shelf_order.lua` (new), `kopanda.koplugin/main.lua`; `kopanda.koplugin/library_order.lua`
  only for the title order's export.
- `spec/unit/shelf_order_spec.lua` (new); `spec/unit/library_order_spec.lua` unchanged if the export is
  needed.

## Tests

Written first, each run failing before the code (C1):

- `shelf_order_spec.lua` on hand-built records:
  - series state: all complete (finished, `next` nil); none started (not started, `next` the first); one
    complete then new (under way, `next` the second); the first `reading` (under way, `next` the first); an
    `abandoned` book before a new one (skipped); a path-less book as the next; a single `reading` book;
    `complete` and `total` counted;
  - D12's order: three under-way and two other series named to separate the rules ("The Broken Earth" before
    "Earthsea", a finished and a not-started series interleaved by name after them);
  - D15: one author; a first book with no author; two first authors differing ("and others"); no author at
    all;
  - D13: "Ursula K. Le Guin" before "Ann Leckie", two authors with one surname ordered by full name, a key
    starting with a digit and one with a non-ASCII first byte under "#" after "Z", a two-author book counted
    under both, a book with no author in none;
  - `author_books`: the Series order, a series' next unread marked only when it is this author's book and
    computed from the whole series (a co-authored series where the next unread is by the other author marks
    none here);
  - `pages`: rows that fit exactly, one over, a single row taller than `available` (a page of its own), a
    group split across a page (`repeats` on the second page), group costs counted once per page; `page_of`
    for a row on page 1, on page 3, and for no row.
- `library_order_spec.lua` passes unchanged if the title order is exported.
- `main_requires_spec.lua` and `hooks_doc_spec.lua` pass with the new module (C12).

## Edge cases

- `series_index` is a REAL in CoverBrowser's table (HOOKS.md, "Book records"), so 1.5 sorts between 1 and 2,
  as `BookIndex.series` already does (`book_index.lua:36-47`).
- Two series whose names differ only by case are two entries (`BookIndex.series` groups by the name as
  written, `:105-107`); they sort by the title order, then by name, so the order is total.
- A record whose `authors` is malformed is skipped by `BookIndex.authors` and logged there (`:73-89`); this
  module adds nothing.
- `progress_of` raising for one book: `Books.progress` already catches and answers `reading`
  (`books.lua:361-364`); a stub that raises in a spec is the screens' failure case, not this module's.
