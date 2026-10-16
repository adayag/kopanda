# A spec that main.lua requires every plugin module

## What

Add a unit spec asserting that every module name `spec/plugin_harness.lua`'s `module_names()` lists
(`:46`) appears as a `require("<name>")` in `kopanda.koplugin/main.lua`.

## Why

`main.lua` must require every KoPanda module at load time: KOReader puts the plugin root on
`package.path` only while it loads `main.lua` (`main.lua:5-7`, citing `frontend/pluginloader.lua:242`,
`:269-270`). The unit harness keeps the plugin root on `package.path` throughout, so a module required
only at call time passes every spec even when `main.lua` forgets it, and on the device the call raises.
The `home/sheets/folder-sheet` (T-8hhlio) review showed it: deleting `require("folder_sheet")` from
`main.lua` passed all 68 cases of the four specs it ran.

## Done when

- The spec fails when any one module's `require` is removed from `main.lua`, and passes on `main`.
- `bin/check` is green.
