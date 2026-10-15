-- The home's weather widget: the cached reading's line, left-aligned and cut with an ellipsis
-- to the column, set in the look's type.weather part. Diner puts the sun or the moon before it
-- (HomeRetro.dc.html:48-51, NightC.dc.html:48-50); Editorial draws the line alone
-- (Main.dc.html:25). A tap fetches the weather.
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local Icons = require("icons")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Looks = require("looks")
local Typeset = require("typeset")
local Weather = require("weather")

-- The id of the look whose tokens are look.
local function look_id(look)
    for _, id in ipairs(Looks.ids()) do
        if Looks.get(id) == look then
            return id
        end
    end
end

local function make(width, ctx)
    local look = ctx.look
    local reading = Weather.reading()
    local group = HorizontalGroup:new{ align = "center" }
    local available = width
    local icon = look.home.weather_icon
    if reading and icon.size > 0 then
        local size = ctx.screen:scaleBySize(icon.size)
        local gap = ctx.screen:scaleBySize(icon.gap)
        -- IconWidget renders the SVG through RenderImage:renderSVGImageFile
        -- (frontend/ui/widget/imagewidget.lua:175); alpha keeps its transparent ground.
        group[1] = IconWidget:new{
            file = Icons.path(reading.is_day == 1 and "sun" or "moon"),
            width = size,
            height = size,
            alpha = true,
        }
        group[2] = HorizontalSpan:new{ width = gap }
        available = math.max(0, width - size - gap)
    end
    local text = Weather.line(reading, ctx.now, look_id(look))
    group[#group + 1] = Typeset.line(look.type.weather, text, available, ctx)
    return LeftContainer:new{
        dimen = Geom:new{ w = width, h = group:getSize().h },
        group,
    }
end

local height, build = Typeset.measured(make)

return {
    id = "weather",
    settings_prefix = "weather",
    height = height,
    build = build,
    tap = function(ctx)
        Weather.tap(ctx.home)
    end,
}
