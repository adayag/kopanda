# Title bar and quick settings

Stage 4 of `design/2026-10-13-kopanda-design.md` §4 and §7; direction doc "Quick settings", the library
board's header.

## Intent

The rest of the file manager's chrome in the looks: its title bar, and a quick-settings sheet for
brightness, warmth and toggles, so nothing the owner touches daily is still KOReader's default styling.

## Scope

Two features: the title bar patch, and the quick-settings sheet. There is no status bar on the home
screen (direction doc "Status bar"); the title bar is the file manager's.

## Definition of done

Both features done: the file browser's title bar matches the library board's header in both looks, the
quick-settings sheet opens from the decided entry point and its controls act, goldens committed, hooks
recorded.

## Dependencies

The title bar needs the looks (`home/looks-and-schema`); the sheet needs the sheet component
(`home/sheets`). The sheet's entry point is open question Q-irxgmk. Recorded as `depends_on` edges.
