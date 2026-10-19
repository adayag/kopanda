-- KoPanda's settings on their own, for every caller outside KOReader's menu: menu.lua's rows in KOReader's
-- TouchMenu with one tab, inside a full-screen container as FileManagerMenu:onShowMenu builds its own
-- (frontend/apps/filemanager/filemanagermenu.lua:1006-1047). TouchMenu closes itself: a tap outside it, the
-- Back key or the up arrow at the top level, each through its default close_callback, which closes the
-- container (frontend/ui/widget/touchmenu.lua:499-504).
local CenterContainer = require("ui/widget/container/centercontainer")
local SchemaMenu = require("menu")
local TouchMenu = require("ui/widget/touchmenu")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local Screen = require("device").screen

local SettingsMenu = {}

-- Shows the rows for group (every row with none, or a group with no keys). A failure is logged
-- and shows nothing.
function SettingsMenu.open(group)
    local ok, err = pcall(function()
        local items = SchemaMenu.items(group)
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
