# Bottom navigation bar across the file manager

Stage 3 of `design/2026-10-13-kopanda-design.md` §4 and §7; direction doc "Nav bar".

## Intent

The first patch into KOReader itself: a five-tab bar under the file manager's screens, in both looks,
so Home, Library, Authors, History and Settings are one tap from anywhere in the shell.

## Scope

One feature: the bar, its patch on the file manager's layout setup, its tabs, and the hooks record.
Authors stays a placeholder tab until the library's author index.

## Definition of done

The bar shows on the home and on the file browser in both looks on both profiles with goldens, each tab
goes where it says, the patch is recorded in `HOOKS.md` with citations, and a KOReader upgrade check
walks it.

## Dependencies

Needs the plugin lifecycle (`home/plugin-shell`), the looks (`home/looks-and-schema`) and the launcher's
entry resolution (`home/launcher`), recorded as `depends_on` edges.
