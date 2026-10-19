-- The plugin's tabs in KOReader's top menus. KOReader sorts each menu against a require-cached
-- order table, the file manager's at frontend/apps/filemanager/filemanagermenu.lua:858-862 and
-- the reader's (frontend/ui/elements/reader_menu_order.lua) at
-- frontend/apps/reader/modules/readermenu.lua:348-351, and overlays the user's own
-- settings/<menu>_menu_order.lua on it (frontend/ui/menusorter.lua:34-43).
local MenuSorter = require("ui/menusorter")
local State = require("state")
local logger = require("logger")

local MenuEntries = {}

local BUTTONS = "KOMenu:menu_buttons"

-- The tabs the plugin adds to KOReader's top menus. order is the require-cached order module
-- the menu is sorted against; menu is the MenuSorter name whose user file may override it; at
-- is the index the tab is inserted at, or "before_main", just before the main tab. Only an
-- index shifts a saved tab index.
local TABS = {
    home = {
        id = "kopanda_home", what = "the Home tab",
        order = "ui/elements/filemanager_menu_order", menu = "filemanager", at = 2,
    },
    filemanager_quick_settings = {
        id = "kopanda_quick_settings", what = "the Quick settings tab",
        order = "ui/elements/filemanager_menu_order", menu = "filemanager", at = "before_main",
    },
    reader_quick_settings = {
        id = "kopanda_quick_settings", what = "the Quick settings tab",
        order = "ui/elements/reader_menu_order", menu = "reader", at = "before_main",
    },
}

local function index_of(list, id)
    for index, value in ipairs(list) do
        if value == id then
            return index
        end
    end
end

local function contains(list, id)
    return index_of(list, id) ~= nil
end

-- A top-level id with no order entry becomes a plain item and is dropped (menusorter.lua:60,
-- :70-72, :139-146), so the tab needs an empty one, as the reader's file-browser tab has
-- (frontend/ui/elements/reader_menu_order.lua:228). A user's own entry overrides it on merge.
local function ensure_order_entry(order, id)
    if order[id] == nil then
        order[id] = {}
    end
end

-- With a user's own top-level list, mergeAndSort replaces the cached one with it, so the tab
-- exists only when that list names it; a textless top-level item it leaves out would be an
-- orphan in tab 1 (menusorter.lua:161-185). The user's list is left alone.
local function tab_allowed(order, user_buttons, id)
    if not contains(user_buttons, id) then
        return false
    end
    ensure_order_entry(order, id)
    return true
end

-- The Home tab goes at index 2, which keeps filemanager_settings at 1, where orphans land, and
-- keeps the far-left and far-right tabs the top menu's swipe opens (filemanagermenu.lua:1083-1100,
-- readermenu.lua:466-482). A before_main tab goes just before main, or last without one, so the
-- far-right tab stays main: a swipe from the right third opens the last index, which on a
-- remember = false tab becomes tab 1 (touchmenu.lua:458-462, from :668).
local function insert_tab(order, tab)
    ensure_order_entry(order, tab.id)
    local buttons = order[BUTTONS]
    if contains(buttons, tab.id) then
        return
    end
    if tab.at == "before_main" then
        table.insert(buttons, index_of(buttons, "main") or #buttons + 1, tab.id)
    else
        table.insert(buttons, tab.at, tab.id)
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

-- Readies the cached order for the named tab and returns true when the menu gets it. Runs from
-- addToMainMenu, inside setUpdateItemTable, before either reader of the file manager's saved
-- index uses it (filemanagermenu.lua:1007-1009, :1084-1086). The user's file is read at every
-- build: after one merge the cached list is the user's (menusorter.lua:35-40). On any error,
-- an unknown name included, no tab.
function MenuEntries.tab(name)
    local ok, result = pcall(function()
        local tab = assert(TABS[name], "no such tab: " .. tostring(name))
        local order = require(tab.order)
        local user_buttons = MenuSorter:readMSSettings(tab.menu)[BUTTONS]
        if user_buttons then
            return tab_allowed(order, user_buttons, tab.id)
        end
        insert_tab(order, tab)
        if type(tab.at) == "number" then
            shift_saved_tab_index()
        end
        return true
    end)
    if not ok then
        local what = TABS[name] and TABS[name].what or "a menu tab"
        logger.err("KoPanda: could not add " .. what .. ":", result)
        return false
    end
    return result
end

-- The Home tab, index 2 of the file browser's menu.
function MenuEntries.home_tab()
    return MenuEntries.tab("home")
end

return MenuEntries
