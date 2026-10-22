-- The records widget: the year's session records as a 2×2 grid of values over captions in the insight
-- tile, zeros with no sessions and the label alone with reading stats off.
describe("the records widget", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local InsightTile = require("insight_tile")
    local Layout = require("layout")
    local Looks = require("looks")
    local Paint = require("paint")
    local ReadingStats = require("reading_stats")
    local Typeset = require("typeset")
    local Records = require("widgets/records")

    local real_insights = ReadingStats.insights
    local fixture = { count = 312, longest = 6480, average = 1440, pages_per_hour = 41 }

    local function stub(insights)
        ReadingStats.insights = function()
            return insights
        end
    end

    after_each(function()
        ReadingStats.insights = real_insights
    end)

    local function ctx_for(look_id)
        return {
            look = Looks.get(look_id),
            variant = "day",
            text_size = "medium",
            now = os.time{ year = 2026, month = 10, day = 13, hour = 8, min = 42 },
            screen = Screen,
        }
    end

    -- The tile's content height under ctx: two rows of value, gap and caption, record_gap apart.
    local function content_h(ctx)
        local scale = Paint.scaler(ctx)
        local cell = Typeset.line_height(ctx.look.type.insight_value, ctx) + scale(ctx.look.insights.value_gap)
            + Typeset.line_height(ctx.look.type.insight_caption, ctx)
        return 2 * cell + scale(ctx.look.insights.record_gap)
    end

    it("reads the sessions as count, longest, average and pages an hour, the durations in words", function()
        assert.same({
            { value = "312", caption = "sessions" },
            { value = "1 h 48 min", caption = "longest" },
            { value = "24 min", caption = "average" },
            { value = "41", caption = "pages an hour" },
        }, Records.cells({ state = "read", sessions = fixture }))
    end)

    it("reads zeros with no sessions", function()
        assert.same({
            { value = "0", caption = "sessions" },
            { value = "0 min", caption = "longest" },
            { value = "0 min", caption = "average" },
            { value = "0", caption = "pages an hour" },
        }, Records.cells({ state = "empty" }))
    end)

    it("is the tile with the label, its aside and the two record rows tall", function()
        stub({ state = "read", sessions = fixture })
        local ctx = ctx_for("diner")
        assert.equals(10, Paint.scaler(ctx)(10))
        local tile = InsightTile.compose(520, ctx, "Sessions", "last year", content_h(ctx), function() end)
        local want = tile:getSize().h
        tile:free()
        assert.equals(want, Records.height(520, ctx))
        local built = Records.build(520, ctx)
        assert.equals(want, built:getSize().h)
        assert.equals(520, built:getSize().w)
        assert.equals("last year", built.tile.aside.text)
        built:free()
    end)

    it("is the label alone, saying reading stats are off, when they are", function()
        stub({ state = "off" })
        local ctx = ctx_for("diner")
        local tile = InsightTile.compose(520, ctx, "Sessions", "Reading stats are off", 0, function() end)
        local want = tile:getSize().h
        tile:free()
        assert.equals(want, Records.height(520, ctx))
        local built = Records.build(520, ctx)
        assert.equals("Reading stats are off", built.aside.text)
        built:free()
    end)

    it("draws in every look, with sessions, without and off", function()
        for _, look_id in ipairs(Looks.ids()) do
            for _, insights in ipairs({ { state = "read", sessions = fixture }, { state = "empty" },
                { state = "off" } }) do
                stub(insights)
                local ctx = ctx_for(look_id)
                local widget = Records.build(260, ctx)
                local size = widget:getSize()
                assert.is_true(size.h > 0)
                local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
                widget:paintTo(bb, 0, 0)
                bb:free()
                widget:free()
            end
        end
    end)

    it("frees its value and caption lines once, on free or on close", function()
        stub({ state = "read", sessions = fixture })
        local ctx = ctx_for("diner")
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local widget = Records.build(520, ctx)
            assert.equals(4, #widget.cells)
            local freed = 0
            for _, cell in ipairs(widget.cells) do
                for _, line in ipairs({ cell.value, cell.caption }) do
                    local free = line.free
                    line.free = function(self)
                        freed = freed + 1
                        return free(self)
                    end
                end
            end
            widget[close](widget)
            widget:free()
            assert.equals(8, freed)
        end
    end)

    -- Whether a line from Typeset.line shows its whole text: a tracked one is a group only when it fits.
    local function whole(line)
        return not (line.isTruncated and line:isTruncated())
    end

    it("sets the values smaller, together, until each fits a quarter-width column on the Colorsoft", function()
        stub({ state = "read", sessions = fixture })
        harness.at_colorsoft(function()
            local ctx = ctx_for("toybox")
            ctx.text_size = "large"
            local home = ctx.look.home
            local columns = Layout.columns(Screen:getWidth() - 2 * Paint.scaler(ctx)(home.margin.side),
                { { widget = "hours", share = 1 }, { widget = "records", share = 1 } }, home.column_gap)
            local widget = Records.build(columns[2].w, ctx)
            assert.is_true(widget.value_size < ctx.look.type.insight_value.size)
            for _, cell in ipairs(widget.cells) do
                assert.is_true(whole(cell.value))
            end
            widget:free()
        end)
    end)

    it("keeps the values at the part's size when they fit, the rows that tall", function()
        stub({ state = "read", sessions = fixture })
        local ctx = ctx_for("toybox")
        local widget = Records.build(520, ctx)
        assert.equals(ctx.look.type.insight_value.size, widget.value_size)
        widget:free()
    end)

    it("is shorter by the smaller values' line height when they shrink", function()
        stub({ state = "read", sessions = fixture })
        harness.at_colorsoft(function()
            local ctx = ctx_for("toybox")
            local widget = Records.build(300, ctx)
            local part = {}
            for k, v in pairs(ctx.look.type.insight_value) do
                part[k] = v
            end
            part.size = widget.value_size
            local scale = Paint.scaler(ctx)
            local content = 2 * (Typeset.line_height(part, ctx) + scale(ctx.look.insights.value_gap)
                + Typeset.line_height(ctx.look.type.insight_caption, ctx)) + scale(ctx.look.insights.record_gap)
            local tile = InsightTile.compose(300, ctx, "Sessions", "last year", content, function() end)
            assert.equals(tile:getSize().h, widget:getSize().h)
            tile:free()
            widget:free()
        end)
    end)

    it("cuts a value too wide for its column at the smallest size with an ellipsis", function()
        stub({ state = "read", sessions = { count = 123456789012345, longest = 6480, average = 1440,
            pages_per_hour = 41 } })
        local ctx = ctx_for("diner")
        local widget = Records.build(240, ctx)
        assert.equals(14, widget.value_size)
        local inner_w = InsightTile.inner_width(240, ctx)
        local column_w = math.floor((inner_w - Paint.scaler(ctx)(ctx.look.home.column_gap)) / 2)
        local first = widget.cells[1].value
        assert.is_true(first:getSize().w <= column_w)
        assert.is_true(first:isTruncated())
        assert.is_false(widget.cells[2].value.isTruncated and widget.cells[2].value:isTruncated() or false)
        widget:free()
    end)

    it("is the registry's records", function()
        assert.equals(Records, require("widgets").get("records"))
    end)
end)
