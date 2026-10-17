# Library and Authors targets act on a window hidden under the home

## Reproduction

Found by reading the code during the review of `library/series-and-authors/routing` (T-8j0bc0); not yet
reproduced on the emulator. **Assumption to verify first:** a home can be shown over an open chrome window.
The reviewer named the KoPanda "home" gesture as the path, since `Home.show` (`kopanda.koplugin/home.lua:210`)
shows the home without closing a chrome window.

1. Open the Library (or Authors) window.
2. Bring up the home over it without closing it, e.g. by the KoPanda home gesture.
3. On the home, tap the launcher's Library entry (or Authors entry, or the nav bar's Authors tab).

## Expected

The home closes and the Library (or Authors) window is shown at its first page, as from any other place.

## Actual

`launcher_entries.lua` sees the window still set (`Library.shown`, `:131`; `AuthorsScreen.shown`, `:155`) and
only calls `go(..., 1)` on it. The window rebuilds underneath; the home stays on top, so the tap appears to do
nothing. The library's branch is cover-grid's; the authors branch copied it in series-and-authors.

## Fixed when

- A spec shows the home over an open Library window and over an open Authors window, runs each target, and
  finds the home closed and that window on top at its first page.
- Either the targets close the home in their "already shown" branch, or `Home.show` closes a shown chrome
  window first (one window at a time), whichever the investigation shows is the honest rule.
