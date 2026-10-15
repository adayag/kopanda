# Swatch screen from Tools › KoPanda, reachable beside another shell

## Approach

1. `kopanda.koplugin/swatch.lua`, the shape of `home.lua` without its forwarding: an `InputContainer`
   with `covers_fullscreen = true` and `dimen = Screen:getSize()` (`home.lua:97-110`), one full-screen
   tap zone that closes it (`home.lua:68-95`), shown with `UIManager:show(w, "full")` and closed in a
   pcall (`home.lua:133-141`, `:189`), `paintTo` wrapped in a pcall that closes on the next tick on
   failure (`home.lua:252-265`), and the `KoPandaSettled` event-hook signal after the first paint with
   `screen = "swatch"` (`home.lua:166`).
2. Layout, computed from the screen size: a title line, then a grid of six panels, columns
   `Looks.ids()`, rows day, night, grey, then an icon row. Each panel: a fill of the palette's `paper`;
   one chip per non-false role (a square of the colour, outlined in the palette's `ink`, labelled
   `role #hex`); a line per non-false face in that face, reading its label. Colour fills paint through
   `paintRectRGB32`, since `paintRect` greys every colour (`base/ffi/blitbuffer.lua:1704-1724`, `:1827`).
   Text in a palette's ink goes through `TextBoxWidget`, which keeps an RGB foreground on a colour
   screen (`frontend/ui/widget/textboxwidget.lua:854-906`), with `bgcolor` set to the panel's paper,
   since its default is white and fills its buffer (`:50`, `:861-864`); `TextWidget` greys it
   (`frontend/ui/widget/textwidget.lua:345-375`). Icons through `ImageWidget` or `IconWidget{ file = }`
   with `alpha = true`, since the default flattens onto white (`frontend/ui/widget/imagewidget.lua:202-226`),
   each with its id beneath. Lengths go through `Screen:scaleBySize`; font sizes go to `Fonts.face` unscaled, since
   `Font:getFace` scales them (`frontend/ui/font.lua:276`).
3. Night mode: when `G_reader_settings:isTrue("night_mode")` (`frontend/device/devicelistener.lua:14-27`),
   a line above the grid: "Night mode is on: KOReader inverts these colours. Turn it off to judge them."
4. `main.lua`: Tools › KoPanda gains Swatches (after Settings), through `after_menu`. Under refusal,
   `init` still registers to the main menu (`self.ui.menu:registerToMainMenu(self)`, today skipped by
   the early return at `main.lua:34-40`) and `addToMainMenu` emits Tools › KoPanda with Swatches only;
   no Home tab, no Home or Settings item, no dispatcher action, no `DispatchBridge`, no pre-build.
   The `refused` checks on every other handler stay as they are.
5. Emulator: `spec/emulator/scenarios/2-scenario-swatch.lua`, a userpatch on the pattern of
   `2-scenario-book-close.lua` that opens the swatch once the home has settled; the capture runs with
   `shot_screen = "swatch"` (`spec/emulator/driver.lua:264`). Goldens `swatch-colorsoft` and
   `swatch-paperwhite` written with `KOPANDA_UPDATE_GOLDENS=1` and opened before commit.
6. `HOOKS.md`: every new KOReader module the swatch requires, `night_mode`, the menu registration
   under refusal.

## Surfaces

`kopanda.koplugin/swatch.lua`, `main.lua`, `HOOKS.md`, `spec/unit/swatch_spec.lua`,
`spec/unit/guards_spec.lua`, `spec/emulator/swatch_golden_spec.lua`,
`spec/emulator/scenarios/2-scenario-swatch.lua`, `spec/goldens/swatch-*.png|json`.

## Tests

Written first, each failing before the code.

- `swatch_spec.lua` (C8), on the unit harness the plugin-shell specs use: the Tools › KoPanda
  sub-items in a file manager and a reader include Swatches; its callback shows a `covers_fullscreen`
  swatch on top; a tap closes it; the built widget tree has six panels in look-by-variant order, each
  holding a chip per non-false role with the role and hex in its text and a line per face; the icon
  row holds one item per registry entry; `night_mode` true shows the note; an error injected into
  build, `paintTo` and the tap handler is logged, the swatch is gone and the file manager is on top
  and takes a tap; the same from a reader leaves the reader on top and taking a tap.
- `guards_spec.lua`: the existing "adds no Home tab, Tools entry or action" case
  (`spec/unit/guards_spec.lua:119-145`) keeps its tab and action assertions and replaces
  `contains(ids, "kopanda")` being false with a positive one: the `kopanda` item's `sub_item_table`
  texts are exactly `{ "Swatches" }`, in the file manager's menu and in a reader's (C10, the preserve
  criterion; every other refusal case unchanged) and a new case (C9) asserts Tools › KoPanda holds Swatches alone and opens the swatch, in
  the file manager and the reader, for each of the three shells.
- `swatch_golden_spec.lua` (C11): a fresh capture per profile on the swatch's settled signal matches its
  golden, on the pattern of `home_golden_spec.lua`.

## Edge cases

- The paperwhite profile runs with `color_rendering = false`, so the colour panels render as KOReader's
  luminance greys there; that is the golden, and the grey panels beside them show the explicit greys.
- Too many icons for one row at 1236 px: wrap to a second row; the panels shrink to fit, never clip.
- Opening Swatches from the reader shows it over the book; closing it returns to the book.
