# Night palettes under KOReader's inversion

## Summary

Each look's night palette shown correctly while KOReader's night mode is on (direction doc "Night mode",
night palettes). KOReader inverts the framebuffer, so the plugin draws the inverse of the night palette
and pre-inverts cover bitmaps, and the panel shows the palette as designed.

## Behavior

- With night mode off, nothing changes.
- With night mode on, every token the widgets read resolves to the inverse of the look's night palette,
  and the featured cover is inverted before painting, so the visible result matches the night boards.
- Toggling night mode (from KOReader's menu or the quick-settings sheet later) repaints the home once.
- Goldens for both looks on the Colorsoft profile with night mode on, captured after inversion so they
  show what the panel shows.

## Notes

Assumption to verify first, before any token work: where KOReader applies the inversion
(`Screen:toggleNightMode` and the framebuffer flag) and that pre-inverting a blitbuffer each paint stays
within the paint budget. If inversion happens somewhere the plugin can't pre-empt, the fallback is to
turn the hardware inversion off while the home is shown and draw the night palette directly; the spec
decides from the spike.
