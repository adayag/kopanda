# A failed chapter write is not retried on the next close

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 13), while verifying TW-soxspy.
Reproduced by hand in the unit harness, not on a device. A regression from TW-soxspy.

## Reproduction

1. `record_chapter` (`kopanda.koplugin/main.lua:274-277`) skips the write when `State.get` already
   holds the file and the chapter. `State.get` reads the `LuaSettings` cache, and `write`
   (`state.lua:73-75`) `saveSetting`s into that cache before `flush`, so a failed flush leaves the
   cache ahead of the disk.
2. Close a book at chapter A: the state file holds A.
3. Make the state file unwritable (a full disk, or stub `write` to fail). Read on to chapter B and
   close: `set_many` fails, the clearing `State.set("featured_chapter", "")` (`main.lua:280`) fails
   too. The cache now holds B; the disk holds A.
4. Restore the disk. Close the same book at chapter B again: the skip compares against the cache,
   finds B, and writes nothing. The disk keeps A.
5. Restart KOReader. `FeaturedBook` reads the chapter from disk (`featured_book.lua:104-114`) and shows
   A.

## Expected

`HOOKS.md:976-977`: a failed write clears `featured_chapter`, so no earlier chapter survives. The next
close after a failed write writes again, and after a restart the featured slot shows the chapter the
reader last left, or none.

## Actual

After a failed write, a later close of the same file at the same chapter skips the write, and the
disk keeps the older chapter until some other `State.set` flushes the whole cache (any library close
does, `library_order.lua:241`). The window is narrow: a full or failing disk that recovers, with no
other state write before a restart.

## Fixed when

- `main.lua` keeps a module-local `chapter_unsaved`, set whenever `set_many` or the clearing `set`
  returns false and cleared on a successful `set_many`. The skip applies only when it is false.
- `spec/unit/prebuild_spec.lua` (the "recording the chapter" describe) gains the reproduction: a
  successful write, then a close where both writes fail, then a close at the same file and chapter
  with the disk restored. The third close writes once, and a `dofile` of `state.lua` then gives
  `featured_chapter == ""` after the failure and the new chapter after the retry. It fails on the
  current code.
- `HOOKS.md:975`'s "skipped when they hold those values already" says it compares against the last
  successful write, not the in-memory copy.
- `bin/check` is green.
