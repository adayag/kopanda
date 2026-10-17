# TintedIcon re-renders its SVG on every construction

Found by the 2026-10-17 efficiency review (`.tiller/reviews/2026-10-17-efficiency-review.md`, finding 2).
Not measured on a device; the plugin has not been installed on the Colorsoft yet.

## What

`TintedIcon:init` (`kopanda.koplugin/tinted_icon.lua:23-37`) calls `RenderImage:renderSVGImageFile`
on every construction, then allocates a BB8 mask, alpha-blits the render onto it and inverts it. The mask
depends only on the icon file and its size; the colour is applied at paint (`:41-51`). Nothing caches
the mask, so the same file at the same size is read from disk, parsed and rasterised again on every
build. KOReader's own `ImageWidget` caches the same work in `ImageCache` keyed by file and size
(`frontend/ui/widget/imagewidget.lua:147-160` at `e1fe1ac`); `TintedIcon` bypasses it.

Callers on hot paths: the nav bar (5 tabs, `nav_bar.lua:119`) and the launcher (6 entries by default,
`widgets/launcher.lua:145`) in every home build; the nav bar again in every file-manager layout
(`fm_nav.lua`, every book close); one per sheet row (`sheet.lua:237`); the title bar's plus icon
(`title_bar.lua:301`). About 11 renders per wake and 16 per book close.

Keep a module-level mask cache in `tinted_icon.lua` keyed by file and size. `TintedIcon:free` (`:53-58`)
must not free a cached mask. A failed render stays uncached. The cache is bounded by the icon registry
times a few sizes, a few KB each.

## Why

Each render is a flash read, an XML parse, a rasterise, two allocations and three blits on the Kindle's
ARM core, repeated with identical inputs on every wake, every book close and every sheet open. It is the
largest fixed cost in a home build after the Statistics read, and it sits on the two hottest paths.

## Done when

- A unit spec spies on `RenderImage.renderSVGImageFile`: two `TintedIcon:new` with the same file and size
  render once; freeing the first still lets the second paint; a different size renders again. The spec
  fails on the current code.
- A `HomeRows.build` run twice under the same ctx renders each icon once.
- `bin/check` is green and every golden is pixel-identical.
