# The quick-settings panel: its tokens in both looks, its state and its paint

## Approach

The sheet's content, drawn and laid out from the look and the device's real state, opened by
`QuickSettings.open`, with its areas in place but no control acting yet (`controls` wires them). Starts after
`bars/quick-settings/sheet-body`. Repo lines on `main` at `e6f2912`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. The feature's "What the sheet shows", "The panel" and "Tokens" are
the spec.

1. **Open fact F1 first: the minus and plus glyphs.** In a scratch case under the harness at the Colorsoft,
   set `Typeset.line` with each look's `quick_button` part (step 2's values, entered first in a scratch
   table) on "−" (U+2212), on "+" and on U+0378 (unassigned in Unicode; not U+E000, which the fallback
   `nerdfonts/symbols.ttf`, `frontend/ui/font.lua:114`, maps), paint each into a `Blitbuffer` and compare.
   Candidates: (a) "−" and "+" each differ from U+0378 in both looks, so they render; (b) one matches U+0378
   in a look, the missing-glyph box. For (a) the buttons draw the text. For (b) add Lucide's `minus` and `plus` (ISC,
   `icons/LICENSE-lucide.txt`) to the registry, `used_in = { "quick settings" }`, stroke 2 and black like
   their siblings, drawn tinted in the part's colour at its line height, in both looks; if `bars/title-bar`
   has already added `plus`, add `"quick settings"` to its `used_in` instead. A new registry file means this
   task also regenerates `studio/src/catalog.json` (`npm run catalog` in `studio/`) and the two swatch goldens
   (`KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/swatch_golden_spec.lua`), opening each PNG. Record which
   in the module's header comment and the PR.
2. **Tokens.** In `looks/editorial.lua` and `looks/diner.lua`: `sheet.quick_settings_band_color` beside the
   other band colours (`looks/diner.lua:124-126`), a `quick_settings` block after `sheet`, and the parts
   `type.quick_label`, `type.quick_button`, `type.quick_cell` after the sheet parts, with the feature's two
   tables, each line's comment naming its board line or source, as the look files do.
3. **`kopanda.koplugin/quick_settings.lua`**, requiring at load KOReader's `device`, `ui/network/manager`,
   `ui/geometry`, `ffi/blitbuffer`, `logger`, `ui/time`, and KoPanda's `looks`, `typeset`, `icons`,
   `tinted_icon`, `paint`, `layout`, `settings`, `sheet`, `launcher_entries`:
   - `QuickSettings.state()`: `{ battery, brightness, warmth, cells }`, every read in its own `pcall`, a
     raising one logged and that control marked greyed: `battery` the capacity when `Device:hasBattery()`,
     else nil; `brightness` nil without `Device:hasFrontlight()`, else `{ value, min = 0, max = fl_max }` from
     `powerd:frontlightIntensity()` (`frontend/device/generic/powerd.lua:126-133`); `warmth` nil without
     `Device:hasNaturalLight()`, else `{ value = powerd:toNativeWarmth(powerd:frontlightWarmth()), min =
     fl_warmth_min, max = fl_warmth_max }` (`:169-175`, `:233-235`); `cells` the six of the feature's table,
     each `{ id, label, icon, on, greyed }`, greyed by `LauncherEntries.available` on the entries the table
     names (`launcher_entries.lua:59-80`), the radio from `NetworkMgr:isWifiOn()`
     (`frontend/ui/network/manager.lua:182-185`).
   - `body(bctx, content_w)`: the feature's layout from `bctx.look.quick_settings` and the three parts through
     `Typeset.line` with `bctx` (so `text_size` applies, `typeset.lua:24`), returning a widget that paints its
     fills, outlines, lines and icons with `Paint.fill`/`Paint.border` (`paint.lua:10-32`) and `TintedIcon`,
     colours from `Looks.palette(bctx.look, bctx.variant)` through `Looks.color` (`looks.lua:63-89`), and the
     areas: minus and plus per bar, one per cell, each with its `id` and no handler yet.
   - `QuickSettings.open(opts)`: the feature's ctx and spec, `Sheet.show(spec, ctx, opts)`
     (`sheet.lua:507-521`); the header's aside "Battery N%".
4. **`main.lua`** requires `quick_settings` with the other modules (`main.lua:22-62`).
5. **`HOOKS.md`:** under "Widget and support modules" (`HOOKS.md:1079`), each KOReader module
   `quick_settings` requires that it doesn't name yet; a new section "The quick-settings sheet" with the
   reads of step 3 (the powerd reads and scales, `frontend/device/generic/powerd.lua:7-11`, `:36-39`,
   `:126-133`, `:169-175`, `:233-239`, `:254`; `frontend/device/kindle/powerd.lua:8-11`;
   `frontend/device/sdl/powerd.lua:4-12`, `:28-33`; `isWifiOn`; the `night_mode` and `lock_rotation`
   keys; `Device:hasFrontlight`, `hasNaturalLight`, `hasBattery`). `controls` adds the actions to it.

## Surfaces

`kopanda.koplugin/looks/editorial.lua`, `kopanda.koplugin/looks/diner.lua`, `kopanda.koplugin/quick_settings.lua`
(new), `kopanda.koplugin/main.lua` (the require only), `kopanda.koplugin/HOOKS.md`; under F1 (b) only,
`kopanda.koplugin/icons.lua`, `kopanda.koplugin/icons/minus.svg` and `plus.svg`, `studio/src/catalog.json`,
`spec/goldens/swatch-*.{png,json}`. Specs: `spec/unit/quick_settings_spec.lua` (new), `spec/unit/looks_spec.lua`,
and under F1 (b) `spec/unit/icons_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `looks_spec.lua` (C1): the new paths join the identical-paths list (`spec/unit/looks_spec.lua:83-125`); a
  "give the quick settings block and parts their values" case per look asserting every value of the feature's
  two tables; the existing role, face and type rules (`:185-233`) then cover the new tokens.
- `quick_settings_spec.lua` (C4), in the harness, the device's capability functions and powerd fields stubbed
  and restored where each case makes them:
  - **Opens** one sheet named `quick_settings` over a shown home, and over `harness.show_fm()` with no home;
    its settled signal names `quick_settings`.
  - **Header:** "Quick settings"; "Battery 84%" with `getCapacity` stubbed to 84; no aside with
    `Device.hasBattery` false.
  - **Bars:** with `fl_max = 24` and intensity 12, the value line reads "12" and the fill spans half the bar's
    inner width (sampled pixels); light off reads "0", no fill; with `fl_warmth_max = 24` (and `warmth_scale`
    set as `new` sets it, `powerd.lua:38`) and warmth 4 native, "4" and a sixth; no frontlight hides both
    sections, no natural light only warmth, and the grid moves up.
  - **Cells:** order, labels and icons; Wi‑Fi on and filled with `emulator_fake_wifi_connected` true, "Wi-Fi
    off", `wifi_off`, unfilled with it false; Night and Rotation lock filled exactly when their settings are
    true (`G_reader_settings` restored); Sync books greyed with no `cwngsync`, not greyed with a module named
    `cwngsync` loaded (`PluginLoader.loaded_plugins` stubbed) and `cwngsync_sync_now` registered
    (`Dispatcher:registerAction`, removed after, `frontend/dispatcher.lua:665-690`); Sleep and Wi‑Fi each greyed
    when `LauncherEntries.available` refuses their entries (stubbed for the case: KOReader's Dispatcher fixes
    an action's `condition` when it loads, `frontend/dispatcher.lua:94`, `:124`, `:689-695`, so a `Device`
    stub can't reach it); a greyed cell's label pixels in
    muted and its inside not filled; a raising `isWifiOn` greys Wi‑Fi and logs once.
  - **Paint:** at the Colorsoft into a `Blitbuffer`, per look, day, night and grey: Editorial's 1 px ink
    outlines, hairline section rules and ink fills; Diner's band header, 2 px outline-coloured outlines,
    mustard level fill on paper and the on cell in ink.
  - **Fit:** at the Colorsoft, at `text_size` small, medium and large, portrait and with width and height
    swapped (the screen stubs of `at_colorsoft`, `spec/plugin_harness.lua:151-178`, swapped), the sheet's box
    is no taller than the screen less the bottom inset (`sheet.lua:271`), its top below the screen's top
    (y > 0), and nothing is logged as too tall. (A too-tall body is pinned at y 0, so "top ≥ 0" alone can't
    fail.)
  - **Areas:** ten, each inside the panel, none overlapping: the four buttons and the six cells.
- `night_mode_spec.lua` (C4) runs unchanged: its scan for the word `palettes` covers `quick_settings.lua`.
- `main_requires_spec.lua` and `hooks_doc_spec.lua` (C11) pass with the module required and its modules and
  keys named.

## Edge cases

- `getCapacity` caches for a minute (`frontend/device/generic/powerd.lua:254-270`); the aside shows what it
  returns, which is the best KOReader knows.
- The emulator's scales are 0–100 (`frontend/device/sdl/powerd.lua:4-12`): values read "50", which is right for
  that device.
- A label wider than its cell at `large` ("Rotation lock" in Diner's heavy face) is cut by `max_width`;
  the fit case shows whether the grid still fits.
- A face that fails to load: `Typeset` raises (`typeset.lua:22-30`), `body` raises, and the sheet's failure
  path closes it (C2).
- No timers, no animation: state is read when the sheet lays out.
