-- The home's date, from KOReader's translation tables so it follows its language
-- (frontend/datetime.lua:29-42 month names, :54-62 long day names), with no leading zero on the
-- day and no year. Editorial draws the weekday as a label over the month and day
-- (Main.dc.html:20-22); Diner draws one line (HomeRetro.dc.html:22). Left-aligned.
local Geom = require("ui/geometry")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Looks = require("looks")
local Typeset = require("typeset")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local datetime = require("datetime")

local LABEL_GAP = 2 -- between the weekday and the date (Main.dc.html:20)

local Date = {
    id = "date",
    settings_prefix = "date",
}

-- Whether look draws the date as one line.
local function one_line(look)
    return look == Looks.get("diner")
end

-- The date's lines at time t in look, before the type's case: the weekday and "October 13" in
-- Editorial, "Tuesday, October 13" in Diner. os.date's %a and %B are the C locale's English
-- names, the keys of KOReader's tables.
function Date.lines(look, t)
    local weekday = datetime.shortDayOfWeekToLongTranslation[os.date("%a", t)]
    local month = datetime.longMonthTranslation[os.date("%B", t)]
    local day = month .. " " .. tonumber(os.date("%d", t))
    if one_line(look) then
        return { weekday .. ", " .. day }
    end
    return { weekday, day }
end

local function make(width, ctx)
    local styles = ctx.look.type
    local lines = Date.lines(ctx.look, ctx.now)
    local content
    if #lines == 1 then
        content = Typeset.line(styles.date, lines[1], width, ctx)
    else
        content = VerticalGroup:new{
            align = "left",
            allow_mirroring = false,
            Typeset.line(styles.date_label, lines[1], width, ctx),
            VerticalSpan:new{ width = ctx.screen:scaleBySize(LABEL_GAP) },
            Typeset.line(styles.date, lines[2], width, ctx),
        }
    end
    return LeftContainer:new{
        dimen = Geom:new{ w = width, h = content:getSize().h },
        allow_mirroring = false,
        content,
    }
end

Date.height, Date.build = Typeset.measured(make)

return Date
