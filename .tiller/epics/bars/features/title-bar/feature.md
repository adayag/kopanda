# File manager title bar in look tokens

## Summary

KOReader's file manager title bar redrawn from the look: the folder or screen name in the display face,
a count, and the sort and status pickers the library board shows in its header.

## Behavior

- Wraps `TitleBar.new` (`frontend/ui/widget/titlebar.lua`; SimpleUI's patch at `infra/sui_patches.lua:1491`)
  for the file manager only; the reader's title bar is untouched (reader out of scope).
- Editorial: hairline under a serif title with a small-caps count. Diner: a mustard band with the count
  in the handwritten face and outlined chips for the pickers.
- The pickers call KOReader's own sort and filter menus until the library epic replaces them.
- `HOOKS.md` gains the patched constructor; goldens on the file browser in both looks.

## Notes

What the "status" picker filters before the library's book model exists is KOReader's own status filter
if it exposes one, else the picker is absent until stage 5; specify-time with citations.
