# Rows and columns with date, clock, weather, quote and stats

## Summary

The home screen's layout engine and its text widgets. Rows of one to three columns, laid out at runtime
from the screen's size through `Screen:scaleBySize` (direction doc "Screens"), drawing every visual value
from the active look. The widgets that need no book: date, clock, weather, quote, reading stats.

## Behavior

- The layout section of the settings (rows, each with slots and width shares) becomes a vertical stack
  of rows filling the screen width; a row's columns take their shares. A row that would not fit the
  height budget is refused at edit time, never paged (design §1b).
- Widgets are tables with `id`, `build(width, ctx)`, `height(width, ctx)` and a settings prefix.
- Date and clock follow the look's display face; the clock follows KOReader's own 12-hour clock setting.
- Weather shows the cached line, with its age once it is old; it fetches once per KOReader session when
  connected and on tap, from Open-Meteo, with the location stored as coordinates (design §1b); with
  nothing cached it shows "Weather needs Wi‑Fi" (direction doc "First run and failures").
- Quote draws from a shipped public-domain file; "My highlights" is a later source.
- Reading stats reads KOReader's Statistics database for streak, minutes today and books this month;
  with the plugin disabled it says so; with nothing read it shows the empty wording.
- Goldens for both looks on both profiles; a paint-time budget asserted from `dev-loop`'s measurement.
- The screen redraws only on input.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac` (`base/` is
the koreader-base submodule in that checkout). Canvas references are to
`.tiller/design/2026-10-13-kopanda-screens/<board>.dc.html:<line>`; sizes are board pixels, which the
looks already use. `looks-and-schema` is cited from its feature review branch
`tiller/reviews/features/home/looks-and-schema` (head `d56bc42`), since it is in review: `schema.lua`,
`settings.lua`, `looks.lua`, `looks/*.lua`, `fonts.lua`, `icons.lua`. This feature starts after it merges.

### Keys

Six keys enter the schema with this feature, after `look`, in this order. Each was confirmed by the owner
on 2026-10-14. `schema.version` stays 1: every key is new and has a default, which needs no migration
(`looks-and-schema` "Settings"; `migrations.lua` is empty).

| Key | Type | Default | Group | Why it exists |
|---|---|---|---|---|
| `text_size` | choice `small` Small, `medium` Medium, `large` Large; label "Text size" | `medium` | `appearance` | One type scale for every widget (direction doc "Schema consequences"). |
| `layout.rows` | rows; label "Layout" | see "Default layout" | `home` | Edit layout and the studio's row editor write it. |
| `weather.location` | location; label "Weather location" | `{ name = "Chicago, Illinois", latitude = 41.85003, longitude = -87.65005 }` | `weather` | The owner's place. Another household member's device may be elsewhere. |
| `weather.units` | choice `fahrenheit` Fahrenheit, `celsius` Celsius; label "Units" | `fahrenheit` | `weather` | The owner reads °F. |
| `quote.source` | choice `builtin` Built-in; label "Quote source" | `builtin` | `quote` | The owner wants the source to be switchable. "My highlights" adds its values when it ships; adding a choice value needs no migration. |
| `stats.show` | boolean; label "Show reading stats" | `true` | `stats` | Hides reading stats without editing the layout. |

- The default location is what Open-Meteo's geocoding returned for `name=60612&countryCode=US` on
  2026-10-14: Chicago's city record (geonames 4887398), whose `postcodes` list holds 60612. Open-Meteo
  resolves a ZIP to the city that lists it, not to the ZIP's own centroid.
- No `clock.twenty_four_hour` key. The clock follows KOReader's own `twelve_hour_clock` setting
  (Settings › Time and date › 12-hour clock, `frontend/ui/elements/common_settings_menu_table.lua:76-89`;
  unset means 24-hour, the way `frontend/datetime.lua:298-300` reads it). KOReader broadcasts
  `TimeFormatChanged` when it is flipped (`common_settings_menu_table.lua:87`). Owner-approved, 2026-10-14.
- Three types are new, each a validator in `settings.lua`'s `Settings.validators`
  (`settings.lua:18-27` on the review branch):
  - `boolean`: `true` or `false`.
  - `location`: a table with a non-empty string `name`, a number `latitude` from −90 to 90 and a number
    `longitude` from −180 to 180, and no other fields.
  - `rows`: a list of one or more rows. A row is a list of one to `max_columns` slots. A slot is
    `{ widget = <id>, share = <integer 1–3> }`, and `widget` is one of the entry's `widgets` list. No
    widget appears twice in a layout. The schema entry carries `widgets` and `max_columns = 3` as data,
    so the schema stays pure data and later features (`featured-book`, `launcher`) add their ids to
    `widgets` and their rows to the default.
- A stored value the validator rejects reads as the schema default, as every key does today
  (`settings.lua:83-103`).
- `Settings.set` checks its write by reading the file back and comparing `data[key] == value`
  (`settings.lua:136-140`), which is never true for a table read back from disk. The check becomes a
  deep comparison, so `layout.rows` and `weather.location` can be written.
- Guidance about the device menus and the studio form for these keys belongs to `device-menus` and
  `settings-form`: typing a place and geocoding it, the edit-layout screen and its height budget. This
  feature exposes the functions those screens call (`Layout.fits`) and stores coordinates only.

### Default layout

Owner decision, 2026-10-14: one default for both looks. Weather and stats share the last row, the
strip Diner's board draws (HomeRetro:47-53).

```lua
default = {
    { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
    { { widget = "quote", share = 1 } },
    { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
}
```

`featured-book` inserts its row after the header and `launcher` inserts its row before the strip, which
gives the direction doc's order (direction doc "Layout"; EditLayout:35-95).

### The row engine

- `kopanda.koplugin/layout.lua` holds the pure layout maths, with no widgets and no KOReader UI
  requires, so it is unit-tested alone:
  - **Columns.** A row's content width is split by its slots' shares, with the look's column gap
    between columns. Each column gets `floor(available × share / total_shares)`, and the last column
    takes the remainder, so the widths and gaps sum exactly to the content width.
  - **Rows.** Rows stack from the top margin, with the look's row gap between them. Each row's height is
    the tallest of its widgets' `height(width, ctx)` at their column widths, plus the row's chrome (the
    header style for row 1). A row whose height is 0 takes no gap. The look says where the free height
    goes (`home.free_space`): Editorial puts it before the last row, so that row sits on the bottom margin,
    because its stats row has `margin-top: auto` (Main:87). Diner puts it before its footer stripe, so
    the rows stay together under the header, because the stripe carries the `margin-top: auto`
    (HomeRetro:82).
  - **Overflow.** If the rows' total height exceeds the screen's height minus the margins, rows are
    dropped from the end until the rest fit, and each dropped row is logged. The home is never paged and
    never scrolls. This is the runtime fallback for a layout written for a taller screen or for landscape;
    edit time refuses such a row through `Layout.fits(rows, ctx)`, which `device-menus` calls.
  - All lengths are look tokens in board pixels, scaled by `Screen:scaleBySize`
    (`base/ffi/framebuffer.lua:414-425`). Font sizes go to `Font:getFace` unscaled, because it scales
    them itself (`frontend/ui/font.lua:276`). `text_size` multiplies every widget's font size by 0.85
    (small), 1 (medium) or 1.15 (large), rounded to an integer. It does not change margins, gaps or
    strokes.
- `kopanda.koplugin/widgets.lua` is the registry: a widget id maps to its module under
  `kopanda.koplugin/widgets/` (`date`, `clock`, `weather`, `quote`, `stats`). A widget module returns
  `{ id, settings_prefix, height(width, ctx), build(width, ctx), tap(ctx)? }`:
  - `ctx` carries the active look, the palette variant (`Looks.variant()`), the text scale, the current
    time, the screen and the home widget itself (so `tap` can refresh it).
  - `build` returns a KOReader widget exactly `width` wide.
  - `tap`, when present, is what a tap inside the slot does.

  Featured book and launcher register the same way later.
- `home.lua` replaces the placeholder: `Home:init` reads `layout.rows` and the active look and builds
  the rows. If a slot names an id the registry doesn't hold (a layout written by a newer plugin), the
  slot is left blank and logged. If a widget's `height` or `build` raises, its slot is left blank, the
  error is logged and the rest of the home still shows. The home's own fail-safes from `plugin-shell`
  (build, paint and gesture errors close the home over a usable file browser) stay as they are.
- **Chrome.** Two token blocks join both look files under the same paths, `home` and `type`, with
  values from the canvas. They keep the look files' token rules (`looks_spec.lua:151-174` on the review
  branch): a colour is a palette role named in a key ending `_color`, widths are numbers, and case is
  the boolean `uppercase`, as `label` has it.
  - `home`: page margins, row gap, column gap, `free_space` (`"before_last_row"` or
    `"before_footer"`), the header style (row 1) and the footer style. Editorial's header is the main rule
    under row 1, `rule_color = "ink"` at `stroke.rule`'s width, 22 px above and below (Main:30). Diner's
    header is a full-bleed band, `band_color = "band"`, with a 4 px `ink` bottom edge and padding 36/40/28,
    its text in `on_band` (HomeRetro:19). Editorial has no footer. Diner's is the decorative stripe at
    the foot: 22 px of 2 px ink lines every 10 px on paper, under a 4 px ink edge (HomeRetro:82).
  - `type`: per widget part, `{ face, size, uppercase, tracking, line_height, color }`, with face a face
    role and colour a palette role. Both looks declare every part, including parts only one look draws
    (Editorial's `date_label`), so the paths stay identical.

  Diner's header text needs a colour the palettes don't have (paper on the band), so each palette gains
  the role `on_band`: Diner day `#f5f1e6`, night `#f1ece0` (NightC:19), grey `#111111` (PWRetro:19);
  Editorial `false`. In grey it equals `ink`, which `looks_spec.lua:138-149` (roles that differ by day
  stay distinct in grey) would refuse. `on_band` is exempt by name there, because it is chosen for
  contrast against the band, not to tell roles apart. A face role, `strong` (Bricolage Grotesque 700; IBM Plex Sans Medium for Editorial),
  and `quote` (Newsreader 16pt Medium Italic; Bricolage Grotesque Medium for Diner) join `faces`. All the
  files are already shipped. `looks_spec.lua`'s identical-paths invariant covers the new tokens.
- **Taps.** A tap inside a slot whose widget has `tap` runs it. A tap that no widget acts on keeps the
  placeholder's interim behaviour and closes the home onto the file browser. This lasts until `sheets`
  gives the home "Open the file browser" (direction doc "Hold on empty space"); `sheets` removes it.
  Gesture routing is otherwise unchanged: the swipe up, the top menu zones, the consumed page swipe and
  the forwarding to the file manager's zones keep their order (`home.lua:279-312`). A tap's step runs only
  where `plugin-shell`'s tap close ran.
- **Redraws.** The home rebuilds its rows and repaints in three cases:
  - on `Resume`, broadcast to every window-level widget on wake (`frontend/device/generic/device.lua:1125`,
    `frontend/ui/uimanager.lua:1042-1061`), so the date, clock and stats are current when the reader picks
    the device up;
  - on `TimeFormatChanged`;
  - after a weather fetch.

  It schedules no repeating task. The clock shows the time of the last redraw, as an e-ink clock does
  under the project's no-timer rule.

### Date and clock

- Formats are US English, from KOReader's translation tables so they follow its language
  (`frontend/datetime.lua:29-42` month names, `:54-62` long day names):
  - Editorial's date is two lines: the weekday as a label ("TUESDAY", the look's label style) over
    "October 13" in the display face at 36 (Main:21-22).
  - Diner's date is one line, "Tuesday, October 13", in `strong` at 16, uppercase, tracking 0.04 em,
    `on_band` (HomeRetro:22).
  - The day has no leading zero and there is no year.
- The clock is right-aligned in its column, bottom-aligned with the date. It uses `display` at 36 in
  Editorial (Main:26) and `display` at 56 in Diner, line height 0.9, `on_band` (HomeRetro:24). With
  `twelve_hour_clock` on it reads "8:42", with no leading zero and no AM/PM, as both boards draw it. Off,
  it reads "20:42", or "8:42" in the morning (`%-H:%M`, as KOReader formats the 24-hour time on
  Linux and Kindle, `datetime.lua:262-264`).

### Quote

- `kopanda.koplugin/quotes.lua` is pure data: an ordered list of at least 60 entries
  `{ text, author, work, source }`.
  - `source` names a public-domain edition the text appears in verbatim: a Project Gutenberg ebook
    number, or a Wikisource page, of a work published before 1931.
  - Each `text` is at most 160 characters, so it fits four lines in a full-width row at `large`.
- The quote of the day is entry `(local days since 1970-01-01) mod count + 1`, so it changes at local
  midnight, is stable through the day and is deterministic in a golden.
- Drawn in curly quotes with no attribution, as the boards draw it (Main:56-57, EmptyStates:43). At most
  four lines; a longer text ends in an ellipsis.
  - Editorial: the `quote` face at 18, line height 1.4, `ink`, between `hairline` rules with 18 px
    padding (Main:56). KOReader's `TextBoxWidget` counts line height as extra space in em
    (`frontend/ui/widget/textboxwidget.lua:48`, `:151`), so CSS 1.4 is `line_height = 0.4`. Its
    `height_overflow_show_ellipsis` (`:54`) gives the four-line cap.
  - Diner has no board with a quote, though the direction doc says both looks show it (direction doc
    "Widgets", "Layout"). It draws the quote in the `quote` face at 18 inside the look's tile: a `paper`
    box with an `outline` stroke and the tile's hard shadow (`looks/diner.lua` `tile`, `shadow.tile`).
- `quote.source = builtin` is the only source; the widget reads it so "My highlights" plugs in by value.

### Reading stats

- `kopanda.koplugin/reading_stats.lua` reads `<settings dir>/statistics.sqlite3`
  (`plugins/statistics.koplugin/main.lua:27`). It opens the file read-only through
  `require("lua-ljsqlite3/init")` (`main.lua:13`; `SQ3.open(path, "ro")`,
  `base/thirdparty/lua-ljsqlite3/init.lua:325-345`), only when the file exists, since an `rwc` open
  would create an empty file that later trips the plugin's "Cannot open database" path
  (`main.lua:292-317`). Integers come back as int64 cdata and go through `tonumber`.
- Off: the stats read "Reading stats are off" when `statistics` is in `G_reader_settings`'
  `plugins_disabled` (`frontend/pluginloader.lua:175`, keyed by folder name, `:210-216`), or when the
  plugin's own `G_reader_settings` table `statistics` has `is_enabled == false` (`main.lua:61`, `:85`,
  `:143`; when disabled it stops recording, `:188-192`, `:267`). Settings are read without a default argument,
  because `readSetting(key, default)` writes the default back (`frontend/luasettings.lua:89-99`).
- Three numbers, from `page_stat_data` (`main.lua:405-416`; `start_time` is `os.time()` epoch seconds,
  `:2584`; `duration` whole seconds, `:2604`), with days as local calendar days and no day-start shift
  (the plugin applies its shift only in its calendar, `main.lua:2786`, `:2824`):
  - **Minutes today:** the sum of `duration` since local midnight, divided by 60 and floored.
  - **Streak:** the count of consecutive local days with any reading time, ending today, or ending
    yesterday when nothing has been read yet today, so a streak doesn't read 0 until the evening. Only the
    last 400 days are scanned, through the `start_time` index (`main.lua:419`). A longer streak reads as
    400 days, an accepted ceiling.
  - **Books this month:** distinct `id_book` with any reading time since the first of the local month.
    That is the plugin's own meaning of "books read in" a month (`getBooksFromPeriod`,
    `main.lua:2079-2093`, titled at `:1858`).

  Raw `page_stat_data`, not the `page_stat` view, whose integer rescaling can come out seconds lower
  (`main.lua:422-451`). The plugin has already filtered out page views under `min_sec` and capped long
  ones before writing (`main.lua:2605-2620`).
- Freshness: the plugin flushes its in-memory page times to the database on `CloseDocument`
  (`main.lua:2672-2675`), which `ReaderUI:onClose` sends before the file manager returns
  (`frontend/apps/reader/readerui.lua:870-888`, `:935-941`). So the home that follows a book close counts
  that session.
  - Open fact for the `reading-stats` task: KoPanda's pre-build also runs from `CloseDocument`, and
    plugin order decides which handler runs first. Determine it in the emulator by closing a fixture
    book with a seeded database and checking that the pre-built home's minutes include the session.
  - If KoPanda's handler runs first, the stats widget reads its numbers when the pre-built home is shown
    (`Home.take_pending`), not when it is built. That keeps the paint budget, since the query is a few
    milliseconds.
- Wording is per look. Parts are listed in order and dropped from the end while they don't fit the
  column width. The first part always shows, ending in an ellipsis if it must.
  - Editorial: "Streak 4 days", "23 min today", "3 books in October", spread across the width with no
    separator, 12 px uppercase, tracking 0.08 em, `muted` (Main:87-91).
  - Diner: "4-day streak · 23 min today · 3 books in October", joined by " · ", 13 px `strong` uppercase,
    tracking 0.06 em (the strip's, HomeRetro:47), `ink`, right-aligned (HomeRetro:52). In the default half-width strip the books part is expected to
    drop, as on the board.
  - Singular forms: "Streak 1 day", "1-day streak", "1 book in October".
  - Nothing read (streak 0 and 0 minutes today, or no database file): "No streak yet", "0 min today",
    "Read something and this fills in" (EmptyStates:74-76; direction doc "First run and failures").
- `stats.show = false`: the widget draws nothing and its height is 0, so a row holding only stats
  collapses.

### Weather

- `kopanda.koplugin/weather.lua` fetches from Open-Meteo, keeps a cache, and gives the widget its line.
- **Request:**
  `https://api.open-meteo.com/v1/forecast?latitude=<lat>&longitude=<lon>&current=temperature_2m,weather_code,is_day&temperature_unit=<fahrenheit|celsius>&timezone=auto`.
  The response carries `current.temperature_2m`, `current.weather_code` and `current.is_day`
  (open-meteo.com/en/docs, read 2026-10-14; a live response was checked the same day). No key is needed.
  The service is free for non-commercial use, 10,000 calls a day (open-meteo.com/en/terms).
- **HTTP:** `socket.http` request with `socketutil:set_timeout(5, 10)` and `socketutil.table_sink`,
  `socketutil:reset_timeout()` on every path (`frontend/socketutil.lua:52-70`, `:98-115`; the pattern of
  `frontend/ui/wikipedia.lua:146-215`). `socket.http` handles `https` itself
  (`base/build/<target>/common/socket/http.lua:28-41`). The body is decoded with `rapidjson`, which
  returns nil and an error on bad input. `http.request` is looked up at call time, not cached in a local,
  so specs can stub it.
- **It blocks the UI thread.** A request normally takes about a second, and a dead network takes up to
  the 5 s block timeout plus an unbounded DNS lookup (`socketutil.lua:50-51`).
  - The fetch never runs before the home's first paint.
  - The upgrade path, if the freeze bites on the device, is `Trapper:wrap` with
    `dismissableRunInSubprocess` (`frontend/ui/trapper.lua:42-61`, `:500-680`). It is not built now.
- **When it fetches:**
  - Once per KOReader process. From the `nextTick` after the home's settled signal, when
    `NetworkMgr:isConnected()` is true (a cheap check with no prompt and no network I/O;
    `frontend/device/kindle/device.lua:523-524`) and no fetch has been attempted this process. Not
    `isOnline`, which is a synchronous DNS lookup (`frontend/ui/network/manager.lua:641-648`, `:348-354`).
  - From the home's `onNetworkConnected` (`manager.lua:109`, `:154`), when `isConnected()` is true and no
    fetch has succeeded this process. The handler returns nothing, so the broadcast reaches every listener
    (`frontend/ui/widget/container/widgetcontainer.lua:80-107`).
  - On a tap on the weather widget, always. When connected it fetches at once. Otherwise it calls
    `NetworkMgr:runWhenOnline(fetch)`, which may ask to turn Wi‑Fi on as the user's `wifi_enable_action`
    says (`manager.lua:605-618`, `:698-709`); a tap is the user asking, so the prompt is wanted. No other
    path prompts.
  - None of these schedules a repeating task.
- **Cache:** `settings/kopanda/weather.lua` through `LuaSettings`, holding `fetched_at` (`os.time()` at
  the fetch, not `current.time`), `temperature`, `weather_code`, `is_day`, `units`, `latitude` and
  `longitude`.
  - It is runtime state like `state.lua`: not a setting, no schema entry, never read by the studio. The
    `settings/kopanda/` directory is created before the flush, as `state.lua` does.
  - A cache whose units or coordinates differ from the current settings is not shown, so the location or
    units changed and the next fetch replaces it.
  - A failed fetch (timeout, nil headers, a non-200 status, undecodable JSON, missing fields) is logged
    and leaves the cache as it was. A tap that fails shows an `InfoMessage`, "Couldn't update the
    weather", for 3 s.
- **The line:**
  - Condition from the WMO code table (open-meteo.com/en/docs, "WMO Weather interpretation codes"),
    plain words: 0 "Clear", 1 "Mainly clear", 2 "Partly cloudy", 3 "Overcast", 45 and 48 "Fog", 51–57
    "Drizzle", 61–67 "Rain", 71–77 "Snow", 80–82 "Showers", 85–86 "Snow showers", 95–99 "Thunderstorm".
    An unknown code shows the temperature alone.
  - The temperature is rounded to an integer, then "°".
  - Editorial: "Partly cloudy, 61°" in the label style, `muted` (Main:25).
  - Diner: a 20 px icon, then "61° partly cloudy" in `strong` at 13, uppercase, tracking 0.06 em, `ink`
    (HomeRetro:48-51). The icon is `sun` when `is_day` is 1 and `moon` otherwise, reached by id through
    `Icons.path` (`icons.lua:57-64`; the night board draws the moon, NightC:48-50).
  - Age: once the cache is more than an hour old, " · 3 h ago" is appended (whole hours; " · 2 d ago"
    past 48 h). Under an hour, no age, as the boards draw it.
  - Nothing usable cached: "Weather needs Wi‑Fi", with U+2011 in Wi‑Fi (EmptyStates:25-26), in the same
    style.

### Goldens and the paint budget

- A capture fixture userpatch, `spec/emulator/scenarios/2-scenario-home-fixture.lua`, makes the home
  deterministic:
  - it freezes `os.time()` and `os.date()` with no time argument at 2026-10-13 08:42 in a fixed `TZ`
    (a Tuesday, the boards' date);
  - it stubs `NetworkMgr:isConnected` to false, so no fetch runs, neither after the show nor from the
    `NetworkConnected` that NetworkMgr broadcasts at start (`manager.lua:152-154`; the SDL emulator's own
    `isConnected` is always true, `frontend/device/sdl/device.lua:445-449`);
  - it writes a weather cache fetched 20 minutes earlier and a Statistics database with a known history
    (4-day streak, 23 minutes today, 3 books this month) before any plugin starts;
  - a variant leaves both out for the empty state.
- Goldens, each taken on `KoPandaSettled`, `screen = "home"`:
  - populated, both looks on both profiles (`home-diner-colorsoft`, `home-diner-paperwhite`,
    `home-editorial-colorsoft`, `home-editorial-paperwhite`);
  - empty, both looks on the Colorsoft (`home-empty-diner-colorsoft`, `home-empty-editorial-colorsoft`).

  The `home-placeholder` goldens and their spec are removed with the placeholder, and so is
  `book_close_spec.lua`'s check against them (`spec/emulator/book_close_spec.lua:45`), which captures with
  a live clock. The budget assertions in that spec stay.
- Paint budget, in the emulator on this Mac: a freshly built populated home's `paint_ms` (build start to
  first paint) is at most 250 ms on each profile. After a book close, `plugin-shell`'s budget still holds
  with the real rows: the file manager is never painted before the home's settled signal, the pre-built
  home is the one shown, and the home's share is at most 100 ms (`spec/emulator/book_close_spec.lua`).
  The 250 ms number is a regression tripwire on this Mac, not a device measurement.

### HOOKS.md

Every new KOReader surface goes into `kopanda.koplugin/HOOKS.md` with its `file:line`: `datetime`'s
tables, `twelve_hour_clock` and `TimeFormatChanged`, `Resume`, `NetworkMgr:isConnected`, `runWhenOnline`
and `NetworkConnected`, `socketutil`, `socket.http`, `rapidjson`, `lua-ljsqlite3`, the Statistics
database path, schema and settings, and `plugins_disabled`.

## Notes

Owner decisions, 2026-10-14:

- **Weather place and units:** ZIP 60612, °F, as the default `weather.location` and `weather.units`.
- **Weather placement:** one default layout for both looks, with weather and stats sharing the last row.
- **Keys:**
  - `weather.location`, `weather.units`, `text_size`, `stats.show` and `quote.source` enter now, with
    `layout.rows`.
  - The clock follows KOReader's `twelve_hour_clock` instead of a `clock.twenty_four_hour` key. That
    leaves the epic's schema at ten keys once `featured.pinned`, `launcher.entries` and `icons.pack`
    arrive with their features.

Defaults this spec writes in from the design, the canvas and the reads, without a question:

- **Quote in Diner:** the direction doc's same-widget rule wins over the Diner boards, which have no
  quote. It is drawn in Diner's tile.
- **Weather age:** shown on the widget only once the reading is over an hour old. The boards show no age
  (it appears only on the home sheet, HoldHome:52), while this feature's narrative promised it.
- **Stats:** three parts, dropped from the end to fit, which reproduces both boards. The streak
  tolerates a morning with nothing read yet.
- **Interim tap:** a tap no widget uses still opens the file browser until `sheets`. `plugin-shell`'s
  note said `home-layout` would remove it with the placeholder. Without it the emulator home has no way
  to the file browser before `sheets` and `launcher`.
- **Geocoding:** no geocoding here. Typing a place belongs to `device-menus`, which calls Open-Meteo's
  geocoding endpoint (`geocoding-api.open-meteo.com/v1/search`, with `countryCode` for ZIPs, since a bare
  ZIP also matches places abroad).
- **No greeting:** Diner's "Good morning, Allen" stays a candidate, not scope (direction doc
  "Candidates, not scope").

For the owner:

- Open-Meteo's data licence is CC BY 4.0 and asks for "Weather data by Open-Meteo.com" near where the
  data shows (open-meteo.com/en/licence). For an owner-only plugin nothing is published. This spec puts
  no credit on the home; `device-menus` can carry it in the weather group if wanted.
- The weather fetch freezes input for about a second after the home first paints on a connected
  device. This is accepted for now, with the subprocess fetch as the named upgrade.
