# Focused mode release 3: outside the reader

Design: `docs/plans/2026-11-02-focused-mode-design.md` (decisions table, "Outside" rows). With `focused.on` true
(the default), the home and the library windows stop opening KOReader's screens on a tap; with it off,
everything is as today. One builder, one reviewer. About 1 day.

## What changes

| Where | Mode off (today) | Mode on |
|---|---|---|
| Home / library top edge, tap | KOReader's file-manager menu | Quick-settings sheet |
| Home / library top edge, swipe down | KOReader's file-manager menu | Quick-settings sheet |
| Home / library top edge, hold | Home: the slot's hold or the home sheet; library: the hold step | KOReader's file-manager menu (`FileManagerMenu:onShowMenu`, `filemanagermenu.lua:1006`) |
| Home, tap on an empty spot | Closes the home onto the file browser (`home_gestures.lua:176-181`) | Consumed; the home stays |
| Nav bar Settings tab, tap | KoPanda's settings (`nav_bar.lua:87`) | Quick-settings sheet |
| Nav bar Settings tab, hold | Quick-settings sheet (`nav_bar.lua:209-235`) | KoPanda's settings |
| Home sheet | "Open the file browser" row (`home_sheet.lua:67-73`) | Row hidden |

Decided 2026-11-02 with the owner, after the design: the file browser's holds are dropped (no book or folder
sheet over KOReader's file browser), since with the empty tap and the home-sheet row gone a reader can't reach
the file browser; the owner turns the mode off to use it. A top-edge swipe down does what the top tap does.

Unchanged: the home's swipe up from the bottom (KoPanda's settings), every header control the library's
`self:tap` acts on (the top-edge rule sits after it), Gestures' corner zones (still forwarded), the Go to
screen (it is in the reader; no file manager there).

## Facts the build relies on

- Top zones: `DTAP_ZONE_MENU` and `DTAP_ZONE_MENU_EXT`, read as `home_gestures.lua:15-29` reads them. The file
  manager's menu opens on a tap unless `activate_menu` is `"swipe"`, on a swipe south unless it is `"tap"`
  (`filemanagermenu.lua:51`, `:1102-1114`); the quick-settings rule honours the same setting.
- Both routes reach the top zone at the forward step: the home's tap zone skips the menu zones
  (`home_gestures.lua:70-80`), and the library's route runs nav, `self:tap`, the page swipe, then
  `HomeGestures.forward` (`library_chrome.lua:744-765`). The new rule runs just before `forward` in both, so a
  Gestures corner zone inside the top band loses to it only for tap, swipe south and hold in the menu zones.
- Quick settings over a window: `nav_bar.lua:199-207` (`beneath` is the library for the library, else nil).
  Reuse it rather than copy it.
- The mode read: `focused_hooks.lua:18-26` (pcall, a raise reads as off, logged). Move it to a tiny
  `focused.lua` (`Focused.on()`) that `focused_hooks`, `home_gestures`, `nav_bar` and `home_sheet` require, so
  `nav_bar` doesn't pull in the reader hooks' chain.

## Tasks

TDD each: write the test, run it, see it fail for the right reason, implement, run again.

1. **`focused.lua`.** `Focused.on()` from `focused_hooks.lua`'s `focused()`; `focused_hooks` uses it. Unit:
   true with nothing stored, false when set false, false (and logged) when `Settings.get` raises.
2. **Top edge.** One function in `home_gestures.lua`, `HomeGestures.focused_top(ges, where)`, consumed or not:
   with the mode on, a tap or swipe south in the menu zones opens quick settings (per `activate_menu`), a hold
   there opens the file manager's menu with no tab index; otherwise false. Called before `forward` in
   `HomeGestures.route` and `Window:routeGesture`. Unit (`gesture_routing_spec.lua`, `library_chrome_spec.lua`):
   each of the three gestures on the home and on the library, mode on; `activate_menu` = swipe leaves a top tap
   with nothing opened; a header control's tap in the library still runs it; with the mode off, the existing
   tests' behaviour.
3. **Empty tap.** `HomeGestures.route`'s fallback: with the mode on, return true without `close(home)`. Unit:
   mode on, a tap outside every tappable slot leaves `Home.shown`; mode off, it still closes.
4. **Settings tab.** `Bar:handle`: with the mode on, a tap on Settings opens quick settings and a hold runs
   `NavBar.run("settings", where)`; other tabs unchanged. Unit (`nav_bar_spec.lua`): both, on, and off.
5. **Home sheet row.** `home_sheet.lua` leaves out "Open the file browser" with the mode on. Unit
   (`home_sheet_spec.lua`): the row list both ways.

Then: one emulator scenario in `gesture_forward_spec.lua` (or a new `focused_home_spec.lua`): mode on, a
top-edge tap on the home settles with the quick-settings sheet up and an empty tap leaves the home shown.
HOOKS.md gains `FileManagerMenu:onShowMenu` (`filemanagermenu.lua:1006`) and `activation_menu`
(`filemanagermenu.lua:51`). The design doc's Outside rows and Tests line are updated to the table above.

## Existing tests

`focused.on` defaults to true, so every existing spec that asserts today's home or library behaviour (the
file manager's menu on a top tap, the empty-tap close, the Settings tab's tap and hold, the home sheet's rows)
fails once this lands. Each such spec sets `focused.on = false` for those cases, so the mode-off path keeps
its coverage, and gains the mode-on case beside it. A spec failing only because of the new default is fixed
that way; anything else that fails is a finding.

## Done

`bin/check --unit` green, the new emulator scenario green, then the lead's full `bin/check`. Captures of the
home with the quick-settings sheet up from the top edge, opened for the owner. Cuts release v0.1.20.
