# Night palettes under KOReader's inversion

## Summary

Each look's night palette shown correctly while KOReader's night mode is on (direction doc "Night mode",
night palettes). KOReader inverts the framebuffer, so the plugin draws the inverse of the night palette
while KOReader's own image widget keeps the cover in its original colours, and the panel shows the
palette as designed.

## Behavior

- With night mode off, nothing changes.
- With night mode on, every token the widgets read resolves to the inverse of the look's night palette,
  and the featured cover shows in its own colours (KOReader's `ImageWidget` re-inverts it; the plugin adds
  nothing), so the visible result matches the night boards.
- Toggling night mode (from KOReader's menu or the quick-settings sheet later) repaints the home once.
- Goldens for both looks on the Colorsoft profile with night mode on, captured after inversion so they
  show what the panel shows.

### Where KOReader inverts

Paths are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`.

- `Screen:toggleNightMode()` flips `Screen.night_mode` (`base/ffi/framebuffer.lua:22`, `:476-477`). On a
  device that can invert in hardware it sets the panel's inversion flag (`:478-480`); the Kindle base
  class says it can (`frontend/device/kindle/device.lua:396`) and the Colorsoft doesn't override it
  (`:1208-1220`). Otherwise it flips the screen blitbuffer's inverse flag (`:481-488`). The emulator takes
  that path, since the SDL device inherits the generic device's "can't invert in hardware"
  (`frontend/device/generic/device.lua:117`, `frontend/device/sdl/device.lua:67`).
- With the software flag set, every paint inverts the colour as it writes it: `setPixel`, `paintRect`,
  `paintRectRGB32` and `fill` (`base/ffi/blitbuffer.lua:840-844`, `:1704-1724`, `:1827-1845`, `:1506-1516`).
  An RGB colour inverts each channel (`:592-597`).
- Either way the panel shows the inverse of what the plugin paints. Painting the inverse of a night colour
  makes the panel show that night colour, so the direction doc's approach holds on both paths, and the
  Notes' fallback (turning the inversion off while the home is shown) isn't needed.
- KOReader already inverts covers. `ImageWidget` inverts its rectangle after the blit in night mode, so the
  original shows through, unless the widget is an icon (`frontend/ui/widget/imagewidget.lua:76-77`,
  `:583-593`). The featured cover is an `ImageWidget` (`featured-book`'s `cover` task), so the plugin
  doesn't invert it a second time. Icons (`IconWidget`) are left to KOReader's own inversion, as KOReader
  does for its own icons.
- Night mode at start: the device toggles it before any UI exists when `night_mode` is set in
  `G_reader_settings` (`frontend/device/generic/device.lua:344-347`).
- `Screen:shot()` writes what the panel shows in both modes (`base/ffi/framebuffer.lua:566-581`). In night mode it
  flips the flag on a copy of the screen buffer (`:575`; a copy keeps the flag,
  `base/ffi/blitbuffer.lua:2357-2365`). On the software path that clears the flag, and `writePNG`'s blit
  into a fresh buffer copies the stored pixels raw (`base/ffi/blitbuffer.lua:2460-2474`). On the hardware
  path it sets the flag, so the blit inverts what it reads. So the capture driver's PNG is the panel view,
  as the goldens need.

### The palette the home draws with

- `Looks.variant()` answers `"night"` when `Screen.night_mode` is on and the screen renders colour,
  `"grey"` on a screen without colour whatever the night mode, and `"day"` otherwise.
- `Looks.palette(look, variant)` is the palette to paint with. For `"day"` and `"grey"` it is the look's
  own. For `"night"` it is the night palette with each `#rrggbb` inverted per channel (`ff - x`), roles
  that are `false` staying `false`, computed once per look and never written into the look table. The
  swatch keeps reading the designed palettes, so in night mode it still shows them under KOReader's
  inversion with its note.
- The home, `typeset.lua` and every widget resolve colours through `Looks.palette(ctx.look, ctx.variant)`.
  Only `looks.lua` and `swatch.lua` read `look.palettes` directly.
- Grey screens in night mode keep the grey palette and KOReader's plain inversion: a dark ground with
  light text, and Diner's tile greys stay distinct. There is no grey night palette and no Paperwhite night
  golden.
- No settings key is added.

### Toggling

- Both routes broadcast or send `ToggleNightMode`, and the home receives it before the file manager's
  `DeviceListener` has flipped the screen. KOReader's menu broadcasts it
  (`frontend/ui/elements/common_settings_menu_table.lua:266-271`). A gesture or the quick-settings sheet
  goes through `Dispatcher` (`frontend/dispatcher.lua:138`; `SetNightMode` at `:139` takes the same
  route), which reaches the file manager through
  the dispatch bridge. `DeviceListener` then marks every window dirty with a full refresh
  (`frontend/device/devicelistener.lua:14-27`).
- So the home doesn't handle the event. When its `paintTo` finds that the variant it was built with is no
  longer `Looks.variant()`, it rebuilds before painting. The one repaint KOReader asks for is already in
  the new palette, the home asks for no repaint of its own, and no frame shows the old palette inverted.
- A build that fails during that paint takes the home's existing paint-failure path: it is logged and the
  home closes onto the file browser.
- A pre-built home handed over after the variant changed is dropped and built afresh, as one built at
  another screen size is.

### Captures

- The capture driver can start the emulator with night mode on, which sets `night_mode` in the scratch
  profile's `settings.reader.lua`.
- Night goldens: `home-night-diner` and `home-night-editorial` on the Colorsoft, with the populated
  fixture and the featured row as `featured-book` leaves the default layout. The paper corner of each
  capture is the look's designed night paper (`#1e1c1a`, `#15161a`) within the compare tolerance.
- Paperwhite with night mode on: outside the cover, the capture is the pixel inverse of the day
  Paperwhite golden. Inside the cover it matches the day golden un-inverted, because `ImageWidget`
  re-inverts the cover.
- Toggle: from a day home, a scenario toggles night mode through the menu's broadcast and, in a second
  run, through `Dispatcher`. The home is painted exactly once before the next settled signal, and that
  capture matches the night golden.
- Paint budget: a fresh night home's `paint_ms` is at most 250 ms in the emulator on this Mac, the
  home-layout tripwire. With the software flag set, the C blitter is skipped for the screen buffer and Lua
  blits instead (`base/ffi/blitbuffer.lua:737-740`). The emulator's night paint is therefore slower than
  the device's hardware-inverted one.

## Notes

The assumption the spec started with is settled by reading KOReader. The inversion happens at the
framebuffer, on both paths (see "Where KOReader inverts"). The cover is already inverted by `ImageWidget`.
The only per-paint cost the plugin adds is a variant comparison. Whether the emulator's Lua-blit night
paint stays inside 250 ms is open until the first night capture. If it doesn't, the task stops and asks
rather than move the budget.

Out of this feature: the direction doc's night greeting ("Good night") belongs to a greeting widget the
home doesn't have. The Diner weather icon is already a moon when Open-Meteo says it is night (the
`weather` widget's `is_day`). Diner's dark text on mustard and pink tiles at night is the tiles' own
tokens, so it belongs to `launcher` and `sheets`. Night mode on the real Colorsoft panel, where the
inversion is in hardware, isn't checked here, since the Kindle stays on SimpleUI until the studio exists
(design §1b).
