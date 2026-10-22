-- The calendar widget: this month's days in an insight tile, Monday first, the days read filled, the rest up to
-- today outlined, today ringed in ink, the days to come their number only.
describe("the calendar widget", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local InsightTile = require("insight_tile")
    local Looks = require("looks")
    local Paint = require("paint")
    local ReadingStats = require("reading_stats")
    local Typeset = require("typeset")
    local Calendar = require("widgets/calendar")

    local real_insights = ReadingStats.insights
    local insights

    before_each(function()
        local days = {}
        for i = 1, ReadingStats.INSIGHT_DAYS do
            days[i] = 0
        end
        insights = { state = "ok", days = days, hours = {}, sessions = nil }
        ReadingStats.insights = function()
            return insights
        end
    end)

    after_each(function()
        ReadingStats.insights = real_insights
    end)

    local function at(year, month, day, hour, min)
        return os.time{ year = year, month = month, day = day, hour = hour, min = min }
    end

    local function ctx_for(look_id, now)
        return {
            look = Looks.get(look_id),
            variant = "day",
            text_size = "medium",
            now = now or at(2026, 10, 13, 20, 42),
            screen = Screen,
        }
    end

    -- The fixture's day d days before today read for seconds.
    local function read(d, seconds)
        insights.days[#insights.days - d] = seconds
    end

    -- A line's text: a TextWidget's, or a tracked line's characters joined.
    local function text_of(line)
        if line.text then
            return line.text
        end
        local chars = {}
        for _, child in ipairs(line) do
            if child.text then
                chars[#chars + 1] = child.text
            end
        end
        return table.concat(chars)
    end

    local function painted_bb(widget)
        local size = widget:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        widget:paintTo(bb, 0, 0)
        return bb
    end

    local function same_color(bb, x, y, color)
        local c = bb:getPixel(x, y):getColorRGB32()
        local want = color:getColorRGB32()
        return c.r == want.r and c.g == want.g and c.b == want.b
    end

    -- The content's height for a month of rows under ctx, as the plan states it.
    local function content_h(rows, ctx)
        local scale = Paint.scaler(ctx)
        local tokens = ctx.look.insights
        return Typeset.line_height(ctx.look.type.insight_caption, ctx) + scale(tokens.label_gap)
            + rows * scale(tokens.calendar_cell) + (rows - 1) * scale(tokens.gap)
    end

    -- The top-left corner of the grid cell at column col and row row (both from 0) of tile under ctx.
    local function cell_at(tile, ctx, col, row)
        local scale = Paint.scaler(ctx)
        local tokens = ctx.look.insights
        local gap = scale(tokens.gap)
        local cell_w = math.floor((tile.inner_w - 6 * gap) / 7)
        local cell_h = scale(tokens.calendar_cell)
        local grid_y = tile.inner_y + tile.content_y + Typeset.line_height(ctx.look.type.insight_caption, ctx)
            + scale(tokens.label_gap)
        return tile.inner_x + col * (cell_w + gap), grid_y + row * (cell_h + gap), cell_w, cell_h
    end

    it("lays October 2026 out in five rows, the 1st in the fourth column, under the month's name", function()
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local tile = Calendar.build(520, ctx)
        assert.equals("OCTOBER", text_of(tile.label))
        local expected = InsightTile.compose(520, ctx, "October", "0 of 13 days", content_h(5, ctx), function() end)
        assert.equals(expected:getSize().h, tile:getSize().h)
        expected:free()
        local bb = painted_bb(tile)
        local outline = color(ctx.look.insights.empty_outline_color)
        local x, y = cell_at(tile, ctx, 3, 0)
        assert.is_true(same_color(bb, x, y, outline))
        x, y = cell_at(tile, ctx, 2, 0)
        assert.is_true(same_color(bb, x, y, color("paper")))
        tile:free()
    end)

    it("fills the days read, outlines the rest up to today, rings today and leaves the days to come bare", function()
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local scale = Paint.scaler(ctx)
        for d = 0, 3 do
            read(d, 600)
        end
        local tile = Calendar.build(520, ctx)
        assert.equals("4 of 13 days", text_of(tile.aside))
        local bb = painted_bb(tile)
        -- A cell's middle-left, clear of its outlines and its number.
        local inset = scale(ctx.look.insights.today_outline_width) + 2
        local function middle_left(col, row)
            local x, y, _, h = cell_at(tile, ctx, col, row)
            return x + inset, y + math.floor(h / 2)
        end
        -- October 2026 starts on a Thursday: the 9th is row 1 column 4, the 10th to 13th follow.
        local fill = color(ctx.look.insights.read_fill_color)
        for col, row in pairs({ [5] = 1, [6] = 1, [0] = 2, [1] = 2 }) do
            local x, y = middle_left(col, row)
            assert.is_true(same_color(bb, x, y, fill))
        end
        local x, y = middle_left(4, 1)
        assert.is_true(same_color(bb, x, y, color("paper")))
        x, y = cell_at(tile, ctx, 4, 1)
        assert.is_true(same_color(bb, x, y, color(ctx.look.insights.empty_outline_color)))
        x, y = cell_at(tile, ctx, 1, 2)
        assert.is_true(same_color(bb, x, y, color("ink")))
        x, y = middle_left(2, 2)
        assert.is_true(same_color(bb, x, y, color("paper")))
        x, y = cell_at(tile, ctx, 2, 2)
        assert.is_true(same_color(bb, x, y, color("paper")))
        tile:free()
    end)

    it("needs six rows for August 2026 and four for February 2027", function()
        local scale = Paint.scaler(ctx_for("diner"))
        local step = scale(Looks.get("diner").insights.calendar_cell) + scale(Looks.get("diner").insights.gap)
        local october = Calendar.height(520, ctx_for("diner"))
        -- August 2026 starts on a Saturday and has 31 days; February 2027 starts on a Monday and has 28.
        assert.equals(october + step, Calendar.height(520, ctx_for("diner", at(2026, 8, 20, 9, 0))))
        assert.equals(october - step, Calendar.height(520, ctx_for("diner", at(2027, 2, 20, 9, 0))))
    end)

    it("draws only its label line when the reading stats are off", function()
        insights = { state = "off" }
        local ctx = ctx_for("diner")
        local tile = Calendar.build(520, ctx)
        assert.equals("Reading stats are off", text_of(tile.aside))
        local bare = InsightTile.compose(520, ctx, "October", "Reading stats are off", 0, function() end)
        assert.equals(bare:getSize().h, tile:getSize().h)
        bare:free()
        painted_bb(tile)
        tile:free()
    end)

    it("is the tile around the initials line, the gap and the rows tall, at 520 wide", function()
        for _, id in ipairs(Looks.ids()) do
            local ctx = ctx_for(id)
            local tile = InsightTile.compose(520, ctx, "October", "0 of 13 days", content_h(5, ctx), function() end)
            assert.equals(tile:getSize().h, Calendar.height(520, ctx))
            tile:free()
        end
    end)

    -- Measured: the tallest, Toybox's six rows, are 520 px in its 530 px column at the Colorsoft and 508 px in
    -- 518 px at the Paperwhite; the shortest, Frosted's, 487 and 473.
    it("frees its lines once, on free or on close", function()
        local ctx = ctx_for("diner")
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local tile = Calendar.build(520, ctx)
            local freed = 0
            for _, line in ipairs(tile.lines) do
                local free = line.free
                line.free = function(self)
                    freed = freed + 1
                    return free(self)
                end
            end
            local count = #tile.lines
            assert.is_true(count >= 7 + 31)
            tile[close](tile)
            tile:free()
            assert.equals(count, freed)
        end
    end)

    it("is the registry's calendar", function()
        assert.equals(Calendar, require("widgets").get("calendar"))
    end)
end)
