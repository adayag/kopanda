# Edit-layout add-column spec fails on days with a long quote

## Reproduction

On 2026-10-17 (local time), on `main` at `d8ed975`, run the spec alone:

    bash -c 'bin/check spec/unit/edit_layout_spec.lua; echo EXIT $?'

The case "adds a column to row 3 picked from the unused widgets" (`spec/unit/edit_layout_spec.lua:359-369`)
fails. It passed on earlier days, including in every gate run on 2026-10-16.

## Expected

The case passes on every calendar day: picking "Weather" for row 3 adds it beside the quote, so row 3 is
`{ quote, weather }`.

## Actual

"Weather" is offered in the picker, but picking it adds nothing; row 3 stays `{ quote }`. The quote widget
picks its entry by the local calendar day (`kopanda.koplugin/widgets/quote.lua:35-48`, `local_days(t) %
count + 1`), and the spec doesn't fix the day. The likely cause (assumption, not yet verified) is that the
2026-10-17 quote is long enough that quote and weather no longer fit one row, so the editor refuses the add.

## Fixed when

The cause is confirmed, and the case's result no longer depends on the day it runs: the spec fixes the time
or the quote it lays out, and passes on 2026-10-17 and on a day whose quote fit before. The whole `bin/check`
is green on `main`.
