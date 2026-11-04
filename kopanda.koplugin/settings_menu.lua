-- KoPanda's settings on their own, for every caller outside KOReader's menu: menu.lua's rows in KOReader's
-- TouchMenu with one tab, inside a full-screen container as FileManagerMenu:onShowMenu builds its own
-- (frontend/apps/filemanager/filemanagermenu.lua:1006-1047). TouchMenu closes itself: a tap outside it, the
-- Back key or the up arrow at the top level, each through its default close_callback, which closes the
-- container (frontend/ui/widget/touchmenu.lua:499-504).
local CenterContainer = require("ui/widget/container/centercontainer")
local Guards = require("guards")
local SchemaMenu = require("menu")
local StudioMenu = require("studio_menu")
local TouchMenu = require("ui/widget/touchmenu")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local Screen = require("device").screen

local SettingsMenu = {}

-- The plugin folder, as fonts.lua finds it: as require found this file.
local PLUGIN_DIR = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")

-- Storefront's dispatcher action, as the launcher runs a plugin's (launcher_entries.lua:61-80).
local STOREFRONT = { kind = "plugin", plugin = "storefront", action = "storefront_open", label = "Storefront" }

-- The Updates section: actions, not settings, after the last setting and a separator. KOReader menu opens
-- FileManagerMenu:onShowMenu (filemanagermenu.lua:1006) and shows only with a file manager up: opening a book closes it
-- (filemanager.lua:834-839). Apps (Storefront) shows only while the launcher could run it; a check that raises reads
-- as no.
local function updates(items)
    -- launcher_entries requires this module, so it is required here, at call time.
    local LauncherEntries = require("launcher_entries")
    if #items > 0 then
        items[#items].separator = true
    end
    local check = "Settings › Check for KoPanda update"
    items[#items + 1] = {
        text = "Check for KoPanda update",
        callback = Guards.after_menu(check, function()
            StudioMenu.check_for_update({ path = PLUGIN_DIR }, check)
        end),
    }
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    if FileManager and FileManager.instance and FileManager.instance.menu then
        items[#items + 1] = {
            text = "KOReader menu",
            callback = Guards.after_menu("Settings › KOReader menu", function()
                FileManager.instance.menu:onShowMenu()
            end),
        }
    end
    local ok, available = pcall(LauncherEntries.available, STOREFRONT)
    if ok and available then
        items[#items + 1] = {
            text = "Apps (Storefront)",
            callback = Guards.after_menu("Settings › Apps (Storefront)", function()
                LauncherEntries.run(STOREFRONT)
            end),
        }
    end
end

-- Shows the rows for group (every row with none, or a group with no keys), and without a group the Updates
-- section after them. A failure is logged and shows nothing.
function SettingsMenu.open(group)
    local ok, err = pcall(function()
        local items = SchemaMenu.items(group)
        if group == nil then
            updates(items)
        end
        -- The icon KOReader's own settings tab uses (filemanagermenu.lua:37).
        items.icon = "appbar.settings"
        local container = CenterContainer:new{ dimen = Screen:getSize(), ignore = "height" }
        container[1] = TouchMenu:new{
            width = Screen:getWidth(),
            tab_item_table = { items },
            show_parent = container,
        }
        UIManager:show(container)
    end)
    if not ok then
        logger.err("KoPanda: could not open the settings menu:", err)
    end
end

return SettingsMenu
