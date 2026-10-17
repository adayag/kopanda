# The Statistics database is opened twice per home build, uncached

Found by the 2026-10-17 efficiency review (`.tiller/reviews/2026-10-17-efficiency-review.md`, finding 3).
Not measured on a device.

## What

Every home build opens KOReader's `statistics.sqlite3` twice and runs five statements, and nothing is
kept between builds:

- `widgets/stats.lua:121-123` → `ReadingStats.read` (`kopanda.koplugin/reading_stats.lua:131-165`;
  `with_db` opens read-only at `:78-97`, `query` at `:99-113`): minutes today (a `sum`), books this month
  (`count(DISTINCT id_book)` over the month's rows), and the streak (one indexed probe per streak day up
  to `MAX_STREAK = 400`, two `os.time` calls each, `:49-61`).
- `widgets/featured.lua:421` → `FeaturedBook.current` → `ReadingStats.seconds_per_page`
  (`featured_book.lua:130-133` → `reading_stats.lua:202-224`, `rate` at `:179-196`): a second open and
  a `GROUP BY page` over the `page_stat` view for the featured book's whole history.

A build runs on every home show, every wake while the home is up, every book close, and after each
weather or cover arrival. The data changes only when the Statistics plugin writes (close, save,
suspend: `plugins/statistics.koplugin/main.lua:2672-2695` at `e1fe1ac`) or when the day rolls over.

Memoise both results in `reading_stats.lua`, keyed on the local date plus the size and mtime of
`statistics.sqlite3` and `statistics.sqlite3-wal`, and additionally on the book's md5 for
`seconds_per_page`. Open one connection when both miss. Keying on the files is exact invalidation, so
no reading can go stale.

## Why

Two SQLite opens and five statements on the Kindle's flash and ARM core, per wake and per book close,
whose cost grows with the owner's reading history, to recompute numbers that have not changed.

## Done when

- A unit spec counts `SQ3.open`: a second `read` with the database and WAL file untouched opens
  nothing; a touched `-wal` file or a date past midnight opens again; a busy database still returns the
  last reading. The spec fails on the current code.
- `seconds_per_page` for the same md5 with the files untouched opens nothing.
- `bin/check` is green and the home goldens are unchanged.
