# The nav bar: its tokens in both looks and its five tabs

## Approach

The bar as a module both screens draw, with its tokens, its height, its paint and its tabs' runs, and
nothing placed on a screen yet. Repo lines on `main` at `fa0e7dd`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. The feature's "Tokens", "The bar's geometry" and "Where the bar
shows and what it does" are the spec.

1. **Tokens.** In `looks/editorial.lua` and `looks/diner.lua`, a `nav` block after `editor` and the parts
   `type.nav_label` and `type.nav_label_active`, with the feature's values, each line's comment naming its
   board line (NavBar:68-87, NavBarC:70-89) or why it has none, as the look files do
   (`looks/diner.lua:381-417`). Booleans and numbers only besides colour roles and faces, so
   `looks_spec.lua`'s string rule (`:185-212`) needs no new marker. D7's home tokens are `home-band`'s.
2. **`kopanda.koplugin/nav_bar.lua`** (`NavBar`), requiring at load only KOReader widgets, `looks`, `layout`,
   `typeset`, `icons`, `tinted_icon` and `paint`. `launcher_entries`, `settings_menu` and `home` are required
   at call time: `launcher_entries` requires `home` (`launcher_entries.lua:6`), and `home` will reach this
   module through `home_rows`, so a load-time require would loop.
   - `NavBar.TABS`: `{ id, label, icon }` for home, library, authors, history, settings, in that order, labels
     Home, Library, Authors, History, Settings.
   - `NavBar.height(look, screen)`: the feature's height formula in device px, each length through
     `screen:scaleBySize`, the label line from `Typeset.line(look.type.nav_label, "Home", screen:getWidth(),
     ctx)` with `ctx = { look = look, variant = "day" }` and no `text_size` (D8); the active part's line is
     measured too and the taller taken, so the two weights can't disagree. Both the width and the variant
     are needed: `Typeset.line` colours the line from `Looks.palette(ctx.look, ctx.variant)` (`typeset.lua:51`),
     which finds no palette for a nil variant (`looks.lua:63-65`), and a tracked part compares its width
     with `max_width` (`typeset.lua:58-73`), which raises on nil whenever its tracking rounds to a pixel or
     more (Editorial's 0.12 at every size, Diner's 0.04 at the Colorsoft). The variant doesn't change the
     height.
   - `NavBar.new{ look, variant, width, where, listen }`, `where` "home" (Home active) or "file_browser"
     (Library active): a widget `width × NavBar.height(look, Screen)`;
     `dimen.x`/`y` are set by whoever places it. It builds once: each tab's `TintedIcon` and label line.
     `paintTo` follows the feature's drawing order with `Paint.fill`, colours from
     `Looks.color(Looks.palette(look, variant)[role])`. With `listen`, it is an `InputContainer` whose
     `ges_events` take `tap` and `hold` over its `dimen` and call `handle`; without, it takes none (the home
     routes to it).
   - `bar:column_at(pos)`: the tab whose column holds `pos`, or nil outside the bar.
   - `bar:handle(ges)`: outside the bar, false. A `hold` inside: true, nothing run (D3). A `tap` inside a column:
     `NavBar.run(tab.id, bar.where)`, true; inside the side padding, true with nothing run. Anything else: false.
   - `NavBar.run(id, where)`, `where` "home" or "file_browser", in `pcall`, an error logged with the tab's
     name:
     - home: on the home nothing (D5); in the file browser `FileManager.instance.kopanda:goHome()`
       (`main.lua:252-258`; the instance is registered by name, `filemanager.lua:379-389`, `:424`);
     - library, authors, settings: `LauncherEntries.run{ kind = "kopanda", target = id }`
       (`launcher_entries.lua:122-139`, `:158-162`);
     - history: `LauncherEntries.run{ kind = "koreader", target = "history" }` (`:171-189`).
3. **`main.lua`** requires `nav_bar` with the other modules (`main.lua:22-62`), so it loads while the plugin
   root is on `package.path` (`main.lua:5-7`).
4. **`HOOKS.md`:** any KOReader module `nav_bar` requires that `HOOKS.md` doesn't name yet goes under
   "Widget and support modules", with its `file:line`.

## Surfaces

`kopanda.koplugin/looks/editorial.lua`, `kopanda.koplugin/looks/diner.lua`, `kopanda.koplugin/nav_bar.lua`
(new), `kopanda.koplugin/main.lua` (the require only), `kopanda.koplugin/HOOKS.md`. Specs:
`spec/unit/nav_bar_spec.lua` (new), `spec/unit/looks_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `looks_spec.lua` (C1): the nav paths join the identical-paths list (`:83-125`); "give the nav block and
  parts the boards' values" per look, as the editor cases do (`:358-394`), asserting every value of the
  feature's two tables. The existing role, face and type rules (`:185`, `:214`) then cover the new tokens.
- `nav_bar_spec.lua` (C2), in the harness:
  - **Tabs:** `NavBar.TABS` ids, labels and icons in order; every icon resolves through `Icons.path`.
  - **Height:** per look, equal to the formula from the tokens and a measured label line, at the unit screen
    and inside `harness.at_colorsoft`; the same with `text_size` stored as small, medium and large; the two
    looks' heights differ (the reason for the relayout).
  - **Columns:** five, equal to `Layout.columns(width − 2 × padding_x, five shares of 1, 0)`, filling the
    width less the padding.
  - **Paint:** painted into a `Blitbuffer` at the Colorsoft, sample pixels: Editorial's 1 px ink edge across
    the top and the 3 px ink rule over the active column only; Diner's 4 px ink edge, the mustard fill in
    the active column only, a 3 px outline divider at the right of columns 1-4 and none at 5, the band fill
    elsewhere; once in night (night palette inverted, `looks.lua:63-76`) and once in grey.
  - **Tap:** with `NavBar.run` spied, a tap at each column's centre runs that tab's id once with the bar's
    `where` and returns true; a tap above the bar returns false and runs nothing.
  - **Runs:** with `LauncherEntries.run` stubbed, library, authors and settings pass `{ kind = "kopanda",
    target }`, history `{ kind = "koreader", target = "history" }`; home with `where = "home"` calls nothing,
    with `where = "file_browser"` calls the file manager's `kopanda:goHome()` once (spied); a run whose
    callee raises is logged and `handle` still returns true.
  - **Hold:** a hold on any column returns true and runs nothing; a swipe on the bar returns false.
  - **Listening:** with `listen`, a `Gesture` event sent to the bar's container reaches `handle`; without,
    the bar has no `ges_events`.
- `night_mode_spec.lua` runs unchanged: its scan for the word `palettes` covers `nav_bar.lua`.
- `main_requires_spec.lua` and `hooks_doc_spec.lua` run unchanged and pass with `nav_bar` required and named.

## Edge cases

- A look whose label face file fails to load: `Typeset` raises (`typeset.lua:22-30`); `NavBar.height` and
  `new` raise to their callers, which the next two tasks guard (a blank band).
- A label wider than its column (a future label, or a narrow landscape screen): `Typeset.line`'s `max_width`
  cuts it rather than spilling into the next tab.
- Diner's grey palette has `band` and `mustard` as greys (`looks/diner.lua:57-74`); the active block stays
  distinct from the band since `looks_spec.lua:171` keeps roles that differ by day apart in grey.
- No timers and no animation: the bar builds when its screen builds and paints when asked.
