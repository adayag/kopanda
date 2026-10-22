-- The year's session records in an insight tile: a 2×2 grid of the session count, the longest and average
-- session and the pages read an hour, each value over its caption, from ReadingStats.insights.
local Geom = require("ui/geometry")
local Helpers = require("helpers")
local InsightTile = require("insight_tile")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local TextWidget = require("ui/widget/textwidget")
local Typeset = require("typeset")
local Widget = require("ui/widget/widget")

local VALUE_STEP = 2
local VALUE_MIN_SIZE = 14

local Records = {
    id = "records",
    settings_prefix = "stats",
}

-- The four { value, caption } cells in reading order for insights (ReadingStats.insights's shape), zeros when it
-- holds no sessions.
function Records.cells(insights)
    local s = insights.sessions or { count = 0, longest = 0, average = 0, pages_per_hour = 0 }
    return {
        { value = tostring(s.count), caption = "sessions" },
        { value = Helpers.duration(s.longest), caption = "longest" },
        { value = Helpers.duration(s.average), caption = "average" },
        { value = tostring(s.pages_per_hour), caption = "pages an hour" },
    }
end

-- Whether a line from Typeset.line shows its whole text: a tracked line is a group only when it fits, and a
-- TextWidget says when it cut its text (frontend/ui/widget/textwidget.lua:307).
local function whole(line)
    return getmetatable(line) ~= TextWidget or not line:isTruncated()
end

-- The four values set in part, at its size or the largest smaller one, a step at a time down to VALUE_MIN_SIZE,
-- that sets every value whole in column_w, so the grid's values read at one size; and that part.
local function value_lines(part, values, column_w, ctx)
    local sized = {}
    for k, v in pairs(part) do
        sized[k] = v
    end
    while true do
        local lines, fits = {}, true
        for i, value in ipairs(values) do
            lines[i] = Typeset.line(sized, value, column_w, ctx)
            fits = fits and whole(lines[i])
        end
        if fits or sized.size <= VALUE_MIN_SIZE then
            return lines, sized
        end
        for _, line in ipairs(lines) do
            line:free()
        end
        sized.size = math.max(VALUE_MIN_SIZE, sized.size - VALUE_STEP)
    end
end

-- The tile and the cells' lines, which the tile's paint draws but doesn't own.
local RecordsTile = Widget:extend{
    name = "kopanda_records",
}

function RecordsTile:free()
    local cells = self.cells
    if cells then
        self.cells = nil
        for _, cell in ipairs(cells) do
            cell.value:free()
            cell.caption:free()
        end
    end
    self.tile:free()
end

function RecordsTile:onCloseWidget()
    self:free()
end

function RecordsTile:paintTo(bb, x, y)
    self.tile:paintTo(bb, x, y)
end

local function compose(width, ctx)
    local insights = ReadingStats.insights(ctx.now)
    if insights.state == "off" then
        return InsightTile.compose(width, ctx, "Sessions", "Reading stats are off", 0, function() end)
    end
    local look = ctx.look
    local scale = Paint.scaler(ctx)
    local caption_part = look.type.insight_caption
    local column_gap = scale(look.home.column_gap)
    local value_gap, record_gap = scale(look.insights.value_gap), scale(look.insights.record_gap)
    local column_w = math.floor((InsightTile.inner_width(width, ctx) - column_gap) / 2)

    local records = Records.cells(insights)
    local values = {}
    for i, cell in ipairs(records) do
        values[i] = cell.value
    end
    local lines, value_part = value_lines(look.type.insight_value, values, column_w, ctx)
    local value_h = Typeset.line_height(value_part, ctx)
    local cell_h = value_h + value_gap + Typeset.line_height(caption_part, ctx)
    local cells = {}
    for i, cell in ipairs(records) do
        cells[i] = {
            value = lines[i],
            caption = Typeset.line(caption_part, cell.caption, column_w, ctx),
        }
    end
    local function paint(bb, x, y)
        for i, cell in ipairs(cells) do
            local cell_x = x + (i - 1) % 2 * (column_w + column_gap)
            local cell_y = y + math.floor((i - 1) / 2) * (cell_h + record_gap)
            cell.value:paintTo(bb, cell_x, cell_y)
            cell.caption:paintTo(bb, cell_x, cell_y + value_h + value_gap)
        end
    end
    local tile = InsightTile.compose(width, ctx, "Sessions", "last year", 2 * cell_h + record_gap, paint)
    return RecordsTile:new{
        dimen = Geom:new{ w = width, h = tile:getSize().h },
        tile = tile,
        cells = cells,
        value_size = value_part.size,
    }
end

Records.height, Records.build = Typeset.measured(compose)

return Records
