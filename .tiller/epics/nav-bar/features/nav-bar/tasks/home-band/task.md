# The home reserves the bar's band, draws it, routes its taps first, and its goldens are regenerated

## Approach

The home with the bar: the layout leaves the band free, the rows draw the bar with Home active, the
gesture order hands taps and holds in the band to the bar before anything else can take them, and the home's
goldens are regenerated on purpose. Starts after `nav-bar/nav-bar/bar`. Repo lines on `main` at `fa0e7dd`;
KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. The feature's "The home" and "Fitting the
default home above the bar" are the spec. This task regenerates the home's goldens because every task's
tests gate is the whole `bin/check`, emulator goldens included (`.tiller/tiller.yml`).

1. **D7 tokens:** Diner's `home.footer.height` becomes 0, its comment citing NavBarC:70
   (`looks/diner.lua:190-191`); Editorial's `home.margin.bottom` becomes 20, citing NavBar:19, :61
   (`looks/editorial.lua:168`).
2. **The band in `Layout.arrange`** (`layout.lua:167-259`): the bar's height is `NavBar.height(ctx.look,
   Layout.screen)`, through a field a spec can stub as it stubs `Widgets.get` (`spec/unit/layout_spec.lua:12`,
   `:25`); the placer gets `height − bar` as its available height (`:212`); the footer's y and the free-space
   shift use it (`:245-257`, `place`'s `avail_h`, `:45-102`); `arranged.height` stays the screen's height
   (`layout_spec.lua:268-275`); `arranged.nav = { x = 0, y = height − bar, w = width, h = bar }`. A raising
   `NavBar.height` is logged and reads as 0, so the home still lays out.
3. **Open fact F1, settled before anything else changes.** With step 2 in place, a unit case computes
   `Layout.overflow(Schema default rows, ctx)` with the real widgets, both looks, `text_size` small, medium
   and large, at the Colorsoft (`harness.at_colorsoft`) and at the Paperwhite's 1236×1648 with the device
   screen stubbed as `at_colorsoft` stubs it (`spec/plugin_harness.lua:151-178`, done in the spec, since its
   size is fixed at `:155`): a screen as `layout_spec.lua:14-21` makes one moves only `Layout.screen`, while
   `Font:getFace` scales text by the device screen (`frontend/ui/font.lua:276`), so it would measure the
   widgets at the unit scale. With the populated content (a featured book, its chapter and the quote) and
   with the empty one. Candidates: (a) zero everywhere; (b) rows dropped only at `large`; (c) rows
   dropped at `medium`. For (a), keep the case as a test and go on. For (b) or (c), follow the owner's decision
   (2026-10-16, feature.md "Fitting the default home above the bar"): tighten the looks' home vertical
   tokens (row gaps, header and bottom padding, the launcher's tile height) in both looks by the smallest
   steps until the case drops nothing at `small` and `medium` on both profiles with both contents, keeping
   every row and the default `layout.rows`. The case then asserts that, and records what `large` drops.
   Write the case first and see it fail before changing a token. Put the before and after values in a
   comment beside each changed token and in the PR body, with any rows still left out at `large`.
4. **Drawing** in `HomeRows.build` (`home_rows.lua:80-135`): after the chrome fills, `NavBar.new{ look,
   variant, width = home.dimen.w, where = "home", listen = false }` placed at `arranged.nav`, appended to the
   rows widget so it paints after the slots and is freed with them (`home_rows.lua:27-40`); the home keeps it
   as `home.nav` beside `home.slots`. A raising build is logged and the band left as paper.
5. **Gestures** in `HomeGestures.route` (`home_gestures.lua:127-160`): after the settings step (`:133-136`)
   and before the file manager's menu zones (`:139`), when `own_step` is `tap` or `hold` and `home.nav`
   contains the position, return `home.nav:handle(ges)`. The own zones already exclude the top menu zones
   from `tap` (`:70-80`), which lie far from the band. The comment over `route` (`:117-126`) gains the step.
6. **Probe points moved above the bar** (D4), each with a comment saying why: `gesture_routing_spec.lua`'s
   corner case (`:232-254`, both its taps) and `failsafe_spec.lua`'s forwarded-action case (`:510-531`) tap at
   `y = height − bar − 5`, asserted inside the corner eighth (`y ≥ 7/8 h`, KOReader's `defaults.lua:68`);
   `gesture_routing_spec.lua:303-328` keeps its probe at the stats slot's corner (`:319-322`) but lowers its
   stub heights (`:305-306`) so the last row still fits above the band and ends inside the corner eighth
   (today it ends at about 728 of the unit screen's 800 and would drop); the emulator
   scenario `spec/emulator/scenarios/2-scenario-gesture-forward.lua:68` taps at `size.h − bar − 10` with the
   bar's height from `NavBar.height(Looks.active(), Screen)`, its header comment (`:1-7`, `:62`) saying so.
   If the bar on some screen is taller than an eighth of its height, the corner zone has no point above it:
   stop and report.
7. **Goldens:** `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/home_golden_spec.lua
   spec/emulator/night_golden_spec.lua spec/emulator/sheet_golden_spec.lua`, then open every PNG (`open
   <png>`) beside Main/HomeRetro, NavBar and NavBarC; the PR lists the deliberate differences (the bar, Diner's
   stripe gone, Editorial's 20 px bottom, the registry's stroke-2 icons). A second plain run passes. The
   screens, swatch and probe goldens must not change (C10).
8. **`HOOKS.md`:** the hold-on-home section (`HOOKS.md:911`) and the gestures-under-the-home section
   (`:235`) gain the bar's step and Gestures' bottom-left default (`plugins/gestures.koplugin/defaults.lua:9`,
   KOReader's `defaults.lua:68`, `frontend/device/sdl/device.lua:157`).

## Surfaces

`kopanda.koplugin/layout.lua`, `kopanda.koplugin/home_rows.lua`, `kopanda.koplugin/home_gestures.lua`,
`kopanda.koplugin/looks/diner.lua`, `kopanda.koplugin/looks/editorial.lua`, `kopanda.koplugin/HOOKS.md`.
Specs: `spec/unit/layout_spec.lua`, `spec/unit/home_layout_spec.lua`, `spec/unit/gesture_routing_spec.lua`,
`spec/unit/hold_routing_spec.lua`, `spec/unit/failsafe_spec.lua`, `spec/unit/looks_spec.lua`,
`spec/emulator/scenarios/2-scenario-gesture-forward.lua`; the goldens `spec/goldens/home-*.{png,json}`
other than `home-night-*` (ten), `home-night-*` (two) and `sheet-*` (four). `home.lua` changes only if `home.nav` needs a field there.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `looks_spec.lua` (C1): Diner's `home.footer.height` is 0 and Editorial's `home.margin.bottom` is 20.
- `layout_spec.lua` (C3), with `NavBar.height` stubbed to a fixed figure:
  - the rows, the footer (none now for Diner) and Editorial's last row all end at or above `height − bar −
    margin.bottom`; `arranged.nav` is the band; `arranged.height` is the screen's;
  - "puts Diner's footer on the bottom edge" (`:249-257`) becomes: Diner and Editorial have no footer;
  - "is true exactly when the placement drops nothing" (`:320-343`) places in `1680 − bar`;
  - a layout that fits the full height but not the height less the band drops its last row, and
    `Layout.overflow` counts it;
  - F1's case from step 3, with the real `NavBar.height`.
- `home_layout_spec.lua` (C3): a shown home's `home.nav` is a bar with Home active at `arranged.nav`, painted
  last (a pixel of the band in the bar's fill after a paint); a bar whose build raises leaves the band paper,
  logged, and the slots built.
- `gesture_routing_spec.lua` (C3, C12): new cases: a tap at `(w − 10, h − 10)` with the corner zone bound on
  the file manager runs the Settings tab and not the zone; a tap at `(10, h − 10)` with Gestures' bottom-left
  frontlight binding registered runs nothing and the home stays; a tap on the Library tab closes the home and
  calls `onHome` once; a swipe up starting in the band opens the settings list; under the touch lock a tap in
  the band does nothing. The moved cases of step 6 keep their assertions.
- `hold_routing_spec.lua` (C3): a hold in the band opens no home sheet and runs no slot's hold.
- `failsafe_spec.lua` (C6): the moved case of step 6; a tab whose run raises on the home is logged and the
  home stays up; a raising `NavBar.height` lays out the home with no band, logged.
- `home_golden_spec.lua`, `night_golden_spec.lua`, `sheet_golden_spec.lua` (C9): fail first against the old
  goldens with the band; pass after step 7. `home_capture_spec.lua` (C11) stays within 250 ms.
- `gesture_forward_spec.lua` (C13) passes with the moved tap.
- `screens_golden_spec.lua`, `swatch_golden_spec.lua`, `golden_spec.lua` (C10) pass unchanged.

## Edge cases

- Edit layout counts the band: a layout that fitted before may now be refused with "That won't fit on the
  home." (`edit_layout.lua`), by design, since the home really has less room.
- The pre-built home (`Home.prebuild`, `home.lua:234-241`) carries its bar; one built in another look is
  dropped only for size or variant (`home.lua:260-269`), and a look change in between rebuilds through the
  menu's refresh, so no stale bar shows.
- Night mode: the home rebuilds at paint when its variant changed (`home.lua:282-291`), the bar with it.
- Landscape: the band takes the same height; `layout_spec.lua:372`'s landscape case drops what doesn't fit,
  as before.
- The sheets sit over the bar (`sheet.lua:362-364`); their goldens change only by the home beneath.
