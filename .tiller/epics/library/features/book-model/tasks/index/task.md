# Author and series index over the records

## Approach

A pure module over a list of records; no KOReader read of its own.

1. **`kopanda.koplugin/book_index.lua`.**
   - **`BookIndex.authors(records)`**: walk the records; for each name in `record.authors` (already trimmed
     and squeezed by `books.lua`), append the record to that name's entry, once per record even if the
     name repeats in its list. Entries `{ name, books }`; `#books` is the count. Books inside an entry by
     `title:lower()`, then `id`. Entries by `name:lower()`, then `name`.
   - **`BookIndex.series(records)`**: entries `{ name, books }` per distinct `record.series`; books by
     `series_index` ascending (nil after any number), then `title:lower()`, then `id`. Entries by
     `name:lower()`, then `name`.
   - Both build fresh tables on each call and keep nothing in module state. A record whose fields are
     the wrong type (a source's malformed record that passed `books.lua`'s id-and-title check) is skipped
     for the part that's wrong, logged once per call.
2. **`main.lua`** requires `book_index`. No `HOOKS.md` entry: it reads nothing from KOReader.

The orders are for determinism only. Surname order, letter dividers, under-way-first and the next unread
mark are `library/series-and-authors`'s (feature "The author and series index").

## Surfaces

- `kopanda.koplugin/book_index.lua` (new)
- `kopanda.koplugin/main.lua`
- `spec/unit/book_index_spec.lua` (new); `spec/unit/books_source_spec.lua` (index cases added)

## Tests

Written first and run failing, then the module. Run through `bin/check <spec>` with its output filtered to
the summary and failures.

- **`spec/unit/book_index_spec.lua`** (C5), on hand-built records:
  - authors: a two-author book in both entries, each counting it; a book with no authors in none; "Ursula
    K. Le Guin" and "Mary Shelley" as written; a name listed twice in one book counted once; case
    variants "mary shelley" and "Mary Shelley" as two entries; entry and book order as above.
  - series: indexes 2, 1, 1.5 and nil ordered 1, 1.5, 2, nil; two nil-index books by title; equal titles
    by id; books without a series in no entry.
  - currency: index a list, add a record and change another's authors, index again, and the second
    result follows while the first table is untouched.
- **`books_source_spec.lua`** (C4): a source's path-less record listed under its author and series by
  `BookIndex` over `Books.all()`.
- **`books_coverbrowser_spec.lua`** (C7): after `setBookInfoProperties` writes two authors and a series,
  `BookIndex` over `Books.all()` lists the book under both authors and in the series.
- `main_requires_spec.lua` and `hooks_doc_spec.lua` (C10) pass.

## Edge cases

- **Sorting with `table.sort`** needs a strict weak order: every comparator ends on `id`, which is unique
  within one listing (`Books.all()` lists each id once).
- **A series index of 0 or a negative** sorts as a number, before 1.
- **Large lists.** One pass and one sort per list; no caching, as the feature's Notes say.
