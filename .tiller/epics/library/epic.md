# KoPanda's library replaces the file browser

Stage 5 of `design/2026-10-13-kopanda-design.md` §4 and §7; direction doc "Library", "Context menu",
"Noted for after the MVP".

## Intent

The last of KOReader's default screens the owner sees daily, replaced: a cover grid with progress strips
and header pickers, a context menu on hold, and the Series and Authors screens the home has promised
since stage 1. Built on a book model that never assumes a local file, so Calibre-Web-NextGen can become
a source later without a rewrite.

## Scope

Four features: the book model and its caches, the cover grid, the context menu, and the series and
author screens. Out, noted for later: CWNG as a source, to-be-read and collections, consuming icon
packs.

## Definition of done

All four features done: the Library tab opens KoPanda's grid in both looks on both profiles with
goldens, hold on a book, a folder or empty space opens the right menu, Series and Authors list real data
and the placeholders are gone, and every patched KOReader function is in `HOOKS.md`.

## Dependencies

The book model builds on the featured book's access (`home/featured-book`); the grid sits over the nav
bar (`nav-bar/nav-bar`); the context menu uses the sheet component (`home/sheets`); Series and Authors
replace the launcher's placeholders (`home/launcher`). Recorded as `depends_on` edges.
