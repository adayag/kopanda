# One book-open in the chrome, not three copies

## What

`Library:open`, `SeriesScreen:open` and `AuthorsScreen:open` are the same ten-odd lines three times: open a
downloaded book through `filemanagerutil.openFile`, run the window's `on_open(view, page)` from its
pre-callback, and do nothing for a path-less record. Move that into `LibraryChrome` as the chrome window's
default `open`, so each window keeps only its `on_open` hook, the way `book_closed` already became a chrome
default in `library/series-and-authors/routing` (T-8j0bc0).

Found reading the three windows on the feature aggregate (`tiller/reviews/features/library/series-and-authors`):
`kopanda.koplugin/library.lua:56`, `series_screen.lua:243`, `authors_screen.lua:286`. Each task that added a
copy recorded it as a departure because `library.lua` and `library_chrome.lua` were outside its surfaces.

## Why

Three copies of the path that opens a book drift: a fix to one (the pre-callback, a refused open, the return
record) has to be made three times, and a missed copy is a window whose book-close return breaks.

## Done when

- One `open` lives in `library_chrome.lua`; the three windows have no `open` of their own.
- The library, series and authors book-open and return cases in `library_lifecycle_spec.lua`,
  `shelf_lifecycle_spec.lua`, `library_gestures_spec.lua` and `shelf_gestures_spec.lua` pass unchanged.
- The library goldens match without regeneration.
