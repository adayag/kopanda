-- What a launcher entry (schema.lua's launcher.entries) is and does: resolve reads what it
-- shows when the home is built, run is what a tap on it does. No widget code: the launcher
-- widget draws from resolve, and the folder sheet (folder_sheet.lua) reuses both, resolving a
-- folder's entries when it opens and running them through run. Nothing here writes a setting.
local Dispatcher = require("dispatcher")
local Home = require("home")
local InfoMessage = require("ui/widget/infomessage")
local SettingsMenu = require("settings_menu")
local UIManager = require("ui/uimanager")
local T = require("ffi/util").template
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local time = require("ui/time")

local LauncherEntries = {}

-- KoPanda's own screens, by target.
LauncherEntries.KOPANDA = {
    library = { label = "Library", icon = "library" },
    series = { label = "Series", icon = "series" },
    authors = { label = "Authors", icon = "authors" },
    settings = { label = "Settings", icon = "settings" },
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

-- A note over the home, closed by a tap anywhere; no timeout, so no timer
-- (frontend/ui/widget/infomessage.lua:53, :283-290, :67, :88-100).
local function note(text)
    UIManager:show(InfoMessage:new{ text = text })
end

local function file_manager()
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    return FileManager and FileManager.instance
end

local KOPANDA_RUN = {
    library = function()
        Home.close()
        local fm = file_manager()
        if fm then
            fm:onHome()
        end
    end,
    series = function()
        note("Series are coming with the library.")
    end,
    authors = function()
        note("Authors are coming with the library.")
    end,
    settings = function()
        SettingsMenu.open()
    end,
}

-- The note for an entry that can't run, by its cause.
local function unavailable_note(entry, suffix)
    local label = label_of(entry)
    if suffix == "plugin missing" then
        note(T("%1: the %2 plugin isn't loaded.", label, entry.plugin))
    elseif suffix == "folder missing" then
        note(T("%1: %2 isn't there.", label, entry.path))
    else
        note(T("%1 isn't available here.", label))
    end
end

-- What a tap on the entry does under ctx, the home's: a folder opens its sheet, which passes
-- ctx on to its rows' runs. Availability is checked again now, so what has gone since the home
-- was built gives its note; a check that raises is logged and reads as not available. Any other
-- error raises to the caller, so a tap reaches Home:onGesture's pcall, which logs it and closes
-- the home onto the file browser.
function LauncherEntries.run(entry, ctx)
    local kind = entry.kind
    if kind == "kopanda" then
        KOPANDA_RUN[entry.target]()
        return
    end
    if kind == "folder" then
        -- The tap's start, which the sheet's paint_ms runs from. folder_sheet requires this
        -- module, so it is required here, at call time.
        local started = time.monotonic()
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
