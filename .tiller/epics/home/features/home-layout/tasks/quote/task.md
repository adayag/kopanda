# Quote of the day from a shipped public-domain file

## Approach

1. **Schema.** Add `quote.source` after `weather.units` in the final order: choice with one value,
   `{ value = "builtin", label = "Built-in" }`, default `builtin`, group `quote`. Until `weather` lands,
   it goes after `layout.rows`; `weather` places its keys before it.
2. **`kopanda.koplugin/quotes.lua`.** Pure data: `return { { text = ..., author = ..., work = ...,
   source = "gutenberg:1342" | "wikisource:<page title>" }, ... }`, at least 60 entries.
   - Each `text` is copied verbatim from the named edition, at most 160 characters, with no surrounding
     quotation marks (the widget adds them).
   - Works must be published before 1931, so they are public domain in the US.
   - Prefer short sentences about reading, books, attention and time. The builder lists in the PR how
     each source was checked. The owner may replace any entry at review: the file is theirs to curate.
3. **`kopanda.koplugin/widgets/quote.lua`**, registered and required from `main.lua`:
   - `Quote.index(t)` is `math.floor(local_days(t)) % #quotes + 1`, where `local_days` counts local
     calendar days since 1970-01-01. It is computed from `os.date("*t", t)` through
     `os.time{ year, month, day, hour = 12 }` divided by 86400, so DST never moves the day.
   - The widget reads `Settings.get("quote.source")`; `builtin` selects `quotes.lua`.
   - The text is wrapped in “ ” and laid out with KOReader's `TextBoxWidget` at the column width, in
     `type.quote`. Editorial: `quote` face, 18, `ink` (Main:56), with `line_height = 0.4`.
     `TextBoxWidget` counts line height as extra space in em, `(1 + line_height) × size`
     (`frontend/ui/widget/textboxwidget.lua:48`, `:151`), so CSS 1.4 is 0.4. Diner: `quote` face, 18,
     `ink`, the same line height.
   - Four lines at most: `height` set to four line heights with `height_overflow_show_ellipsis = true`
     (`textboxwidget.lua:54`).
   - Chrome per look: Editorial rules in `hairline` above and below at `stroke.hairline`, with 18 px
     padding (Main:56). Diner uses the tile: a `paper` fill, an `outline` stroke at `stroke.outline`, and
     the hard shadow `shadow.tile` (`looks/diner.lua:70-87`), with padding 18.
   - `height` is the laid-out box plus chrome. No `tap`.
4. Fill in `type.quote` in both looks.

## Surfaces

`kopanda.koplugin/schema.lua`, `quotes.lua` (new), `widgets/quote.lua` (new), `widgets.lua`,
`main.lua`, `looks/editorial.lua`, `looks/diner.lua`, `HOOKS.md` (`TextBoxWidget`, if internals are read);
`spec/unit/quote_spec.lua` (new), `spec/unit/schema_spec.lua`.

## Tests

Written first and run failing.

- `quote_spec.lua` (C6):
  - `quotes.lua` loads by `dofile` with no `require` and has at least 60 entries. Each `text` is
    non-empty, at most 160 characters, has no leading or trailing quote mark, and has an `author` and a
    `work`. Each `source` matches `^gutenberg:%d+$` or `^wikisource:.+$`.
  - Under a fixed `TZ`, `index` is the same at 00:01 and 23:59 of one day and advances by one across
    midnight, including across a DST change.
  - The widget's text starts with “ and ends with ”, holds no author, and wraps to four lines or fewer
    for the longest entry at `large` in a full-width row (the default layout's) at both profiles' widths,
    1236 and 1264 px. A half-width column holds about 112 characters in four lines at `large`, so a quote
    moved into a half column can hit the ellipsis; that is accepted.
  - A synthetic 400-character text ends in "…" within four lines.
- `schema_spec.lua` gains `quote.source`.

## Edge cases

- Verbatim checking can't run offline in a spec. Provenance is a review item: the reviewer samples ten
  entries against their sources.
- An empty `quotes.lua` can't happen (the spec holds it at 60 or more), but the widget still returns a
  blank box of height 0 for an empty list, rather than dividing by zero.
