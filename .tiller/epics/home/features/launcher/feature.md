# Launcher entries, folders and placeholders

## Summary

The launcher widget: up to six entries on the home screen, drawn as the look's tiles with icons from the
registry, each a KoPanda screen, a KOReader screen, a plugin, a folder on disk or a dispatcher action.
A seventh entry goes into a folder. Series and Authors are present from day one as placeholders
(direction doc "Launcher", "Placeholder entries", "Tap a folder entry").

## Behavior

- The default six: Library, Series, Authors, History, Wi‑Fi, Settings.
- Tap runs the entry: Library reveals the file browser, History opens KOReader's history, Wi‑Fi toggles
  and shows its state, Settings opens KoPanda's settings, a plugin entry opens that plugin, an action
  entry dispatches it.
- Series and Authors show a short "coming with the library" note and return.
- Tapping a folder entry opens a sheet listing its entries by kind; the folder's entries behave as above.
- An entry whose plugin is gone stays in place, greyed and labelled "plugin missing"; it is never
  silently dropped.
- Entries and folders live under the `launcher.entries` key; the widget never holds state of its own.
- Goldens for both looks on both profiles, including the missing-plugin state.

## Notes

Managing entries on the device is `device-menus`; this feature draws and runs them. How a "KOReader
screen" entry names its target (history, collections, file browser) is a specify-time list with
citations into KOReader's dispatcher.
