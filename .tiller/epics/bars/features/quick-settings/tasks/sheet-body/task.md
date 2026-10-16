# The sheet's body hook: areas that act without closing, in-place redraw and refresh events

## Approach

`sheet.lua` learns to lay out a body under its header in place of rows, whose areas act with the sheet left
open, and to redraw itself in place; nothing uses it yet but its spec. Starts once `nav-bar/nav-bar` is done
(the feature's prerequisite). Repo lines on `main` at `e6f2912`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. The feature's "The body hook" is the spec.

1. **Spec shape.** The module's header comment (`sheet.lua:1-12`) gains `body` and `refresh_on`. A spec with
   both `rows` and `body` logs once and is built with its rows only.
2. **Layout.** In `build` (`sheet.lua:92-390`), after the header (`:224`), when `spec.body`: call
   `spec.body(bctx, content_w)` → `{ widget, areas }`; `add(widget, content_x, y)`; keep each area with its
   `rect` moved by `(content_x, y)`; `y = y + widget:getSize().h`. The rows loop then sees no rows. The foot,
   chrome and placement (`:333-380`) are unchanged; the areas join the rows in being moved to the screen
   (`:377-379`) and are returned as `areas`. When the box is taller than `size.h − inset.bottom` and the spec
   has a body, `box_y` is 0 and `lay_out` logs it on the first build only, as it logs dropped rows
   (`:397-400`).
3. **`lay_out`** (`:394-411`) keeps `sheet.areas`.
4. **Taps** (`tap`, `:578-591`): before the rows, an area containing the position: with `close_first`,
   `close_sheet` then `area.tap()`; without, `area.tap()` in its own `pcall` (an error logged with the sheet's
   name), then `redraw(sheet)`. An area with no `tap` is consumed with nothing run. The rest is unchanged.
5. **Holds** (`Sheet:init`, `:420-426`; `onHoldSheet`, `:602-611`): `HoldSheet` is registered when the spec
   has `hold` or `body`. In the handler, an area with `hold` containing the position runs as a tap does
   (step 4, with `hold`); otherwise the spec's `hold`, when it has one, as today; otherwise consumed, nothing
   run. The handler now takes `(_, ges)` to read the position.
6. **`redraw(sheet)`**: when `UIManager:isWidgetShown(sheet)`, keep the old `sheet.rect`, `lay_out(sheet,
   sheet.variant)`, then `UIManager:setDirty(sheet, "ui", old:combine(sheet.rect))`
   (`frontend/ui/geometry.lua`'s `combine`; the `"ui"` refresh as `FrontLightWidget:update`,
   `frontend/ui/widget/frontlightwidget.lua:430-437`). A raising layout goes to `fail` (`:480-483`).
   `Sheet.redraw()` calls it for `Sheet.shown`, doing nothing with none.
7. **`refresh_on`**: in `Sheet:init`, for each name, `self["on" .. name] = function() redraw(self) end`,
   returning nothing; `broadcastEvent` offers the event to every window whatever a handler returns
   (`frontend/ui/uimanager.lua:1042-1061`), so the windows beneath still hear it.
8. **Size.** If `sheet.lua` passes 700 lines, extract `build` and its helpers into a `sheet_layout.lua`
   module before adding the hook, as AGENTS.md's 500/1000 rule asks, in its own commit inside this task with
   the existing specs green before and after; say so in the PR. Its name must not collide with a KOReader
   module (`spec/unit/hooks_doc_spec.lua:104-122`), and `main.lua` requires it with the others.
9. **`HOOKS.md`:** the sheet's section (`HOOKS.md:866-909`) gains the in-place redraw (`setDirty` with
   `"ui"`, `frontend/ui/uimanager.lua:659`), `isWidgetShown` (`:881`), `Geom:combine` and the broadcast
   handlers' return value (`uimanager.lua:1042-1061`).

## Surfaces

`kopanda.koplugin/sheet.lua` (and `kopanda.koplugin/sheet_layout.lua`, new, only under step 8),
`kopanda.koplugin/main.lua` (only under step 8), `kopanda.koplugin/HOOKS.md`. Specs: `spec/unit/sheet_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `sheet_spec.lua` (C2), a new `describe("a body")` over a shown home and, where named, over
  `harness.show_fm()` with no home, with a test body: a fixed-size widget (a spy on `paintTo` and `free`) and
  areas `stay` (`tap` and `hold` spies), `closer` (`close_first`, a `tap` spy recording whether the sheet was
  still shown), `inert` (no handlers):
  - the body's widget is placed under the header at the content's left, and `free` runs once on close;
  - a tap on `stay` runs its spy once with the sheet still shown, `body` is called a second time, and
    exactly one `setDirty` with `"ui"` is asked for, its region the union of the old and new rectangles (a
    body whose second call is taller proves the union);
  - a tap on `closer` finds the sheet closed when its spy runs;
  - a hold on `stay` runs its hold spy once and keeps the sheet; a hold on `inert` runs nothing and keeps the
    sheet; the same body with a spec `hold` runs that on a hold on `inert`;
  - a tap on `inert` and on the header run nothing and keep the sheet; a tap above the panel closes it;
  - a `stay` spy that raises is logged and the sheet stays shown and redraws;
  - `body` raising on the redraw closes the sheet and logs; over the bare file manager the file manager is
    then the top window;
  - with `refresh_on = { "TestRefresh" }`, a broadcast `TestRefresh` calls `body` again and reaches a spy
    handler on the home too;
  - `Sheet.redraw()` with no sheet shown does nothing; with one, redraws it;
  - night mode turned on (the existing cases' stub, `:711-833`) calls `body` with `bctx.variant == "night"`
    at the next paint;
  - a body taller than the screen puts the panel at y 0 and logs once, not again on a redraw;
  - a spec with rows and body logs and shows the rows.
- `sheet_spec.lua`'s existing cases, `home_sheet_spec.lua`, `book_sheet_spec.lua`, `folder_sheet_spec.lua` and
  `launcher_manage_spec.lua` (the folder sheet's hold) pass unchanged (C3); `sheet_golden_spec.lua` passes
  unchanged (C14).

## Edge cases

- An area overlapping a row: a spec has one or the other, so it can't happen.
- A redraw while a KOReader dialog covers the sheet (Wi‑Fi's prompt): `setDirty` on the sheet only marks it;
  the dialog above repaints over it as `_repaint` walks up from it (`HOOKS.md:868-873`).
- A redraw after the sheet closed, from a late callback: `isWidgetShown` is false and nothing happens.
- Night rebuild and redraw both go through `lay_out`, so the body never sees two variants at once.
- No timers: a redraw happens only on a tap, a hold, a `refresh_on` event or a caller's `Sheet.redraw()`.
