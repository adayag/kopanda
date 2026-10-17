# Specs plan goldens only where a look's structure differs or a board draws the state

## What

`AGENTS.md`'s Testing section gains a rule for planning goldens in a feature spec:

- **One look by default.** A screen gets a golden in both looks only when Diner and Editorial differ in
  structure (layout, frame, which parts are drawn), not only in colour, type or tokens. A screen whose looks
  differ only in tokens gets one golden, in Diner. `looks_spec.lua` keeps checking both looks' token paths.
- **No golden for an undrawn state.** A state no board draws (a variant such as library/context-menu's
  not-downloaded book, or the Editorial folder and empty-space sheets) gets no golden. The owner judges it on
  the emulator during the feature's manual check, and its behaviour stays covered by unit specs.
- Existing goldens stay. The rule applies to specs written after it lands.

## Why

Owner decision, 2026-10-17, after library/context-menu (F-l0kw8m) added eight goldens. Four of them had no
board to compare against (the remote book in both looks, Editorial's folder and empty-space sheets), and two
looks doubled every screen. Each golden costs a regeneration, an eyeball pass at review and at C16, and
emulator time on every full `bin/check`. The owner accepts the tradeoff: an Editorial-only layout regression
or a break in an undrawn state is caught by eye at the manual check instead of by a capture.

## Done when

`AGENTS.md`'s Testing section states both rules and that existing goldens are kept. The next feature spec that
plans goldens follows them, and its Goldens section names each golden's board and why a second look is
captured when it is.
