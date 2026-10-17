# Recording the chapter fsyncs state.lua twice per book close

Found by the 2026-10-17 efficiency review (`.tiller/reviews/2026-10-17-efficiency-review.md`, finding 9).
Not measured on a device.

## What

`record_chapter` (`kopanda.koplugin/main.lua:224-244`) makes two `State.set` calls on every
`CloseDocument`, one for `featured_chapter_file` and one for `featured_chapter`. Each `State.set`
(`state.lua:62-81`) stats the state directory twice, serialises the whole state file and flushes it
through `LuaSettings:flush`, which fsyncs the file and, when the file is older than 60 s, first renames
it to `.old` and fsyncs the directory (`frontend/luasettings.lua:251-275`, `frontend/util.lua:1124-1142`
at `e1fe1ac`), then reads the file back with `dofile` to verify the write. That runs inside the
reader's close, before the home builds, and also on reload and switch.

Add a `State.set_many` that writes several keys in one flush and one read-back, use it in
`record_chapter`, and skip the write when the file and chapter are unchanged.

## Why

Each fsync on the Kindle's flash is roughly 5-50 ms, on the critical path from closing a book to the
home appearing. Two writes and two parses per close for two keys that usually have not changed.

## Done when

- `spec/unit/prebuild_spec.lua`'s chapter-recording case stubs `util.writeToFile`: one close writes
  once; a repeat close of the same file and chapter writes zero times. The case fails on the current
  code.
- `State.set_many` refuses an undefined key the way `State.set` does, with a spec.
- `bin/check` is green.
