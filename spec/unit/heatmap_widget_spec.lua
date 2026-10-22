-- The year heatmap: 53 weeks of days in an insight tile, today in the last column at its Monday-first row, each
-- day filled by its level, month names under the grid, and the year's hours in the aside.
describe("the heatmap widget", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local Looks = require("looks")
    local Paint = require("paint")
    local Typeset = require("typeset")
    local InsightTile = require("insight_tile")
    local ReadingStats = require("reading_stats")
    local Heatmap = require("widgets/heatmap")

    local real_insights = ReadingStats.insights
    local fixture

    before_each(function()
        ReadingStats.insights = function()
            return fixture
        end
    end)

    after_each(function()
        ReadingStats.insights = real_insights
    end)

    -- A Tuesday: today sits on the second row.
    local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 8, min = 42 }

    local function ctx_for(look_id)
        return {
            look = Looks.get(look_id or "diner"),
            variant = "day",
            text_size = "medium",
            now = NOW,
            screen = Screen,
        }
    end

    -- An ok reading history of count days (371 unless given), zero but for seconds[i], i counted back from today
    -- at 0.
    local function history(seconds, count)
        local days = {}
        count = count or ReadingStats.INSIGHT_DAYS
        for i = 1, count do
            days[i] = 0
        end
        for back, s in pairs(seconds) do
            days[count - back] = s
        end
        local hours = {}
        for i = 1, 24 do
            hours[i] = 0
        end
        return { state = "ok", days = days, hours = hours }
    end

    local function painted_bb(widget)
        local size = widget:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, size.w, size.h, Blitbuffer.ColorRGB32(0, 255, 0, 0xFF))
        widget:paintTo(bb, 0, 0)
        return bb
    end

    local function same_color(bb, x, y, color)
        local c = bb:getPixel(x, y):getColorRGB32()
        local want = color:getColorRGB32()
        return c.r == want.r and c.g == want.g and c.b == want.b
    end

    -- The top-left of the cell at column, row (from 1) of a widget width wide under ctx, and the cell's side.
    local function cell_at(widget, width, ctx, column, row)
        local tile = widget[1]
        local scale = Paint.scaler(ctx)
        local gap = scale(ctx.look.insights.gap)
        local cell = math.min(scale(ctx.look.insights.cell_max),
            math.floor((InsightTile.inner_width(width, ctx) - 52 * gap) / 53))
        return tile.inner_x + (column - 1) * (cell + gap), tile.inner_y + tile.content_y + (row - 1) * (cell + gap),
            cell
    end

    -- The colour at the centre of the cell at column, row.
    local function centre_is(bb, widget, width, ctx, column, row, color)
        local x, y, cell = cell_at(widget, width, ctx, column, row)
        local half = math.floor(cell / 2)
        return same_color(bb, x + half, y + half, color)
    end

    it("draws today in the last of 53 columns at its weekday's row, each day in its level's colour", function()
        assert.equals(2, tonumber(os.date("%w", NOW)))
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local insights = ctx.look.insights
        local level_1, level_2, level_3 = color(insights.level_1_color), color(insights.level_2_color),
            color(insights.level_3_color)
        local paper = color(ctx.look.tile.fill_color)
        local shades = { level_1, level_2, level_3, paper }
        for i = 1, #shades do
            for j = i + 1, #shades do
                assert.are_not.same(shades[i]:getColorRGB32(), shades[j]:getColorRGB32())
            end
        end
        fixture = history{ [0] = 3000, [1] = 899, [2] = 900, [7] = 2699, [8] = 2700, [364] = 1 }
        local widget = Heatmap.build(520, ctx)
        local bb = painted_bb(widget)
        assert.is_true(centre_is(bb, widget, 520, ctx, 53, 2, level_3))
        assert.is_true(centre_is(bb, widget, 520, ctx, 53, 1, level_1))
        assert.is_true(centre_is(bb, widget, 520, ctx, 52, 7, level_2))
        assert.is_true(centre_is(bb, widget, 520, ctx, 52, 2, level_2))
        assert.is_true(centre_is(bb, widget, 520, ctx, 52, 1, level_3))
        assert.is_true(centre_is(bb, widget, 520, ctx, 1, 2, level_1))
        widget:free()
    end)

    it("draws a day with no reading as an outline on the tile's paper", function()
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local paper = color(ctx.look.tile.fill_color)
        local outline = color(ctx.look.insights.empty_outline_color)
        assert.are_not.same(paper:getColorRGB32(), outline:getColorRGB32())
        fixture = history{ [0] = 3000 }
        local widget = Heatmap.build(520, ctx)
        local bb = painted_bb(widget)
        assert.is_true(centre_is(bb, widget, 520, ctx, 53, 1, paper))
        local x, y = cell_at(widget, 520, ctx, 53, 1)
        assert.is_true(same_color(bb, x, y, outline))
        widget:free()
    end)

    it("draws nothing after today, nor before the window's first day", function()
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local paper = color(ctx.look.tile.fill_color)
        local outline = color(ctx.look.insights.empty_outline_color)
        fixture = history({ [0] = 3000 }, 10)
        local widget = Heatmap.build(520, ctx)
        local bb = painted_bb(widget)
        local function bare(column, row)
            local x, y, cell = cell_at(widget, 520, ctx, column, row)
            local half = math.floor(cell / 2)
            return same_color(bb, x, y, paper) and same_color(bb, x + half, y + half, paper)
        end
        -- Tomorrow, and the day after today's Sunday.
        assert.is_true(bare(53, 3))
        assert.is_true(bare(53, 7))
        -- The window's first day, nine days back on a Sunday, is drawn; the Saturday before it isn't.
        local x, y = cell_at(widget, 520, ctx, 51, 7)
        assert.is_true(same_color(bb, x, y, outline))
        assert.is_false(bare(51, 7))
        assert.is_true(bare(51, 6))
        assert.is_true(bare(1, 1))
        widget:free()
    end)

    it("is a tile around 7 cells, 6 gaps, the label gap and a caption line tall", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        assert.equals(1, scale(1))
        fixture = history{ [0] = 3000 }
        local insights = ctx.look.insights
        local gap = scale(insights.gap)
        local cell = math.min(scale(insights.cell_max), math.floor((InsightTile.inner_width(520, ctx) - 52 * gap) / 53))
        local content_h = 7 * cell + 6 * gap + scale(insights.label_gap)
            + Typeset.line_height(ctx.look.type.insight_caption, ctx)
        local tile = InsightTile.compose(520, ctx, "Reading this year", "0 h over 1 day", content_h, function() end)
        assert.equals(tile:getSize().h, Heatmap.height(520, ctx))
        tile:free()
        Heatmap.build(520, ctx):free()
    end)

    it("sums the year's whole hours and the days read in its aside", function()
        local ctx = ctx_for("diner")
        local seconds = {}
        for back = 0, 39 do
            seconds[back * 3] = 1080
        end
        seconds[3] = 1080 + 3599
        fixture = history(seconds)
        local widget = Heatmap.build(520, ctx)
        assert.equals("12 h over 40 days", widget[1].aside.text)
        widget:free()
    end)

    it("says nothing is read yet when every day is empty", function()
        local ctx = ctx_for("diner")
        fixture = history{}
        fixture.state = "empty"
        local widget = Heatmap.build(520, ctx)
        assert.equals("Nothing read yet", widget[1].aside.text)
        widget:free()
    end)

    it("is the label line alone, saying the stats are off, when they are off", function()
        local ctx = ctx_for("diner")
        fixture = { state = "off" }
        local widget = Heatmap.build(520, ctx)
        assert.equals("Reading stats are off", widget[1].aside.text)
        local tile = InsightTile.compose(520, ctx, "Reading this year", "Reading stats are off", 0, function() end)
        assert.equals(tile:getSize().h, widget:getSize().h)
        painted_bb(widget)
        tile:free()
        widget:free()
    end)

    it("names each month under the first column whose Monday falls in it, past the first column", function()
        local ctx = ctx_for("diner")
        fixture = history{ [0] = 3000 }
        local widget = Heatmap.build(520, ctx)
        local x_of = function(column)
            local x = cell_at(widget, 520, ctx, column, 1)
            return x - widget[1].inner_x
        end
        -- Column 1's Monday is 2025-10-13: November's first Monday is column 4's, October's last column 52's.
        local names = {}
        for _, caption in ipairs(widget.captions) do
            names[#names + 1] = caption.line.text
        end
        assert.same({ "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct" }, names)
        assert.equals(x_of(4), widget.captions[1].x)
        assert.equals(x_of(52), widget.captions[12].x)
        widget:free()
    end)

    it("frees its caption lines once, on free or on close", function()
        local ctx = ctx_for("diner")
        fixture = history{ [0] = 3000 }
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local widget = Heatmap.build(520, ctx)
            local freed = 0
            for _, caption in ipairs(widget.captions) do
                local free = caption.line.free
                caption.line.free = function(self)
                    freed = freed + 1
                    return free(self)
                end
            end
            if close == "free" then
                widget:free()
            else
                widget:handleEvent(require("ui/event"):new("CloseWidget"))
            end
            widget:free()
            assert.equals(12, freed)
        end
    end)

    it("is the registry's heatmap", function()
        assert.equals(Heatmap, require("widgets").get("heatmap"))
    end)
end)
