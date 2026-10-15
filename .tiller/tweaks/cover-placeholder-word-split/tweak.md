# The cover placeholder breaks a long title word mid-word in a narrow slot

## What

`featured_cover.lua`'s typographic placeholder (home/featured-book/cover, T-ew6y91) sets the title in
`cover_title` inside a `TextBoxWidget`. In a narrow slot (a half-width row at the large text size) a
word wider than the box's inner width is broken mid-word: "PIRANESI" renders as "PIRAN / ESI". Seen in
the widget task's scratch renders during its build and noted in its review (2026-10-15). The full-width
goldens are not affected.

Step `cover_title`'s size down, within the placeholder only, until the widest word of the title fits the
inner width, keeping the four-line cap and ellipsis.

## Why

A split word reads as a typo on the home's most prominent element, and the placeholder is what the
owner's Kindle always shows: CoverBrowser is disabled there.

## Done when

A unit test builds the placeholder in a 253 px column for a title whose longest word is wider than the
inner width at the token size, and the placeholder's lines join back into the uppercase title with no
word split; the four-line cap test still passes; the home goldens are unchanged.
