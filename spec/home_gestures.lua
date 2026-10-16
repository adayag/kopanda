-- Helpers shared by the specs of the home's gestures (spec/unit/gesture_routing_spec.lua and
-- spec/unit/hold_routing_spec.lua). Each reads the home module at call time, so it sees the one
-- the spec's harness.load() left loaded.
-- Busted gives a spec file its assert; a module required from one takes luassert, the same table.
local assert = require("luassert")
local harness = require("plugin_harness")
local Event = require("ui/event")
local TouchMenu = require("ui/widget/touchmenu")
local UIManager = require("ui/uimanager")

local M = {}

function M.send(ges)
    UIManager:sendEvent(Event:new("Gesture", ges))
end

-- KoPanda's settings menu (settings_menu.lua), wherever it is on the stack, or nil: the container
-- holding a TouchMenu of one tab, which KOReader's own menus never are.
function M.settings_menu()
    for _, widget in ipairs(harness.stack()) do
        local menu = widget[1]
        if getmetatable(menu) == TouchMenu and #menu.tab_item_table == 1 then
            return widget
        end
    end
end

-- The settings menu's rows as their schema keys, in order, or nil with no settings menu shown.
function M.settings_keys()
    local container = M.settings_menu()
    if not container then
        return nil
    end
    local keys = {}
    for i, item in ipairs(container[1].tab_item_table[1]) do
        keys[i] = item.kopanda_key
    end
    return keys
end

-- A file manager with its home up.
function M.fm_with_home(dir)
    local fm = harness.show_fm(dir)
    harness.tick(2)
    assert.equals(require("home").shown, harness.top())
    return fm
end

-- The shown home's slot for widget id.
function M.slot_of(id)
    for _, slot in ipairs(require("home").shown.slots) do
        if slot.widget == id then
            return slot
        end
    end
end

function M.point(x, y)
    return require("ui/geometry"):new{ x = x, y = y, w = 0, h = 0 }
end

return M
