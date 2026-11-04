-- The header's weather line: the cached reading's line, fitted to the column. Diner puts the sun or the moon before
-- it; Editorial draws the line alone.
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local Icons = require("icons")
local Typeset = require("typeset")
local Weather = require("weather")

local WeatherWidget = {}

-- The cached reading's line in part, at most width wide, set smaller until it fits (Typeset.fitted) and then
-- cut with an ellipsis; with a reading, after the look's sun or moon (home.weather_icon) icon_px square.
function WeatherWidget.line(part, icon_px, width, ctx)
    local look = ctx.look
    local reading = Weather.reading()
    local group = HorizontalGroup:new{ align = "center" }
    local available = width
    local icon = look.home.weather_icon
    if reading and icon.shown then
        local gap = ctx.screen:scaleBySize(icon.gap)
        -- IconWidget renders the SVG through RenderImage:renderSVGImageFile
        -- (frontend/ui/widget/imagewidget.lua:175); alpha keeps its transparent ground.
        group[1] = IconWidget:new{
            file = Icons.path(reading.is_day == 1 and "sun" or "moon"),
            width = icon_px,
            height = icon_px,
            alpha = true,
        }
        group[2] = HorizontalSpan:new{ width = gap }
        available = math.max(0, width - icon_px - gap)
    end
    local text = Weather.line(reading, ctx.now, look)
    group[#group + 1] = Typeset.fitted(part, { text }, available, ctx)[1]
    return group
end

-- The header's weather line, at most width wide: in the weekday label's part, the icon the label's line tall. A
-- one-line date (widgets/date.lua) draws it over the date, the clock (widgets/clock.lua) over the time otherwise.
function WeatherWidget.header_line(width, ctx)
    local label = ctx.look.type.date_label
    return WeatherWidget.line(label, Typeset.line_height(label, ctx), width, ctx)
end

return WeatherWidget
