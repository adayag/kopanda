# Generated settings menu, edit layout and launcher management

## Summary

Everything editable on the device: the settings menu generated from the schema into KOReader's native
menu widgets, and the two screens the schema can't express, edit layout and launcher entries, drawn in
the look (direction doc "Settings menus", "Edit layout", "Launcher management").

## Behavior

- `menu.lua` walks the schema and emits KOReader menu tables: toggles for booleans, spinners for ranges,
  radio lists for choices, pickers for icon and path types. Adding a key to the schema adds a menu row
  with no other change; a test proves every schema key appears exactly once.
- The menu is native KOReader styling and is not restyled by a look.
- Edit layout: rows as a list with their columns as boxes showing width shares, up and down arrows,
  tap to select a row revealing Add column, Change widget, Remove row; Add row at the foot; Reset to
  the look's default. A row that would exceed the height budget is refused with a message.
- Launcher entries: a list with icon, label and kind, arrows, remove; Add opens a picker by kind;
  the seventh entry and beyond go into a folder, with the folder's own list reachable from its row.
- "This widget's settings" from a sheet opens that widget's group of the generated menu.
- Every change writes through `settings.lua` and repaints the home once.

## Notes

The two hand-written screens are the only ones; anything else wanting a screen must first justify a
schema key. Which KOReader menu widgets map to which schema types is a specify-time table with
citations.
