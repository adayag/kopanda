-- The looks: their token tables by id, the active one from the look setting, and the palette
-- variant to draw with. Adding a look is its id here, its token file looks/<id>.lua, its
-- require in main.lua and its choice of the look setting in schema.lua.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Settings = require("settings")

local Looks = {}

-- The look ids in the swatch's column order.
local ids = { "editorial", "diner", "riso", "toybox" }

local looks = {}
for _, id in ipairs(ids) do
    -- The plugin's own looks/<id>.lua, not a KOReader module HOOKS.md names.
    local module = "looks/" .. id
    looks[id] = require(module)
end

-- The look ids in the swatch's column order, as a fresh list.
function Looks.ids()
    local copy = {}
    for i, id in ipairs(ids) do
        copy[i] = id
    end
    return copy
end

-- The token table of the look id, or nil for an id that is no look.
function Looks.get(id)
    return looks[id]
end

-- The token table of the look the settings choose (the schema default when none is stored).
function Looks.active()
    return looks[Settings.get("look")]
end

-- The palette variant to draw with: grey when the screen renders without colour, whatever the
-- night mode; night when KOReader's night mode is on (Screen.night_mode,
-- base/ffi/framebuffer.lua:22, :476-477); day otherwise. isColorEnabled honours the user's
-- color_rendering setting before the panel's capability (frontend/device/generic/device.lua:265-271).
function Looks.variant()
    if not Device.screen:isColorEnabled() then
        return "grey"
    end
    if Device.screen.night_mode then
        return "night"
    end
    return "day"
end

-- Each look's night palette inverted, by look table; never written into the look itself.
local inverted = setmetatable({}, { __mode = "k" })

-- The per-channel inverse of a #rrggbb; any other value as it is.
local function invert(value)
    if type(value) ~= "string" then
        return value
    end
    local r, g, b = value:match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then
        return value
    end
    return string.format("#%02x%02x%02x", 255 - tonumber(r, 16), 255 - tonumber(g, 16), 255 - tonumber(b, 16))
end

-- The palette to paint look with in variant. KOReader's night mode inverts everything painted
-- (base/ffi/framebuffer.lua:476-488), so night paints the night palette inverted and the panel
-- shows it as designed; day and grey are the look's own.
function Looks.palette(look, variant)
    if variant ~= "night" then
        return look.palettes[variant]
    end
    local palette = inverted[look]
    if not palette then
        palette = {}
        for role, value in pairs(look.palettes.night) do
            palette[role] = invert(value)
        end
        inverted[look] = palette
    end
    return palette
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
