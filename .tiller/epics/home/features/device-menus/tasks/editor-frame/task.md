# The full-screen editor frame, its look tokens and its icons

## Approach

The frame both hand-written screens draw in, the `editor` tokens in both looks, and the three icons the
screens need. Paths into KOReader are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`; repo lines
are on `main` at `ca26783`. This task starts after `sheets` has merged (the feature's "Order"); the tweak
`split-home-lua` already has. It changes no `sheets` module, but its failure cases sit beside the sheets' in
`failsafe_spec.lua`, so read that file as `sheets` left it first.

1. **Tokens.** Add the `editor` block and the nine `editor_*` type parts to `looks/editorial.lua` and
   `looks/diner.lua`, exactly the paths and values of the feature's "Tokens" tables, each value with its
   board line in a comment (Editorial) or "no board" and the direction doc's reason (Diner). Read
   `looks_spec.lua`'s rules first (`:83` identical paths, `:173` colours only by role, `:202` type part
   shape) and keep every value inside them. Cards cast the look's existing `shadow.tile`
   (`looks/diner.lua:83`, `looks/editorial.lua:83`); no shadow token is added.
2. **Icons.** Add `icons/chevron_up.svg`, `icons/chevron_down.svg` and `icons/action.svg`: Lucide's
   `chevron-up`, `chevron-down` and `zap`, coordinates rounded, `stroke="#000000"`,
   `stroke-width="2"`, as `icons/sun.svg` is written. Register each in `Icons.entries` (`icons.lua:13-54`)
   with a comment naming it as Lucide's (ISC, `icons/LICENSE-lucide.txt`), as `sun` has (`:37`):
   - `chevron_up`, label "Move up", `used_in = { "edit layout", "launcher management" }`;
   - `chevron_down`, label "Move down", the same `used_in`;
   - `action`, label "Action or plugin entry", `used_in = { "launcher", "launcher management" }`.

   `close` (`icons.lua:52`) gains `"edit layout"` and `"launcher management"` in its `used_in`.
3. **`kopanda.koplugin/editor.lua`**, an `InputContainer` subclass, `covers_fullscreen = true`:
   - `Editor.show(spec, opts)`: `spec = { screen, aside, title, body, foot }`, where `screen` is the
     settled signal's name (`edit_layout` or `launcher`) and `body` and `foot` are functions
     `(ctx, width) -> rows`, each row a list of controls `{ kind, rect-in-row, draw, run }`. `kind` is
     one of `card`, `button`, `arrow`, `box`, `kind_button`, `caption`, `note`, `row`. `opts.started`
     is the `time.monotonic()` its opener took, as the sheet takes it.
   - It builds its ctx as `HomeRows.build` builds the home's (`home_rows.lua:84-91`), with no `home`, reading the look,
     variant and text size now.
   - **Drawing:** paper over the whole screen; the header: aside (`editor_aside`) over title
     (`editor_title`) on the left, the Done button on the right baseline-aligned to the title's foot
     (EditLayout:19-25), the header band (Diner) or none (Editorial), then the header rule. Then the
     body's rows from `body_gap` below the rule, then the foot pinned to the bottom with
     `padding.bottom`. Text through `Typeset.line(part, text, max_width, ctx)` (`typeset.lua:49`), icons
     as `TintedIcon`s (`tinted_icon.lua:23-60`), fills and borders through the RGB32 calls for a colour
     (`home_rows.lua:16-25`'s `fill`). Every colour through `Looks.palette(ctx.look, ctx.variant)`
     (`looks.lua:63`), never by name.
   - **Shadows:** a card with `shadow.tile.color` gets a filled rectangle offset by its `x` and `y`,
     drawn first; Editorial's is `false`, so none.
   - **Too tall:** rows of the body that don't fit above the foot are left out, logged once.
   - **Input:** `ges_events.TapEditor`, a tap anywhere. The first control whose rect contains the
     point runs; no control, nothing. A disabled control runs nothing. Holds, swipes and `hold_release`
     have no handler. `key_events.Close` on `Device.input.group.Back` only when `Device:hasKeys()`, and
     `onBack` and `onClose` close, as the sheet binds them (`sheets/feature.md:224-226`).
   - **`Editor:refresh()`** rebuilds from the spec's functions and calls `setDirty(self, "ui")` once.
   - **Show and close:** `UIManager:show(editor, "full")`, `UIManager:close(editor, "full")`
     (`home.lua:200`, `:42`). `Editor.shown` is the one shown; showing another closes it first.
   - **Settled:** from `tickAfterNext` after show, once the first paint has happened,
     `UIManager.event_hook:execute("KoPandaSettled", { screen = spec.screen, paint_ms })`, as `settle`
     sends the home's (`home.lua:149-163`). A failed paint sends nothing.
   - **Failing safe:** `show`, the build, `paintTo`, the gesture and key handlers each in `pcall`; a
     failure is logged and closes the editor, from the next tick for a paint (`home.lua:283-297`).
4. **`main.lua`** requires `editor` (`main.lua:22-48`).
5. **HOOKS.md:** `covers_fullscreen` and `_repaint` are there already (`HOOKS.md` "covers_fullscreen in
   UIManager:_repaint"); add the editor's `"full"` show and close beside the home's, and its Back
   binding beside the sheet's.

## Surfaces

`kopanda.koplugin/looks/editorial.lua`, `looks/diner.lua`, `icons.lua`, `icons/chevron_up.svg`,
`icons/chevron_down.svg`, `icons/action.svg` (new), `editor.lua` (new), `main.lua`, `HOOKS.md`. Specs:
`spec/unit/looks_spec.lua`, `spec/unit/icons_spec.lua`, `spec/unit/editor_spec.lua` (new),
`spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines
(`grep -v 'ffi\.\|dlopen\|lib_\|has monolibtic\|\[ RUN\|\[       OK'`).

- `looks_spec.lua` (C4): the existing identical-paths, role and type-part rules now cover the new
  tokens; add one case per look checking a handful of the board's values (Editorial
  `editor.header_rule_width` 1, `editor.card_outline_color` `hairline`, `type.editor_title.size` 34;
  Diner `editor.header_band_color` `band`, `editor.selected_fill_color` `mustard`).
- `icons_spec.lua` (C4): the canvas list (`:37-49`) gains `action`, `chevron_down` and `chevron_up`; the
  existing per-file cases (stroke width 2, no `currentColor`, opaque black render) then cover the three
  files.
- `night_mode_spec.lua` (C4) passes unchanged: `editor.lua` never contains the word `palettes`.
- `editor_spec.lua` (C5), over a shown home in the harness, with a spec of a two-card body and a
  one-button foot whose `run`s are spies:
  - **Drawing, each look:** paint into a `Blitbuffer`; the header's rule is in the look's
    `header_rule_color` at the rule's row; Diner's header band pixel is `band`, Editorial's header pixel
    is `paper`; the Done button's border pixel is `button_outline_color`; a Diner card's shadow pixel is
    `shadow`.
  - **Taps:** a tap on card 2 runs its `run` once; a tap on blank paper runs nothing; a tap on Done
    closes the editor (not on the stack) and the home is on top again; a disabled control runs nothing.
  - **Ignored:** a hold, a `hold_release` and a swipe run nothing and leave it shown.
  - **Keys:** with `Device.hasKeys` stubbed true, the Back key closes it; stubbed false, no `Close` key
    binding exists; a `Back` event closes it either way.
  - **Paint once:** `show` calls `UIManager:show` with `"full"` and schedules no `scheduleIn`;
    `refresh` calls `setDirty` once with `"ui"`.
  - **Settled:** exactly one `KoPandaSettled` with its `screen` and a numeric `paint_ms` after the first
    paint, from `opts.started` when given.
  - **Too tall:** a body of 40 cards keeps those that fit and logs once.
- `failsafe_spec.lua` (C15): an editor whose body raises inside `show`, one whose paint raises, and one
  whose control's `run` raises: each logged, no editor on the stack, the file manager handling input.
- `hooks_doc_spec.lua` (C16) passes: `editor` collides with no KOReader module path.

## Edge cases

- The editor opens over the reader too (the menu exists there, `main.lua:310`). It reads no home, so it
  draws the same; the home beneath, if any, isn't painted while it is up (`uimanager.lua:1305-1316`).
- Night mode toggled while it is up: rebuild inside `paintTo` when `ctx.variant ~= Looks.variant()`,
  with no `setDirty`, the home's rule (`home.lua:272-281`).
- A rotation while it is up: the editor rebuilds at the new size on its next paint when
  `Screen:getSize()` differs from its `dimen`.
- A look missing a token (a later look file): `looks_spec.lua`'s identical-paths rule catches it before
  the device does.
