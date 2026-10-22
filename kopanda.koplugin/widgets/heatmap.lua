-- The year heatmap: the reading history's days (ReadingStats.insights) as 53 week columns of Monday-first days in
-- an insight tile, today in the last column, each day filled by its level, with the months' abbreviations from
-- KOReader's translation table (frontend/datetime.lua:14-27) under the grid.
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local datetime = require("datetime")

local COLUMNS = 53
local LEVEL_2 = 900 -- 15 minutes
local LEVEL_3 = 2700 -- 45 minutes

local Heatmap = {
    id = "heatmap",
    settings_prefix = "stats",
}

-- The tile and the month captions it paints, which it frees with itself.
local Grid = WidgetContainer:extend{
    name = "kopanda_heatmap",
}

function Grid:free()
    for _, caption in ipairs(self.captions) do
        caption.line:free()
    end
    self.captions = {}
    WidgetContainer.free(self)
end

function Grid:onCloseWidget()
    self:free()
end

local function aside_of(insights)
    if insights.state == "off" then
        return "Reading stats are off"
    end
    local total, read = 0, 0
    for _, seconds in ipairs(insights.days) do
        total = total + seconds
        if seconds > 0 then
            read = read + 1
        end
    end
    if read == 0 then
        return "Nothing read yet"
    end
    return string.format("%d h over %d %s", math.floor(total / 3600), read, read == 1 and "day" or "days")
end

-- The row of t's weekday, Monday first.
local function row_of(t)
    return (tonumber(os.date("%w", t)) + 6) % 7 + 1
end

-- The noon of the day back days before t's, so a DST change never moves the day.
local function day_before(t, back)
    local day = os.date("*t", t)
    return os.time{ year = day.year, month = day.month, day = day.day - back, hour = 12 }
end

-- The month captions under ctx, one at the x of each of columns 2 to 53 whose Monday falls in another month than
-- the column before's, each cut to the room right of its x.
local function month_captions(now, pitch, inner_w, ctx)
    local today_row = row_of(now)
    local captions = {}
    local month = os.date("%b", day_before(now, (COLUMNS - 1) * 7 + today_row - 1))
    for column = 2, COLUMNS do
        local abbreviation = os.date("%b", day_before(now, (COLUMNS - column) * 7 + today_row - 1))
        if abbreviation ~= month then
            month = abbreviation
            local x = (column - 1) * pitch
            captions[#captions + 1] = {
                x = x,
                line = Typeset.line(ctx.look.type.insight_caption, datetime.shortMonthTranslation[abbreviation],
                    inner_w - x, ctx),
            }
        end
    end
    return captions
end

local function compose(width, ctx)
    local insights = ReadingStats.insights(ctx.now)
    local aside = aside_of(insights)
    if insights.state == "off" then
        return Grid:new{
            captions = {},
            (InsightTile.compose(width, ctx, "Reading this year", aside, 0, function() end)),
        }
    end

    local look = ctx.look
    local tokens = look.insights
    local scale = Paint.scaler(ctx)
    local color = Looks.colorer(ctx)
    local gap = scale(tokens.gap)
    local inner_w = InsightTile.inner_width(width, ctx)
    local cell = math.min(scale(tokens.cell_max), math.floor((inner_w - (COLUMNS - 1) * gap) / COLUMNS))
    local pitch = cell + gap
    local grid_h = 7 * cell + 6 * gap
    local label_gap = scale(tokens.label_gap)
    local caption_h = Typeset.line_height(look.type.insight_caption, ctx)
    local captions = month_captions(ctx.now, pitch, inner_w, ctx)
    local levels = { color(tokens.level_1_color), color(tokens.level_2_color), color(tokens.level_3_color) }
    local empty_color = color(tokens.empty_outline_color)
    local empty_w = scale(1)
    local days = insights.days
    local today_row = row_of(ctx.now)

    local function paint(bb, x, y)
        for column = 1, COLUMNS do
            for row = 1, 7 do
                local seconds = days[#days + (column - COLUMNS) * 7 + row - today_row]
                if seconds then
                    local cx, cy = x + (column - 1) * pitch, y + (row - 1) * pitch
                    if seconds == 0 then
                        Paint.border(bb, cx, cy, cell, cell, empty_w, empty_color)
                    else
                        local level = seconds < LEVEL_2 and 1 or seconds < LEVEL_3 and 2 or 3
                        Paint.fill(bb, cx, cy, cell, cell, levels[level])
                    end
                end
            end
        end
        for _, caption in ipairs(captions) do
            caption.line:paintTo(bb, x + caption.x, y + grid_h + label_gap)
        end
    end

    return Grid:new{
        captions = captions,
        (InsightTile.compose(width, ctx, "Reading this year", aside, grid_h + label_gap + caption_h, paint)),
    }
end

Heatmap.height, Heatmap.build = Typeset.measured(compose)

return Heatmap
