-- The home's clock: the time of the home's last build, following KOReader's own 12-hour clock
-- setting, read as frontend/datetime.lua:298-300 reads it (unset is 24-hour). Right-aligned in
-- its column.
local Geom = require("ui/geometry")
local RightContainer = require("ui/widget/container/rightcontainer")
local Typeset = require("typeset")

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
    local content = Typeset.line(ctx.look.type.clock, Clock.text(ctx.now), width, ctx)
    return RightContainer:new{
        dimen = Geom:new{ w = width, h = content:getSize().h },
        allow_mirroring = false,
        content,
    }, Typeset.baseline(content)
end

Clock.height, Clock.build, Clock.baseline = Typeset.measured(make)

return Clock
