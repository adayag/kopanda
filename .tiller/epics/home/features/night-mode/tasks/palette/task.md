# Night variant, the inverted night palette and the home's rebuild on a variant change

## Approach

The plugin side of night mode: one more variant, one palette accessor, one check in the home's paint.
Paths into KOReader are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`; the feature's "Where
KOReader inverts" section has the citations this task rests on.

1. **`Looks.variant()`** (`kopanda.koplugin/looks.lua`). Keep the colour test first, as it is now
   (`Device.screen:isColorEnabled()`, `frontend/device/generic/device.lua:265-271`): without colour it
   answers `"grey"`. With colour it answers `"night"` when `Device.screen.night_mode` is true
   (`base/ffi/framebuffer.lua:22`, `:476-477`), else `"day"`.
2. **`Looks.palette(look, variant)`**. For `"day"` and `"grey"` it returns `look.palettes[variant]`. For
   `"night"` it returns a table with the night palette's roles. Each `#rrggbb` becomes the
   per-channel inverse (`string.format("#%02x%02x%02x", 255 - r, 255 - g, 255 - b)`), and a `false` role
   stays `false`. The table is built once per look, held in a local weak-keyed cache in `looks.lua`, and
   never written into the look table or its `palettes`. A value that isn't a `#rrggbb` string passes
   through unchanged, so `Looks.color` keeps answering nil for it as it does by day.
3. **Call sites.** Replace every direct `look.palettes[...]` / `ctx.look.palettes[ctx.variant]` read
   outside `looks.lua` and `swatch.lua` with `Looks.palette(ctx.look, ctx.variant)`. Today that is
   `home.lua:175`, `typeset.lua:51` and `widgets/quote.lua:103`. By the time this task starts,
   `featured-book` has merged, so `grep -rn "palettes" kopanda.koplugin/` again and move whatever its
   widget and `featured_cover.lua` added. The swatch keeps reading `look.palettes[variant]`: it shows the
   designed palettes and already says, in night mode, that KOReader is inverting them (`swatch.lua:291-299`).
4. **The rebuild on a variant change** (`home.lua`). `Home:paintTo` already wraps the paint in a `pcall`
   and closes the home from the next tick on a failure. Inside that same `pcall`, before
   `InputContainer.paintTo`, compare `self.ctx.variant` with `Looks.variant()`. When they differ, rebuild
   the way `Home:refresh` does (`self:build()`, then free the old `self[1]`), without `setDirty`: this is
   the repaint `DeviceListener` already asked for (`frontend/device/devicelistener.lua:14-27`). The home
   adds no `onToggleNightMode` handler. The menu's broadcast
   (`frontend/ui/elements/common_settings_menu_table.lua:266-271`) and the Dispatcher route both reach the
   home before `Screen:toggleNightMode()` has run, so a handler would read the old state.
5. **The pending home.** `Home.take_pending` already drops a home built at another size. Extend that
   test: a pending home whose `ctx.variant` isn't `Looks.variant()` is dropped too, so the next show
   builds afresh.
6. **The cover.** Nothing is added for it. KOReader's `ImageWidget` inverts its own rectangle in night
   mode (`frontend/ui/widget/imagewidget.lua:76-77`, `:583-593`), and `featured_cover.lua` builds the cover
   as a plain `ImageWidget`. The test proves the pixels; if `featured-book` built the cover some other
   way (an `IconWidget`, `is_icon`, `original_in_nightmode = false`, or a manual blit), the test fails,
   and this task stops and asks rather than add a second inversion.
7. **HOOKS.md.** Add entries for: `Screen.night_mode` (`base/ffi/framebuffer.lua:22`, `:476-490`, both
   inversion paths); the software path's per-paint inversion (`base/ffi/blitbuffer.lua:840-844`,
   `:1506-1516`, `:1704-1724`, `:1827-1845`); `ImageWidget`'s `original_in_nightmode` and `is_icon`
   (`imagewidget.lua:76-77`, `:583-593`); the toggle's path (`devicelistener.lua:14-27`,
   `common_settings_menu_table.lua:266-271`, `dispatcher.lua:138`, and `:139` for `SetNightMode`); and night mode at start
   (`frontend/device/generic/device.lua:344-347`). The existing `night_mode` key entry
   (`HOOKS.md:127-128`) gains the home's use alongside the swatch's, if the home reads it; the plan reads
   `Screen.night_mode` instead, which is the flag the framebuffer itself keeps.

## Surfaces

`kopanda.koplugin/looks.lua`, `home.lua`, `typeset.lua`, `widgets/quote.lua`, and any `featured-book`
module that reads a palette; `kopanda.koplugin/HOOKS.md`. Specs: `spec/unit/looks_spec.lua`,
`spec/unit/night_mode_spec.lua` (new), `spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Every stub of `Device.screen.night_mode` and `isColorScreen`, and every
`color_rendering` write, is restored in `after_each`, as `looks_spec.lua`'s `variant` block does today.

- `looks_spec.lua` (C1, C2):
  - `variant`: night mode on with colour on gives `"night"`; night mode on with colour rendering off gives
    `"grey"`; night mode off keeps the three existing answers.
  - `palette`: day and grey are the look's own tables. For both looks, every night role's value inverted
    again equals the designed night value, and every `false` role is `false`. Two concrete values are
    written out: Editorial's night paper `#15161a` gives `#eae9e5`, and Diner's night teal `#2f6b65` gives
    `#d0949a`. After `Looks.palette` has run, each look's `palettes` still has exactly `day`, `grey` and
    `night`, and `load_look` of the file gives the same night values.
- `night_mode_spec.lua` (C3 to C5), under the plugin harness:
  - **C3**: every `*.lua` under `kopanda.koplugin/` except `looks.lua`, `swatch.lua` and the look files is
    scanned for the word `palettes` in any form (`.palettes`, `["palettes"]`, a local alias's
    assignment), comments included; none may contain it. Same idea as `hooks_doc_spec.lua`'s source walk.
  - **C4**: a real `Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)` with `bb:invert()` stands in for the
    software-inverted screen, and `Device.screen` is stubbed for colour and `night_mode`. A pixel's
    panel colour is read by clearing the flag on a `bb:copy()` and calling `getPixel`, as `Screen:shot`
    does (`base/ffi/framebuffer.lua:566-581`). Cases:
    1. A home built at night paints the night paper at (1, 1) within one unit per channel.
    2. A home built by day, then `night_mode = true`, then one `paintTo`: night paper. `UIManager.setDirty`
       is stubbed and counts no call from the home.
    3. Back to `night_mode = false`: the next paint gives the day paper.
    4. `Home.prebuild()` by day, flag on, `Home.take_pending()` returns nil.
    5. With colour off, flipping the flag between two paints leaves `self[1]` the same object.
    6. Text goes through the inverted palette too. In a night home, the clock slot's rectangle holds at
       least one pixel within 8 per channel of the designed night ink, and none within 8 of the day ink.
       The quote slot does the same with its `type.quote` role.
  - **C5**: with `featured-book`'s widget fed a stub book whose `cover_bb` is a 2×3 RGB32 buffer filled
    with `#c05030`, the painted cover's centre pixel reads `#c05030` in the panel view. With
    `bookinfomanager` unrequirable, the placeholder's fill reads the designed night `cover` role. Its
    outline reads the designed night `outline` role.
- `failsafe_spec.lua` (C10): a home built by day whose `build` raises once the flag is on: the paint is
  caught, logged, and the home is closed on the next tick with the file manager on top.

## Edge cases

- `Device.screen.night_mode` is nil on the unit harness's dummy screen until a test sets it. `nil`
  counts as off.
- A user who sets `color_rendering` off on the Colorsoft gets `"grey"` with night mode on, the same as
  the Paperwhite, which is what the owner chose.
- A variant change while another window covers the home (KOReader's top menu over it) still repaints the
  home, because `setDirty("all", ...)` marks every window. The paint-time check runs then.
- The rebuild runs inside the repaint, so a slow widget build lengthens that one frame. The goldens task
  measures the night paint.
- Rotation and night mode both changing before a pending home is taken: either check drops it.
- `home.lua` is already 504 lines, past AGENTS.md's 500-line signal, and this task adds about 15 more.
  Splitting it isn't this task's job (minimal change). The split is raised with the owner at plan
  approval, and this task follows whatever they decide.
