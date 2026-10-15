# Reading stats from KOReader's Statistics database

## Approach

1. **Schema.** Add `stats.show` (type `boolean`, default `true`, label "Show reading stats", group
   `stats`) last. Add the `boolean` validator to `Settings.validators`: `type(value) == "boolean"`.
2. **`kopanda.koplugin/reading_stats.lua`** (module name checked against KOReader's and the bundled
   plugins' module paths by `hooks_doc_spec.lua`):
   - `ReadingStats.read(now)` returns `{ state = "off" | "empty" | "ok", streak, minutes_today,
     books_month, month_name }`.
   - **Off:** `G_reader_settings:readSetting("plugins_disabled")` has `statistics = true`
     (`frontend/pluginloader.lua:175`, `:210-216`), or `G_reader_settings:readSetting("statistics")` is
     a table with `is_enabled == false` (`plugins/statistics.koplugin/main.lua:61`, `:85`, `:143`). Both
     are read without a default (`frontend/luasettings.lua:89-99`).
   - **Empty:** no file at `DataStorage:getSettingsDir() .. "/statistics.sqlite3"` (`main.lua:27`;
     checked with `util.fileExists`, as `frontend/ui/data/onetime_migration.lua:620` does), or a streak of 0 with 0 minutes today.
   - Otherwise it opens the file with `SQ3.open(path, "ro")` (`require("lua-ljsqlite3/init")`,
     `main.lua:13`; `base/thirdparty/lua-ljsqlite3/init.lua:325-345`) inside `pcall`, runs three queries
     and closes the connection. Any error is logged and reads as empty. Results go through `tonumber`.
   - Local-day bounds are computed in Lua from `os.date("*t", now)`, so the spec's frozen time controls
     them:
     - **Today's start:** `os.time{ year, month, day, hour = 0 }`.
     - **Month start:** the same call with `day = 1`.
     - **Minutes today:** `SELECT coalesce(sum(duration), 0) FROM page_stat_data WHERE start_time >= ?`
       with today's start, divided by 60 and floored.
     - **Books this month:** `SELECT count(DISTINCT id_book) FROM page_stat_data WHERE start_time >= ?`
       with the month start.
     - **Streak:** `SELECT DISTINCT date(start_time, 'unixepoch', 'localtime') FROM page_stat_data WHERE
       start_time >= ? ORDER BY 1 DESC`, bound to 400 days before today's start. The walk happens in Lua
       from today, or yesterday when today is absent, counting consecutive dates. `'localtime'` in SQLite
       uses the process `TZ`, the same as `os.date`.
3. **Freshness, an open fact to settle first.** In the emulator, with a seeded database, open a fixture
   book, turn pages for more than `min_sec` each (5 s by default, `main.lua:29`), close it, and check
   whether the pre-built home's minutes include the session. Statistics flushes on `CloseDocument`
   (`main.lua:2672-2675`), and KoPanda pre-builds on the same event, so which runs first depends on plugin
   order. If the session is missing, the widget reads its numbers in a `refresh` called from
   `Home.take_pending` instead of in `build`. Record the outcome and the evidence in the PR.
4. **`kopanda.koplugin/widgets/stats.lua`**, registered and required from `main.lua`:
   - `stats.show` false: `height` 0, `build` returns an empty widget of the column width and height 0.
   - Parts, built from `read`:
     - ok: streak, today, month;
     - empty: "No streak yet", "0 min today", "Read something and this fills in";
     - off: the single part "Reading stats are off".
   - Wording per look, from the feature's table:
     - Editorial: "Streak 4 days" or "Streak 1 day", "23 min today", "3 books in October" or "1 book in
       October". The month name comes from `datetime.longMonthTranslation` (`frontend/datetime.lua:29-42`).
     - Diner: "4-day streak", "23 min today", "3 books in October", joined by " · ".
   - Layout. Editorial spreads the parts across the column with equal free space between them (Main:87,
     `justify-content: space-between`); one part is left-aligned. Diner draws one right-aligned line.
     `type.stats`: Editorial text face, 12, uppercase, tracking 0.08, `muted`; Diner `strong`, 13,
     uppercase, tracking 0.06 (the strip's, HomeRetro:47), `ink` (HomeRetro:52).
   - Fit: drop trailing parts while the line is wider than the column. If the first part alone is too
     wide, truncate it with an ellipsis.
5. `HOOKS.md` gains `lua-ljsqlite3`, the Statistics database path, `page_stat_data` and its columns, the
   `statistics` settings table and `plugins_disabled`.

## Surfaces

`kopanda.koplugin/schema.lua`, `settings.lua`, `reading_stats.lua` (new), `widgets/stats.lua` (new),
`widgets.lua`, `main.lua`, `home.lua` (only if the freshness check needs the show-time read),
`looks/editorial.lua`, `looks/diner.lua`, `HOOKS.md`; `spec/unit/reading_stats_spec.lua` (new),
`spec/unit/schema_spec.lua`, `spec/unit/settings_spec.lua` (boolean refusals).

## Tests

Written first and run failing.

- `reading_stats_spec.lua` (C7):
  - Fixture databases are built in the spec with the plugin's exact `page_stat_data` and `book` DDL
    (`main.lua:405-419`, `:462-480`) and `PRAGMA user_version = 20221111` (`:35`), under the spec's
    `KO_HOME`, with `TZ` fixed.
  - Cases: 23 min today (1380 s split across rows, plus 59 s more to prove the floor); a 4-day streak
    ending today; the same history read the next morning before any reading (streak still 4); a gap
    two days ago (streak resets); reading 401 days ago only (streak 0); three books this month and one
    last month (3); a missing file (`empty`, and the file still doesn't exist afterwards); `plugins_disabled`
    and `is_enabled = false` (`off`); a corrupt file (`empty`, logged).
  - Wording, singular forms and the per-look join. The fit drops parts at a narrow width and keeps the
    first.
  - `stats.show = false` gives height 0.
  - Note from the spike: KOReader's `readerfooter_spec.lua:86-87` calls lj-sqlite3 "horribly broken
    under Busted". A plain on-disk fixture worked in seven runs through `bin/check` on 2026-10-14. Keep
    every SQ3 use in this one spec file, and require the binding once per file
    (`spec/emulator/driver.lua:87-88` records the once-per-process limit).
- `settings_spec.lua` gains the boolean refusals (C2), and `schema_spec.lua` gains `stats.show`.

## Edge cases

- The journal mode is WAL where `canUseWAL` is true (`main.lua:455-460`): the emulator and current
  Kindles, which inherit `yes` (`frontend/device/generic/device.lua:131`). Only the Kindle 2 and DX
  classes say `no` (`frontend/device/kindle/device.lua:931`, `:946`). A read-only open works under WAL;
  the spike verified it.
- The Statistics plugin may be flushing while the home reads. A read-only reader can still hit
  `SQLITE_BUSY` at a checkpoint or under TRUNCATE. A busy error reads as the previous numbers if
  the home already has them, and as empty otherwise. It is logged, never raised.
- A query over 400 days of `page_stat_data` on a Kindle: the `start_time` index bounds it. The goldens
  task measures the fresh-build paint time with the fixture history, and C10 holds it.
