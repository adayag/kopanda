# Five-tab nav bar in both looks

## Summary

A bottom bar with Home, Library, Authors, History and Settings, drawn from the look (direction doc
"Nav bar"), present on the home screen and on KOReader's file browser screens.

## Behavior

- The bar wraps `FileManager.setupLayout` (`frontend/apps/filemanager/filemanager.lua:116`) the way
  SimpleUI does (`infra/sui_patches.lua:423` at 61b71da, MIT) to reserve its height beneath the file
  chooser, and the home widget reserves the same height.
- Editorial: a hairline bar with small-caps labels and a 3 px rule over the active tab. Diner: a teal
  band with ink dividers and the active tab as a mustard block.
- Tabs resolve through the launcher's entry resolution; Authors shows the placeholder note until
  `library/series-and-authors`.
- Hold on the Settings tab is reserved for the quick-settings sheet (question Q-irxgmk).
- `HOOKS.md` gains the patched function with its citation; goldens for both looks on both profiles on
  the home and on the file browser.

## Notes

The first feature that can break on a KOReader upgrade; the upgrade chore in design §8 starts here.
Whether the bar also appears over KOReader's history and collections screens is specify-time.
