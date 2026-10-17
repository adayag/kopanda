# Every library close rewrites the state file even when unchanged

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 9). Traced in code at KOReader
`e1fe1ac`, not measured on a device.

## What

`Library:close` (`kopanda.koplugin/library.lua:399`) calls `LibraryOrder.leave`
(`library_order.lua:273-280`) → `write` (`:230-242`) → `State.set` → `state.lua:62-87`: two directory
stats, a `LuaSettings:flush` (a backup rename and a directory fsync when the file is older than 60 s,
`frontend/luasettings.lua:251-275`; a write with fsync, `frontend/util.lua:1124-1142`) and a `dofile`
read-back. It runs on every book opened from the library (`readerui.lua:793-794` closes the file
manager → `main.lua:323-335` → `Library.close`), every library-to-home hop and every show that
replaces a shown library (`library.lua:237`), whether or not the folder or page changed. Page turns
don't write.

Skip the write when `dir` and `page` equal the last value written *successfully*. Compare against a
record of the last successful write, not the in-memory `session.at` or the State cache: both run ahead
of the disk after a failed flush, which is the defect in `bugs/chapter-write-retry`.

## Why

One or two fsyncs plus a parse, an estimated 10 to 50 ms on the Kindle, on the way into every book
and on each hop between the library and the home, for a value that usually hasn't changed. The same
shape as the first pass's finding 9 (TW-soxspy).

## Done when

- A unit spec spies on `State.set`: closing the library at the folder and page already stored writes 0
  times; closing after a turn writes once; after a failed write, the next close at the same place
  writes again. The first case fails on the current code.
- `bin/check` is green.
