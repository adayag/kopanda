# Comments and test names left stale by the efficiency tweaks

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, findings 14 and 15), while verifying the
five shelf items merged that day.

## What

- `kopanda.koplugin/HOOKS.md:1631-1633` says freeing a tile frees "its icons' masks … and `TintedIcon`
  its mask". Since TW-9atgka, `TintedIcon:free` only drops its reference (`tinted_icon.lua:65-68`).
- `spec/unit/library_tiles_spec.lua:449`'s title, "frees its cover's bitmap and its icons' masks", is
  stale the same way. The comment at `:447-448` is right.
- `reading_stats.lua:166-167` and the HOOKS note say the post-close build opens the Statistics database
  "once". It opens twice, because `read` and `seconds_per_page` (`:172`, `:218`) cross-refresh only
  when the stamp is set, and the post-close build runs before the files settle. Reword to "once when
  the files are settled".
- `HOOKS.md:975`'s "skipped when they hold those values already" means the in-memory copy. Reword with
  `bugs/chapter-write-retry`, or here if that bug lands first.
- `books.lua:4-5`'s header needs `with_progress`'s cached-table exception.
- `State.set_many({})` does a full flush (`state.lua:96-106`). There is no caller today; return early
  with true.
- Optional: `spec/unit/prebuild_spec.lua` keeps its pre-B-2o8ya3 file name.

## Why

Each of these says the code does something it no longer does. The next reader of HOOKS.md or the
test list trusts them, and HOOKS.md is the record of every KOReader internal the plugin touches.

## Done when

- Each line above is corrected or its item is noted as out of scope in the PR.
- `spec/unit/hooks_doc_spec.lua` passes, and `State.set_many({})` has a one-line spec: returns true
  and writes nothing.
- `bin/check` is green.
