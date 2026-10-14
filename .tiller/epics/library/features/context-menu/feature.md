# Hold on a book, a folder or empty space

## Summary

The gesture rule applied to the library (direction doc "Context menu"): hold opens a sheet whose actions
depend on what was held.

## Behavior

- Hold on a book: Open, Book details, Read status ›, More by this author ›, Add to the home (feature
  it), and Delete behind a confirm.
- Hold on a folder tile: Open, Set as library root, Hide.
- Hold on empty space: this folder's sort and status, Display (grid density), Refresh covers.
- Drawn with the sheet component in both looks; goldens on the Colorsoft profile.

## Notes

Delete goes through KOReader's own file operations so sidecars and history stay consistent;
specify-time with citations into `filemanager.lua`'s delete path.
