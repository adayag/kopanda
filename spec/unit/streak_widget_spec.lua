-- The streak widget: the run of days read to today (or to yesterday before today's reading) as a big count, the
-- best run in its aside, and this week's days as dots, each day read filled and today ringed.
describe("the streak widget", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local InsightTile = require("insight_tile")
    local Looks = require("looks")
    local Paint = require("paint")
    local ReadingStats = require("reading_stats")
    local Typeset = require("typeset")
    local Streak = require("widgets/streak")

    local real_insights = ReadingStats.insights
    local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 20, min = 42 }
    local fixture

    -- 371 days ending today, Tuesday 2026-10-13, with seconds[back] read back days before today.
    local function insights_with(seconds)
        local days = {}
        for i = 1, 371 do
            days[i] = seconds[371 - i] or 0
        end
        return { state = "ok", days = days, hours = {} }
    end

    before_each(function()
        fixture = insights_with({ [1] = 900, [2] = 600, [3] = 300, [10] = 60, [11] = 60, [12] = 60, [13] = 60,
            [14] = 60 })
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

    -- The text of a line from Typeset.line, a tracked one's from its characters.
    local function text_of(line)
        if line.text then
            return line.text
        end
        local chars = {}
        for _, child in ipairs(line) do
            chars[#chars + 1] = child.text
        end
        return table.concat(chars)
    end

    describe("runs", function()
        local function runs(days)
            return { Streak.runs(days) }
        end

        it("is nothing for no reading", function()
            assert.same({ 0, 0 }, runs({ 0, 0, 0 }))
        end)

        it("counts to today when today is read", function()
            assert.same({ 3, 3 }, runs({ 1, 1, 0, 1, 1, 1 }))
        end)

        it("counts to yesterday while today is unread", function()
            assert.same({ 2, 2 }, runs({ 0, 1, 1, 0 }))
            assert.same({ 0, 2 }, runs({ 1, 1, 0, 0 }))
        end)

        it("breaks at a day without reading", function()
            assert.same({ 1, 1 }, runs({ 1, 0, 1 }))
        end)

        it("keeps the best run when it is longer than the current", function()
            assert.same({ 2, 4 }, runs({ 1, 1, 1, 1, 0, 1, 1 }))
        end)

        it("finds the best run at the window's start", function()
            assert.same({ 0, 3 }, runs({ 1, 1, 1, 0, 0, 0 }))
        end)
    end)

    it("reads the best run in its aside", function()
        local ctx = ctx_for("diner")
        local widget = Streak.build(260, ctx)
        assert.equals("best 5", widget.aside.text)
        assert.equals("3", text_of(widget.count))
        assert.equals("days in a row", text_of(widget.note))
        widget:free()

        fixture = insights_with({ [0] = 60 })
        local one = Streak.build(260, ctx)
        assert.equals("best 1", one.aside.text)
        assert.equals("day in a row", text_of(one.note))
        one:free()

        fixture = insights_with({})
        local none = Streak.build(260, ctx)
        assert.equals("best 0", none.aside.text)
        assert.equals("0", text_of(none.count))
        none:free()
    end)

    it("is the label alone when reading stats are off", function()
        fixture = { state = "off" }
        local ctx = ctx_for("diner")
        local widget = Streak.build(260, ctx)
        assert.equals("Reading stats are off", widget.aside.text)
        local bare = InsightTile.compose(260, ctx, "Streak", "Reading stats are off", 0, function() end)
        assert.equals(bare:getSize().h, widget:getSize().h)
        assert.equals(bare:getSize().h, Streak.height(260, ctx))
        widget:paintTo(Blitbuffer.new(260, widget:getSize().h, Blitbuffer.TYPE_BBRGB32), 0, 0)
        bare:free()
        widget:free()
    end)

    -- The widget at width under ctx painted on a fresh buffer, and the centre y and left x of weekday i's dot,
    -- Monday 1, the dot row being the content's last, its dots centred on it.
    local function painted(width, ctx)
        local scale = Paint.scaler(ctx)
        local look = ctx.look
        local widget = Streak.build(width, ctx)
        local size = widget:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        widget:paintTo(bb, 0, 0)
        local inset = scale(look.stroke.outline) + scale(look.insights.padding)
        local dot, dot_gap = scale(look.insights.dot), scale(look.insights.dot_gap)
        local row_h = math.max(dot, Typeset.line_height(look.type.insight_caption, ctx))
        local bottom = size.h - inset - scale(look.shadow.tile.y)
        local top = bottom - row_h + math.floor((row_h - dot) / 2)
        return bb, {
            r = math.floor(dot / 2),
            cy = top + math.floor(dot / 2),
            x = function(i)
                return inset + (i - 1) * (dot + dot_gap)
            end,
        }, widget
    end

    it("fills a day read, rings today and outlines a day to come", function()
        local ctx = ctx_for("diner")
        local tokens = ctx.look.insights
        local color = Looks.colorer(ctx)
        local fill, ring, empty = color(tokens.dot_fill_color), color(tokens.today_ring_color),
            color(tokens.dot_empty_color)
        local paper = color("paper")
        local bb, g, widget = painted(260, ctx)
        assert.is_true(same_color(bb, g.x(1) + g.r, g.cy, fill))
        assert.is_true(same_color(bb, g.x(2) + g.r, g.cy, paper))
        assert.is_true(same_color(bb, g.x(2) + 1, g.cy, ring))
        assert.is_true(same_color(bb, g.x(3) + g.r, g.cy, paper))
        assert.is_true(same_color(bb, g.x(3), g.cy, empty))
        assert.is_true(same_color(bb, g.x(3) + 2, g.cy, paper))
        widget:free()

        fixture.days[#fixture.days] = 60
        local read_bb, read_g, read = painted(260, ctx)
        assert.is_true(same_color(read_bb, read_g.x(2) + read_g.r, read_g.cy, fill))
        assert.is_true(same_color(read_bb, read_g.x(2) + 1, read_g.cy, ring))
        read:free()
    end)

    it("is the chrome, the label line, the count's line and the dot row tall", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        local look = ctx.look
        local count_part = {}
        for k, v in pairs(look.type.insight_value) do
            count_part[k] = v
        end
        count_part.size = look.type.insight_value.size * look.insights.streak_scale
        local count = Typeset.line(count_part, "3", 260, ctx)
        local note = Typeset.line(look.type.insight_note, "days in a row", 260, ctx)
        local note_y = Typeset.baseline(count) - Typeset.baseline(note)
        local count_y = math.max(0, -note_y)
        local line_h = math.max(count_y + count:getSize().h, count_y + note_y + note:getSize().h)
        count:free()
        note:free()
        local row_h = math.max(scale(look.insights.dot), Typeset.line_height(look.type.insight_caption, ctx))
        local tile = InsightTile.compose(260, ctx, "Streak", "best 5",
            line_h + scale(look.insights.record_gap) + row_h, function() end)
        assert.equals(tile:getSize().h, Streak.height(260, ctx))
        local widget = Streak.build(260, ctx)
        assert.equals(tile:getSize().h, widget:getSize().h)
        assert.equals(260, widget:getSize().w)
        tile:free()
        widget:free()
    end)

    it("draws in every look, read, empty and off", function()
        for _, look_id in ipairs(Looks.ids()) do
            for _, insights in ipairs({ insights_with({ [0] = 60, [1] = 60 }), insights_with({}),
                { state = "off" } }) do
                fixture = insights
                local widget = Streak.build(260, ctx_for(look_id))
                local size = widget:getSize()
                local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
                widget:paintTo(bb, 0, 0)
                bb:free()
                widget:free()
            end
        end
    end)

    it("frees its count, note and caption lines once, on free or on close", function()
        local ctx = ctx_for("diner")
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local widget = Streak.build(260, ctx)
            local freed = 0
            for _, name in ipairs({ "count", "note", "caption" }) do
                local line = widget[name]
                local free = line.free
                line.free = function(self)
                    freed = freed + 1
                    return free(self)
                end
            end
            widget[close](widget)
            widget:free()
            assert.equals(3, freed)
        end
    end)

    it("is the registry's streak", function()
        assert.equals(Streak, require("widgets").get("streak"))
    end)
end)
