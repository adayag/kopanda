# The plugin shows a home over the file browser

## Summary

`kopanda.koplugin` loads under KOReader and puts a full-screen home widget over the file browser whenever
the file browser appears, the way ennUI does (design §5, Entry), with every hook wrapped so a failure
leaves KOReader usable. The home it draws is a placeholder until `home-layout`; this feature is the
lifecycle.

## Behavior

- The plugin registers with `is_doc_only = false`, so it is present in both the file manager and the
  reader.
- When the file browser is shown, the home widget appears over it, `covers_fullscreen`, so nothing
  beneath is painted. When a book closes, the home is pre-built before the file browser reappears and
  showing it is a single paint.
- A dispatcher action "KoPanda: home" and a Tools-menu entry open the home; a Home entry in the file
  manager's menu returns to it from the file browser (design §1b, native for the MVP).
- Swipe up from the bottom edge opens KoPanda's settings (a stub menu until `device-menus`); KOReader's
  top menu zone keeps working.
- A home that didn't finish drawing last start is skipped once with a notice (ennUI's `boot_pending`).
- If SimpleUI, Bookshelf or ennUI is enabled, the shell does not start and a message names which.
- `HOOKS.md` lists every KOReader internal this feature reads, with `file:line` at the pinned build.

## Notes

ennUI's `main.lua:62–161` (commit ae26fc4) is the reference for the hooks; read, don't copy, it has no
licence. The settled signal `dev-loop` waits on is emitted here. KOReader's `start_with` setting is left
alone.
