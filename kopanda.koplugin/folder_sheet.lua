-- The folder sheet: a launcher folder's entries as a sheet over the home, opened by a tap on the
-- folder. Each row is its entry as LauncherEntries.resolve reads it now, with its kind at the
-- right, or its suffix when it is off or can't run; a tap on one runs it as the home does.
-- Folders don't nest, so a folder sheet never opens another. Nothing here writes a setting.
local LauncherEntries = require("launcher_entries")
local Sheet = require("sheet")

local FolderSheet = {}

-- Each entry kind's name, at a row's right.
local KINDS = {
    kopanda = "KoPanda",
    koreader = "KOReader",
    plugin = "Plugin",
    action = "Action",
    directory = "Folder on disk",
}

-- Shows the sheet of entry, a folder entry ({ label, entries }), under ctx (the home's), with
-- opts passed on to Sheet.show.
function FolderSheet.open(entry, ctx, opts)
    local rows = {}
    for i, child in ipairs(entry.entries) do
        local view = LauncherEntries.resolve(child)
        local blocked = view.state == "off" or view.state == "unavailable"
        rows[i] = {
            icon = view.icon,
            label = view.label,
            detail = blocked and view.suffix or KINDS[child.kind],
            muted = view.state == "unavailable",
            run = function()
                LauncherEntries.run(child, ctx)
            end,
        }
    end
    Sheet.show({
        name = "folder",
        band = "folder",
        header = { heading = entry.label, aside = "Folder · " .. #entry.entries, aside_beside = true },
        rows = rows,
    }, ctx, opts)
end

return FolderSheet
