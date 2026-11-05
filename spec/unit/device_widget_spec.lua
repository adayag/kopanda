-- The Device tile: the battery with its time left, the storage free and the memory KOReader uses, each value over its
-- caption in equal columns; a reading the device can't give drops its cell, and the rest fill the row.
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

        it("opens with the battery over its time left", function()
            local cells = Device.cells({ battery = 74, left = 259200, storage = 1, memory = 1 })
            assert.equals(3, #cells)
            assert.same({ value = "74%", caption = "about 3 days left" }, cells[1])
        end)

        it("captions the battery plainly with no time left", function()
            assert.same({ value = "74%", caption = "battery" }, Device.cells({ battery = 74 })[1])
        end)

        it("captions the battery plainly while charging, whatever the time left", function()
            assert.same({ value = "74%", caption = "battery" },
                Device.cells({ battery = 74, charging = true, left = 259200 })[1])
        end)

        it("drops the battery's cell without a reading, whatever the time left", function()
            assert.same({}, Device.cells({ left = 259200 }))
        end)
    end)

    describe("readings", function()
        local DeviceStats = require("device_stats")
        local KoDevice = require("device")
        local QuickSettings = require("quick_settings")
        local stubs

        -- The real read with the battery at percent, the charging read's own function, and totals on record.
        local function read_with(percent, is_charging, totals)
            stubs = {
                stub(QuickSettings, "battery", function()
                    return percent
                end),
                stub(KoDevice, "getPowerDevice", function()
                    return { isCharging = is_charging }
                end),
                stub(DeviceStats, "battery_totals", function()
                    return totals
                end),
                stub(DeviceStats, "storage", function()
                    return 11800000000
                end),
                stub(DeviceStats, "memory", function()
                    return 96000000
                end),
            }
            finally(function()
                for _, s in ipairs(stubs) do
                    s:revert()
                end
            end)
            return real_readings()
        end

        local TOTALS = { discharging = { percentage = 37, time = 10 * 3600 * 1000000 } }

        local function not_charging()
            return false
        end

        it("reads the battery, its time left at the rate on record, the storage and the memory", function()
            assert.same({ battery = 74, charging = false, left = 20 * 3600, storage = 11800000000, memory = 96000000 },
                read_with(74, not_charging, TOTALS))
        end)

        it("reads charging as the device says", function()
            local readings = read_with(74, function()
                return true
            end, TOTALS)
            assert.is_true(readings.charging)
            assert.equals("battery", Device.cells(readings)[1].caption)
        end)

        it("takes a failed charging read as charging", function()
            local readings = read_with(74, function()
                error("no power device")
            end, TOTALS)
            assert.is_true(readings.charging)
            assert.equals("battery", Device.cells(readings)[1].caption)
        end)

        it("reads no time left from no totals, or from no battery", function()
            local unread = read_with(74, not_charging, nil)
            assert.is_nil(unread.left)
            assert.equals("battery", Device.cells(unread)[1].caption)
            for _, s in ipairs(stubs) do
                s:revert()
            end

            local none = read_with(nil, not_charging, TOTALS)
            assert.is_nil(none.battery)
            assert.is_nil(none.left)
            assert.equals("storage free", Device.cells(none)[1].caption)
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

    it("sets the battery first of three columns", function()
        fixture = { battery = 74, left = 259200, storage = 11800000000, memory = 96000000 }
        local ctx = ctx_for("diner")
        local inner_w = InsightTile.inner_width(520, ctx)
        local gap = Paint.scaler(ctx)(ctx.look.home.column_gap)
        local widget = Device.build(520, ctx)
        assert.equals(3, #widget.cells)
        assert.equals("74%", widget.cells[1].value.text)
        assert.equals("about 3 days left", widget.cells[1].caption.text)
        assert.equals(2 * (math.floor((inner_w - 2 * gap) / 3) + gap), widget.cells[3].x)
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
