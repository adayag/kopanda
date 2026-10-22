-- This month's calendar in an insight tile, Monday first: the days read (ReadingStats.insights) filled, the other
-- days up to today outlined, today ringed in ink, the days to come their number only. The month and weekday names
-- come from KOReader's translation tables (frontend/datetime.lua:29-42, :54-62).
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")
local datetime = require("datetime")
local util = require("util")

local WEEKDAYS = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }

local Calendar = {
    id = "calendar",
    settings_prefix = "stats",
}

-- The month holding t: its name, its number of days, the column of its 1st (0 for Monday), the rows it needs
-- and t's day of the month. os.date's %B is the C locale's English name, the key of KOReader's table.
local function month_of(t)
    local date = os.date("*t", t)
    local first = os.time{ year = date.year, month = date.month, day = 1, hour = 12 }
    local days = os.date("*t", os.time{ year = date.year, month = date.month + 1, day = 0, hour = 12 }).day
    local offset = (tonumber(os.date("%w", first)) + 6) % 7
    return {
        name = datetime.longMonthTranslation[os.date("%B", t)],
        days = days,
        offset = offset,
        rows = math.ceil((offset + days) / 7),
        today = date.day,
    }
end

-- A copy of the type part part, set in the colour role role instead of its own.
local function recolored(part, role)
    local copy = {}
    for name, value in pairs(part) do
        copy[name] = value
    end
    copy.color = role
    return copy
end

local function compose(width, ctx)
    local month = month_of(ctx.now)
    local insights = ReadingStats.insights(ctx.now)
    if insights.state == "off" then
        return (InsightTile.compose(width, ctx, month.name, "Reading stats are off", 0, function() end))
    end

    local tokens = ctx.look.insights
    local caption = ctx.look.type.insight_caption
    local color = Looks.colorer(ctx)
    local scale = Paint.scaler(ctx)
    local gap = scale(tokens.gap)
    local cell_w = math.floor((InsightTile.inner_width(width, ctx) - 6 * gap) / 7)
    local cell_h = scale(tokens.calendar_cell)
    local caption_h = Typeset.line_height(caption, ctx)
    local grid_y = caption_h + scale(tokens.label_gap)

    -- Every line and where it paints, and every cell up to today, from the content's top-left.
    local lines, placed, cells = {}, {}, {}
    local function place(part, text, x, y, h)
        local line = Typeset.line(part, text, cell_w, ctx)
        local size = line:getSize()
        lines[#lines + 1] = line
        placed[#placed + 1] = {
            line = line,
            x = x + math.floor((cell_w - size.w) / 2),
            y = y + math.floor((h - size.h) / 2),
        }
    end

    for i, key in ipairs(WEEKDAYS) do
        local initial = util.splitToChars(datetime.shortDayOfWeekToLongTranslation[key])[1]
        place(caption, initial, (i - 1) * (cell_w + gap), 0, caption_h)
    end

    local read_part = recolored(caption, tokens.read_text_color)
    local later_part = recolored(caption, "muted")
    local read = 0
    for day = 1, month.days do
        local index = month.offset + day - 1
        local x = index % 7 * (cell_w + gap)
        local y = grid_y + math.floor(index / 7) * (cell_h + gap)
        local part = later_part
        if day <= month.today then
            local filled = insights.days[#insights.days - (month.today - day)] > 0
            if filled then
                read = read + 1
                part = read_part
            else
                part = caption
            end
            cells[#cells + 1] = { x = x, y = y, filled = filled, today = day == month.today }
        end
        place(part, tostring(day), x, y, cell_h)
    end

    local fill = color(tokens.read_fill_color)
    local outline = color(tokens.empty_outline_color)
    local ink = color("ink")
    local ring = scale(tokens.today_outline_width)
    local content_h = grid_y + month.rows * cell_h + (month.rows - 1) * gap
    local tile = InsightTile.compose(width, ctx, month.name, read .. " of " .. month.today .. " days", content_h,
        function(bb, x, y)
            for _, cell in ipairs(cells) do
                if cell.filled then
                    Paint.fill(bb, x + cell.x, y + cell.y, cell_w, cell_h, fill)
                else
                    Paint.border(bb, x + cell.x, y + cell.y, cell_w, cell_h, 1, outline)
                end
                if cell.today then
                    Paint.border(bb, x + cell.x, y + cell.y, cell_w, cell_h, ring, ink)
                end
            end
            for _, at in ipairs(placed) do
                at.line:paintTo(bb, x + at.x, y + at.y)
            end
        end)

    tile.lines = lines
    local free_tile = tile.free
    function tile:free()
        for _, line in ipairs(self.lines) do
            line:free()
        end
        self.lines = {}
        free_tile(self)
    end
    return tile
end

Calendar.height, Calendar.build = Typeset.measured(compose)

return Calendar
