-- The Home tab's place in the file manager's top menu. KOReader sorts the menu against a
-- require-cached order table (frontend/apps/filemanager/filemanagermenu.lua:858-862) and
-- overlays the user's own settings/filemanager_menu_order.lua on it (frontend/ui/menusorter.lua:34-43).
local MenuSorter = require("ui/menusorter")
local State = require("state")
local logger = require("logger")

local MenuEntries = {}

local TAB = "kopanda_home"
local BUTTONS = "KOMenu:menu_buttons"

local function contains(list, id)
    for _, value in ipairs(list) do
        if value == id then
            return true
        end
    end
    return false
end

-- A top-level id with no order entry becomes a plain item and is dropped (menusorter.lua:60,
-- :70-72, :139-146), so the tab needs an empty one, as the reader's file-browser tab has
-- (frontend/ui/elements/reader_menu_order.lua:228). A user's own entry overrides it on merge.
local function ensure_order_entry(order)
    if order[TAB] == nil then
        order[TAB] = {}
    end
end

-- With a user's own top-level list, mergeAndSort replaces the cached one with it, so the tab
-- exists only when that list names it; a textless top-level item it leaves out would be an
-- orphan in tab 1 (menusorter.lua:161-185). The user's list is left alone.
local function home_tab_allowed(order, user_buttons)
    if not contains(user_buttons, TAB) then
        return false
    end
    ensure_order_entry(order)
    return true
end

-- Index 2 keeps filemanager_settings at 1, where orphans land, and keeps the far-left and
-- far-right tabs the top menu's swipe opens (filemanagermenu.lua:1083-1100).
local function insert_home_tab(order)
    ensure_order_entry(order)
    local buttons = order[BUTTONS]
    if not contains(buttons, TAB) then
        table.insert(buttons, 2, TAB)
    end
end

-- The menu reopens on the saved tab (filemanagermenu.lua:1021, :1087), so the first insert in
-- a profile moves a saved index at or past the new tab up by one. The marker goes first: a
-- shift that could not be recorded would repeat at every start.
local function shift_saved_tab_index()
    if State.get("menu_tab_shifted") then
        return
    end
    if not State.set("menu_tab_shifted", true) then
        return
    end
    local index = G_reader_settings:readSetting("filemanagermenu_tab_index")
    if type(index) == "number" and index >= 2 then
        G_reader_settings:saveSetting("filemanagermenu_tab_index", index + 1)
    end
end

-- Readies the cached order for the Home tab and returns true when the menu gets it. Runs from
-- addToMainMenu, inside setUpdateItemTable, before either reader of the saved index uses it
-- (filemanagermenu.lua:1007-1009, :1084-1086). The user's file is read at every build: after
-- one merge the cached list is the user's (menusorter.lua:35-40). On any error, no tab.
function MenuEntries.home_tab()
    local ok, result = pcall(function()
        local order = require("ui/elements/filemanager_menu_order")
        local user_buttons = MenuSorter:readMSSettings("filemanager")[BUTTONS]
        if user_buttons then
            return home_tab_allowed(order, user_buttons)
        end
        insert_home_tab(order)
        shift_saved_tab_index()
        return true
    end)
    if not ok then
        logger.err("KoPanda: could not add the Home tab:", result)
        return false
    end
    return result
end

return MenuEntries
