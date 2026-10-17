# Quick settings lays out twice on Night and up to three times on Wi-Fi

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 7, the small part). Traced in code
at KOReader `e1fe1ac`, not measured on a device. The Wi-Fi triple is plausible, not confirmed: it
depends on `NetworkMgr` running the callback in the same pass as its broadcast
(`frontend/ui/network/manager.lua:109`, `:116`), which was not run.

## What

Every action on the quick-settings sheet goes through `act` → `redraw` (`sheet.lua:281-292`) →
`SheetLayout.build` → `QuickSettings.body` (`quick_settings.lua:278-413`), which re-sets every tracked
label, one `TextWidget` per glyph in Diner (`looks/diner.lua:362-372`).

- **Night:** `act`'s `redraw` lays out in the old `sheet.variant` (`sheet.lua:154-166`), then `paint`
  rebuilds because `Looks.variant()` changed (`:242-246`). Two layouts for one tap.
- **Wi-Fi:** the `refresh_on` handlers (`sheet.lua:92-96`) plus `redraw_later`
  (`quick_settings.lua:179-197`) can redraw up to three times for one toggle.

Two small changes: in `act`, skip `redraw` when `Looks.variant() ~= sheet.variant`, because the paint
rebuilds; for Wi-Fi, drop the immediate redraw or `redraw_later`, after checking that a toggle which
never connects (prompt cancelled, Wi-Fi off) still redraws once.

Keeping handles on each bar's value line and fill so a brightness or warmth step swaps one value
with a regional refresh is the medium part of the finding and not in this tweak.

## Why

About 75 glyph widgets re-set per layout, an estimated 0.1 to 0.27 s on the Kindle (the open-to-paint
golden is 9 ms on the Mac). Night and Wi-Fi pay it two or three times for one tap.

## Done when

- A unit spec spies on `SheetLayout.build`: a Night tap and its paint give exactly 1. It fails on the
  current code.
- A unit spec: a Wi-Fi-on tap, its `NetworkConnected` broadcast and its callback give exactly 1; a
  toggle that never connects still redraws once.
- `bin/check` is green and the sheet goldens are unchanged.
