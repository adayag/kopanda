-- The reading widget: this month's hours and days read over their captions, beside an area chart of the last 12
-- weeks' hours, one point a Monday-to-Sunday week scaled to the busiest, ringed at this week, captioned at each
-- month change.
describe("the reading widget", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local InsightTile = require("insight_tile")
    local Looks = require("looks")
    local Paint = require("paint")
    local ReadingStats = require("reading_stats")
    local Typeset = require("typeset")
    local Reading = require("widgets/reading")

    local real_insights = ReadingStats.insights
    local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 20, min = 42 }
    local fixture

    -- 371 days ending on now's, with seconds[{ month, day }] read on those 2026 days.
    local function insights_with(seconds)
        local days = {}
        for i = 1, 371 do
            local t = os.time{ year = 2026, month = 10, day = 13 - (371 - i), hour = 12 }
            local key = tonumber(os.date("%m", t)) .. "-" .. tonumber(os.date("%d", t))
            days[i] = seconds[key] or 0
        end
        local hours = {}
        for h = 1, 24 do
            hours[h] = 0
        end
        return { state = "ok", days = days, hours = hours }
    end

    -- Weeks 1 to 12 (Mondays Jul 27 to Oct 12): 7200, 3600, 0, 0, 0, 0, 3600, 1800, 36000, 8400, 0, 5400.
    local function weeks_fixture()
        return insights_with({
            ["7-28"] = 7200, ["8-4"] = 3600, ["9-8"] = 3600, ["9-15"] = 1800, ["9-22"] = 36000,
            ["9-30"] = 7200, ["10-1"] = 1200, ["10-12"] = 3600, ["10-13"] = 1800,
        })
    end

    before_each(function()
        fixture = weeks_fixture()
        ReadingStats.insights = function()
            return fixture
        end
    end)

    after_each(function()
        ReadingStats.insights = real_insights
    end)

    local function ctx_for(look_id)
        return { look = Looks.get(look_id), variant = "day", text_size = "medium", now = NOW, screen = Screen }
    end

    local function same_color(bb, x, y, color)
        local c = bb:getPixel(x, y):getColorRGB32()
        local want = color:getColorRGB32()
        return c.r == want.r and c.g == want.g and c.b == want.b
    end

    -- The widget built at width under ctx (a boxed look), painted on a fresh buffer, and its chart's geometry
    -- there: x of week k's point, the chart's left, top, bottom (one past its last row) and height.
    local function painted(width, ctx)
        local scale = Paint.scaler(ctx)
        local look = ctx.look
        local widget = Reading.build(width, ctx)
        local size = widget:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        widget:paintTo(bb, 0, 0)
        local inset = scale(look.stroke.outline) + scale(look.insights.padding)
        local inner_w = InsightTile.inner_width(width, ctx)
        local column_w = math.floor(inner_w * look.insights.reading_column)
        local left = inset + column_w + scale(look.insights.padding)
        local chart_w = inner_w - column_w - scale(look.insights.padding)
        local top = inset + Typeset.line_height(look.type.insight_label, ctx) + scale(look.insights.label_gap)
        local chart = scale(look.insights.chart_height)
        return bb, {
            left = left,
            top = top,
            bottom = top + chart,
            chart = chart,
            x = function(k)
                return left + math.floor((k - 1) * (chart_w - 1) / 11 + 0.5)
            end,
        }, widget
    end

    it("reads this month's hours and days read, not the day before the month began", function()
        assert.same({
            { value = "1 h 50 min", caption = "this month" },
            { value = "3", caption = "days read" },
        }, Reading.figures(fixture, NOW))
        assert.same({
            { value = "24 h", caption = "this month" },
            { value = "1", caption = "day read" },
        }, Reading.figures(insights_with({ ["9-30"] = 600, ["10-2"] = 86400 }), NOW))
        assert.same({
            { value = "24 min", caption = "this month" },
            { value = "1", caption = "day read" },
        }, Reading.figures(insights_with({ ["10-13"] = 1440 }), NOW))
    end)

    it("says what its chart shows in its aside", function()
        local widget = Reading.build(520, ctx_for("diner"))
        assert.equals("hours a week, last 12 weeks", widget.aside.text)
        widget:free()
    end)

    it("is the label alone when reading stats are off", function()
        fixture = { state = "off" }
        local ctx = ctx_for("diner")
        local widget = Reading.build(520, ctx)
        assert.equals("Reading stats are off", widget.aside.text)
        local bare = InsightTile.compose(520, ctx, "Reading", "Reading stats are off", 0, function() end)
        assert.equals(bare:getSize().h, widget:getSize().h)
        assert.equals(bare:getSize().h, Reading.height(520, ctx))
        widget:paintTo(Blitbuffer.new(520, widget:getSize().h, Blitbuffer.TYPE_BBRGB32), 0, 0)
        bare:free()
        widget:free()
    end)

    it("draws the busiest week chart tall and a week with none on the baseline", function()
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local line, area = color(ctx.look.insights.chart_line_color), color(ctx.look.insights.chart_area_color)
        local paper = color("paper")
        local bb, g, widget = painted(520, ctx)
        local stroke = ctx.look.insights.chart_line_width

        assert.is_true(same_color(bb, g.x(9), g.top, line))
        assert.is_true(same_color(bb, g.x(9), g.top - 1, paper))
        assert.is_true(same_color(bb, g.x(9), g.top + stroke + 2, area))
        assert.is_true(same_color(bb, g.x(9), g.bottom - 3, area))

        assert.is_true(same_color(bb, g.x(4), g.bottom - 1, line))
        assert.is_true(same_color(bb, g.x(4), g.bottom - stroke, line))
        assert.is_true(same_color(bb, g.x(4), g.bottom - stroke - 1, paper))
        assert.is_true(same_color(bb, g.x(4), g.top + 1, paper))
        widget:free()
    end)

    it("fills below the line in the area colour and leaves paper above it", function()
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local line, area = color(ctx.look.insights.chart_line_color), color(ctx.look.insights.chart_area_color)
        local paper = color("paper")
        local bb, g, widget = painted(520, ctx)
        local stroke = ctx.look.insights.chart_line_width
        local y = g.bottom - stroke - math.floor((g.chart - stroke) * 8400 / 36000 + 0.5)
        assert.is_true(same_color(bb, g.x(10), y, line))
        assert.is_true(same_color(bb, g.x(10), y - 2, paper))
        assert.is_true(same_color(bb, g.x(10), y + stroke + 1, area))
        widget:free()
    end)

    it("draws a flat line on the baseline when nothing is read", function()
        fixture = insights_with({})
        fixture.state = "empty"
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local line, paper = color(ctx.look.insights.chart_line_color), color("paper")
        local bb, g, widget = painted(520, ctx)
        local stroke = ctx.look.insights.chart_line_width
        for k = 1, 11 do
            assert.is_true(same_color(bb, g.x(k), g.bottom - 1, line), "week " .. k)
            assert.is_true(same_color(bb, g.x(k), g.bottom - stroke - 1, paper), "week " .. k)
        end
        widget:free()
    end)

    it("rings this week's point, paper inside", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        local color = Looks.colorer(ctx)
        local line, paper = color(ctx.look.insights.chart_line_color), color("paper")
        local bb, g, widget = painted(520, ctx)
        local stroke = ctx.look.insights.chart_line_width
        local r = math.floor(scale(ctx.look.insights.today_ring) / 2)
        local cx = g.x(12)
        local cy = g.bottom - stroke - math.floor((g.chart - stroke) * 5400 / 36000 + 0.5) + math.floor(stroke / 2)
        assert.is_true(same_color(bb, cx, cy, paper))
        assert.is_true(same_color(bb, cx - r + 1, cy, line))
        widget:free()
    end)

    it("captions each week whose Monday begins another month, Aug, Sep and Oct", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        local paper = Looks.colorer(ctx)("paper")
        local bb, g, widget = painted(520, ctx)
        local top = g.bottom + scale(ctx.look.insights.label_gap)
        local caption_h = Typeset.line_height(ctx.look.type.insight_caption, ctx)
        local function first_ink(x, x_end)
            for cx = x, x_end do
                for cy = top, top + caption_h - 1 do
                    if not same_color(bb, cx, cy, paper) then
                        return cx
                    end
                end
            end
        end
        local width = bb:getWidth()
        for _, case in ipairs({ { from = g.left, at = 2 }, { from = g.x(5), at = 7 }, { from = g.x(9), at = 11 } }) do
            local ink = first_ink(case.from, width - 1)
            assert.is_truthy(ink)
            assert.is_true(ink >= g.x(case.at) and ink - g.x(case.at) <= scale(4),
                "the caption of week " .. case.at .. " starts at " .. tostring(ink))
        end
        widget:free()
    end)

    it("is the chrome, the label line and the taller of the figures and the captioned chart tall", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        local look = ctx.look
        local widget = Reading.build(520, ctx)
        local value_part = {}
        for k, v in pairs(look.type.insight_value) do
            value_part[k] = v
        end
        value_part.size = widget.value_size
        local caption_h = Typeset.line_height(look.type.insight_caption, ctx)
        local figures = 2 * (Typeset.line_height(value_part, ctx) + scale(look.insights.value_gap) + caption_h)
            + scale(look.insights.record_gap)
        local chart = scale(look.insights.chart_height) + scale(look.insights.label_gap) + caption_h
        local tile = InsightTile.compose(520, ctx, "Reading", "hours a week, last 12 weeks",
            math.max(figures, chart), function() end)
        assert.equals(tile:getSize().h, widget:getSize().h)
        assert.equals(tile:getSize().h, Reading.height(520, ctx))
        assert.equals(520, widget:getSize().w)
        tile:free()
        widget:free()
    end)

    it("sets the figures smaller until they fit the column", function()
        fixture = insights_with({ ["10-1"] = 6480, ["10-2"] = 6480 })
        local ctx = ctx_for("toybox")
        ctx.text_size = "large"
        local widget = Reading.build(300, ctx)
        assert.is_true(widget.value_size < ctx.look.type.insight_value.size)
        for _, figure in ipairs(widget.figures) do
            assert.is_false(figure.value.isTruncated and figure.value:isTruncated() or false)
        end
        widget:free()
    end)

    it("draws in every look, read, empty and off", function()
        for _, look_id in ipairs(Looks.ids()) do
            for _, insights in ipairs({ weeks_fixture(), insights_with({}), { state = "off" } }) do
                fixture = insights
                local widget = Reading.build(520, ctx_for(look_id))
                local size = widget:getSize()
                local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
                widget:paintTo(bb, 0, 0)
                bb:free()
                widget:free()
            end
        end
    end)

    it("frees its figure and caption lines once, on free or on close", function()
        local ctx = ctx_for("diner")
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local widget = Reading.build(520, ctx)
            local lines = {}
            for _, figure in ipairs(widget.figures) do
                lines[#lines + 1] = figure.value
                lines[#lines + 1] = figure.caption
            end
            for _, caption in ipairs(widget.captions) do
                lines[#lines + 1] = caption.line
            end
            local freed = 0
            for _, line in ipairs(lines) do
                local free = line.free
                line.free = function(self)
                    freed = freed + 1
                    return free(self)
                end
            end
            widget[close](widget)
            widget:free()
            assert.equals(7, freed)
        end
    end)

    it("is the registry's reading", function()
        assert.equals(Reading, require("widgets").get("reading"))
    end)
end)
