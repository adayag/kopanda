-- The Device tile: the storage free and the memory KOReader uses, each value over its caption in equal columns; a
-- reading the device can't give drops its cell, and the rest fill the row.
describe("the device widget", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local InsightTile = require("insight_tile")
    local Looks = require("looks")
    local Paint = require("paint")
    local Typeset = require("typeset")
    local Device = require("widgets/device")

    local real_readings = Device.readings
    local fixture

    before_each(function()
        fixture = { storage = 11800000000, memory = 96000000 }
        Device.readings = function()
            return fixture
        end
    end)

    after_each(function()
        Device.readings = real_readings
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

    describe("cells", function()
        it("reads the storage free and the memory KOReader uses", function()
            assert.same({
                { value = "11.8 GB", caption = "storage free" },
                { value = "96.0 MB", caption = "KOReader memory" },
            }, Device.cells({ storage = 11800000000, memory = 96000000 }))
        end)

        it("drops a nil reading's cell", function()
            assert.same({ { value = "96.0 MB", caption = "KOReader memory" } }, Device.cells({ memory = 96000000 }))
            assert.same({ { value = "11.8 GB", caption = "storage free" } }, Device.cells({ storage = 11800000000 }))
        end)

        it("is empty with no readings", function()
            assert.same({}, Device.cells({}))
        end)
    end)

    it("is the tile with the label, its aside and a value over a caption tall", function()
        local ctx = ctx_for("diner")
        local scale = Paint.scaler(ctx)
        local look = ctx.look
        local content_h = Typeset.line_height(look.type.insight_value, ctx) + scale(look.insights.value_gap)
            + Typeset.line_height(look.type.insight_caption, ctx)
        local tile = InsightTile.compose(520, ctx, "Device", "when you opened Stats", content_h, function() end)
        local widget = Device.build(520, ctx)
        assert.equals(tile:getSize().h, widget:getSize().h)
        assert.equals(tile:getSize().h, Device.height(520, ctx))
        assert.equals(520, widget:getSize().w)
        assert.equals("when you opened Stats", widget.aside.text)
        tile:free()
        widget:free()
    end)

    it("shares the row equally among the cells it has, the first at the left", function()
        local ctx = ctx_for("diner")
        local inner_w = InsightTile.inner_width(520, ctx)
        local gap = Paint.scaler(ctx)(ctx.look.home.column_gap)
        local two = Device.build(520, ctx)
        assert.equals(2, #two.cells)
        assert.equals(0, two.cells[1].x)
        assert.equals(math.floor((inner_w - gap) / 2) + gap, two.cells[2].x)
        two:free()

        fixture = { memory = 96000000 }
        local one = Device.build(520, ctx)
        assert.equals(1, #one.cells)
        assert.equals(0, one.cells[1].x)
        assert.equals("96.0 MB", one.cells[1].value.text)
        one:free()
    end)

    it("says it has nothing to report with no readings, the label alone", function()
        fixture = {}
        local ctx = ctx_for("diner")
        local widget = Device.build(520, ctx)
        assert.equals("Nothing to report", widget.aside.text)
        local bare = InsightTile.compose(520, ctx, "Device", "Nothing to report", 0, function() end)
        assert.equals(bare:getSize().h, widget:getSize().h)
        bare:free()
        widget:free()
    end)

    it("sets the values smaller, together, until each fits its column", function()
        fixture = { storage = 188888888888, memory = 188888888 }
        local ctx = ctx_for("diner")
        local widget = Device.build(240, ctx)
        assert.is_true(widget.value_size < ctx.look.type.insight_value.size)
        for _, cell in ipairs(widget.cells) do
            assert.is_true(Typeset.whole(cell.value))
        end
        widget:free()
    end)

    it("reads the device at each build", function()
        local ctx = ctx_for("diner")
        local first = Device.build(520, ctx)
        first:free()
        fixture = { storage = 2000000000 }
        local second = Device.build(520, ctx)
        assert.equals("2.0 GB", second.cells[1].value.text)
        second:free()
    end)

    it("draws in every look, with readings and without", function()
        for _, look_id in ipairs(Looks.ids()) do
            for _, readings in ipairs({ { storage = 11800000000, memory = 96000000 }, {} }) do
                fixture = readings
                local widget = Device.build(520, ctx_for(look_id))
                local size = widget:getSize()
                local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
                widget:paintTo(bb, 0, 0)
                bb:free()
                widget:free()
            end
        end
    end)

    it("frees its value and caption lines once, on free or on close", function()
        local ctx = ctx_for("diner")
        for _, close in ipairs({ "free", "onCloseWidget" }) do
            local widget = Device.build(520, ctx)
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
            assert.equals(4, freed)
        end
    end)

    it("is the registry's device", function()
        assert.equals(Device, require("widgets").get("device"))
    end)
end)
