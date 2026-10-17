# Another key's failed state write leaves the chapter stale with the retry flag clear

Found by the review of B-e2tfz0 (`.tiller/reviews/2026-10-17-efficiency-pass2-followups.md`, finding
1). Traced in code at KOReader `e1fe1ac`, not reproduced on a device. A narrower sibling of
B-e2tfz0, which only covers the chapter write's own failure.

## Reproduction

1. Close a book at chapter A: the state file holds A, and `record_chapter`'s `chapter_unsaved` flag
   (`kopanda.koplugin/main.lua`) is false.
2. Make the disk fail. Any other module writes a state key: the library's close
   (`library_order.lua`'s `write` → `State.set("library", …)`), the studio menu, the launcher
   entries. `State`'s `write` (`state.lua`) saves the pair into LuaSettings' cache, then `flush` →
   `util.writeToFile`, which opens the file with `"wb"` (`frontend/util.lua:1130`): the file is
   truncated before the write fails. The chapter keys are gone from disk but still in the cache.
3. Restore the disk. Close the same book at chapter A again: `chapter_unsaved` is false and the cache
   holds A, so the write is skipped. The disk is still truncated.
4. Restart: `LuaSettings:open` falls back to `state.lua.old` (`frontend/luasettings.lua:31-44`), which
   rotates only when the file is older than 60 s (`:255-265`), so it can hold an older chapter.

## Expected

After any failed state write, the next chapter close writes the chapter again, so a restart shows
the chapter the reader last left or none.

## Actual

The skip compares against the chapter write's own last outcome. A failure elsewhere leaves the disk
behind the cache with the flag clear, and the next close at the same chapter writes nothing. Any
later successful write of any key heals it, since a flush writes the whole cache.

## Fixed when

- `state.lua` remembers whether its last write failed (for example `State.unsaved()`), set in
  `write` on failure and cleared on success, and `record_chapter` skips only when neither its own flag
  nor that is set. If the State-level flag covers every case, the module-local `chapter_unsaved` goes.
- A spec in `spec/unit/prebuild_spec.lua`'s "recording the chapter" describe: a successful close,
  then a `State.set("x", 1)` that fails through a `util.writeToFile` stub that truncates the file
  before returning nil, then a close at the chapter already recorded: it writes once, and a `dofile`
  of the state file shows the file and chapter. It fails on the current code.
- `HOOKS.md`'s chapter bullet says the skip compares against the last successful state write.
- `bin/check` is green.
