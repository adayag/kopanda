# Row engine over layout.rows and text_size, with header and footer chrome

## Approach

The placeholder becomes a home built from rows. This task ships the engine, the keys it reads, the
registry and the look tokens, with no real widget yet. Its spec widgets are stubs; `date-clock` lands
the first real ones.

1. **Schema and validators.** In `kopanda.koplugin/schema.lua`, after `look`, add `text_size` (choice
   small / medium / large, labels Small, Medium, Large, default `medium`, group `appearance`) and
   `layout.rows` (type `rows`, group `home`, `widgets = { "date", "clock", "weather", "quote", "stats" }`,
   `max_columns = 3`, and the feature's three-row default). In `settings.lua`, add the `rows` validator to
   `Settings.validators` (review branch `settings.lua:18-27`). It returns false, never raises, for
   anything but:
   - a non-empty array of rows;
   - each row an array of 1 to `max_columns` slots;
   - each slot exactly `{ widget, share }`, with `widget` in `entry.widgets`, not repeated, and `share` an
     integer from 1 to 3.

   The validator is called inside `pcall` already (`settings.lua:116`), but `Settings.get` calls it
   without one (`:91`, inside the outer pcall at `:89`), so it must not raise on a malformed stored
   table. `schema.version` stays 1.

   `Settings.set` checks its write by reading the file back and comparing `data[key] == value`
   (`settings.lua:136-140`), which is never true for a table. Replace the comparison with a deep equality
   check (same keys, same values, recursively), so `layout.rows` and later `weather.location` can be
   written. The existing `look` cases keep passing.
2. **`kopanda.koplugin/layout.lua`**, pure functions, requiring only `device` for `Screen:scaleBySize`,
   injectable for the spec:
   - `Layout.columns(content_w, slots, gap)` returns `{ x, w }` per slot. Each slot gets
     `floor((content_w - gaps) × share / total)`, and the last slot takes the remainder.
   - `Layout.place(row_heights, avail_h, margins, row_gap, free_space, footer_h)` returns a y per kept row
     and the list of dropped row indexes. Rows stack from the top margin; a zero-height row takes no gap.
     With `free_space = "before_last_row"` and two or more rows, the last row's bottom sits on the bottom
     margin. With `"before_footer"` the rows stay together and the footer sits on the bottom edge. When the
     sum overflows, rows are dropped from the end until the rest fit.
   - `Layout.fits(rows, ctx)` is true exactly when `place` drops nothing.
   - `Layout.font_size(size, text_size)` multiplies by 0.85, 1 or 1.15 and rounds.

   Lengths arrive in board px and are scaled once through `Screen:scaleBySize`
   (`base/ffi/framebuffer.lua:414-425`). Font sizes are not scaled here, because `Font:getFace` scales them
   (`frontend/ui/font.lua:276`).
3. **`kopanda.koplugin/widgets.lua`**, the registry: `Widgets.get(id)` returns the module for id, or
   nil. Modules live under `kopanda.koplugin/widgets/`. Each module is required from `main.lua` at load
   time (the plugin-shell rule, `frontend/pluginloader.lua:242`, `:269-270`, `:283-286`). This task
   registers none; each widget task adds its line.
4. **Look tokens.** Add the `home` block to `looks/editorial.lua` and `looks/diner.lua`, with values read
   from the canvas, each implied value commented with its board line as the look files already do:
   - `margin { top, side, bottom }`: Editorial 44/40/36 (Main:17); Diner 0 top and bottom with a per-row
     side gutter of 40 (HomeRetro:17-19).
   - `row_gap`: Editorial 28, the quote's top margin (Main:56); Diner 22 (HomeRetro:47, :55).
     `column_gap`: Editorial 16 (Main:19); Diner 14 (HomeRetro:55).
   - `free_space`: Editorial `"before_last_row"` (Main:87); Diner `"before_footer"` (HomeRetro:82).
   - `header { band_color = <role|false>, edge_width, edge_color, rule_color = <role|false>, rule_width,
     rule_space, padding { top, side, bottom } }`: Editorial `rule_color = "ink"` at `stroke.rule`'s value
     with `rule_space = 22` (Main:30); Diner `band_color = "band"`, `edge_width = 4`, `edge_color = "ink"`,
     padding 36/40/28 (HomeRetro:19).
   - `footer { height, stripe_color, gap_color, line_width, line_pitch, edge_width, edge_color }`: Diner 22
     px of 2 px `ink` lines every 10 px on `paper` under a 4 px `ink` edge (HomeRetro:82); Editorial height
     0 and `false` colours.

   These keep the look files' token rules (`looks_spec.lua:151-174` on the review branch): a string
   value sits only under a key ending `_color` (a palette role), `face` or `fill_grey`; widths and sizes
   are numbers; case is the boolean `uppercase`.

   Also add the `type` block with an entry per widget part. Each entry is `{ face, size, uppercase,
   tracking, line_height, color }` with face a face role and `color` a palette role. Both looks declare
   every part, including parts one look doesn't draw (Diner's `date_label`). Widget tasks fill their
   own parts. Add the palette role `on_band` to all three palettes of both looks: Diner day `#f5f1e6`,
   night `#f1ece0` (NightC:19), grey `#111111` (PWRetro:19); Editorial `false`. Exempt `on_band` by
   name from `looks_spec.lua`'s grey-distinctness check (`:138-149`), with a comment: it is chosen for
   contrast against the band and equals `ink` in grey on purpose. Add the face roles `strong` (Diner
   `BricolageGrotesque-Bold.ttf`; Editorial `IBMPlexSans-Medium.ttf`) and `quote` (Editorial
   `Newsreader16pt-MediumItalic.ttf`; Diner `BricolageGrotesque-Medium.ttf`). These files are already
   shipped on the review branch.
5. **`home.lua`.** `Home:init` builds `ctx` once (look, `Looks.variant()`, text size, `os.time()`, the
   screen and the home itself), reads `Settings.get("layout.rows")`, measures each slot with its widget's `height`, places the
   rows, then builds each slot with `build(width, ctx)` inside `pcall`. A missing module or a raising
   widget leaves a blank slot of its column width and logs. It draws the header chrome on row 1 and the
   footer, all from the look and the palette variant, with colours from `Looks.color`. The placeholder
   strings and the `cfont` faces go.
   - **Taps.** Each slot's screen rectangle is kept. `routeGesture`'s fifth step, today the placeholder's
     tap close (`home.lua:307-310`), becomes: a tap inside a slot whose widget has `tap` runs it and is
     consumed; any other tap reaching that step closes the home as before. Steps 1–4 are untouched.
   - **Redraws.** `Home:onResume` and `Home:onTimeFormatChanged` rebuild the content and repaint with
     `UIManager:setDirty(self, "ui")`. Neither returns true, so other listeners still get the broadcast
     (`frontend/ui/uimanager.lua:1042-1061`, `frontend/device/generic/device.lua:1125`,
     `frontend/ui/elements/common_settings_menu_table.lua:87`). `Home:refresh()` is the same rebuild,
     for the weather task.
6. `HOOKS.md` gains `Resume`, `TimeFormatChanged`, `setDirty` and anything else read.

## Surfaces

`kopanda.koplugin/schema.lua`, `settings.lua`, `layout.lua` (new), `widgets.lua` (new), `home.lua`,
`main.lua` (requires), `looks/editorial.lua`, `looks/diner.lua`, `HOOKS.md`; specs `schema_spec.lua`,
`settings_spec.lua`, `layout_spec.lua` (new), `home_layout_spec.lua` (new), `looks_spec.lua`,
`gesture_routing_spec.lua`, `failsafe_spec.lua`, `home_lifecycle_spec.lua` (placeholder assertions);
`spec/emulator/home_golden_spec.lua` and `spec/goldens/home-placeholder-*` (removed),
`spec/emulator/book_close_spec.lua` (its `home-placeholder` golden check at `:45` removed).

## Tests

Written first and run failing.

- `schema_spec.lua` (C1, partial): `text_size` and `layout.rows` in place after `look`, with the default
  passing its own validator. The full seven-key list is asserted as each widget task adds its keys, and
  completes in `weather`.
- `settings_spec.lua` (C2, rows part): every refusal in C2's rows list leaves the file byte-identical;
  the default and a two-column, one-column and three-column layout are accepted and survive a reopen; a
  stored malformed layout (a string, a row of four, an unknown id, a repeated id, share 0, share 1.5)
  reads as the default without raising.
- `layout_spec.lua` (C3): every share combination of 1–3 slots with shares 1–3 at widths 1236, 1264 and
  1680 sums exactly; placement with fitting and overflowing heights; `fits` agrees with `place`; a
  1680×1264 screen; the font scale table.
- `home_layout_spec.lua` (C4, engine part):
  - In the plugin harness with stub widgets registered for the test, the home builds one slot per entry
    at the computed widths.
  - An unknown id and a raising `height`/`build` give blank slots and a log line.
  - A tap in a stub slot with `tap` runs it once and does not close the home; a tap in a slot without
    `tap` closes the home.
  - `Resume` and `TimeFormatChanged` rebuild (the stubs count builds).
  - After show, settle and resume, `UIManager._task_queue` holds no task whose function is KoPanda's.
- `looks_spec.lua` (C5, tokens part): the identical-paths invariant already covers `home`, `type`,
  `on_band`, `strong` and `quote`. Add an assertion that every `type` entry's face names a face role and
  its colour a palette role.
- `gesture_routing_spec.lua` (C14) and `failsafe_spec.lua` (C15): placeholder-specific setup is replaced
  by the real home. "Closes on a tap mid-screen" becomes a tap outside every tappable slot. Every other
  assertion is kept unchanged; the reviewer diffs old against new.
- `book_close_spec.lua` loses its `golden.check("home-placeholder", ...)` line (`:45`): the golden is
  gone and the capture runs with a live clock. Every budget assertion in it stays (C13).
- `settings_spec.lua`: a table value written with `Settings.set` survives a reopen (the deep compare).
- `home_golden_spec.lua` and the two `home-placeholder` goldens are deleted here. `goldens-and-budget`
  adds the new spec. Until then C9 has no spec, which is expected mid-feature.

## Edge cases

- A stored layout from a newer plugin naming a widget this one lacks fails validation (its id is not in
  `widgets`), so the whole layout reads as the default. The registry's blank-slot path covers a widget
  that is in `widgets` but whose module is absent mid-feature.
- `Settings.get("layout.rows")` returns the schema default table itself. The engine must not mutate it;
  the spec checks the default is unchanged after a build.
- Rotation: `Home.take_pending` already drops a home built at another size (`home.lua:236-248`). A
  landscape build simply drops rows that don't fit.
- Zero-height rows (stats with `stats.show = false`) take no row gap, so a hidden widget leaves no hole.
