-- Helpers shared by the specs of the home's gestures (spec/unit/gesture_routing_spec.lua and
-- spec/unit/hold_routing_spec.lua). Each reads the home module at call time, so it sees the one
-- the spec's harness.load() left loaded.
-- Busted gives a spec file its assert; a module required from one takes luassert, the same table.
local assert = require("luassert")
local harness = require("plugin_harness")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local M = {}

M.SETTINGS_TEXT = "KoPanda has no settings yet."

function M.send(ges)
    UIManager:sendEvent(Event:new("Gesture", ges))
end

-- The settings stub's message, wherever it is on the stack, or nil.
function M.settings_message()
    for _, widget in ipairs(harness.stack()) do
        if getmetatable(widget) == InfoMessage and widget.text == M.SETTINGS_TEXT then
            return widget
        end
    end
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
