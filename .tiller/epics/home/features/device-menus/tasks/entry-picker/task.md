# The add-an-entry picker for the five kinds

## Approach

`EntryPicker.pick(kind, ctx, on_entry)`: the flow that turns one of the five kinds into a valid launcher
entry, or a note. It writes nothing; launcher management stores what it gets. Paths into KOReader are
relative to `~/Projects/kodev/koreader/` at `e1fe1ac`; repo lines on `main` at `ca26783`. Starts after
`sheets` has merged (its `Sheet.show` lists the screen and plugin choices).

1. **Kinds** are `"kopanda"`, `"koreader"`, `"directory"`, `"action"` and `"plugin"`, labelled KoPanda
   screen, KOReader screen, Folder on disk, Action and Plugin (LauncherManage:98-101 draws the last four;
   decision D4 adds the first). `EntryPicker.KINDS` lists them in that order with their labels, for the
   screen's buttons.
2. **Screens:** a sheet "KoPanda screen" (or "KOReader screen") of `Schema` `launcher.entries`
   `targets[kind]` (`schema.lua:104-107`), each row the label and icon of `LauncherEntries.KOPANDA` or
   `.KOREADER` (`launcher_entries.lua:16-30`). A tap calls `on_entry{ kind = kind, target = target }`.
   No label: the validator takes exactly `{ kind, target }` (`settings.lua:85-86`).
3. **Folder on disk:** `PathChooser:new{ select_directory = true, select_file = false, path = <the file
   browser's path, or its last dir> , onConfirm = … }`, as Folder shortcuts opens it
   (`frontend/apps/filemanager/filemanagershortcuts.lua:427-439`); `onConfirm(path)` runs after the
   chooser's own confirm dialog (`frontend/ui/widget/pathchooser.lua:137-155`).
   - The path with any trailing `/` removed. `/` itself gives "Choose a folder inside the root." and
     stops (`settings.lua:117-118`).
   - The label: the path's last part, then the label dialog (step 6), then
     `on_entry{ kind = "directory", path = path, label = label }`.
4. **Action:** the action tree.
   - `local scratch, caller, menu = {}, {}, {}`; `Dispatcher:addSubMenu(caller, menu, scratch, "action")`
     (`frontend/dispatcher.lua:1109-1170`).
   - Keep `menu[2]` to `menu[5]`, the General, Device, Screen and lights and File browser sections
     (`section_list`, `dispatcher.lua:1132-1140`, inserted in that order after "Nothing" at index 1,
     `:1112-1131`). Reader, reflowable and fixed-layout sections and the trailing arrange, execute and
     QuickMenu items are dropped. **Before relying on the positions**, assert each kept item has a
     `sub_item_table` and that there are at least eight items; otherwise log, show "Couldn't list
     KOReader's actions." and stop. HOOKS.md records the positions for the next KOReader upgrade.
   - Show them in a one-tab `TouchMenu` (`tab_item_table = { items }`, `items.icon = "appbar.settings"`)
     inside a full-screen `CenterContainer`, as the settings menu shows its list
     (`filemanagermenu.lua:1006-1047`), titled by nothing (the tab bar is the menu's own).
   - Its `close_callback` closes the container, then reads `scratch.action`:
     - the keys other than `settings` (`dispatcher.lua:740-749`; `_addToOrder` adds `settings.order`,
       `:799-830`) are the ticked actions;
     - exactly one, whose value is `true` (`none` and `arg` actions, `:931-940`): continue with it;
     - exactly one with another value (`absolutenumber`, `incrementalnumber`, `string`, `configurable`,
       `:943-1067`): "That action needs a value, which a launcher entry can't keep.";
     - none, or more than one: "Pick one action.".
   - The label: `Dispatcher.getDisplayList({ [id] = true })[1].text` (`dispatcher.lua:866-890`), then the
     label dialog, then `on_entry{ kind = "action", action = id, label = label, icon = "action" }`.
5. **Plugin:** a sheet "Plugin" of the plugins `PluginLoader:loadPlugins()` returns enabled
   (`frontend/pluginloader.lua:273-292`, cached after the first call), kept when
   `PluginLoader:isPluginLoaded(p.name)` (`:566-568`) and not `p.is_doc_only`
   (`frontend/apps/filemanager/filemanager.lua:419`), `kopanda` left out, labelled `p.fullname or p.name`
   (`pluginloader.lua:104-109`), sorted by that label. None: "No plugins are loaded." A tap runs the
   action tree (step 4), then
   `on_entry{ kind = "plugin", plugin = p.name, action = id, label = label, icon = "action" }`.
6. **The label dialog:** an `InputDialog` (`frontend/ui/widget/inputdialog.lua:125-167`) titled "Label",
   `input` the default, buttons Cancel and Add (Add `is_enter_default`), keyboard shown (`:640`). Add with
   `util.trim(text)` (`frontend/util.lua:52`) empty does nothing; otherwise it closes and continues.
   Cancel closes and adds nothing.
7. Every step's callback is guarded: an error is logged, the open dialog or menu closes, and `on_entry`
   isn't called.
8. **`main.lua`** requires `entry_picker`. **HOOKS.md:** `PathChooser` (`pathchooser.lua:13-21`,
   `:137-155`); `Dispatcher:addSubMenu`, its `section_list` positions, the scratch table's shape and the
   value categories; `Dispatcher.getDisplayList`; `isActionEnabled`'s file-browser rule
   (`dispatcher.lua:1435-1449`, why reader sections are dropped); `PluginLoader:loadPlugins`,
   `isPluginLoaded`, `is_doc_only`; `InputDialog`; `TouchMenu` one-tab use (shared with
   `settings-menu`; whichever lands first adds it).

## Surfaces

`kopanda.koplugin/entry_picker.lua` (new), `main.lua`, `HOOKS.md`. Specs: `spec/unit/entry_picker_spec.lua`
(new), `spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

`entry_picker_spec.lua` (C10), in the harness over a real file manager, `on_entry` a spy, each entry it
receives checked with `Settings.validators.launcher` as a one-entry list:

- **Screens:** the KoPanda sheet lists Library, Series, Authors, Settings with their icons; a tap gives
  `{ kind = "kopanda", target = "series" }`. The KOReader sheet lists History, Favorites, Collections,
  Wi-Fi.
- **Folder on disk:** a real temporary directory confirmed through the chooser's `onConfirm` opens the
  label dialog with its last part; Add gives `{ kind = "directory", path, label }`; `/` gives its note
  and no call; a path with a trailing `/` is stored without it.
- **Action tree:** the shown menu's top items are exactly the four file-browser sections (their texts
  from `addSubMenu`'s own table, not literals); ticking `history` and closing gives the label dialog with
  "History", then `{ kind = "action", action = "history", label = "History", icon = "action" }`; ticking
  none and closing gives "Pick one action."; ticking two gives it too; ticking an `absolutenumber`
  action (set through its item's callback with a stubbed spin value) gives the value note. The
  reader-only `kosync_push_progress`-style action registered for the case (`reader = true`) appears in no
  kept section.
- **Positions guard:** with `Dispatcher.addSubMenu` stubbed to add three items, the note "Couldn't list
  KOReader's actions." and no menu.
- **Plugin:** with `PluginLoader.loadPlugins` stubbed to return a loaded plugin, a disabled one, an
  `is_doc_only` one and `kopanda`, and `isPluginLoaded` stubbed, the sheet lists only the first; picking
  it and then `history` gives `{ kind = "plugin", plugin = <name>, action = "history", label, icon =
  "action" }`. The stub keeps the emulator's own `plugins/` (which holds untracked SimpleUI, Bookshelf
  and Solar icon pack folders) out of the case.
- **Label:** Cancel gives no call; an all-space label does nothing and keeps the dialog.
- **No writes:** after every case the settings file is byte-identical or absent.

`failsafe_spec.lua` (C15): `Dispatcher.addSubMenu` raising is logged, leaves no menu shown and calls
nothing.

## Edge cases

- **`addSubMenu` on a scratch caller** sets `caller.updated` (`dispatcher.lua:924`, `:1125`); the caller
  is a throwaway table, so no KOReader profile or gesture is touched.
- **Hold on a section** clears that section's ticks (`dispatcher.lua:1155-1165`); that's KOReader's
  behaviour and harmless here.
- **A plugin whose actions aren't in the file-browser sections** (reader-only): the tree has nothing of
  it; the user ticks nothing and gets "Pick one action.".
- **`Dispatcher:init`** runs inside `addSubMenu` (`dispatcher.lua:1110`) and returns at once once initialized (`:586`).
- **The picker opened over the reader**: `isPluginLoaded` there includes reader-only plugins, which the
  `is_doc_only` test still removes.
