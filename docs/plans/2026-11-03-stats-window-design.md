# Stats window (2026-11-03)

Decided on 2026-11-03 with the owner. The reading stats leave the home's second page for a window of their own
that pages by swipe, on the same window base as the book details page, and can take more pages later. The home becomes
one page.

## Decisions

| Question | Decision | What lost |
|---|---|---|
| Shape | A full-screen window on `LibraryChrome.Window`, the book details page's base, built as a top-level screen like Series | A panel over the home, chosen first, then dropped: it needed its own swipe code and could overflow the screen |
| Opening | A Stats tab on the nav bar, replacing Authors | A west swipe on the home; a launcher entry, built first by mistake and dropped |
| Launcher | Unchanged. Authors stays on it, its only way in now | Stats on the launcher |
| Home page 2 | Removed; the owner already has what it would hold on page 1 | A calmer non-stats page 2 |
| West and east swipes on the home | Consumed, and do nothing | Opening Stats |
| Layout | Today's page 2 arrangement, then the month bars, with rows flowing onto pages by fit | Three hand-set pages of full-width tiles: the five tiles fit one screen today, and half-width tiles stretch badly |
| Nav bar on the window | Yes, with the Stats tab lit and no back control | None, like book details, which sits under a book |
| Text size | Tiles honour Large and Extra large; the window's header, pager and nav bar stay at the shell's size | Large drawn at Medium, as other windows do, which would shrink the owner's stats |
| Frosted tiles | A box with the plate's keyline and radius | Plain labels on paper, since Frosted's tiles expect a plate behind them |
| Extra page | 12 month bars | The year heatmap, which the owner removed in `862b5689` (2026-10-23) as too busy on the panel |

## Facts

- `LibraryChrome.Window` gives a window its west and east page swipes (`library_chrome.lua:802-804`), the pager's
  arrows and count (`LibraryChrome.foot`), page keys, night mode and rotation rebuilds, and the
  settled signal. `Window:turn` stops at either end with no repaint (`:483-488`).
- `SeriesScreen` is the model for the list form: `LibraryChrome.header` with no `back_label`, then
  `LibraryChrome.foot(built, frame, "series")` for the pager and nav bar (`series_screen.lua:177-225`).
  `LibraryTiles.room` gives the height between the header and the pager (`library_tiles.lua:82-85`).
- `NavBar.run` closes a chrome window through `WINDOWS[where]` before going home, and `ACTIVE` maps a `where` to the
  tab it lights (`nav_bar.lua:35`, `:73-96`). The tabs are fixed in `NavBar.TABS`, not a setting, so a new tab reaches
  the Kindle with the update.
- `LibraryChrome.show` closes the home and shows the window, and `show_shelf` is the plugin's way in. A window that
  fails to build leaves the file browser up (`main.lua:233-238`).
- A hold on a window with no `hit` opens nothing (`library_sheets.lua:266-270`).
- `LibraryChrome.build`'s ctx has `look`, `variant`, `screen` and `text_size` (`Layout.shell_text_size`: nil except
  at Extra large). The window hands tiles their own copy, with the stored text size, `now` and `boxed`.
- `Typeset.on_plate` reads the look, so an insight tile in Frosted draws no chrome (`typeset.lua:164`,
  `insight_tile.lua:18`). `Paint.backing` and `Paint.outline` already take a radius (`paint.lua:38-51`).
- The home's row and column gaps are `look.home.row_gap` and `column_gap`. `book_status.section_gap` is twice Diner's.
- The home refreshes on wake (`Home:onResume`, `home.lua:113`). `LibraryChrome.Window` has no such handler.
- Today's page 2 holds all five tiles on one Colorsoft screen with about 200 px spare, under the home's header and
  above its nav bar (capture of 2026-11-03). Its Large default drops hours and records.
- `Typeset.measured` hands the tile `height` built to a `build` with the same width and ctx (`typeset.lua:301-329`).
- Hours and records have never shipped at Extra large, whose default drops them (`schema.lua:84-95`). Side by side
  there, their labels are cut off ("WHEN YOU…", "pages an h…").
- `ReadingStats.insights` holds 371 days ending today, enough for 12 whole calendar months, and memoizes its read.
- Authors is also a launcher default (`schema.lua`, `launcher.entries`), so it stays reachable off the nav bar.
- Settings reads only schema keys and `Settings.set` writes one key into the opened file, so a stored
  `layout.rows_2` stays in the file, unread. `schema.version` changes only when stored values change shape, so it
  stays 1 and no migration is needed.

## What the reader sees

- **Opening.** Tap the Stats tab on the nav bar, between Library and History. The window replaces the screen you were
  on, titled "Stats", with its tab lit. Tapping the tab on Stats goes to its first page.
- **Page names.** The line above the title names the page. A page takes the name of its first row: normally "Now"
  and "Over time", and "Habits" when hours and records start a page, as at Extra large.
- **Page 1.** Reading, then streak and forecast side by side, then hours and records side by side, as page 2 looks
  today, without the date and clock band.
- **Last page.** The month bars always start their own page, named "Over time", with room for later rows.
- **Fit.** A row that doesn't fit moves to the next page and the page count grows, so Extra large, Large on a smaller
  screen and landscape lose nothing. At Extra large, hours and records run full width so their labels aren't cut off.
- **Turning.** A west or east swipe, or the pager's arrows. At either end nothing changes and nothing repaints.
- **Leaving.** Any tab on the nav bar.
- **Waking.** A window left open over sleep reads the stats again on wake.
- **Read-only.** A tap or a hold on a tile does nothing.
- **The home.** One page. A west or east swipe does nothing, and still can't page the hidden file chooser.

## Month bars

`widgets/months.lua`: one bar per calendar month, this month last, labelled with month initials, in an insight
tile headed "Last 12 months" with the total time aside. Bars scale to the busiest month and draw in the bar colour;
only the busiest month takes the high colour, since a steady year would otherwise turn every bar solid ink. A month with any reading shows at least a sliver. With nothing read the aside says "Nothing
read yet"; with Statistics off it says "Reading stats are off". The tile isn't offered on the home.

## Failure

A tile that fails to measure or build is logged and its slot stays blank. A metadata event doesn't repaint the
window, whose tiles don't change with it. A window that fails to show leaves the
file browser up, as the Series window does.

## No new settings

No new key. Rows are one table in `stats_screen.lua`, so a later row is one entry there, and it flows to a page by itself.

## Out of scope

- Tapping or holding a tile.
- Removing the `key` parameters from `RowsEdit`, `rows-edit.ts` and the studio's layout-fit route. They mirror each
  other through shared fixtures, and taking them out changes no behaviour.
