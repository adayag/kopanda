-- The home's date, from KOReader's translation tables so it follows its language (frontend/datetime.lua:14-27
-- short and :29-42 long month names, :44-52 short and :54-62 long day names), with no leading zero on the day
-- and no year. The look's home.date_lines chooses: 2 draws the weekday as a label over the month and day, 1
-- draws one line under the weather's (WeatherWidget.header_line). Left-aligned; a date too wide for its column
-- is set smaller until it fits (Typeset.fitted), in the short names when the long ones don't fit at the
-- smallest size.
local Geom = require("ui/geometry")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Typeset = require("typeset")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WeatherWidget = require("widgets/weather")
local datetime = require("datetime")

local Date = {
    id = "date",
    settings_prefix = "date",
    LABEL_GAP = 2, -- under the label line over the date or the time: the weekday's or the weather's
}

-- Whether look draws the date as one line, under the weather's.
function Date.one_line(look)
    return look.home.date_lines == 1
end

-- The date's lines at time t in look, before the type's case: the weekday and "October 13" in
-- Editorial, "Tuesday, October 13" in Diner, or with short true "Tue" and "Oct 13". os.date's %a,
-- %b and %B are the C locale's English names, the keys of KOReader's tables.
function Date.lines(look, t, short)
    local weekday = datetime.shortDayOfWeekToLongTranslation[os.date("%a", t)]
    local month = datetime.longMonthTranslation[os.date("%B", t)]
    if short then
        weekday = datetime.shortDayOfWeekTranslation[os.date("%a", t)]
        month = datetime.shortMonthTranslation[os.date("%b", t)]
    end
    local day = month .. " " .. tonumber(os.date("%d", t))
    if Date.one_line(look) then
        return { weekday .. ", " .. day }
    end
    return { weekday, day }
end

local function make(width, ctx)
    local styles = ctx.look.type
    local lines = Date.lines(ctx.look, ctx.now)
    local last = Typeset.fitted(styles.date, { lines[#lines] }, width, ctx)[1]
    if not Typeset.whole(last) then
        last:free()
        lines = Date.lines(ctx.look, ctx.now, true)
        last = Typeset.fitted(styles.date, { lines[#lines] }, width, ctx)[1]
    end
    local label
    if #lines == 2 then
        label = Typeset.fitted(styles.date_label, { lines[1] }, width, ctx)[1]
    else
        label = WeatherWidget.header_line(width, ctx)
    end
    local content = VerticalGroup:new{
        align = "left",
        allow_mirroring = false,
        label,
        VerticalSpan:new{ width = ctx.screen:scaleBySize(Date.LABEL_GAP) },
        last,
    }
    -- The last line is the content's bottom.
    local h = content:getSize().h
    return LeftContainer:new{
        dimen = Geom:new{ w = width, h = h },
        allow_mirroring = false,
        content,
    }, h - last:getSize().h + Typeset.baseline(last)
end

Date.height, Date.build, Date.baseline = Typeset.measured(make)

return Date
