# Plain hyphen in the weather widget's Wi-Fi line

## What

`kopanda.koplugin/weather.lua:22` draws "Weather needs Wi‑Fi" with U+2011 (non-breaking hyphen), as the
EmptyStates board writes it. Replace it with a plain hyphen, as the launcher and the home sheet already
write "Wi-Fi", and update the comment at `:157`. Regenerate any golden that shows the line, after the
owner has looked at it.

## Why

The look faces lack U+2011: the `home/sheets/hold-and-home-sheet` (T-odbt4w) builder found
`hasGlyph(0x2011)` false for Bricolage Grotesque Bold, and its reviewer confirmed it from the character
maps of all three Bricolage faces and Newsreader. KOReader therefore draws the character from a fallback
font, so the line mixes faces.

## Done when

- No string KoPanda draws contains U+2011.
- The weather spec's fallback-line case expects the plain hyphen.
- Every affected golden is regenerated and seen by the owner.
- `bin/check` is green.
