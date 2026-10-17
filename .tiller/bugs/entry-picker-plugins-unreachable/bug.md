# The entry picker's Plugin sheet shows 13 of 28 plugins and the rest can't be picked

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, the "Dropped, downgraded or folded" list).
The row count was reproduced on 2026-10-17 in the unit harness at the Colorsoft's size: a sheet of 28
label-only rows keeps 13 in Diner and 13 in Editorial. Not reproduced on a device.

## Reproduction

1. On the home, open the launcher's add-an-entry picker and choose Plugin.
2. `entry_picker.lua:218-241` builds one row per loaded plugin that isn't KoPanda or doc-only, sorted
   by label, and hands them to `sheet`. The pinned build's headless file manager loads 28 bundled
   plugins (`studio/src/catalog.json`).
3. `SheetLayout.build` keeps as many rows as fit above the screen's foot and frees the rest
   (`sheet_layout.lua:296-323`), with no scroll or paging. The sheets feature accepts that generally
   (`.tiller/epics/home/features/sheets/feature.md:143`), for lists the design bounds.
4. At 1264 by 1680 the sheet keeps 13 rows. Plugins after the 13th by label (roughly the second half
   of the alphabet) are never shown.

## Expected

Every loaded plugin can be picked as a launcher entry.

## Actual

Only the first 13 by label can. The sheet logs "leaves out 15 rows that don't fit" once
(`sheet.lua:46-47`) and shows no sign on screen.

## Fixed when

- The Plugin sheet reaches every loaded plugin: paging within the sheet, a second sheet, or KOReader's
  own `Menu`. Which one is the owner's call; the fix states it in the PR and keeps the sheets feature's
  no-scroll rule for bounded lists.
- A unit spec stubs 28 loaded plugins at the Colorsoft's size and picks the last one by label; the
  entry handed to `on_entry` names that plugin. It fails on the current code.
- `bin/check` is green and the sheet goldens are unchanged.
