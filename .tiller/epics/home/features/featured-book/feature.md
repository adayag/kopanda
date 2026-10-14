# Featured book with cover and progress

## Summary

The one widget with real plumbing: the most recently opened book that still exists, its cover from
KOReader's bundled CoverBrowser cache, its progress from the sidecar, drawn in the look's cover frame
(design §5 Widgets; direction doc "Featured book", "Covers").

## Behavior

- The featured book is the most recent entry in KOReader's reading history whose file exists, unless
  `featured.pinned` names another.
- Cover and metadata come from `BookInfoManager:getBookInfo(filepath, get_cover)`
  (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325`); when no cover is cached yet the widget shows
  title and author with a typographic placeholder and asks for extraction, repainting when it arrives.
- Progress is the sidecar's `percent_finished` (`frontend/docsettings.lua:221`); time left uses the
  Statistics plugin's reading speed and falls back to pages left.
- Covers fit inside the frame, centred, paper showing on the short side; titles cap at two lines.
- Tap opens the book. With no book ever opened the slot shows the first-run state with an Open the
  Library button.
- Goldens for both looks on both profiles with a fixture book.

## Notes

Assumption to verify first: CoverBrowser is enabled in the test profile and on the Kindle. Hold on the
cover is `sheets`. The stage-5 book model will later supply the same data by book id; this feature reads
KOReader directly and should keep that access behind one function so the swap is local.
