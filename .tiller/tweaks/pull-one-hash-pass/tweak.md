# A pull reads and hashes every file twice

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 12, the small part). Traced in code
at KOReader `e1fe1ac`, not measured on a device. This code verifies files from outside, so it gets the
full review with mutation checks (AGENTS.md).

## What

`verify_files` (`push_bundle.lua:170-187`) hashes each file with `sha256_file` (`:180`), then
`bundle_hash` (`:147-166`) reads every file again to hash the bundle. Both run in pure Lua on the UI
thread. `check_manifest` already requires the manifest in byte order (`:93-95`).

Verify in one pass: walk the manifest in byte order and feed each block to both hashers.

Serving the bundle as one framed stream instead of one HTTP request per file
(`push_pull.lua:179-194`) is the larger part of the finding; it touches the studio and is an owner
decision, not part of this tweak.

## Why

A pull is the owner's tuning loop, about 118 files and 2.4 MB today. The second hash pass is an
estimated 0.3 to 1 s of the time frozen behind the "Pulling…" note on the Kindle.

## Done when

- A unit spec spies on `io.open` in `verify_files`: one open per file. It fails on the current code.
- `push_bundle_spec`'s tampered-file and tampered-hash fixtures still refuse.
- The reviewer's mutation checks (a skipped file, a swapped block, a hash fed out of order) are
  reported in the PR.
- `bin/check` is green.
