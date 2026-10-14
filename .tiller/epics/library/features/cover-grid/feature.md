# Cover grid with header pickers in both looks

## Summary

KoPanda's library screen: a three-column grid of covers with a progress strip on each, a header with the
count and the sort and status pickers, the nav bar beneath, in both looks (direction doc "Library").

## Behavior

- The Library tab and launcher entry open this screen instead of KOReader's file chooser; KOReader's
  file browser stays reachable from the home sheet.
- Covers come from the book model; a record without a path shows the not-downloaded mark; tap on a
  downloaded book opens it.
- Sort (recent, title, author, series) and status (reading, finished, all) pickers filter the grid and
  remember their choice per folder.
- Editorial: hairline header, soft cover shadows. Diner: mustard header with the handwritten count,
  outlined covers with hatched-chip progress.
- Pages by rows; the page position is remembered.
- Goldens for both looks on both profiles with the fixture books.

## Notes

Folder navigation (sub-folders of the library root) is a specify-time decision: a folder tile in the
grid, or the file browser for folders only.
