# Pinned public-domain fixture books for the emulator library

## Approach

1. Pick three public-domain EPUBs with embedded covers from Project Gutenberg or Standard Ebooks, each
   under 2 MB, with short titles and distinct cover art so a golden of a featured-book widget reads at a
   glance (open fact for the task: which titles; the owner may name favourites at review). Download them
   once, verify each opens in the emulator (`./luajit reader.lua <file>` under a scratch `KO_HOME`
   shows the book), and commit them under `spec/fixtures/library/`.
2. Write `spec/fixtures/library/manifest.lua`: `return { { file = "<name>.epub", title = "...",
   author = "...", source = "<URL>", sha256 = "<hex>" }, ... }`. Licence note at the top: every title is
   public domain in the United States; Standard Ebooks releases are CC0.
3. SHA-256 in Lua: `require("ffi/sha2").sha256(f:read("*a"))` returns the lowercase hex digest
   (`base/ffi/sha2.lua:4356`, the `sha256ext` implementation; KOReader requires the module the same
   way, `frontend/util.lua:8`). The spec hashes each file in one read; the largest is under 2 MB.
4. Point the driver's `library_dir` default at `spec/fixtures/library/` (one line in
   `spec/emulator/driver.lua`), keeping the explicit empty-dir option for specs that want no books.
5. `AGENTS.md` Testing section: one line on the fixture library and how to add a book (manifest entry
   plus hash).

## Surfaces

- `spec/fixtures/library/*.epub`, `spec/fixtures/library/manifest.lua` (new)
- `spec/unit/fixtures_spec.lua` (new)
- `spec/emulator/driver.lua` (default `library_dir`)
- `AGENTS.md` (Testing)

## Tests

Written first, seen failing before the files exist.

- `spec/unit/fixtures_spec.lua`:
  - every entry in the manifest has its file, and the file's SHA-256 equals the entry's.
  - every `*.epub` in the folder has a manifest entry (no stray book).
  - every entry has a non-empty `title`, `author`, `source` starting with `https://`.
  - the manifest has exactly three entries.
  - each EPUB is a zip whose first entry is `mimetype` with content `application/epub+zip` (the EPUB
    container rule; read the first local file header with `string.byte`, no zip library).
- `spec/emulator/capture_spec.lua` gains one assertion: a capture with the default `library_dir` still
  produces the probe's PNG (the file browser behind the probe is on the fixture library).

## Edge cases

- Repo size: three books under 2 MB each is under 6 MB of binary, committed once; the manifest hashes
  stop silent replacement.
- Git treating EPUBs as text: `.gitattributes` marks `*.epub binary`.
- A book without an embedded cover would make a later featured-book golden show the fallback; the
  manifest's selection rule (cover embedded) is checked by hand at pick time and recorded per entry as
  `cover = true`.
- The manifest's hashes are plain SHA-256 hex, so `shasum -a 256` on the command line reproduces them
  when adding a book by hand.
