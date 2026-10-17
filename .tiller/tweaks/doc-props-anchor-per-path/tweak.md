# A cover arrival evicts the featured book's doc_props anchor

Found by the reviews of TW-bpvicu and TW-3tfybs and the merge of the two
(`.tiller/reviews/2026-10-17-efficiency-pass2-followups.md`, finding 2). Traced in code at KOReader
`e1fe1ac`, not measured on a device.

## What

`Books.with_progress` (`kopanda.koplugin/books.lua`) keeps the doc_props of the last sidecar it
opened in a one-entry `last_props`, anchored to that book's entry in the progress memo. The
library's cover-arrival rebuild reads a file book through `with_progress` (`library_covers.lua`,
`read_again`), so each arrival moves the anchor off the home's featured book, and the next home build
opens the featured sidecar once more for its doc_props. The progress itself is served from the memo;
only the doc_props read is repeated.

Either keep doc_props per path alongside the progress memo, bounded by the same path, mtime and size
key (doc_props can be large: a description is unbounded, so cap what is kept, or keep only the fields
`FeaturedBook` reads), or give the arrival a read that needs no doc_props: `Books.get` plus the
memoised `Books.progress` opens once for progress now, but `record(path, true)` still opens the
sidecar for the title, so that route needs the title read to go through the memo too. State which in
the PR.

## Why

One small sidecar open per return to the home after an arrival, only while covers are still being
extracted (the first days on the device). Low, but it is the one case where TW-3tfybs's "opened
once" does not hold across the two screens, and TW-bpvicu's contract claimed it would.

## Done when

- A unit spec: a shown library, a cover arrival for a file book, then `FeaturedBook.current()` for
  another book whose progress was already read: 0 `DocSettings.openSettingsFile` calls. It fails on
  the current code with 1.
- The memo holds no unbounded field (a spec shows a sidecar with a long description leaves it out,
  or the chosen route reads no doc_props on arrival).
- `bin/check` is green and the goldens are unchanged.
