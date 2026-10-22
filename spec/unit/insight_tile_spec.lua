-- The insight tiles' shared chrome: the quote's tile, rules or plain plate around a label line, its
-- optional aside and the content a widget paints.
describe("the insight tile", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local Looks = require("looks")
    local Paint = require("paint")
    local Typeset = require("typeset")
    local InsightTile = require("insight_tile")

    local function ctx_for(look_id)
        return {
            look = Looks.get(look_id),
            variant = "day",
            text_size = "medium",
            now = os.time{ year = 2026, month = 10, day = 13, hour = 8, min = 42 },
            screen = Screen,
        }
    end

    local function painted_bb(tile)
        local size = tile:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, size.w, size.h, Blitbuffer.ColorRGB32(0, 255, 0, 0xFF))
        tile:paintTo(bb, 0, 0)
        return bb
    end

    local function same_color(bb, x, y, color)
        local c = bb:getPixel(x, y):getColorRGB32()
        local want = color:getColorRGB32()
        return c.r == want.r and c.g == want.g and c.b == want.b
    end

    it("is the chrome, a label line, the gap and the content tall, the content at the inner top-left", function()
        harness.at_colorsoft(function()
            local ctx = ctx_for("diner")
            local scale = Paint.scaler(ctx)
            assert.is_true(scale(10) > 10)
            local painted
            local tile, inner = InsightTile.compose(1200, ctx, "Reading this year", nil, 100,
                function(_, x, y, w, h, given)
                    painted = { x = x, y = y, w = w, h = h, ctx = given }
                end)
            local outline, pad = scale(ctx.look.stroke.outline), scale(ctx.look.insights.padding)
            local shadow_x, shadow_y = scale(ctx.look.shadow.tile.x), scale(ctx.look.shadow.tile.y)
            local label_h = Typeset.line_height(ctx.look.type.insight_label, ctx)
            local gap = scale(ctx.look.insights.label_gap)
            assert.equals(2 * (outline + pad) + shadow_y + label_h + gap + 100, tile:getSize().h)
            assert.equals(1200, tile:getSize().w)
            assert.equals(1200 - shadow_x - 2 * (outline + pad), InsightTile.inner_width(1200, ctx))
            assert.same({ w = InsightTile.inner_width(1200, ctx), label_h = label_h }, inner)
            painted_bb(tile)
            assert.same({ x = outline + pad, y = outline + pad + label_h + gap,
                w = inner.w, h = 100, ctx = ctx }, painted)
            tile:free()
        end)
    end)

    it("draws its box's outline and shadow in a look with a tile box", function()
        local ctx = ctx_for("diner")
        local color = Looks.colorer(ctx)
        local tile = InsightTile.compose(520, ctx, "Reading this year", nil, 40, function() end)
        local bb = painted_bb(tile)
        local h = tile:getSize().h
        local sx, sy = ctx.look.shadow.tile.x, ctx.look.shadow.tile.y
        assert.is_true(same_color(bb, 260, 0, color(ctx.look.tile.outline_color)))
        assert.is_true(same_color(bb, 260, h - 1, color(ctx.look.shadow.tile.color)))
        assert.is_true(same_color(bb, 520 - 1, h - 1, color(ctx.look.shadow.tile.color)))
        assert.is_true(same_color(bb, 260, h - sy - 1, color(ctx.look.tile.outline_color)))
        assert.is_true(same_color(bb, 520 - sx - 1, math.floor((h - sy) / 2), color(ctx.look.tile.outline_color)))
        tile:free()
    end)

    it("draws rules, not a box, in a look without a tile box", function()
        local ctx = ctx_for("editorial")
        assert.is_false(ctx.look.tile.box)
        local color = Looks.colorer(ctx)
        local scale = Paint.scaler(ctx)
        local painted
        local tile = InsightTile.compose(520, ctx, "Reading this year", nil, 40, function(_, x, y, w)
            painted = { x = x, y = y, w = w }
        end)
        local rule, pad = scale(ctx.look.stroke.hairline), scale(ctx.look.insights.padding)
        local label_h = Typeset.line_height(ctx.look.type.insight_label, ctx)
        local gap = scale(ctx.look.insights.label_gap)
        local h = tile:getSize().h
        assert.equals(2 * (rule + pad) + label_h + gap + 40, h)
        assert.equals(520, InsightTile.inner_width(520, ctx))
        local bb = painted_bb(tile)
        local rule_color = color(ctx.look.tile.rule_color)
        assert.is_true(same_color(bb, 0, 0, rule_color))
        assert.is_true(same_color(bb, 519, h - 1, rule_color))
        assert.is_false(same_color(bb, 0, rule, rule_color))
        assert.same({ x = 0, y = rule + pad + label_h + gap, w = 520 }, painted)
        tile:free()
    end)

    it("draws no chrome on a plate, only the padding above and below", function()
        local ctx = ctx_for("frosted")
        assert.is_true(Typeset.on_plate(ctx))
        local scale = Paint.scaler(ctx)
        local tile = InsightTile.compose(520, ctx, "Reading this year", nil, 40, function() end)
        local pad = scale(ctx.look.insights.padding)
        local label_h = Typeset.line_height(ctx.look.type.insight_label, ctx)
        assert.equals(2 * pad + label_h + scale(ctx.look.insights.label_gap) + 40, tile:getSize().h)
        assert.equals(520, InsightTile.inner_width(520, ctx))
        local bb = painted_bb(tile)
        assert.is_true(same_color(bb, 0, 0, Blitbuffer.ColorRGB32(0, 255, 0, 0xFF)))
        assert.is_true(same_color(bb, 519, tile:getSize().h - 1, Blitbuffer.ColorRGB32(0, 255, 0, 0xFF)))
        tile:free()
    end)

    it("sets the aside right-aligned on the label line, in the caption part", function()
        local ctx = ctx_for("diner")
        local tile = InsightTile.compose(520, ctx, "Year", "312 h", 40, function() end)
        local inner_w = InsightTile.inner_width(520, ctx)
        local whole = Typeset.line(ctx.look.type.insight_caption, "312 h", math.huge, ctx)
        local aside_w = tile.aside:getSize().w
        assert.equals(whole:getSize().w, aside_w)
        assert.equals(tile.inner_x + inner_w, tile.aside_x + aside_w)
        local label = Typeset.line(ctx.look.type.insight_label, "Year", math.huge, ctx)
        assert.equals(label:getSize().w, tile.label:getSize().w)
        local at = {}
        for _, name in ipairs({ "label", "aside" }) do
            local line = tile[name]
            local paint = line.paintTo
            line.paintTo = function(self, bb, x, y)
                at[name] = { x = x, y = y }
                return paint(self, bb, x, y)
            end
        end
        local size = tile:getSize()
        local bb = Blitbuffer.new(size.w + 7, size.h + 5, Blitbuffer.TYPE_BBRGB32)
        tile:paintTo(bb, 7, 5)
        bb:free()
        assert.equals(7 + tile.inner_x, at.label.x)
        assert.equals(7 + tile.inner_x + inner_w - aside_w, at.aside.x)
        assert.equals(at.label.y + Typeset.baseline(tile.label), at.aside.y + Typeset.baseline(tile.aside))
        whole:free()
        label:free()
        tile:free()
    end)

    it("cuts the label before the aside when both don't fit", function()
        local ctx = ctx_for("diner")
        local long = "Reading this year and the year before it and the one before that"
        local tile = InsightTile.compose(300, ctx, long, "312 h this year", 40, function() end)
        local inner_w = InsightTile.inner_width(300, ctx)
        local whole = Typeset.line(ctx.look.type.insight_caption, "312 h this year", math.huge, ctx)
        local aside_w = tile.aside:getSize().w
        assert.equals(whole:getSize().w, aside_w)
        assert.is_true(tile.label:getSize().w > 0)
        local gap = Paint.scaler(ctx)(ctx.look.insights.label_gap)
        assert.is_true(tile.inner_x + tile.label:getSize().w <= tile.aside_x - gap)
        local uncut = Typeset.line(ctx.look.type.insight_label, long, math.huge, ctx)
        assert.is_true(tile.label:getSize().w < uncut:getSize().w)
        assert.equals(tile.inner_x + inner_w, tile.aside_x + aside_w)
        uncut:free()
        whole:free()
        tile:free()
    end)

    it("frees its lines once, on free or on close", function()
        local ctx = ctx_for("diner")
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local tile = InsightTile.compose(520, ctx, "Year", "312 h", 40, function() end)
            local freed = 0
            for _, line in ipairs({ tile.label, tile.aside }) do
                local free = line.free
                line.free = function(self)
                    freed = freed + 1
                    return free(self)
                end
            end
            tile[close](tile)
            tile:free()
            assert.equals(2, freed)
        end
    end)
end)
