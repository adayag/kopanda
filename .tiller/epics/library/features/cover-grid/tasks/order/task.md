# Sort, status filter, paging and per-folder memory in the state file

## Approach

The pure half of the library: what a folder shows, in what order, on which page, and what the library
remembers. No widget, no window. Repo lines on `main` at `4564444`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. Feature decisions D3, D8, D9, D10 and D11.

1. **`BookIndex.surname(name)`** in `book_index.lua`: D10's key, lowercased for comparison. The name is
   split on spaces after the model's trimming (book-model "Metadata"); a one-word name is its own key.
2. **`kopanda.koplugin/library_order.lua` (`LibraryOrder`):**
   - `LibraryOrder.view(listing, sort, status, progress_of, history_times)`: from `Books.folder(dir)`'s
     `{ books, folders }` (`books.lua:242-261`), the folders by the title order of their names, then the
     books the status keeps (D8), in the sort's order (D9). `progress_of(record)` is `Books.progress`
     (`books.lua:358-374`), passed in so specs stub it; it is called once per book per view.
     `history_times` maps a `file:` id to its history time.
   - `LibraryOrder.history_times()`: one walk over `require("readhistory").hist`
     (`frontend/readhistory.lua:15-36`), each entry's `file` realpathed (`ffi/util` `realpath`, as
     `Books` ids are made, `books.lua:121-130`) to `"file:" .. path`, keeping the first (newest) time.
   - `LibraryOrder.page(items, n)`: items `6 × (n − 1) + 1` to `6 × n`, and the page count (at least 1);
     `n` clamped into range.
   - Title order: lowercase, one leading "the ", "a " or "an " dropped, byte order, ties by id (D9).
3. **Memory, in the same module:** `LibraryOrder.choice(dir)` gives `{ sort, status }` for a folder's
   realpath, defaulting to `recent` and `all`; `LibraryOrder.choose(dir, sort, status)` writes it;
   `LibraryOrder.left()` and `LibraryOrder.leave(dir, page)` read and write the folder and page left. All
   under one `State` key `library` = `{ folders = { [realpath] = { sort, status } }, at = { dir, page } }`
   (`state.lua:26-61`). A read of a malformed value gives the defaults, logged.
4. **`State.set`'s read-back** (`state.lua:52`) compares with a deep compare, a local function in
   `state.lua` of the shape `Settings.set` uses (`same`, `settings.lua:208-223`, called at `:333`; local to
   `settings.lua`, not exported): tables equal key by key, recursively; anything else by `==`.
5. **The session fallback:** `LibraryOrder` keeps the last choice per folder and the folder and page left in
   a module table as well; a read prefers it, so when `State.set` returns false the choice still holds until
   the plugin reloads.
6. `main.lua` requires `library_order` at load (`spec/unit/main_requires_spec.lua:22-53`); `HOOKS.md` gains
   `ReadHistory.hist` and its times (`readhistory.lua:15-36`, `:322-334`, `:343-350`) and the `library` state
   key under "The runtime state file" (`HOOKS.md:207-230`).

## Surfaces

- `kopanda.koplugin/library_order.lua` (new), `kopanda.koplugin/book_index.lua`, `kopanda.koplugin/state.lua`,
  `kopanda.koplugin/main.lua`, `kopanda.koplugin/HOOKS.md`.
- `spec/unit/library_order_spec.lua` (new), `spec/unit/book_index_spec.lua`, `spec/unit/guards_spec.lua`,
  `spec/unit/failsafe_spec.lua`.

## Tests

Written first, each run failing before the code:

- `library_order_spec.lua` (C1, C2): each sort on a hand-built listing of records with titles, authors,
  series and indexes chosen to separate the rules (an article title, two books by one surname with
  different first names, a "Le Guin", a series with a missing index, a book with no author, a folder named
  like a book); each status against stubbed progress; Recent with a stubbed history where a never-opened
  book sorts after; page slicing at 0, 6, 7 and 13 items and a clamped page; memory defaults, a stored
  choice for one folder leaving another at the defaults, the choice surviving a reload (`harness.load()`
  deletes the state file, `spec/plugin_harness.lua:71`, `:80-81`, so the reload case `package.unload`s
  `state` and `library_order` itself, then reads), and a malformed value read as the defaults.
- `book_index_spec.lua` (C1): `BookIndex.surname` for "Mary Shelley", "Ursula K. Le Guin", "Charles de
  Gaulle", "Ludwig van Beethoven", "Plato", and a name with doubled spaces.
- `guards_spec.lua` (C2): `State.set` with a table value returns true and reads back equal; with the state
  directory made a file it still returns false.
- `schema_spec.lua` passes unchanged (C2).
- `failsafe_spec.lua` (C11): with `State.set` stubbed to return false, a picked choice still reads back for
  the session.
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C13) pass with the new module and entries.

## Edge cases

- A history entry whose file no longer exists: `realpath` gives nil; skip it.
- A folder's realpath changing (a renamed folder): its memory is orphaned and the folder reads the
  defaults. No pruning: folders are few.
- Ties everywhere end on id, so the order is total and specs are deterministic.
- Folder names compare by the same title order, articles included, so "The Classics" sorts under C.
