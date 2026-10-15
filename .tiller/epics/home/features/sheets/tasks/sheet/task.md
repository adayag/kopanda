# The sheet component and its tokens in both looks

## Approach

The component every sheet is drawn with, and the look tokens it reads. It knows nothing about books or
the home: the three later tasks hand it a spec. Paths into KOReader are relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`; repo lines are on `main` at `f2ef10b`. This task starts after
`night-mode` has merged, so `Looks.palette(look, variant)` exists (`night-mode/tasks/palette/task.md`
step 2) and its C3 scan for the word `palettes` runs over every new file.

1. **Open fact first: has the tweak TW-a7nfpr (`.tiller/tweaks/shared-paint-helpers`) merged?** It
   extracts the fill, border and shadowed-box helpers that `widgets/quote.lua:51-92`,
   `featured_cover.lua:90-130` and `widgets/featured.lua:51-87` each copy.
   - If it has, use its helpers.
   - If not, `sheet.lua` keeps local `fill` and `border` as those files do (`widgets/quote.lua:51-67`),
     and the PR says so. Don't do the tweak's extraction here.
2. **Tokens** (`looks/editorial.lua`, `looks/diner.lua`). Add to each `sheet` block the tokens in the
   feature's "Tokens" table, each value with its board line in a comment, and the eight `type` parts
   (`sheet_heading`, `sheet_aside`, `sheet_title`, `sheet_author`, `sheet_meta`, `sheet_row`,
   `sheet_detail`, `sheet_chip`) with the feature's values.
   - Add the palette role `on_accent` to all three palettes of both looks, after `on_band`: Diner
     `#2f2e2b` / `#1e1c1a` / `#111111`, Editorial `false` in all three. Each value carries a comment
     saying where it comes from; the Diner night one says no board gives it.
   - Update the look files' comment on the Diner `sheet` block (`looks/diner.lua:110-111`): the band's
     colour is now a token per sheet.
   - Lengths are board pixels scaled by `ctx.screen:scaleBySize` at draw time (`looks/editorial.lua:6-8`).
3. **`kopanda.koplugin/sheet.lua`**, an `InputContainer` subclass `Sheet` with module state `Sheet.shown`
   (the sheet on screen, or nil).
   - **`Sheet.show(spec, ctx, opts)`**, where `spec = { name, band, header, rows }` (the feature's
     "The sheet component"), `ctx` is the home's (`look`, `variant`, `text_size`, `now`, `screen`,
     `home`; `home.lua:177-184` at `f2ef10b`), and `opts` is optional: `opts.started` is the
     `time.monotonic()` its opener took on the hold or tap, as `Home.show` takes `opts.started`
     (`home.lua:384-403` at `f2ef10b`). It:
     1. closes `Sheet.shown`, if any;
     2. builds the panel;
     3. shows the sheet with `UIManager:show(sheet, "ui", rect)` (`frontend/ui/uimanager.lua:229-273`), with
        `rect` the panel plus its shadow;
     4. keeps `opts.started`, or `time.monotonic()` at its own start when there is none, as the point
        `paint_ms` runs from: the hold (or tap) that opened it. It registers a `tickAfterNext` that sends
        the settled signal (step 6).

     The whole of it runs in `pcall`. A failure is logged, takes the sheet off the stack if it reached it,
     and closes the home onto the file browser (`Home.close()`), as `Home.show` fails
     (`home.lua:384-403` at `f2ef10b`).
   - **`Sheet.close()`** closes `Sheet.shown`, if any, with `UIManager:close(sheet, "flashui", rect)`, as
     `ButtonDialog:onCloseWidget` refreshes (`frontend/ui/widget/buttondialog.lua:333-337`).
     `onCloseWidget` clears `Sheet.shown` and frees the built widgets.
   - **`dimen`** is the whole screen (`Screen:getSize()`), so every tap reaches it. The sheet is not
     `covers_fullscreen`, and its `paintTo` paints only the panel.
4. **Building the panel**, from the look's tokens and `Looks.palette(ctx.look, ctx.variant)`:
   - **Width and place.** The width is the screen less `2 × inset.side`. The panel sits on the bottom
     edge less `inset.bottom`, plus room for `shadow.sheet` (Diner's 8/8, `looks/diner.lua:84`;
     Editorial's 0/0, `looks/editorial.lua:84`).
   - **Chrome.**
     - The fill is `sheet.fill_color`.
     - Editorial draws its `sheet.rule_color` rule of `rule_width` across the top.
     - Diner draws its `sheet.outline_color` border at `stroke.outline` 3 and the hard shadow, painted as
       `widgets/quote.lua:75-92` paints its tile.
   - **Content** inside `padding`.
   - **Header** (`header_padding`, or `book_header_padding` for a book's header), filled with
     `<band>_band_color` when the look has one (`sheet.header_band`), then a `header_rule_width` rule in
     `header_rule_color`.
     - A heading header puts `sheet_heading` on the left and `sheet_aside` on the right, baseline-aligned
       (HoldHome:35-37). With `aside_beside = true` in the spec, the aside goes `aside_gap` after the
       heading instead (FolderOpen:36-38).
     - A book header puts the `cover` widget on the left, `cover_gap` before a column of `sheet_title`,
       `sheet_author` and `sheet_meta`, `line_gap` apart with `meta_gap` above the meta, centred on the
       cover's height (HoldBook:35-41). Lines that are nil are left out. The title is one line, ending in
       an ellipsis past the column.
   - **Rows**, each `row_padding.y` above and below and `row_padding.x` at the sides:
     - a `TintedIcon` of `icon_size`, or the `check` icon when `tick`, or blank space of that size;
     - then `row_gap` and the label in `sheet_row`;
     - the detail at the right end: in `sheet_chip` inside a chip filled with the `<chip>_chip_color`
       token's role, outlined at `chip_outline_width` in `outline` and padded by `chip_padding`, when the
       row's `chip` names a token the look sets; plain `sheet_detail` otherwise.
     - A `muted` row copies `sheet_row` and its detail part with `color = "muted"` and draws its icon in
       `muted`, as the launcher greys an entry.
     - The label ends in an ellipsis to leave the detail its width.
     - Between rows, a `row_rule_width` rule in `row_rule_color`. The last row has none, and its foot
       padding is `last_row_bottom`.
   - **Too tall.** If the panel would be taller than the screen less `inset.bottom`, the trailing rows are
     left out and logged once ("sheet <name> leaves out N rows that don't fit").
   - **Kept on the sheet:** each row's rectangle in screen coordinates, the panel's rectangle, and the
     variant it was built with.
5. **Input.**
   - `ges_events.TapSheet`, a tap anywhere on the screen. Inside a row's rectangle: `Sheet.close()`, then
     the row's `run`, unless the row is `tick`ed, which only closes. Inside the panel otherwise: consumed,
     nothing runs. Outside the panel: `Sheet.close()`, consumed (`buttondialog.lua:347-352`).
   - With `Device:hasKeys()`, `key_events.Close = { { Device.input.group.Back } }`
     (`buttondialog.lua:98-108`; `frontend/device/input.lua:121`), and `onClose` closes the sheet.
   - `onBack`, the `fm_back` event (`frontend/dispatcher.lua:169`), closes the sheet and returns true.
   - Nothing is registered for `hold`, `hold_release`, `hold_pan` or swipes, so they do nothing.
   - The tap, key and back handlers each run in `pcall`. A failure, a raising `run` included, is logged,
     closes the sheet if still shown, and closes the home (`Home.close()`), leaving the file browser.
     `home` is required at call time, since `home.lua` will reach this module.
6. **Painting and the settled signal.**
   - **`paintTo`** runs in `pcall`. When the variant it was built with is not `Looks.variant()`, it first
     rebuilds the panel inside the paint, with no `setDirty`. That is the home's rule from `night-mode`
     (`night-mode/tasks/palette/task.md` step 4).
   - A failed paint is logged and closes the sheet and the home from the next tick (`home.lua:461-475` at
     `f2ef10b`).
   - The first successful paint records `painted_at`.
   - **The settled signal**, from the `tickAfterNext` of step 3: once, if the paint didn't fail,
     `UIManager.event_hook:execute("KoPandaSettled", { screen = "sheet", name = spec.name, paint_ms })`,
     inside `pcall` (`home.lua:338-355` at `f2ef10b`).
7. **Registry.** In `icons.lua`, add `"sheets"` to `check`'s `used_in`, and `"home sheet"` to `wifi_off`'s
   and `moon`'s if they lack it.
8. **`main.lua`** requires `sheet` beside the other modules (`main.lua:22-46`).
9. **HOOKS.md:**
   - `UIManager:close`'s re-dirtying from the topmost `covers_fullscreen` window (`uimanager.lua:290-355`)
     and `_repaint`'s order (`:1298-1346`);
   - the `"ui"` and `"flashui"` refreshes, after `ButtonDialog` (`buttondialog.lua:89-90`, `:327-337`),
     and `hasKaleidoWfm` (`frontend/device/generic/device.lua:118`, `frontend/device/kobo/device.lua:800`);
   - `Device:hasKeys()` (`generic/device.lua:92`, `frontend/device/kindle/device.lua:553-556`,
     `:673-675`, `frontend/device/sdl/device.lua:73`), `Device.input.group.Back` (`input.lua:121`) and
     the `fm_back` `Back` event (`dispatcher.lua:169`);
   - `hold_release` reaching the top widget (`frontend/device/gesturedetector.lua:1346-1356`);
   - `ui/gesturerange` as a required module (`frontend/ui/gesturerange.lua:21-51`).

## Surfaces

`kopanda.koplugin/sheet.lua` (new), `looks/editorial.lua`, `looks/diner.lua`, `icons.lua`, `main.lua`,
`HOOKS.md`. Specs: `spec/unit/sheet_spec.lua` (new), `spec/unit/looks_spec.lua`,
`spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `looks_spec.lua` (C1):
  - the identical-paths list (`looks_spec.lua:85-105`) gains `sheet.inset.side`,
    `sheet.book_band_color`, `sheet.header_padding.top`, `sheet.book_header_padding.bottom`,
    `sheet.row_rule_color`, `sheet.status_chip_color`, `sheet.chip_padding.x`,
    `type.sheet_heading.face`, `type.sheet_aside.color` and `type.sheet_chip.size`;
  - the role list (`:120-121`) gains `on_accent`;
  - one case writes out Diner's `on_accent` day, night and grey values and Editorial's three `false`s;
  - the existing rules then cover every new token unchanged.
- `sheet_spec.lua` (C2), under the plugin harness, with a home shown over a real file manager
  (`harness.show_fm(); harness.tick(2)`, as `gesture_routing_spec.lua` does). A three-row spec with a
  heading header, one row with a plain detail, one with a `status` chip and one `muted`:
  - **Geometry per look** on the Colorsoft's size:
    - Editorial's panel spans the screen's width, ends on the bottom edge, and has its `ink` rule
      `rule_width` high across its top row of pixels (read back from a `Blitbuffer` the sheet paints
      onto);
    - Diner's panel is inset `scaleBySize(22)` from the sides and the foot, with the `outline` colour at
      its border and the `shadow` colour at the shadow's corner, and its header band in `mustard` for
      `band = "home"`;
    - rows lie top to bottom in order, inside the panel, none overlapping.
  - **Details:** Diner's chip pixel reads `mustard`, and Editorial's same row has no fill behind its
    detail. The muted row's label pixels are within 8 per channel of `muted`, not `ink`.
  - **Taps:**
    - a tap in row 2 closes the sheet, then calls its `run` once, with `Sheet.shown` nil when `run` is
      called;
    - a tap on the header runs nothing and leaves the sheet shown;
    - a tap above the panel closes it, runs nothing, and the home's own tap step doesn't run (no slot tap,
      the home still shown);
    - a ticked row's tap closes and runs nothing.
  - **Ignored:** a `hold`, a `hold_release` and a `swipe` inside a row change nothing.
  - **Back:** with `Device.hasKeys` stubbed true for the sheet's construction, a `Back` key event closes
    it. With it false, no `key_events.Close` is registered. A `Back` event (`Event:new("Back")`) sent to
    the top widget closes it.
  - **One at a time:** showing a second sheet closes the first; the stack holds one sheet.
  - **Paint once:**
    - with `UIManager.setDirty` and `UIManager.scheduleIn` spied, `show` makes one `setDirty` call, with
      `"ui"` and the panel's rectangle, and the sheet schedules nothing;
    - `close` passes `"flashui"` and that rectangle, and the home is repainted (its `paintTo` called once
      in the next repaint).
  - **Settled:** after `harness.tick(3)`, exactly one `KoPandaSettled` with `screen = "sheet"`, the spec's
    `name` and a number `paint_ms`. None when the paint raises.
  - **Where `paint_ms` starts:** with `opts.started` back-dated 200 ms (`time.monotonic() - time.ms(200)`),
    the signal's `paint_ms` is at least 200; with no `opts`, it is under 200 on the same spec.
  - **Night:** with `Device.screen.night_mode` and colour stubbed as `night_mode_spec.lua` stubs them, a
    Diner sheet painted onto a software-inverted `Blitbuffer` stores the designed night `mustard` band and
    the designed night `on_accent` in its heading's pixels, read through a cleared-flag copy as
    `Screen:shot` does (`base/ffi/framebuffer.lua:566-581`). A sheet built by day, then painted after the
    flag turns on, rebuilds inside that paint and calls no `setDirty`.
  - **Too tall:** a spec of 40 rows shows the rows that fit, logs once, and every kept row's rectangle is
    on the screen.
- `night_mode_spec.lua` (C2), `night-mode`'s scan, unchanged: it must still pass with `sheet.lua` in the
  tree.
- `hooks_doc_spec.lua` (C14) passes with the new requires: `ui/gesturerange`, for the tap range, which
  `HOOKS.md` names only as a file today, and any other KOReader module `sheet.lua` gains; `sheet` collides
  with no KOReader module path.
- `failsafe_spec.lua` (C13):
  - a row whose `run` raises: the error is logged, no sheet and no home are on the stack, and the file
    manager is on top;
  - a sheet whose build raises inside `Sheet.show`: the same;
  - a sheet whose paint raises: the same after the next tick.

## Edge cases

- `Typeset.line` draws with `TextWidget`, which KOReader paints in its colour's grey
  (`frontend/ui/widget/textwidget.lua:369`). So a chip's or a heading's text pixel is a grey of its role,
  and the night check reads the grey of the designed night `on_accent`, as `night-mode`'s C4 reads the
  clock.
- A spec with no rows draws the header alone. A spec with no header draws rows alone, with no header
  rule.
- The tap that opens nothing (on the header) must still be consumed, or `sendEvent` would offer it to the
  windows below (`uimanager.lua:988-1031`). The file manager is always-active only inside a dispatch
  (`dispatch_bridge.lua:42-57`), so it would be dropped anyway, but consuming it is explicit.
- `Sheet.close()` with no sheet shown does nothing.
- The `check` icon is in the registry (`icons.lua:53`). An icon id the registry lacks draws blank space,
  logged once per build, as the launcher does.
- `Device.input.group.Back` exists on every device's input (`input.lua:121`), but `key_events` are only
  read on a device with keys, hence the `hasKeys()` guard `ButtonDialog` uses.
