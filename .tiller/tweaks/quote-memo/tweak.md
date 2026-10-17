# The quote is shaped and rendered on every home build

Found by the 2026-10-17 efficiency review, second pass
(`.tiller/reviews/2026-10-17-efficiency-review-pass2.md`, finding 6). Traced in code at KOReader
`e1fe1ac`, not measured on a device; the buffer size is an estimate.

## What

`compose` (`kopanda.koplugin/widgets/quote.lua:73-137`) makes a new `TextBoxWidget` on every home
build. `Typeset.measured` (`:141`, `typeset.lua:103-117`) keeps it only from `height` to `build` within
one build and frees it on the next. KOReader's `TextBoxWidget` shapes the text with xtext and renders
it at construction (`frontend/ui/widget/textboxwidget.lua:986`) into a `Blitbuffer.new(width, h,
TYPE_BBRGB32)` when a colour is in play on a colour screen (`:855-860`).

The inputs are fixed for a day: the day index, the width, the look, the variant, the text size and the
source. A build runs on every show from the file browser, every book close, every wake and every
refresh, and on every measurement in Edit layout.

Add a one-entry module memo of the composed text box, keyed on those inputs. `QuoteBox:free` must not
free the memoised box; the memo frees the old box when the key changes. `Typeset.measured`'s own
`kept.widget:free()` (`typeset.lua:108-111`) would free a memoised child unless the QuoteBox's `free`
skips it.

## Why

About 160 characters shaped and line-broken, then a buffer of roughly 1100 by 190 px at 4 bytes,
about 0.8 MB, allocated and filled on every home build, for a widget that changes once a day. It is
part of the whole-home rebuild cost the first pass's finding 1 lists, and it still pays on the show
and close routes that finding's per-slot fix keeps.

## Done when

- A unit spec spies on `TextBoxWidget.new`: two `Quote.build`s with the same key construct once; the
  next day, or another width, constructs again. It fails on the current code.
- A unit spec frees the first home and shows that the second home's quote still paints ink into a
  scratch buffer (the memoised box was not freed).
- `bin/check` is green and the home goldens are unchanged.
