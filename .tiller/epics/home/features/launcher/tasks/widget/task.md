# Launcher widget in both looks with its states and taps

## Approach

The widget that puts `entries`' resolved views on the home, by `home-layout`'s contract (`widgets.lua:1-8`
on `main`) as `featured-book` extends it. Paths into KOReader are relative to `~/Projects/kodev/koreader/`
at `e1fe1ac`; repo lines are on `main` at `bfb043c`.

1. **Open fact first: how does a widget's `tap` learn where the tap landed?** On `main`, `routeGesture`
   calls `slot.module.tap(self.ctx)` with no position and ignores the return (`home.lua:480-487`).
   `featured-book`'s widget tells its first-run button from the rest of its slot
   (`featured-book/tasks/widget/task.md` §2 "tap"), and makes `home.lua` honour a `false` return, but its
   spec doesn't say how the position arrives. Read `routeGesture` on `main` after `featured-book` merges.
   The candidates:
   - **(a)** It passes the gesture's position, `ges.pos` in screen coordinates, as a second argument: use
     it as it is.
   - **(b)** It passes the position in another form, such as relative to the slot, or with the built
     widget: adapt the launcher to that form, changing nothing in `home.lua`.
   - **(c)** It passes none, because the featured widget found its button another way: add `ges.pos` as
     `tap`'s second argument in `routeGesture`, with a `home_layout_spec.lua` case proving a stub widget
     receives it and that the featured widget's spec still passes.

   Record which in the PR. Either way, the launcher finds its own built widget and slot through
   `ctx.home.slots` (`home.lua:218-227`), the slot whose `module` is the launcher and whose `rect`
   contains the position.
2. **Layout.** In `schema.lua`, add `"launcher"` to `layout.rows`' `widgets` list after `featured`. Insert
   `{ { widget = "launcher", share = 1 } }` as the default's fourth row, so the default is the feature's
   five rows.
3. **`kopanda.koplugin/tinted_icon.lua`**, a `Widget` subclass `TintedIcon{ file, size, color }`:
   - **`init`** renders `RenderImage:renderSVGImageFile(file, size, size)` (`frontend/ui/renderimage.lua:338-344`;
     an RGB32 buffer with straight alpha, `:390-393`). It then makes `mask = Blitbuffer.new(size, size,
     Blitbuffer.TYPE_BB8)`, `mask:fill(Blitbuffer.COLOR_WHITE)`, `mask:alphablitFrom(rendered, 0, 0, 0, 0,
     size, size)` and `mask:invertRect(0, 0, size, size)` (`base/ffi/blitbuffer.lua:1318`, `:1506`,
     `:1567`), and frees the render. `dimen` is `size × size`.
   - **`paintTo(bb, x, y)`**: `bb:colorblitFrom(mask, x, y, 0, 0, size, size, color)` when
     `Blitbuffer.isColor8(color)`, else `bb:colorblitFromRGB32(…)` (`:1405-1437`). The `isColor8` split
     follows `home.lua:96-102`.
   - **`free()`** frees the mask.
   - A file that fails to render gives a widget of `size × size` that paints nothing, logged.
4. **`kopanda.koplugin/widgets/launcher.lua`**, `{ id = "launcher", settings_prefix = "launcher", height,
   build, tap, stale }`, registered in `widgets.lua` and required from `main.lua`.
   - **Entries.** `Settings.get("launcher.entries")`, each through `LauncherEntries.resolve`, read once per
     build.
   - **Geometry** from the look's `launcher` block, scaled by `ctx.screen:scaleBySize`:
     - `columns`; rows `ceil(n / columns)`;
     - column x and width from `Layout.columns(width, slots, launcher.column_gap)` (`layout.lua:22-42`)
       with `columns` share-1 slots;
     - entry height: Editorial `2 × padding.y + max(icon_size, label line height) + stroke.hairline`;
       Diner `tile_height`;
     - widget height: `rows × entry_h + (rows − 1) × row_gap`, plus `shadow.tile.y` when the tile is a box
       with a shadow;
     - 0 entries: 0.

     `height(width, ctx)` and `build` share one function, as `Typeset.measured` pairs them for the other
     widgets (`typeset.lua:103`).
   - **Editorial entry** (`tile.box == false`), a row in its column:
     - padding `padding.y` above and below;
     - a `TintedIcon` of `icon_size`, then `icon_gap`;
     - the label by `Typeset.line(look.type.launcher_label, label, max, ctx)` (`typeset.lua:49`), and, with a
       suffix, `suffix_gap` then `Typeset.line(look.type.launcher_suffix, suffix, …)` on the same line. The
       label's `max` is the column less the icon, the gaps and the suffix's width.
     - a `stroke.hairline` rule in `tile.rule_color` across the column's foot (Main:61).
   - **Diner entry** (`tile.box == true`), a tile:
     - `tile_height` high, its column wide, less the shadow;
     - the fill is `accent_<i>_color` for positions 1 to 3 when the look has one, else `tile.fill_color`;
     - outline `tile.outline_color` at `stroke.outline`, and shadow `shadow.tile` (painted as
       `widgets/quote.lua:75-92` paints its tile);
     - inside the outline and `padding`: the icon at the top left, and the label at the foot, with the
       suffix on its own line under the label when `suffix_below`.
   - **States** from the view:
     - `off`: the `wifi_off` icon in `ink`, and the suffix in `muted`;
     - `unavailable`: the `plugin_missing` icon, label and suffix all in `muted` (each type part copied with
       `color = "muted"`); Diner's tile keeps its fill, outline and shadow;
     - `ready`: the icon in `ink`.

     An icon id `Icons.path` doesn't know (`icons.lua:57-64`) draws no icon and logs once per build.
   - **Built widget.** It keeps the entry list and each entry's rectangle relative to its own top-left (the
     tile box for Diner, without the shadow; the whole row for Editorial). Its `paintTo` records the `x, y`
     it was painted at.
   - **`tap(ctx, pos)`** (`pos` as step 1 settles):
     - find the slot and its built widget (step 1);
     - convert `pos` to the widget's coordinates from its recorded paint origin;
     - inside an entry's rectangle: `LauncherEntries.run(entry, ctx)` and return true;
     - otherwise return false, so the home's next step runs.
   - **`stale(built, ctx)`**: true when the built widget drew a Wi-Fi entry and its drawn `off` differs from
     `NetworkMgr:isWifiOn()` now.
5. **`home.lua`.**
   - The widget contract comment (`widgets.lua:1-8`) gains `stale(built, ctx)?`.
   - A local `refresh_if_stale(home)` walks `home.slots`, calls each module's `stale` in `pcall` (a
     failure is logged and counts as not stale), and calls `home:refresh()` once if any is true.
   - `Home:onNetworkConnected` (`home.lua:277-282`) calls it after the weather.
   - A new `Home:onNetworkDisconnected` calls it.
   - Both return nothing, so the events reach the other windows.
6. **Tokens.** A `launcher` block in both looks, every value with its board line:
   - **Editorial:**
     - `columns = 2`, `column_gap = 32`, `row_gap = 0` (Main:60);
     - `icon_size = 22` (Main:62); `icon_gap = 14`, `padding = { x = 0, y = 15 }` (Main:61);
     - `tile_height = false`; `accent_1_color`, `accent_2_color`, `accent_3_color = false`;
     - `suffix_gap = 6` (EmptyStates:65); `suffix_below = false`.
   - **Diner:**
     - `columns = 3`, `column_gap = 14`, `row_gap = 14` (HomeRetro:55);
     - `icon_size = 28` (HomeRetro:57); `icon_gap = false`;
     - `padding = { x = 14, y = 12 }`, `tile_height = 104` (HomeRetro:56);
     - `accent_1_color = "mustard"` (:56), `accent_2_color = "pink"` (:60), `accent_3_color = "teal"` (:64);
     - `suffix_gap = 6` (no board; unused while `suffix_below`); `suffix_below = true`.
   - **Type parts:**
     - `launcher_label`: Editorial `strong` 16, `ink` (Main:61); Diner `display` 14, `ink` (HomeRetro:56);
     - `launcher_suffix`: Editorial `strong` 11, uppercase, tracking 0.1, `muted` (EmptyStates:65); Diner
       `display` 11, uppercase, tracking 0.1, `muted` (`looks/diner.lua` `label`).

     Both have `line_height = 0`.
7. **Icons registry.** Add `"launcher"` to `bookmark`'s and `list`'s `used_in` (`icons.lua:44-45`). No
   file changes; `icons_spec.lua`'s id list is unchanged.
8. **HOOKS.md:**
   - `RenderImage:renderSVGImageFile`;
   - `Blitbuffer.new`, `fill`, `alphablitFrom`, `invertRect`, `colorblitFrom` and `colorblitFromRGB32`;
   - the `ImageWidget` `dim` note this replaces (`frontend/ui/widget/imagewidget.lua:570-579`);
   - the `NetworkDisconnected` broadcast (`frontend/ui/network/manager.lua:406-408`) and the emulator's fake
     toggle (`frontend/device/sdl/device.lua:477-501`).

## Surfaces

`kopanda.koplugin/schema.lua`, `widgets/launcher.lua` (new), `tinted_icon.lua` (new), `widgets.lua`,
`main.lua` (requires), `home.lua` (network handlers, the `stale` walk, and the tap position if step 1 finds
(c)), `icons.lua`, `looks/editorial.lua`, `looks/diner.lua`, `HOOKS.md`; specs
`spec/unit/launcher_widget_spec.lua` (new), `spec/unit/tinted_icon_spec.lua` (new),
`spec/unit/schema_spec.lua`, `spec/unit/settings_spec.lua`, `spec/unit/looks_spec.lua`,
`spec/unit/home_layout_spec.lua`.

## Tests

Written first and run failing. `LauncherEntries.resolve` and `run` are stubbed per case, except where
noted. Read `bin/check` output through a filter that drops KOReader's library-loading chatter and the
per-test lines.

- `tinted_icon_spec.lua` (C5):
  - `wifi` at 48 px painted into a white BB8 with `Blitbuffer.Color8(0x80)`: every pixel is white or a
    blend toward 0x80, and none is darker than 0x80.
  - The same into an RGB32 buffer with `#e0bd6a`: every inked pixel lies between white and that colour.
    Inked pixels exist in both cases.
  - `free` frees the mask (spied).
  - An unrenderable path gives a blank widget of the size, with a log line.
- `launcher_widget_spec.lua` (C4), in the plugin harness, with a hand-built `ctx` as `weather_spec.lua`
  builds one (`spec/unit/weather_spec.lua:566-575`):
  - **Geometry**, for each look at its full-width column on each profile (1264 and 1236 less both scaled side
    margins):
    - the built width equals the column width, and the height equals `height(width, ctx)`;
    - six entries make 2×3 (Editorial) or 3×2 (Diner) rectangles, with the columns and gaps summing to
      the width;
    - four entries make two rows in either look;
    - zero entries make height 0;
    - Diner's height includes `shadow.tile.y`.
  - **Drawing**, read from the built tree (the `find` and `drawn` helpers as in `weather_spec.lua:578-611`):
    - the labels in order;
    - each `TintedIcon`'s file is the view's icon and its colour is `ink`;
    - Diner tiles 1 to 3 fill mustard, pink and teal and 4 to 6 paper, in day and grey palettes;
    - Editorial draws a rule per entry in `hairline_light`.
  - **States:**
    - `off` draws `wifi_off` in `ink` and "OFF" in `muted`;
    - `unavailable` draws `plugin_missing` and the label and "PLUGIN MISSING" in `muted`;
    - Editorial puts the suffix on the label's line and Diner on the line below;
    - a 60-character label ends in "…" and doesn't overflow its column;
    - an icon id the registry lacks draws no icon and logs once.
  - **Tap:**
    - through the real home (`harness.show_fm(); harness.tick(2)` and a `Gesture` event, as
      `home_layout_spec.lua:62-64` sends one), a tap at each entry's centre calls `run` with that entry;
    - a tap in a column gap returns false and the home's next step runs (a spy on the interim close, or
      whatever `featured-book` left as the next step);
    - a raising `run` closes the home onto the file browser.
  - **Stale:** with Wi-Fi drawn off, `stale` is false until the fake setting flips, then true.
- `home_layout_spec.lua` (C6):
  - A `NetworkDisconnected` broadcast refreshes a shown home exactly once when a stub widget's `stale`
    returns true, not at all when it returns false or raises, and leaves the event unconsumed for the
    other windows.
  - `NetworkConnected` does the same, after the weather call.
  - A stub widget's `tap` receives the tap's position, in the form step 1 settles. Add the case unless
    `featured-book` already added one.
- `schema_spec.lua` (C1, layout part): `widgets` ends with `launcher`, and the default is the five rows.
- `settings_spec.lua` (C2): a layout with a `launcher` slot is accepted.
- `looks_spec.lua` (C7): the `launcher` block and the two parts are declared in both looks with identical
  paths. The existing value rules pass: `accent_*_color` names a palette role or is false, and the parts
  name a face and a palette role (`looks_spec.lua:157-204`).

## Edge cases

- A launcher placed by the owner in a half-width slot gets narrow columns. Labels ellipsize, and Diner's
  icon keeps its size. The spec builds Diner at 560 px to prove nothing overflows.
- The launcher in row 1 would be bottom-aligned by the header (`layout.lua:134`). The recorded paint
  origin keeps tap mapping right there too.
- The `stale` refresh rebuilds the whole home, the weather and the featured row included. It happens once
  per Wi-Fi change.
- The pre-built home's Wi-Fi state is read at `CloseDocument`, milliseconds before it shows. A change in
  between is caught by the next network event or `Resume`.
- Night mode's palette and the inverse drawing are `night-mode`'s. `TintedIcon` takes any colour, so
  nothing here blocks it.
