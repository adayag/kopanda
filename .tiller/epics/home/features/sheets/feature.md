# Tap acts, hold opens a sheet

## Summary

The gesture vocabulary (design §1a; direction doc "Gestures", "Hold on the book", "Hold on empty
space") and the sheet component both looks draw it with: hold on a widget opens that widget's sheet,
hold on empty space opens the home's own sheet, and every sheet row is an action or a submenu.

## Behavior

- One sheet component, styled from the look: Editorial's paper panel under a 2 px rule, Diner's outlined
  box with a hard shadow and a coloured header band.
- Hold on the featured book: header (small cover, title, author, progress, last opened), then Open,
  Book details (KOReader's), Read status › (KOReader's), More by this author › (a list of the author's
  books, placeholder until the library's author index), Feature a different book (a picker over recent
  books), This widget's settings.
- Hold on empty space: Edit layout (stub until `device-menus`), Open the file browser, Refresh weather
  with its age, Wi‑Fi with its state, KoPanda settings, Sleep.
- Hold on any other widget opens that widget's settings (generated, so a stub until `device-menus`).
- A sheet closes on tap outside, on an action, or on KOReader's back; it paints once and never animates.
- Goldens of both sheets in both looks on the Colorsoft profile.

## Notes

Assumption to verify first: a hold on the full-screen home widget does not fall through to the file
manager's own hold handling. "Feature a different book" writes `featured.pinned`.
