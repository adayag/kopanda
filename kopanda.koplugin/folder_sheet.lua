-- The folder sheet: a launcher folder's entries as a sheet over the home, opened by a tap on the folder.
-- Each row is its entry as LauncherEntries.resolve reads it now, with its kind at the right, or its
-- suffix when it is off or can't run; a tap runs it as the home does, a hold in the header opens the
-- folder's list in launcher management. Nothing here writes a setting.
local LauncherEntries = require("launcher_entries")
local PaintClock = require("paint_clock")
local Settings = require("settings")
local Sheet = require("sheet")
local util = require("util")

local FolderSheet = {}

-- Each entry kind's name, at a row's right.
local KINDS = {
    kopanda = "KoPanda",
    koreader = "KOReader",
    plugin = "Plugin",
    action = "Action",
    directory = "Folder on disk",
}

-- The top-level index of the first stored folder equal to entry, or nil when none is: the sheet
-- holds the entry the launcher was built with, not its index.
local function index_of(entry)
    for i, e in ipairs(Settings.get("launcher.entries")) do
        if e.kind == "folder" and util.tableEquals(e, entry) then
            return i
        end
    end
end

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
        header = { heading = entry.label, aside = "Folder · " .. #entry.entries, aside_beside = true,
            hint = "Hold to edit" },
        rows = rows,
        -- launcher_manage is required here, not at load, so loading the sheet doesn't load the
        -- editor and picker chain.
        hold = function()
            local started = PaintClock.now()
            require("launcher_manage").open{ folder = index_of(entry), started = started }
        end,
    }, ctx, opts)
end

return FolderSheet
