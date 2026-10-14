# Form, layout editor and launcher editor from the schema

## Summary

The editor over a profile's settings: a form generated from the schema JSON, a row editor for the
layout, and a launcher editor, all writing the plugin's settings file (design §6 Form).

## Behavior

- Every schema key renders as a control by type (toggle, number with its range, choice, text, icon
  picker from the registry, path), grouped as the schema groups them, with the look picker first.
- The layout editor shows rows with their columns and width shares; rows reorder with arrows, columns
  are added, changed and removed, the height budget is enforced with the same rule as the device.
- The launcher editor lists entries with kind and icon, reorders, removes, adds by kind, and moves the
  seventh entry into a folder.
- A change writes the settings file for the profile and marks the preview stale.
- A test proves every schema key has exactly one control and that an unknown key in a settings file is
  reported, not silently dropped.

## Notes

Visual direction for the studio itself is not drawn; the theme studio's 2026-10-09 direction (dark,
one violet accent) is the default unless the owner asks for a board. Validation messages and field help
are specify-time.
