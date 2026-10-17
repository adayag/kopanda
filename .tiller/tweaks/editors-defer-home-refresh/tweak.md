# Each edit in Edit layout or Launcher management rebuilds the hidden home

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 10). Traced in code at KOReader
`e1fe1ac`, not measured on a device.

## What

Every accepted edit (move, add, remove, width, reset) rebuilds the home underneath the editor:
`edit_layout.lua:112-136` runs two `Layout.overflow` passes (`:120`) and then
`Home.shown:refresh()` (`:132-134`); `launcher_manage.lua:121-141` does the same (`:132-135`). The
editor is `covers_fullscreen` (`editor.lua:57`), so KOReader's `_repaint` never paints the rebuilt
home (`frontend/ui/uimanager.lua:1305-1316`), and the editor's `"full"` close (`editor.lua:68`)
repaints it anyway. `Editor` builds a new ctx per rebuild (`editor.lua:240-246`), so
`Typeset.measured`'s identity check never carries a measurement across edits.

While an editor is shown, mark the home stale and rebuild it once when the editor closes. Keep the
accepted rows' overflow in the editor's state, so each edit measures only the new rows.

## Why

A full home build (stats, sidecar, cover, quote, tracked text, `NavBar.new`) plus a measurement pass
(`layout.lua:182-226`) of both the new rows and the previous rows, on every tap in an editing session,
for a screen nobody can see. An estimated 0.4 to 1.5 s per tap on the Kindle. Editing is rare, but
each session is many taps in a row.

## Done when

- A unit spec with a shown home and `HomeRows.build` stubbed: three moves in each editor build the
  home 0 times while the editor is up and once after Done. It fails on the current code.
- A unit spec counts `Layout.overflow` per accepted layout edit after the first: 1.
- `bin/check` is green and the goldens are unchanged.
