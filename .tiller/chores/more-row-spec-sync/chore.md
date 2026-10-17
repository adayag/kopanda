# Amend the sheets and device-menus specs for the More-row paging

Found by the build and review of B-0vcqvc (`.tiller/reviews/2026-10-17-efficiency-pass2-followups.md`,
finding 4).

## What

Since B-0vcqvc (PR #42) a sheet spec may carry `more = { label, run }`: when its rows don't fit, the
last slot that fits beside a row is a "More…" row whose tap closes the sheet and hands `run` the rows
left out, in order, and the entry picker pages its Plugin list that way, so every loaded plugin can
be picked. Two accepted feature texts say otherwise:

- `.tiller/epics/home/features/sheets/feature.md:143`: of a sheet overflowing the screen, "Only a
  long folder can do that".
- `.tiller/epics/home/features/device-menus/feature.md:394`: the Plugin row of the picker table does
  not mention paging.

These are accepted texts, so the change is an amendment, not an edit: stage one with
`tiller add amendment` naming both features, with the new wording (the sheet's `more` field and its
rules in sheets; the Plugin picker's paging in device-menus), for the owner to approve.

## Why

The specs are what the next reader of the sheet or the picker trusts, and a reviewer of a later
sheet change would read "no sheet pages" and refuse what the code already does.

## Done when

- An amendment is staged covering both texts, with the wording and the acceptance statement it
  touches (sheets' no-scroll rule stays for bounded lists; the Plugin picker's list is unbounded and
  pages).
- No code or spec file changes; `bin/check` is unaffected.
