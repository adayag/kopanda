-- The streak in an insight tile: the run of consecutive days read to today, the best run in ReadingStats.insights'
-- days, and this week's days as dots, Monday first, each day read filled and today ringed.
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")

local Streak = {
    id = "streak",
    settings_prefix = "stats",
}

-- The current and the best run of days read in days (seconds per day, today last): the current one ends today,
-- or yesterday while today has no reading yet.
function Streak.runs(days)
    local best, run = 0, 0
    for _, seconds in ipairs(days) do
        run = seconds > 0 and run + 1 or 0
        best = math.max(best, run)
    end
    local i = #days
    if days[i] == 0 then
        i = i - 1
    end
    local current = 0
    while i >= 1 and days[i] > 0 do
        current = current + 1
        i = i - 1
    end
    return current, best
end

-- The row of t's weekday, Monday first.
local function row_of(t)
    return (tonumber(os.date("%w", t)) + 6) % 7 + 1
end

local function compose(width, ctx)
    local insights = ReadingStats.insights(ctx.now)
    if insights.state == "off" then
        return InsightTile.compose(width, ctx, "Streak", "Reading stats are off", 0, function() end)
    end

    local look = ctx.look
    local tokens = look.insights
    local scale = Paint.scaler(ctx)
    local color = Looks.colorer(ctx)
    local inner_w = InsightTile.inner_width(width, ctx)
    local label_gap, record_gap = scale(tokens.label_gap), scale(tokens.record_gap)
    local days = insights.days
    local current, best = Streak.runs(days)

    local count_part = {}
    for k, v in pairs(look.type.insight_value) do
        count_part[k] = v
    end
    count_part.size = look.type.insight_value.size * tokens.streak_scale
    local count = Typeset.line(count_part, tostring(current), inner_w, ctx)
    local count_w = count:getSize().w
    local note = Typeset.line(look.type.insight_note, current == 1 and "day in a row" or "days in a row",
        math.max(1, inner_w - count_w - label_gap), ctx)
    local note_y = Typeset.baseline(count) - Typeset.baseline(note)
    local count_y = math.max(0, -note_y)
    note_y = count_y + note_y
    local line_h = math.max(count_y + count:getSize().h, note_y + note:getSize().h)

    local dot, dot_gap = scale(tokens.dot), scale(tokens.dot_gap)
    local caption_part = look.type.insight_caption
    local caption_h = Typeset.line_height(caption_part, ctx)
    local row_h = math.max(dot, caption_h)
    local dots_w = 7 * dot + 6 * dot_gap
    local caption = Typeset.line(caption_part, "this week", math.max(1, inner_w - dots_w - label_gap), ctx)
    local today = row_of(ctx.now)
    local fill, ring, empty = color(tokens.dot_fill_color), color(tokens.today_ring_color),
        color(tokens.dot_empty_color)
    local paper = color("paper")
    local ring_w = scale(tokens.today_outline_width)
    local outline_w = scale(look.stroke.hairline or 1)
    local r = math.floor(dot / 2)

    local function paint(bb, x, y)
        count:paintTo(bb, x, y + count_y)
        note:paintTo(bb, x + count_w + label_gap, y + note_y)
        local row_y = y + line_h + record_gap
        local dot_y = row_y + math.floor((row_h - dot) / 2)
        for i = 1, 7 do
            local seconds = i <= today and days[#days - today + i] or 0
            local dx = x + (i - 1) * (dot + dot_gap)
            if seconds > 0 then
                Paint.fill(bb, dx, dot_y, dot, dot, fill, r)
            elseif i == today then
                Paint.fill(bb, dx, dot_y, dot, dot, paper, r)
            end
            if i == today then
                Paint.border(bb, dx, dot_y, dot, dot, ring_w, ring, r)
            elseif seconds == 0 then
                Paint.border(bb, dx, dot_y, dot, dot, outline_w, empty, r)
            end
        end
        caption:paintTo(bb, x + dots_w + label_gap, row_y + math.floor((row_h - caption_h) / 2))
    end

    local tile = InsightTile.compose(width, ctx, "Streak", "best " .. best, line_h + record_gap + row_h, paint)
    tile.count, tile.note, tile.caption = count, note, caption
    local free_tile = tile.free
    function tile:free()
        for _, name in ipairs({ "count", "note", "caption" }) do
            if self[name] then
                self[name]:free()
                self[name] = nil
            end
        end
        free_tile(self)
    end
    return tile
end

Streak.height, Streak.build = Typeset.measured(compose)

return Streak
