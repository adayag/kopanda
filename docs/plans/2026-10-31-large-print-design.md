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
- Today `text_size` scales only the home's text (`Layout.font_size`, factors 0.85, 1, 1.15). The nav
  bar, library, sheets, quick settings, series and authors screens and the editor ignore it.
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
| Type | `Layout.font_size` at Extra large multiplies by 1.4 after lifting any part under 14 tokens to 14. The floor is Extra large's alone. Every surface that sets type passes the text size: nav bar, library (header, tiles, pager), sheets, quick settings, series and authors, the editor screens. Outside the home's rows the step takes effect at Extra large only; Small, Medium and Large keep today's nav bar, title bar, library and shelf screens. |
| Icons and covers | A new `Layout.size_at(px, text_size)`, 1.4 at Extra large, 1 at every other step, no floor, used by the nav bar's icons, the launcher's icons, the sheets' covers, the quick-settings buttons and level bar, and the badges. Paddings, gaps and rules do not scale. |
| The featured row | The cover box keeps its size; at Extra large the row is as tall as the taller of the cover and its text column, so no line drops. Small, Medium and Large keep the cover's height and drop lines in a column too short, as today. |
| Default rows | Each rows key gets `defaults_by_text_size = { extra_large = … }`, pure data. Page 1: date and clock; featured; launcher. Page 2: date and clock; reading; streak and forecast. The settings reader falls back to it when nothing is stored and the text size has an entry; a stored layout wins. The studio's form, fit check and preview read the same table. |
| Free space | Unchanged. Editorial puts spare height before the last row, so the launcher sits by the nav bar. |
| Library paging | A page holds the rows that fit between the header and the pager, times the three columns, at least one row. Six at Medium on both devices, as today. |
| Library columns | Three, unchanged. |
| Editorial's contrast | In the grey palette: muted `#555555` to `#1a1a1a`, text `#444444` to `#111111`, hairline `#8c8c8c` to `#444444`, hairline_light `#d0d0d0` to `#8c8c8c`. The text face becomes IBM Plex Sans Medium. Outline stroke, quote rule, sheet row rule, progress bar and library strip go from one unit to two; the nav's active rule from three to four. Day and night palettes unchanged. Starting values; the owner judges them on the emulator and the device. |
| Editorial's captions | `tile_title` 12 to 16 tokens; `library_count`, `library_picker`, `library_picker_status` and `pager_label` to 14; `nav_label` and `nav_label_active` to 14; `nav.icon_size` 26 to 34. At every size. |
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
- `spec/unit/library_order_spec.lua`: pages hold rows that fit times three, at least one row.
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
that two library rows still fit with the taller captions.

## Out of scope

A fifth step; per-look default rows; scaling KOReader's own screens or the reader's text; darkening
Editorial's day and night palettes; a large-print variant of any other look's tokens; changing the
free-space rule.
