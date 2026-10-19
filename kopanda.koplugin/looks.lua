-- The looks: their token tables by id, the active one from the look setting, and the palette
-- variant to draw with. Every token path is declared in looks/base.lua; a look's file
-- looks/<id>.lua declares only what differs from it. Adding a look is its id here, its token
-- file, its require in main.lua and its choice of the look setting in schema.lua.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Settings = require("settings")

local Looks = {}

-- The look ids in the swatch's column order.
local ids = { "editorial", "diner", "riso", "toybox", "frosted" }

-- A fresh copy of a token value, its tables copied all the way down.
local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deep_copy(v)
    end
    return out
end

-- The base's tokens with a look file's laid over them, both left as they were: a key the file
-- sets wins, false included; a table under the same key in both is laid over key by key; a list
-- (a table with [1]) is replaced whole.
local function inherit(base, own)
    local merged = deep_copy(own)
    for k, v in pairs(base) do
        local mine = own[k]
        if mine == nil then
            merged[k] = deep_copy(v)
        elseif type(v) == "table" and type(mine) == "table" and v[1] == nil and mine[1] == nil then
            merged[k] = inherit(v, mine)
        end
    end
    return merged
end

-- The plugin's own looks/base.lua and looks/<id>.lua, not KOReader modules HOOKS.md names.
local base = require("looks/base")
local looks = {}
for _, id in ipairs(ids) do
    local module = "looks/" .. id
    looks[id] = inherit(base, require(module))
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
