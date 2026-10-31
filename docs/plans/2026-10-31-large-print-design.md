# Large print (2026-10-31)

Decided on 2026-10-31 with the owner, for the older readers in the household on a Kindle Paperwhite
7th generation. Large print is a text size, not a look: the existing `text_size` setting gains an
Extra large step that scales the chosen look's type on every shell surface, and Editorial, the look
those readers use, gets darker greys and heavier lines at every size. Mockups rendered on the emulator
at the 7th gen's screen during the session (Editorial at Medium, at 1.4, with the contrast changes,
and with sparser rows and larger library captions) settled the values below; the owner judges the
final ones by eye.

The UI direction of 2026-10-13 still governs everything this doc does not change: the widget set, the
gesture vocabulary, native settings menus, and the rule that a look is a token table, not code.

## Why not new looks

Two large-print looks were considered first. A look reaches every surface through its tokens, but
picking one means picking a style, and switching look afterwards loses the size. A text size step works
with every look, present and future, and keeps the key count at zero. The cost is a scaling pass over
code deliberately kept at one size, and a look drawn at one size reading slightly off when scaled,
which the owner judges on the emulator.

## Facts

- A token size reaches the screen through `Screen:scaleBySize`, which multiplies by the shorter side
  over 600 (`base/ffi/framebuffer.lua:414-425`, no DPI override on the Kindles), and `Font:getFace`
  scales a size the same way (`frontend/ui/font.lua:276`). On a 1072 by 1448 panel the factor is 1.79
  at 300 dots per inch, so an 18 token part is 8 points on paper, a 12 token part 5. The 7th gen draws
  the same token 15 % smaller than the Colorsoft.
- Before this work `text_size` scaled the home's text, its sheets, quick settings and the editor
  (`Layout.font_size`, factors 0.85, 1, 1.15). The nav bar, title bar, library, series and authors
  screens ignored it.
- The home drops rows that do not fit (`Layout.place`). At 1.4 the default five rows lose the launcher
  and the weather row; at 1.5 the date beside the clock truncates.
- The library pages by a constant of six tiles (`library_order.lua`, `PER_PAGE`), not by height.
- The Paperwhite 7th generation (the 2015 Paperwhite 3) panel is 1072 by 1448 in portrait at 300 dots per
  inch, 16-level grey (MobileRead wiki, Kindle paperwhite 3; Wikipedia, Amazon Kindle devices). KOReader's
  device table confirms the DPI and frontlight (`frontend/device/kindle/device.lua:1023-1027`). Task 1 still
  checks the size the device reports.

## Decisions

| Topic | Decision |
|---|---|
| The step | `text_size` gains `{ value = "extra_large", label = "Extra large" }`. Small, Medium and Large keep their factors. No new schema key. |
| Type | `Layout.font_size` at Extra large multiplies by 1.4 after lifting any part under 14 tokens to 14. The floor is Extra large's alone. Every surface that sets type passes the text size: nav bar, library (header, tiles, pager), sheets, quick settings, series and authors, the editor screens. The nav bar, title bar, library, shelf screens and the sheets opened from them take the step at Extra large only; at Small, Medium and Large they are as they were. The home's rows, its sheets, quick settings and the editor follow every step, as before. |
| Icons and covers | A new `Layout.size_at(px, text_size)`, 1.4 at Extra large, 1 at every other step, no floor, used by the nav bar's icons, the launcher's icons, the sheets' covers, the quick-settings buttons and level bar, and the badges. Paddings, gaps and rules do not scale. |
| The featured row | The cover box keeps its size; at Extra large the row is as tall as the taller of the cover and its text column, so no line of a book's column drops; the first run's body still takes the lines that fit. Small, Medium and Large keep the cover's height and drop lines in a column too short, as today. |
| Default rows | Each rows key gets `defaults_by_text_size = { extra_large = … }`, pure data. Page 1: date and clock; featured; launcher; weather and stats. Page 2: date and clock; quote; reading; streak and forecast, so only hours and records leave the home. Page 1 fits every look on every device. Page 2 is more than Editorial and Riso hold at this size with a book in progress, and Toybox on the Colorsoft and the Paperwhite: there its last row drops under the home's own rule, the quote stays. The settings reader falls back to it when nothing is stored and the text size has an entry; a stored layout wins. The studio's form, fit check and preview read the same table. |
| Free space | Unchanged. Editorial puts spare height before the last row, so the launcher sits by the nav bar. |
| Library paging | The library grid and the one-author grid always hold two rows: where two rows of the look's cover height don't fit the room between the header and the pager, the cover is shortened to the tallest that fits, never below half the token height, the tile's other parts unchanged. A page is the rows that fit times the three columns, at least one row, so six everywhere; at Medium on both current devices the token cover fits and nothing changes. The cover request asks at the shortened box. |
| Library columns | Three, unchanged. |
| Editorial's contrast | In the grey palette: muted `#555555` to `#333333`, text `#444444` to `#222222` (ink stays `#111111`, and the three roles stay distinct, as the look spec demands), hairline `#8c8c8c` to `#444444`, hairline_light `#d0d0d0` to `#8c8c8c`, the cover's outline and shadow to `#444444`. The text face becomes IBM Plex Sans Medium. Outline stroke, quote rule, sheet row rule and library strip go from one unit to two. The progress bar's height and the nav's active rule stay: with them the home's default rows no longer fit at Medium on the Paperwhite, which Editorial's spacing was tightened to. Day and night palettes unchanged. Starting values; the owner judges them on the emulator and the device. |
| Editorial's captions | `tile_title` 12 to 16 tokens; `library_count`, `library_picker`, `library_picker_status` and `pager_label` to 14. At every size: at Medium on the Colorsoft the taller title shortens the library cover by 14 px under the two-rows rule. The nav label and icon stay: Extra large's floor and `size_at` grow them there, and growing them at every size pushes a default row off the Paperwhite at Medium. |
| The device | A `paperwhite7` profile, 1072 by 1448, 300 dots per inch, grey, in `studio/src/server/default-profiles.json` and `spec/emulator/profiles.lua`. `home_capture_spec.lua` captures every look on it by day, as it does the Paperwhite. |
| Goldens | None, per the rule. One new emulator capture, Editorial at Extra large on the 7th gen, asserts that no default row dropped on either page and that the pager sits below the grid's last tile. |

## Tests

Each written first and seen failing.

- `spec/unit/layout_spec.lua`: `font_size` at `extra_large` is 1.4 with the 14 floor; no floor at
  `large`; the three existing steps unchanged; `size_at` has the factor and no floor.
- `spec/unit/settings_spec.lua` and the schema specs: `extra_large` accepted; a rows key with nothing
  stored resolves to its Extra large default at that step and the plain default otherwise; a stored
  value wins. The studio's schema JSON and form tests cover the new choice and the per-step default;
  `npm run schema` regenerates `studio/src/schema.json`.
- Surface specs (`nav_bar_spec`, `library_tiles_spec`, `sheet_spec`, `quick_settings_spec`): the
  height at `extra_large` exceeds the height at `medium`.
- `spec/unit/library_order_spec.lua`: a page slices the count it is given. `spec/unit/library_screen_spec.lua`:
  pages hold rows that fit times three, at least one row; six at Medium on both devices in every look.
- `spec/unit/looks_spec.lua` keeps checking Editorial's token paths; the new values take no test.
- Emulator: the 7th gen in `home_capture_spec.lua`; the new Extra large capture; the paint budget
  unchanged; `bin/preview` on the 7th gen at Extra large as the smoke render.

## Tasks, in order

1. The 7th gen profile in the studio and the specs, checked against the size the device reports.
2. The Extra large step: schema choice, factor, floor, `size_at`.
3. The surfaces that ignore text size start taking it.
4. Per-step default rows: schema data, settings fallback, studio.
5. Library paging by height.
6. Editorial's contrast and caption sizes, judged by eye.

Each lands as its own commit on `main`, test first; no Tiller unless the owner asks.

## Device checks the owner does by hand

That Extra large in Editorial on the 7th gen reads as large print at arm's length; that the darker
hairlines do not read as rules; that the medium text weight does not fill in at 300 dots per inch;
that the shortened covers at Extra large, nearly square boxes with paper either side of a 2:3 cover, read well.

## Out of scope

A fifth step; per-look default rows; scaling KOReader's own screens or the reader's text; darkening
Editorial's day and night palettes; a large-print variant of any other look's tokens; changing the
free-space rule.
