# A book downloaded on one series or one author drops out until its cover returns

Found building `library/cwng-placeholders/download-row` (T-xtol0q), commit `6b0388e` on
`tiller/library/cwng-placeholders/download-row`, and confirmed there with a probe.

## Reproduction

1. With cwngsync loaded and configured, open one series (or one author) holding a cwngsync placeholder.
2. Hold the placeholder and tap Download; let the download finish.

cwngsync's download broadcasts `InvalidateMetadataCache`, and CoverBrowser deletes the book's cached row
(coverbrowser `main.lua:800-803` at the pinned build `e1fe1ac`). The shelf screen's `BookMetadataChanged`
re-list then runs before the row is rebuilt, and a book's series and authors come only from that row
(`books.lua` `record()`).

## Expected

The downloaded book stays on the screen, in its place, through the download and the cover's return; the
screen stays on the page it was on (cwng-placeholders D1: "the screen stays where it is").

## Actual

The book drops out of the one-series or one-author list until CoverBrowser extracts its row again, then
reappears. When it was the only book on the last page, the page clamps back one and stays there after the
book reappears. The library grid is not affected (the tile stays, titled by its file name until the row
returns).

## Fixed when

A test downloads a placeholder that is alone on the last page of one series, and of one author, with
CoverBrowser's row deleted as the broadcast deletes it, and asserts the book is listed on every paint
between the tap and the row's return and that the screen ends on the same page.
