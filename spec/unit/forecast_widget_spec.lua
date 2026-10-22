-- The finish-by forecast: the featured book's time left over the last fourteen days' pace, as the
-- day it ends, its title and the caption beneath, or a line saying what is missing; and its height.
describe("the forecast widget", function()
    require("plugin_harness")
    local Screen = require("device").screen
    local FeaturedBook = require("featured_book")
    local InsightTile = require("insight_tile")
    local Looks = require("looks")
    local Paint = require("paint")
    local ReadingStats = require("reading_stats")
    local Typeset = require("typeset")
    local Forecast = require("widgets/forecast")

    local real_current, real_insights = FeaturedBook.current, ReadingStats.insights

    -- The epoch time of a local wall-clock instant.
    local function at(year, month, day, hour, min)
        return os.time{ year = year, month = month, day = day, hour = hour, min = min }
    end

    local NOW = at(2026, 10, 13, 20, 42)

    -- Insights whose last fourteen days each hold sum / 14 seconds, with a long day just before
    -- them that the pace must not count.
    local function insights_summing(sum)
        local days = {}
        for i = 1, ReadingStats.INSIGHT_DAYS do
            days[i] = 0
        end
        for i = #days - 13, #days do
            days[i] = sum / 14
        end
        days[#days - 14] = 36000
        return { state = "ok", days = days, hours = {} }
    end

    local function book(seconds_left)
        return { file = "/books/b.epub", title = "The Moonstone", percent = 0.62, status = "reading",
            seconds_left = seconds_left }
    end

    local function ctx_for(look_id)
        return {
            look = Looks.get(look_id),
            variant = "day",
            text_size = "medium",
            now = NOW,
            screen = Screen,
        }
    end

    -- fn run with the featured book and the insights stubbed to these, the real ones restored after.
    local function with_data(featured, insights, fn)
        FeaturedBook.current = function() return featured end
        ReadingStats.insights = function() return insights end
        local ok, err = pcall(fn)
        FeaturedBook.current, ReadingStats.insights = real_current, real_insights
        assert(ok, err)
    end

    it("finishes on the weekday the pace reaches, with the date and the caption", function()
        assert.same({ "Friday", "16 October, at this pace", "The Moonstone", "2 h 6 min left · 38 min a day" },
            Forecast.lines(book(7560), insights_summing(31920), NOW))
    end)

    it("finishes today when the time left is under a day's pace", function()
        local lines = Forecast.lines(book(600), insights_summing(31920), NOW)
        assert.equals("Today", lines[1])
        assert.equals("13 October, at this pace", lines[2])
    end)

    it("finishes tomorrow when the time left is two days' pace", function()
        local lines = Forecast.lines(book(4560), insights_summing(31920), NOW)
        assert.equals("Tomorrow", lines[1])
        assert.equals("14 October, at this pace", lines[2])
    end)

    it("reads at five minutes a day at least, counting days through the calendar", function()
        local lines = Forecast.lines(book(7200), insights_summing(4000), NOW)
        assert.equals("Thursday", lines[1])
        assert.equals("5 November, at this pace", lines[2])
        assert.equals("2 h left · 5 min a day", lines[4])
    end)

    it("asks for a book without one", function()
        assert.same({ "No book", "Open one and this fills in" },
            Forecast.lines(nil, insights_summing(31920), NOW))
    end)

    it("asks for reading with a book but no pace", function()
        local want = { "No pace yet", "Read a few pages first", "The Moonstone" }
        assert.same(want, Forecast.lines(book(nil), insights_summing(31920), NOW))
        assert.same(want, Forecast.lines(book(7560), { state = "off" }, NOW))
        local empty = insights_summing(0)
        empty.state = "empty"
        assert.same(want, Forecast.lines(book(7560), empty, NOW))
    end)

    it("is the tile around its lines and their gaps tall", function()
        local function tile_h(ctx, parts, gaps)
            local scale = Paint.scaler(ctx)
            local content = 0
            for i, part in ipairs(parts) do
                content = content + Typeset.line_height(ctx.look.type[part], ctx) + (gaps[i] and scale(gaps[i]) or 0)
            end
            local tile = InsightTile.compose(520, ctx, "Finish by", nil, content, function() end)
            local h = tile:getSize().h
            tile:free()
            return h
        end
        for _, look_id in ipairs(Looks.ids()) do
            local tokens = Looks.get(look_id).insights
            with_data(book(7560), insights_summing(31920), function()
                local ctx = ctx_for(look_id)
                assert.equals(1, Paint.scaler(ctx)(1))
                assert.equals(tile_h(ctx, { "insight_value", "insight_note", "featured_authors", "featured_caption" },
                    { tokens.value_gap, tokens.label_gap, tokens.label_gap }), Forecast.height(520, ctx))
                local widget = Forecast.build(520, ctx)
                assert.equals(Forecast.height(520, ctx_for(look_id)), widget:getSize().h)
                widget:free()
            end)
            with_data(book(nil), insights_summing(31920), function()
                local ctx = ctx_for(look_id)
                assert.equals(tile_h(ctx, { "insight_value", "insight_note", "featured_authors" },
                    { tokens.value_gap, tokens.label_gap }), Forecast.height(520, ctx))
            end)
            with_data(nil, insights_summing(31920), function()
                local ctx = ctx_for(look_id)
                assert.equals(tile_h(ctx, { "insight_value", "insight_note" }, { tokens.value_gap }),
                    Forecast.height(520, ctx))
            end)
        end
    end)

    it("sets the title in the featured authors' part, in every look", function()
        with_data(book(7560), insights_summing(31920), function()
            for _, look_id in ipairs(Looks.ids()) do
                local ctx = ctx_for(look_id)
                local widget = Forecast.build(520, ctx)
                local want = Typeset.line(ctx.look.type.featured_authors, "The Moonstone", math.huge, ctx)
                assert.equals(want.face.hash, widget.lines[3].face.hash)
                assert.equals(want.fgcolor, widget.lines[3].fgcolor)
                want:free()
                widget:free()
            end
        end)
    end)

    it("frees its lines once, on free or on close", function()
        with_data(book(7560), insights_summing(31920), function()
            for _, close in ipairs({ "free", "onCloseWidget" }) do
                local widget = Forecast.build(520, ctx_for("diner"))
                local freed = 0
                for _, line in ipairs(widget.lines) do
                    local free = line.free
                    line.free = function(self)
                        freed = freed + 1
                        return free(self)
                    end
                end
                widget[close](widget)
                widget:free()
                assert.equals(4, freed)
            end
        end)
    end)

    it("is the registry's forecast", function()
        assert.equals(Forecast, require("widgets").get("forecast"))
    end)
end)
