-- The hours widget: 24 bars of the last 90 days' reading per hour of day, scaled to the busiest hour, the busy
-- ones in the high colour, captioned at midnight, 6, noon and 18 in KOReader's clock format.
describe("the hours widget", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local Looks = require("looks")
    local Paint = require("paint")
    local Typeset = require("typeset")
    local InsightTile = require("insight_tile")
    local ReadingStats = require("reading_stats")
    local Hours = require("widgets/hours")

    local real_insights = ReadingStats.insights
    local fixture

    -- The insights with seconds[h] read at hour h, every other hour 0.
    local function insights_with(seconds)
        local hours = {}
        for h = 0, 23 do
            hours[h + 1] = seconds[h] or 0
        end
        return { state = "ok", days = {}, hours = hours }
    end

    before_each(function()
        fixture = insights_with({ [7] = 900, [12] = 300, [21] = 1500 })
        ReadingStats.insights = function()
            return fixture
        end
    end)

    after_each(function()
        ReadingStats.insights = real_insights
        G_reader_settings:delSetting("twelve_hour_clock")
    end)

    local function ctx_for(look_id)
        return {
            look = Looks.get(look_id),
            variant = "day",
            text_size = "medium",
            now = os.time{ year = 2026, month = 10, day = 13, hour = 20, min = 42 },
            screen = Screen,
        }
    end

    local function same_color(bb, x, y, color)
        local c = bb:getPixel(x, y):getColorRGB32()
        local want = color:getColorRGB32()
        return c.r == want.r and c.g == want.g and c.b == want.b
    end

    -- The widget built at width under ctx, painted on a fresh buffer, and its chart's geometry in that buffer:
    -- x of hour h's bar, its width, the chart's bottom (one past its last row) and height.
    local function painted(width, ctx)
        local scale = Paint.scaler(ctx)
        local look = ctx.look
        local widget = Hours.build(width, ctx)
        local size = widget:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        widget:paintTo(bb, 0, 0)
        local inset = scale(look.stroke.outline) + scale(look.insights.padding)
        local gap = scale(look.insights.gap)
        local inner_w = InsightTile.inner_width(width, ctx)
        local bar_w = math.floor((inner_w - 23 * gap) / 24)
        local top = inset + Typeset.line_height(look.type.insight_label, ctx) + scale(look.insights.label_gap)
        local chart = scale(look.insights.chart_height)
        local geometry = {
            bar_w = bar_w,
            bottom = top + chart,
            chart = chart,
            x = function(h)
                return inset + h * (bar_w + gap)
            end,
        }
        return bb, geometry, widget
    end

    it("draws the busiest hour chart tall and an hour at 60 % of it in the high colour, a quieter one in the fill",
        function()
            local ctx = ctx_for("diner")
            local color = Looks.colorer(ctx)
            local high, fill = color(ctx.look.insights.bar_high_color), color(ctx.look.insights.bar_fill_color)
            local paper = color(ctx.look.tile.fill_color)
            local bb, g, widget = painted(520, ctx)
            local function centre(h)
                return g.x(h) + math.floor(g.bar_w / 2)
            end
            assert.is_true(g.bar_w > 4)

            assert.is_true(same_color(bb, centre(21), g.bottom - math.floor(g.chart / 2), high))
            assert.is_true(same_color(bb, centre(21), g.bottom - g.chart + 2, high))
            assert.is_true(same_color(bb, centre(21), g.bottom - g.chart - 1, paper))

            local h7 = math.floor(g.chart * 0.6 + 0.5)
            assert.is_true(same_color(bb, centre(7), g.bottom - 3, high))
            assert.is_true(same_color(bb, centre(7), g.bottom - h7 + 2, high))
            assert.is_true(same_color(bb, centre(7), g.bottom - h7 - 1, paper))

            assert.is_true(same_color(bb, centre(12), g.bottom - 3, fill))
            assert.is_true(same_color(bb, centre(3), g.bottom - 1, paper))
            assert.is_true(same_color(bb, centre(3), g.bottom - math.floor(g.chart / 2), paper))
            widget:free()
        end)

    it("draws an hour read for a second 2 px tall", function()
        fixture = insights_with({ [0] = 1, [21] = 1500 })
        local ctx = ctx_for("toybox")
        local color = Looks.colorer(ctx)
        local fill, paper = color(ctx.look.insights.bar_fill_color), color(ctx.look.tile.fill_color)
        local bb, g, widget = painted(520, ctx)
        local x = g.x(0) + math.floor(g.bar_w / 2)
        assert.is_true(same_color(bb, x, g.bottom - 1, fill))
        assert.is_true(same_color(bb, x, g.bottom - 2, fill))
        assert.is_true(same_color(bb, x, g.bottom - 3, paper))
        widget:free()
    end)

    it("outlines each bar with a height in the tile's outline colour when the look gives bars an outline", function()
        local ctx = ctx_for("diner")
        assert.equals(1, ctx.look.insights.bar_outline_width)
        local color = Looks.colorer(ctx)
        local outline, fill = color(ctx.look.tile.outline_color), color(ctx.look.insights.bar_fill_color)
        local bb, g, widget = painted(520, ctx)
        local mid = g.bottom - 5
        assert.is_true(same_color(bb, g.x(12), mid, outline))
        assert.is_true(same_color(bb, g.x(12) + g.bar_w - 1, mid, outline))
        assert.is_true(same_color(bb, g.x(12) + 1, mid, fill))
        assert.is_true(same_color(bb, g.x(12) + 1, g.bottom - 1, outline))
        widget:free()

        local plain = ctx_for("toybox")
        assert.equals(0, plain.look.insights.bar_outline_width)
        local bare_bb, bare, bare_widget = painted(520, plain)
        assert.is_true(same_color(bare_bb, bare.x(12), bare.bottom - 5,
            Looks.colorer(plain)(plain.look.insights.bar_fill_color)))
        bare_widget:free()
    end)

    it("captions midnight, 6, noon and 18 in KOReader's clock format", function()
        G_reader_settings:saveSetting("twelve_hour_clock", true)
        assert.same({ "Midnight", "6 am", "Noon", "6 pm" }, Hours.captions())
        for _, value in ipairs({ false, "unset" }) do
            if value == "unset" then
                G_reader_settings:delSetting("twelve_hour_clock")
            else
                G_reader_settings:saveSetting("twelve_hour_clock", value)
            end
            assert.same({ "00:00", "06:00", "12:00", "18:00" }, Hours.captions())
        end
    end)

    it("sets each caption under the chart at the x of hours 0, 6, 12 and 18", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        local paper = Looks.colorer(ctx)(ctx.look.tile.fill_color)
        local bb, g, widget = painted(520, ctx)
        local top = g.bottom + scale(ctx.look.insights.label_gap)
        local caption_h = Typeset.line_height(ctx.look.type.insight_caption, ctx)
        -- The leftmost inked column in the caption band from x to x_end.
        local function first_ink(x, x_end)
            for cx = x, x_end do
                for cy = top, top + caption_h - 1 do
                    if not same_color(bb, cx, cy, paper) then
                        return cx
                    end
                end
            end
        end
        for _, h in ipairs({ 0, 6, 12, 18 }) do
            local ink = first_ink(g.x(h), g.x(h) + 6 * g.bar_w)
            assert.is_truthy(ink)
            assert.is_true(ink - g.x(h) <= scale(4), "the caption at " .. h .. " starts at " .. ink)
        end
        assert.is_nil(first_ink(g.x(0) - scale(ctx.look.insights.padding), g.x(0) - 1))
        widget:free()
    end)

    it("is the chrome, the label line, the chart, the gap and a caption line tall", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        assert.equals(10, scale(10))
        local look = ctx.look
        local label_h = Typeset.line_height(look.type.insight_label, ctx)
        local caption_h = Typeset.line_height(look.type.insight_caption, ctx)
        local chrome = 2 * (scale(look.stroke.outline) + scale(look.insights.padding)) + scale(look.shadow.tile.y)
        local expected = chrome + label_h + scale(look.insights.label_gap) + scale(look.insights.chart_height)
            + scale(look.insights.label_gap) + caption_h
        assert.equals(expected, Hours.height(520, ctx))
        local widget = Hours.build(520, ctx)
        assert.equals(expected, widget:getSize().h)
        assert.equals(520, widget:getSize().w)
        widget:free()
    end)

    it("reads the last 90 days in its aside, or that nothing is read yet", function()
        local ctx = ctx_for("diner")
        local widget = Hours.build(520, ctx)
        assert.equals("last 90 days", widget.aside.text)
        widget:free()

        fixture = insights_with({})
        fixture.state = "empty"
        local empty = Hours.build(520, ctx)
        assert.equals("Nothing read yet", empty.aside.text)
        assert.equals(Hours.height(520, ctx), empty:getSize().h)
        local bb, g, again = painted(520, ctx)
        local paper = Looks.colorer(ctx)(ctx.look.tile.fill_color)
        for h = 0, 23 do
            assert.is_true(same_color(bb, g.x(h) + math.floor(g.bar_w / 2), g.bottom - 1, paper))
        end
        empty:free()
        again:free()
    end)

    it("is the label alone when reading stats are off", function()
        fixture = { state = "off" }
        local ctx = ctx_for("diner")
        local widget = Hours.build(520, ctx)
        assert.equals("Reading stats are off", widget.aside.text)
        local bare = InsightTile.compose(520, ctx, "When you read", "Reading stats are off", 0, function() end)
        assert.equals(bare:getSize().h, widget:getSize().h)
        assert.equals(bare:getSize().h, Hours.height(520, ctx))
        widget:paintTo(Blitbuffer.new(520, widget:getSize().h, Blitbuffer.TYPE_BBRGB32), 0, 0)
        bare:free()
        widget:free()
    end)

    it("frees its caption lines once, on free or on close", function()
        local ctx = ctx_for("diner")
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local widget = Hours.build(520, ctx)
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
            assert.equals(4, freed)
        end
    end)

    it("is the registry's hours", function()
        assert.equals(Hours, require("widgets").get("hours"))
    end)
end)
