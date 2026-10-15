# One paint module for the fill, border and shadowed-box helpers

## What

Three modules carry their own RGB32-aware fill and border helpers and a box with shadow, fill and
outline: `widgets/quote.lua` (about :51-65), `featured_cover.lua` (about :92-110) and
`widgets/featured.lua` (about :51-87), as of the home/featured-book (F-e8jz6h) review branch. Extract
them into one `kopanda.koplugin/paint.lua` and use it from all three. A pure refactor: no behaviour
change.

## Why

The duplication will spread to every new widget, and `widgets/featured.lua` (508 lines) and `home.lua`
(519) are past AGENTS.md's 500-line signal. The widget task's review (2026-10-15) named this as the
natural cut, taking about 60 lines out of `widgets/featured.lua`.

## Done when

The three modules paint through `paint.lua` with no local copies of those helpers; `bin/check` passes
with every golden unchanged and no golden regenerated; `widgets/featured.lua` is under 500 lines.
