# Home screen in the emulator

Stage 1 of `design/2026-10-13-kopanda-design.md` §4, drawn to `design/2026-10-13-kopanda-ui-direction.md`.

## Intent

A KoPanda home screen the owner would want to live on, proven in the emulator: the plugin loads under
KOReader, sits over the file browser, draws the home from a schema and two looks, answers tap and hold
the way the direction doc says, and is editable from KOReader's own menus. The Kindle stays on SimpleUI
until the studio exists (design §1b), so this epic's bar is the emulator, with one hand-pushed swatch
screen on the device to fix the token colours.

## Scope

The plugin and nothing else: the dev loop it is tested with, the plugin shell and its safety nets, the
schema and settings store, the two looks with their grey and night variants, the icon registry, the home
layout engine and every stage-1 widget (date, clock, weather, quote, reading stats, featured book,
launcher), the gesture vocabulary and its sheets, the generated settings menu plus the two hand-written
screens (edit layout, launcher entries), and night mode. Series and Authors exist as placeholder entries.

Out: the studio (next epic), any patch into KOReader's file manager (nav bar, bars, library), the
reader, sleep screens, Android.

## Definition of done

Every feature under this epic is done: the home screen renders in both looks on both device profiles
and under night mode with goldens committed, `bin/check` runs the Lua specs and luacheck and is Tiller's
gate, the schema's ten keys drive both the device menus and a JSON dump, the owner has seen the swatch
screen on the Colorsoft and the token values are final, and closing a book in the emulator lands on the
home screen within the paint budget.

## Dependencies

None outside the epic. Inside it, `dev-loop` precedes everything that has a test, `plugin-shell` and
`looks-and-schema` precede the widgets, and the sheets and menus come after the widgets they act on.
Recorded as `depends_on` edges.
