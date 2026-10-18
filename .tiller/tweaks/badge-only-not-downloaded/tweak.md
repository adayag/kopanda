# A book not downloaded shows only the download badge, no Not downloaded chip

Owner's direction, 2026-10-18: "Instead of Not Downloaded we should just rely on the icon on the top right."

## What

Wherever KoPanda draws a book not downloaded (a record with no path, or cwngsync's placeholder,
`library/cwng-placeholders` D1), drop the "Not downloaded" chip and keep the download badge on the cover's
top right as the one sign:

- Library grid, one-author grid and every other cover tile (`kopanda.koplugin/library_tiles.lua:244-310`,
  `foot` and `chip`): no chip on the cover's foot for a book not downloaded. The badge stays. A tile's own
  chip (the one-author grid's "Up next", series-and-authors D5) still draws.
- Series and author rows (`kopanda.koplugin/shelf_rows.lua:386-395`, `book_chip`): no "Not downloaded" chip.
  The precedence becomes Finished, else Up next; the row's cover badge stays (`:483`).
- The book sheet's meta line keeps reading "Not downloaded" (`book_sheet.lua:93-99`): the sheet draws no badge.
- Tokens and type entries used only by the removed chip (`looks/*.lua` `library.not_downloaded`,
  `type.not_downloaded`, the rows' `not_downloaded` chip kind) go with it; tokens the badge or other chips
  still read stay.

## Why

The chip sits on the cover's foot and hides the cover's printed title on real covers (seen in the
`library-placeholder-diner-colorsoft` golden: "CHARLES DICKENS" peeking under it), and it repeats what the
badge already says.

## Done when

- A book not downloaded draws the badge and no "Not downloaded" chip on every tile and row, in both looks;
  unit specs prove it on the tile, the one-author tile with Up next, and a series row (Finished, Up next,
  neither).
- The sheet's meta still reads "Not downloaded".
- The affected goldens are regenerated deliberately and each regenerated PNG is looked at: the only change
  is the chip gone from not-downloaded books (library, series/authors, hold-remote and placeholder goldens).
- `bin/check` is green.
