-- The month bars: twelve calendar months' reading from ReadingStats.insights' days, this month last, the total aside,
-- each bar scaled to the busiest month and only that month in the high colour.
describe("the months widget", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local Looks = require("looks")
    local Paint = require("paint")
    local Typeset = require("typeset")
    local InsightTile = require("insight_tile")
    local ReadingStats = require("reading_stats")
    local Months = require("widgets/months")
    local ffi = require("ffi")
    ffi.cdef[[
        int setenv(const char *name, const char *value, int overwrite);
        int unsetenv(const char *name);
        void tzset(void);
    ]]

    local WIDTH = 1040
    local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 20, min = 42 }

    local real_insights = ReadingStats.insights
    local fixture

    -- 371 days ending at now's day, with seconds[month] read on the 1st of each month.
    local function days_with(seconds, now)
        local t = os.date("*t", now)
        local days = {}
        for i = 1, 371 do
            local day = os.date("*t", os.time{ year = t.year, month = t.month, day = t.day - (371 - i), hour = 12 })
            days[i] = day.day == 1 and seconds[day.month] or 0
        end
        return days
    end

    local function insights_with(seconds)
        return { state = "ok", days = days_with(seconds, NOW), hours = {} }
    end

    before_each(function()
        fixture = insights_with({ [10] = 3600 })
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

    -- Diner's ctx with its bars unoutlined.
    local function unoutlined()
        local ctx = ctx_for("diner")
        local look = ctx.look
        ctx.look = setmetatable({ insights = setmetatable({ bar_outline_width = 0 }, { __index = look.insights }) },
            { __index = look })
        return ctx
    end

    local function same_color(bb, x, y, color)
        local c = bb:getPixel(x, y):getColorRGB32()
        local want = color:getColorRGB32()
        return c.r == want.r and c.g == want.g and c.b == want.b
    end

    -- The widget built under ctx, painted on a fresh buffer, and its chart's geometry in that buffer: the centre x of
    -- the i-th bar, the chart's bottom (one past its last row) and height.
    local function painted(ctx)
        local scale = Paint.scaler(ctx)
        local look = ctx.look
        local widget = Months.build(WIDTH, ctx)
        local size = widget:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        widget:paintTo(bb, 0, 0)
        local inset = scale(look.stroke.outline) + scale(look.insights.padding)
        local gap = scale(look.insights.month_gap)
        local bar_w = math.floor((InsightTile.inner_width(WIDTH, ctx) - 11 * gap) / 12)
        local top = inset + Typeset.line_height(look.type.insight_label, ctx) + scale(look.insights.label_gap)
        local chart = scale(look.insights.month_chart_height)
        return bb, {
            bottom = top + chart,
            chart = chart,
            centre = function(i)
                return inset + (i - 1) * (bar_w + gap) + math.floor(bar_w / 2)
            end,
        }, widget
    end

    -- The height of the column of color standing on the chart's foot under bar i.
    local function bar_height(bb, g, i, color)
        local h = 0
        while h < g.chart + 2 and same_color(bb, g.centre(i), g.bottom - 1 - h, color) do
            h = h + 1
        end
        return h
    end

    describe("totals", function()
        local function months(list)
            local out = {}
            for i, entry in ipairs(list) do
                out[i] = entry.month
            end
            return out
        end

        it("is twelve months oldest first, ending at now's", function()
            local list = Months.totals({}, NOW)
            assert.same({ 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, months(list))
        end)

        it("in January starts at February of last year", function()
            local list = Months.totals({}, os.time{ year = 2026, month = 1, day = 15, hour = 12 })
            assert.same({ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 1 }, months(list))
        end)

        it("on the 1st counts yesterday in last month and today in this one", function()
            local now = os.time{ year = 2026, month = 10, day = 1, hour = 12 }
            local list = Months.totals({ 300, 60 }, now)
            assert.equals(300, list[11].seconds)
            assert.equals(9, list[11].month)
            assert.equals(60, list[12].seconds)
        end)

        it("drops a day older than the twelve months", function()
            local days = {}
            for i = 1, 371 do
                days[i] = 0
            end
            days[1], days[371] = 500, 60
            local total = 0
            for _, entry in ipairs(Months.totals(days, NOW)) do
                total = total + entry.seconds
            end
            assert.equals(60, total)
        end)

        it("keeps each day in its own month across a DST change", function()
            local previous = os.getenv("TZ")
            ffi.C.setenv("TZ", "America/Chicago", 1)
            ffi.C.tzset()
            local ok, err = pcall(function()
                -- The Monday after the change: a walk back by 86400 s would land the 1st of March on 28 February.
                local now = os.time{ year = 2026, month = 3, day = 9, hour = 0, min = 30 }
                local days = {}
                for i = 1, 40 do
                    days[i] = 100
                end
                local list = Months.totals(days, now)
                assert.equals(900, list[12].seconds)
                assert.equals(2800, list[11].seconds)
                assert.equals(300, list[10].seconds)
            end)
            if previous then
                ffi.C.setenv("TZ", previous, 1)
            else
                ffi.C.unsetenv("TZ")
            end
            ffi.C.tzset()
            assert(ok, err)
        end)
    end)

    describe("the tile", function()
        it("gives the total read aside as a duration, half an hour in minutes and never 0 h", function()
            fixture = insights_with({ [9] = 900, [10] = 900 })
            local widget = Months.build(WIDTH, ctx_for("diner"))
            assert.equals("30 min", widget.aside.text)
            widget:free()

            fixture = insights_with({ [9] = 3600, [10] = 3600 })
            local hours = Months.build(WIDTH, ctx_for("diner"))
            assert.equals("2 h", hours.aside.text)
            hours:free()
        end)

        it("says nothing is read yet, with the bars' room kept, when every month is 0", function()
            local ctx = ctx_for("diner")
            local tall = Months.height(WIDTH, ctx)
            fixture = insights_with({})
            local widget = Months.build(WIDTH, ctx_for("diner"))
            assert.equals("Nothing read yet", widget.aside.text)
            assert.equals(tall, widget:getSize().h)
            widget:free()
        end)

        it("is the label alone when reading stats are off", function()
            fixture = { state = "off" }
            local ctx = ctx_for("diner")
            local widget = Months.build(WIDTH, ctx)
            assert.equals("Reading stats are off", widget.aside.text)
            assert.equals(0, widget.content_h)
            widget:paintTo(Blitbuffer.new(WIDTH, widget:getSize().h, Blitbuffer.TYPE_BBRGB32), 0, 0)
            widget:free()
        end)

        it("draws the busiest month chart tall and a month of one minute at the minimum bar", function()
            fixture = insights_with({ [10] = 36000, [4] = 60 })
            local ctx = unoutlined()
            local color = Looks.colorer(ctx)
            local high, fill = color(ctx.look.insights.bar_high_color), color(ctx.look.insights.bar_fill_color)
            local bb, g, widget = painted(ctx)
            assert.equals(g.chart, bar_height(bb, g, 12, high))
            -- April is the sixth bar of November to October.
            assert.equals(2, bar_height(bb, g, 6, fill))
            widget:free()
        end)

        it("marks only the busiest of twelve near-equal months in the high colour", function()
            local seconds = {}
            for month = 1, 12 do
                seconds[month] = 3600 + month
            end
            fixture = insights_with(seconds)
            local ctx = unoutlined()
            local color = Looks.colorer(ctx)
            local high, fill = color(ctx.look.insights.bar_high_color), color(ctx.look.insights.bar_fill_color)
            local bb, g, widget = painted(ctx)
            -- December, the busiest, is the second bar of November to October.
            for i = 1, 12 do
                local want = i == 2 and high or fill
                assert.is_true(same_color(bb, g.centre(i), g.bottom - 3, want), "bar " .. i)
            end
            widget:free()
        end)

        it("frees its caption lines once, on free or on close", function()
            local ctx = ctx_for("diner")
            for _, close in ipairs({ "free", "onCloseWidget" }) do
                local widget = Months.build(WIDTH, ctx)
                local freed = 0
                for _, caption in ipairs(widget.captions) do
                    local free = caption.line.free
                    caption.line.free = function(self)
                        freed = freed + 1
                        return free(self)
                    end
                end
                widget[close](widget)
                widget:free()
                assert.equals(12, freed)
            end
        end)

        it("is the registry's months, offered on no home row", function()
            assert.equals(Months, require("widgets").get("months"))
            local schema = require("schema")
            for _, key in ipairs(schema.keys) do
                for _, id in ipairs(key.widgets or {}) do
                    assert.is_not.equals("months", id)
                end
            end
        end)
    end)
end)
