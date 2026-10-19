-- What a launcher entry (schema.lua's launcher.entries) is and does: resolve reads what it shows when
-- the home is built, run is what a tap does. No widget code: the launcher widget draws from resolve, and
-- the folder sheet reuses both. Nothing here writes a setting.
local Dispatcher = require("dispatcher")
local Helpers = require("helpers")
local Home = require("home")
local LibraryOrder = require("library_order")
local PaintClock = require("paint_clock")
local SettingsMenu = require("settings_menu")
local T = require("ffi/util").template
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local LauncherEntries = {}

-- KoPanda's own screens, by target.
LauncherEntries.KOPANDA = {
    library = { label = "Library", icon = "library" },
    series = { label = "Series", icon = "series" },
    authors = { label = "Authors", icon = "authors" },
    settings = { label = "Settings", icon = "settings" },
    quick_settings = { label = "Quick settings", icon = "quick_settings" },
}

-- KOReader's screens, by target, each run by one dispatcher id (frontend/dispatcher.lua:68,
-- :70, :71, :124).
LauncherEntries.KOREADER = {
    history = { label = "History", icon = "history", action = "history" },
    favorites = { label = "Favorites", icon = "bookmark", action = "favorites" },
    collections = { label = "Collections", icon = "list", action = "collections" },
    wifi = { label = "Wi-Fi", icon = "wifi", action = "toggle_wifi" },
}

-- The fixed table row for a kopanda or koreader entry, or nil.
local function fixed(entry)
    local tables = { kopanda = LauncherEntries.KOPANDA, koreader = LauncherEntries.KOREADER }
    local by_target = tables[entry.kind]
    return by_target and by_target[entry.target]
end

-- The entry's label, never raising: its own, its fixed table's, or "Entry".
local function label_of(entry)
    local ok, label = pcall(function()
        if type(entry.label) == "string" then
            return entry.label
        end
        local row = fixed(entry)
        return row and row.label
    end)
    return ok and label or "Entry"
end

-- Whether the dispatcher lists id as available: getDisplayList lists an id only when it is in
-- its settingsList and its condition holds (frontend/dispatcher.lua:866-890, :689-696).
local function registered(id)
    return #Dispatcher.getDisplayList({ [id] = true }) == 1
end

-- True, or false and the suffix saying why the entry can't run here.
function LauncherEntries.available(entry)
    local kind = entry.kind
    if kind == "plugin" then
        if not (require("pluginloader"):isPluginLoaded(entry.plugin) and registered(entry.action)) then
            return false, "plugin missing"
        end
    elseif kind == "action" then
        if not registered(entry.action) then
            return false, "not available"
        end
    elseif kind == "koreader" then
        if not registered(fixed(entry).action) then
            return false, "not available"
        end
    elseif kind == "directory" then
        if lfs.attributes(entry.path, "mode") ~= "directory" then
            return false, "folder missing"
        end
    end
    return true
end

-- What the entry shows: { label, icon, state, suffix }, state "ready", "off" or "unavailable".
-- A resolution that raises is logged and reads as not available.
function LauncherEntries.resolve(entry)
    local ok, view = pcall(function()
        local label = label_of(entry)
        local is_available, suffix = LauncherEntries.available(entry)
        if not is_available then
            return { label = label, icon = "plugin_missing", state = "unavailable", suffix = suffix }
        end
        if entry.kind == "koreader" and entry.target == "wifi"
                and not require("ui/network/manager"):isWifiOn() then
            return { label = label, icon = "wifi_off", state = "off", suffix = "off" }
        end
        local icon
        if entry.kind == "folder" or entry.kind == "directory" then
            icon = "folder"
        else
            local row = fixed(entry)
            icon = row and row.icon or entry.icon
        end
        return { label = label, icon = icon, state = "ready" }
    end)
    if not ok then
        logger.err("KoPanda: could not resolve a launcher entry:", view)
        return { label = label_of(entry), icon = "plugin_missing", state = "unavailable", suffix = "not available" }
    end
    return view
end

local function file_manager()
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    return FileManager and FileManager.instance
end

local KOPANDA_RUN = {
    -- The library: on the library, its root's first page, in place; from anywhere else, the home closed and
    -- the library shown at the folder and page it was last left at. library and library_view are required
    -- now: through library_tiles they reach widgets/featured, which requires this module.
    library = function()
        local Library = require("library")
        if Library.shown then
            Library.shown:go(require("library_view").root(), 1)
            return
        end
        Home.close()
        local fm = file_manager()
        if fm then
            local left = LibraryOrder.left()
            fm.kopanda:showLibrary(left and { dir = left.dir, page = left.page } or {})
        end
    end,
    -- The Series window's list at its first page, the home closed.
    series = function()
        Home.close()
        local fm = file_manager()
        if fm then
            fm.kopanda:showSeries{}
        end
    end,
    -- The Authors window's list at its first page: on the Authors window, in place; from anywhere else, the
    -- home closed and the window shown. authors_screen is required now, as library is.
    authors = function()
        local AuthorsScreen = require("authors_screen")
        if AuthorsScreen.shown then
            AuthorsScreen.shown:go({ kind = "list" }, 1)
            return
        end
        Home.close()
        local fm = file_manager()
        if fm then
            fm.kopanda:showAuthors{}
        end
    end,
    settings = function()
        SettingsMenu.open()
    end,
    quick_settings = function()
        -- The tap's start, which the sheet's paint_ms runs from. quick_settings requires this
        -- module, so it is required here, at call time.
        local started = PaintClock.now()
        require("quick_settings").open{ started = started }
    end,
}

-- The note for an entry that can't run, by its cause.
local function unavailable_note(entry, suffix)
    local label = label_of(entry)
    if suffix == "plugin missing" then
        Helpers.note(T("%1: the %2 plugin isn't loaded.", label, entry.plugin))
    elseif suffix == "folder missing" then
        Helpers.note(T("%1: %2 isn't there.", label, entry.path))
    else
        Helpers.note(T("%1 isn't available here.", label))
    end
end

-- What a tap on the entry does under ctx: a folder opens its sheet. Availability is checked again now,
-- so what has gone since the home was built gives its note; a check that raises reads as not
-- available. Any other error raises to the caller, so Home:onGesture's pcall logs it and closes the home.
function LauncherEntries.run(entry, ctx)
    local kind = entry.kind
    if kind == "kopanda" then
        KOPANDA_RUN[entry.target]()
        return
    end
    if kind == "folder" then
        -- The tap's start, which the sheet's paint_ms runs from. folder_sheet requires this
        -- module, so it is required here, at call time.
        local started = PaintClock.now()
        require("folder_sheet").open(entry, ctx, { started = started })
        return
    end
    local available_ok, is_available, suffix = pcall(LauncherEntries.available, entry)
    if not available_ok then
        logger.err("KoPanda: could not check a launcher entry:", is_available)
        is_available, suffix = false, "not available"
    end
    if not is_available then
        unavailable_note(entry, suffix)
        return
    end
    if kind == "directory" then
        Home.close()
        local fm = file_manager()
        if fm then
            fm.file_chooser:changeToPath(entry.path)
        end
        return
    end
    local id = kind == "koreader" and fixed(entry).action or entry.action
    Dispatcher:execute({ [id] = true })
end

return LauncherEntries
