# Date and clock widgets in both looks

## Approach

1. `kopanda.koplugin/widgets/date.lua` and `widgets/clock.lua`, registered in `widgets.lua` and required
   from `main.lua`.
2. **Date.** The weekday and month come from `datetime.shortDayOfWeekToLongTranslation[os.date("%a", t)]`
   and `datetime.longMonthTranslation[os.date("%B", t)]` (`frontend/datetime.lua:54-62`, `:29-42`). The day
   is `tonumber(os.date("%d", t))`, with no leading zero. `t` is `ctx.now`.
   - Both looks declare `type.date_label`; Diner's is never drawn.
   - Editorial: a `VerticalGroup` of the weekday in the label style (`type.date_label`: text face, 11,
     uppercase, tracking 0.14, `muted`; Main:21) over "October 13" (`type.date`: display, 36, line height
     1, `ink`; Main:22), with a 2 px gap (Main:20).
   - Diner: one `TextWidget`, "Tuesday, October 13" (`type.date`: strong, 16, uppercase, tracking 0.04,
     `on_band`; HomeRetro:22).
   - Left-aligned.
3. **Clock.** `G_reader_settings:isTrue("twelve_hour_clock")` (`frontend/datetime.lua:298-300` reads
   it the same way).
   - On: `(hour % 12 == 0 and 12 or hour % 12) .. os.date(":%M", t)`, so "8:42" with no AM/PM, as both
     boards draw it (Main:26, HomeRetro:24).
   - Off or unset: `os.date("%-H:%M", t)`, so "8:42" and "20:42", as KOReader formats the 24-hour time on
     Linux and Kindle (`frontend/datetime.lua:262-264`; the `%H` form at `:224-236` is the Windows
     branch).
   - `type.clock`: Editorial display, 36, `ink`; Diner display, 56, line height 0.9, tracking −0.02,
     `on_band`.
   - Right-aligned in its column, its baseline bottom-aligned with the date's last line (Main:19
     `align-items: flex-end`).
4. **Case and tracking.** Uppercase (the token's `uppercase = true`) is applied with `string.upper` on the
   translated string, since the
   fixed strings are ASCII in English. Tracking: KOReader's `TextWidget` has no letter spacing. Open fact:
   determine whether tracking is drawn by per-glyph placement (a small `TextWidget` per character in a
   `HorizontalGroup`) or dropped. Measure the paint cost of per-glyph labels in the emulator, and choose
   per-glyph only if it costs under 5 ms per label. Record the choice in `HOOKS.md` only if a KOReader
   internal is read.
5. Both widgets' `height(width, ctx)` measure their built widget's height (build once and cache per
   width/ctx). Neither has `tap`.
6. Fill in the `type.date_label`, `type.date` and `type.clock` tokens in both looks, with each value's
   board line in a comment.

## Surfaces

`kopanda.koplugin/widgets/date.lua`, `widgets/clock.lua` (new), `widgets.lua`, `main.lua`,
`looks/editorial.lua`, `looks/diner.lua`, `HOOKS.md` (`datetime` tables, `twelve_hour_clock`);
`spec/unit/date_clock_spec.lua` (new).

## Tests

Written first and run failing.

- `date_clock_spec.lua` (C5):
  - At `t` = 2026-10-13 08:42 local (with `TZ` set in the spec's environment), Editorial's date texts
    are "TUESDAY" and "October 13". Diner's date string is "Tuesday, October 13" and is drawn as
    "TUESDAY, OCTOBER 13" (uppercased by the style). The spec asserts both the string and the drawn text.
  - On the 5th of a month the day reads "5".
  - The clock reads "8:42" at 08:42 both with `twelve_hour_clock` true and with it unset. At 20:42 it
    reads "8:42" with the setting true and "20:42" with it false or unset. Midnight reads "12:00" and
    "0:00".
  - Each built `TextWidget`'s face is the look's face file at `Layout.font_size(size, text_size)`, and
    its fgcolor is `Looks.color` of the role in the active variant.
  - `height` equals the built widget's height.
- `looks_spec.lua` keeps passing with the filled tokens.

## Edge cases

- `os.date("%a")` returns the C locale's English abbreviation, which is the key the translation tables
  use (`datetime.lua:44-62`). The spec asserts a lookup never returns nil for all seven days and twelve
  months.
- A narrow column (three columns at 1236 px): the date's longest line ("Wednesday, September 30" in
  Diner) is truncated with KOReader's `TextWidget` `max_width` ellipsis, never overflowing its column.
  The spec checks the built width is at most the column width.
