# Stats additions (2026-11-05)

Decided on 2026-11-05 with the owner. The Stats window grows from two pages to three. It gains a week-on-week line, a
headline on When you read, a Device tile and a wall of the year's finished books, ideas taken from the Reading Log
plugin (`stevenzamora1/reading-log`, `ab31f2d`). Reading Log is AGPL-3.0, so its ideas are reused and its code isn't.

Mockup: <https://claude.ai/artifact/SmCdGg5yWYgSwWiHFqngnZ>. Approved for layout; its numbers and covers are samples.

## Decisions

| Question | Decision | What lost |
|---|---|---|
| What to take | This week vs last, the When you read headline, Device, the cover wall | Trends and Longest reads, chosen against; rings, goals, styles, ornaments and pick-your-own cards, which need settings or aren't stats; cover calendar and month rings, as busy as the heatmap removed in `862b5689` |
| This week vs last | One line in the Reading tile | A tile with two bars: the chart's last two points already show the two weeks |
| Finished books | A cover wall | Books-per-month bars, since month labels and the count carry the same news |
| Finding finished books | KOReader's history, then each book's sidecar through `Books.with_progress` | Walking the library |
| Wall's span | The calendar year, resetting in January | The last 12 months |
| More covers than a page holds | Further pages named "This year" | Showing only the newest, since the window's rule is that fit loses nothing |
| Device readings | Battery with time left, storage free and the memory KOReader uses | Wi-Fi and the light, already in Quick Settings; dropping battery, or a bare percent that repeats Quick Settings (`quick_settings.lua:103`) |
| Device freshness | Read when the window builds and on wake | Reading Log's once a minute, which would need a timer |
| Window names | "last 12 weeks" and "last 12 months" throughout | "last 90 days" and "last year", the same spans under other names |
| Tiles in a row | Same height | Each tile its own height |
| Taps | Stats stays read-only | Opening a book from its cover |

## What the reader sees

- **Page 1, Now.** Reading with the week line under a rule, Streak beside Finish by, then Device.
- **Page 2, Habits.** When you read beside Sessions, then the 12 month bars.
- **Page 3, This year.** The wall under the label "Finished" with the count aside, 7 covers across on the Colorsoft.
  A month's name sits over its first cover, oldest first. A cover not yet cached shows the library's placeholder.
- **Fit.** Rows still flow by fit. Habits takes no `page` mark, so a small screen or a large text size keeps Device
  with Habits instead of alone on a page. Only the wall always starts a page. Medium is 3 pages, Large 4 and Extra
  large 5, on the Colorsoft and the Paperwhite. A page's header names its first row, so the page Device starts at
  Large reads "Now" above When you read.

## The rules

### Week line (`widgets/reading.lua`)

- Weeks run Monday to Sunday, as `row_of` already counts them.
- This week's average is over the days gone by. Today joins once it lifts the average, so a morning doesn't drag it
  down. Last week's is over its 7 days.
- Compared in whole minutes: "16 min a day, up from 9 last week", "down from", or "same as last week".
- Monday before any reading: "9 min a day last week". Nothing either week: "Nothing read this week or last".

### Headline (`widgets/hours.lua`)

- The busiest of four parts of the day, by the share of its hours in the bars' reading: Morning 05–12, Afternoon
  12–17, Evening 17–22, Night 22–05.
- "Evenings" over "62% of your reading, peak 20:00", the hour in the captions' clock format.
- A tie goes to the earlier part. With no reading, the tile stays as it is today.
- When the caption won't fit whole it reads "98%, peak Midnight". `Typeset.fitted` can't step it down: the caption's
  size is already under its floor.
- `HOUR_DAYS` goes from 90 to 84, so the tile reads "last 12 weeks".

### Finish dates (`reading_stats.lua`, a new `finished_books.lua`)

- `summary.modified` isn't only a finish date: any save of the summary rewrites it, a rating or a note on a finished
  book included (`frontend/apps/filemanager/filemanagerutil.lua:111`, `filemanagerbookinfo.lua:748`, `:778`;
  `frontend/apps/reader/modules/readerstatus.lua:215`).
- So a book's finish day is its last Statistics reading day on or before `summary.modified`, or that date when
  Statistics has none. One query reads the year's reading days per book md5, memoized on the files' stamp as
  `insights` is.
- A book counts when its status is `complete` and its finish day falls in `now`'s year.
- Books leave the list with their files: `Books.for_path` needs the file, though the history keeps an entry for a
  deleted one (`frontend/readhistory.lua:25-35`). The history holds 500 books by default (`:81-86`).
- A book marked finished without being opened isn't in the history, so it isn't counted.

### Device (`widgets/device.lua`)

- Battery from `QuickSettings.battery()`, the value over "about 3 days left", or hours under a day.
- Time left comes from KOReader's Battery statistics, which saves running totals to `settings/battery_stats.lua`
  (`plugins/batterystat.koplugin/main.lua:17`), `discharging` among them, a percentage and a time (`:44-47`,
  `:138-147`). It is the current percent over that rate, as the plugin works it out (`:69-73`). The file is opened
  read-only and never flushed, and its values are checked as a file from outside, so this read takes the full review.
- The caption falls back to "battery" while charging, with under an hour of discharging on record, or when the file
  is missing or malformed. Under an hour is this design's guard against a wild estimate from a fresh count.
- The figures lag by up to one of the plugin's flushes. Assumption, checked against the Kindle's Battery statistics
  screen at the manual check: the saved `discharging` rate gives a sensible figure on the device.
- Storage from `util.diskUsage` on the home folder (`frontend/util.lua:925`), written with `util.getFriendlySize`
  (`:1057`).
- Memory from `VmRSS` in `/proc/self/status`. The emulator on macOS has no `/proc`, so a reading that can't be had
  drops out and the rest fill the row.

### Same height

`flow` knows each row's height. The tiles are built with that height in a `ctx` copy, and `InsightTile.compose` grows
its content box to reach it. Measuring and building use different `ctx` tables, so `Typeset.measured` builds twice for
a row. The paint budget judges whether that matters.

### Wall (`widgets/wall.lua`)

- Reads covers with `BookCovers.read`. Missing ones go through `BookCovers.request`, with the window repainting on
  arrival as the library does (`library_covers.lua`).
- `stats_screen.lua` asks the wall how many pages it needs, and repeats its row once per page. Wall rows aren't
  measured, since each has a page to itself: measuring would read every page's covers on the first paint of page 1.
- The finished list is read once per flow, and again on wake. On the Colorsoft a wall page holds 3 rows of 7.
- Stats' window holds the bitmaps and frees them, as the home's featured cover does.

## Failure

Every read stays guarded, as today's tiles are: a tile that fails to measure or build is logged and leaves its slot
blank. Statistics off shows the existing "Reading stats are off". With no finished books the wall reads "Nothing
finished yet this year". A cover that can't be read stays a placeholder.

## Testing

- Unit: the week line at Monday, mid-week, the same minute, and a today that does and doesn't lift the average; the
  headline's part edges and tie; finish days for a rating saved after the finish, no Statistics rows, and either side
  of New Year; the wall's rows and pages at the page's edge; `VmRSS` parsing, with and without the line; time left
  from a real `battery_stats.lua` shape, either side of the hour, at zero, while charging, and from a malformed file.
- Emulator: `stats_screen_capture_spec.lua` moves to three pages on the Colorsoft and the Paperwhite, and adds a wall
  fixture with finished books. The wall goes under the paint budget (250 ms).
- By eye: the owner, on the emulator and the Kindle.

## Size

About 1.5 days and 2 hours. The wall and its finish dates are about 1 day, battery's time left about 2 hours.
