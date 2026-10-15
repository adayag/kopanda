-- The two looks: their token tables by id, the active one from the look setting, and the
-- palette variant to draw with.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Settings = require("settings")

local Looks = {}

local ids = { "editorial", "diner" }

local looks = {
    editorial = require("looks/editorial"),
    diner = require("looks/diner"),
}

-- The look ids in the swatch's column order.
function Looks.ids()
    return { ids[1], ids[2] }
end

-- The token table of the look id, or nil for an id that is no look.
function Looks.get(id)
    return looks[id]
end

-- The token table of the look the settings choose (the schema default when none is stored).
function Looks.active()
    return looks[Settings.get("look")]
end

-- The palette to draw with: grey when the screen renders without colour, day otherwise.
-- isColorEnabled honours the user's color_rendering setting before the panel's capability
-- (frontend/device/generic/device.lua:265-271).
function Looks.variant()
    if Device.screen:isColorEnabled() then
        return "day"
    end
    return "grey"
end

-- The KOReader colour for a palette token's #rrggbb, or nil when it is not one. colorFromString
-- returns nil for a wrong length and raises for non-hex digits or a non-string
-- (base/ffi/blitbuffer.lua:2653-2683).
function Looks.color(hex)
    local ok, color = pcall(Blitbuffer.colorFromString, hex)
    if ok then
        return color
    end
    return nil
end

return Looks
