-- The home's clock: the time of the home's last build, following KOReader's own 12-hour clock
-- setting, read as frontend/datetime.lua:298-300 reads it (unset is 24-hour). Right-aligned in
-- its column, set smaller until it fits there (Typeset.fitted). Beside a two-line date it's under the
-- weather's line (WeatherWidget.header_line), the date's label gap apart, so the weekday and the weather
-- share a line where the date and the time rise alike. No tap: a tap on the header falls through to the
-- home's top edge.
local Date = require("widgets/date")
local Geom = require("ui/geometry")
local RightContainer = require("ui/widget/container/rightcontainer")
local Typeset = require("typeset")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WeatherWidget = require("widgets/weather")

local Clock = {
    id = "clock",
    settings_prefix = "clock",
}

-- The time t as the clock reads it: "8:42" with the 12-hour clock, no leading zero and no AM/PM; otherwise
-- "8:42" or "20:42", the %-H:%M form KOReader gives the 24-hour time on Linux and Kindle
-- (frontend/datetime.lua:262-264).
function Clock.text(t)
    if G_reader_settings:isTrue("twelve_hour_clock") then
        local hour = tonumber(os.date("%H", t)) % 12
        return (hour == 0 and 12 or hour) .. os.date(":%M", t)
    end
    return os.date("%-H:%M", t)
end

local function make(width, ctx)
    local time = Typeset.fitted(ctx.look.type.clock, { Clock.text(ctx.now) }, width, ctx)[1]
    local content = time
    if not Date.one_line(ctx.look) then
        content = VerticalGroup:new{
            align = "right",
            allow_mirroring = false,
            WeatherWidget.header_line(width, ctx),
            VerticalSpan:new{ width = ctx.screen:scaleBySize(Date.LABEL_GAP) },
            time,
        }
    end
    local h = content:getSize().h
    return RightContainer:new{
        dimen = Geom:new{ w = width, h = h },
        allow_mirroring = false,
        content,
    }, h - time:getSize().h + Typeset.baseline(time)
end

Clock.height, Clock.build, Clock.baseline = Typeset.measured(make)

return Clock
