-- The row engine's maths: column widths by share, rows stacked from the top margin with the
-- free height where the look puts it, rows dropped from the end when they overflow, Layout.fits
-- in agreement with the placement, and the text size scale.
describe("Layout", function()
    require("plugin_harness")
    local Screen = require("device").screen
    local logger = require("logger")
    local Layout = require("layout")
    local Widgets = require("widgets")
    local NavBar = require("nav_bar")
    local editorial = require("looks").get("editorial")
    local diner = require("looks").get("diner")
    local frosted = require("looks").get("frosted")
    local real_get = Widgets.get
    local real_bar_height = NavBar.height

    -- A screen of w by h that scales as KOReader's framebuffer does (base/ffi/framebuffer.lua:414-425).
    local function screen(w, h)
        return {
            getWidth = function() return w end,
            getHeight = function() return h end,
            scaleBySize = Screen.scaleBySize,
        }
    end

    after_each(function()
        Layout.screen = Screen
        Widgets.get = real_get
        NavBar.height = real_bar_height
    end)

    describe("columns", function()
        -- Every list of n shares from 1 to 3.
        local function share_lists(n)
            if n == 0 then
                return { {} }
            end
            local out = {}
            for _, rest in ipairs(share_lists(n - 1)) do
                for share = 1, 3 do
                    local list = { share }
                    for _, s in ipairs(rest) do
                        list[#list + 1] = s
                    end
                    out[#out + 1] = list
                end
            end
            return out
        end

        it("splits the width by share with every gap, summing exactly, the last taking the remainder", function()
            for _, size in ipairs({ { 1236, 1648 }, { 1264, 1680 }, { 1680, 1264 } }) do
                Layout.screen = screen(size[1], size[2])
                local gap = Layout.screen:scaleBySize(16)
                for _, width in ipairs({ 1236, 1264, 1680 }) do
                    for n = 1, 3 do
                        for _, shares in ipairs(share_lists(n)) do
                            local slots, total = {}, 0
                            for i, share in ipairs(shares) do
                                slots[i] = { widget = "w" .. i, share = share }
                                total = total + share
                            end
                            local where = width .. " " .. table.concat(shares, ",")
                            local columns = Layout.columns(width, slots, 16)
                            assert.equals(n, #columns, where)
                            local available = width - (n - 1) * gap
                            local x, sum = 0, 0
                            for i, column in ipairs(columns) do
                                assert.equals(x, column.x, where)
                                if i < n then
                                    assert.equals(math.floor(available * shares[i] / total), column.w, where)
                                end
                                x = x + column.w + gap
                                sum = sum + column.w
                            end
                            assert.equals(available, sum, where)
                            assert.equals(width, columns[n].x + columns[n].w, where)
                        end
                    end
                end
            end
        end)
    end)

    describe("place", function()
        local margins = { top = 44, side = 40, bottom = 36 }
        local warned

        before_each(function()
            warned = spy.on(logger, "warn")
        end)

        after_each(function()
            logger.warn:revert()
        end)

        local function logged(text)
            for _, call in ipairs(warned.calls) do
                for _, arg in ipairs(call.vals) do
                    if tostring(arg):find(text, 1, true) then
                        return true
                    end
                end
            end
            return false
        end

        it("stacks rows from the top margin with the gap, a zero-height row taking none", function()
            local ys, dropped = Layout.place({ 100, 0, 50, 80 }, 800, margins, 28, "before_footer", 0)
            assert.same({ 44, 144, 172, 250 }, ys)
            assert.same({}, dropped)
        end)

        it("puts the free height before the last row, its bottom on the bottom margin", function()
            local ys, dropped = Layout.place({ 100, 0, 50, 80 }, 800, margins, 28, "before_last_row", 0)
            assert.same({ 44, 144, 172, 800 - 36 - 80 }, ys)
            assert.same({}, dropped)
        end)

        it("puts the free height before the last row that has a height", function()
            local ys = Layout.place({ 100, 80, 0 }, 800, margins, 28, "before_last_row", 0)
            assert.same({ 44, 800 - 36 - 80, 800 - 36 }, ys)
        end)

        it("leaves a single row at the top margin", function()
            local ys = Layout.place({ 100 }, 800, margins, 28, "before_last_row", 0)
            assert.same({ 44 }, ys)
        end)

        it("keeps the rows together before the footer", function()
            local ys, dropped = Layout.place({ 100, 50 }, 800, { top = 0, side = 40, bottom = 0 }, 22,
                "before_footer", 26)
            assert.same({ 0, 122 }, ys)
            assert.same({}, dropped)
        end)

        it("drops rows from the end until the rest fit, logging each drop", function()
            local ys, dropped = Layout.place({ 300, 300, 300, 10 }, 800, margins, 28, "before_footer", 0)
            assert.same({ 44, 372 }, ys)
            assert.same({ 3, 4 }, dropped)
            assert.is_true(logged("row 3"))
            assert.is_true(logged("row 4"))
            assert.is_false(logged("row 2"))
        end)

        it("fits rows that exactly fill the height and drops one pixel more", function()
            -- 800 - 44 - 36 = 720 = 346 + 28 + 346.
            local _, dropped = Layout.place({ 346, 346 }, 800, margins, 28, "before_last_row", 0)
            assert.same({}, dropped)
            _, dropped = Layout.place({ 346, 347 }, 800, margins, 28, "before_last_row", 0)
            assert.same({ 2 }, dropped)
        end)

        it("counts the footer against the height", function()
            local _, dropped = Layout.place({ 400, 374 }, 800, { top = 0, side = 40, bottom = 0 }, 0,
                "before_footer", 26)
            assert.same({}, dropped)
            _, dropped = Layout.place({ 400, 375 }, 800, { top = 0, side = 40, bottom = 0 }, 0,
                "before_footer", 26)
            assert.same({ 2 }, dropped)
        end)

        it("puts the last kept row on the bottom margin after a drop", function()
            local ys, dropped = Layout.place({ 300, 300, 300 }, 800, margins, 28, "before_last_row", 0)
            assert.same({ 3 }, dropped)
            assert.same({ 44, 800 - 36 - 300 }, ys)
        end)

        it("takes first_gap below row 1 in place of the row gap, a zero-height row 1 taking none", function()
            local ys = Layout.place({ 100, 50, 80 }, 800, margins, 28, "before_footer", 0, 0)
            assert.same({ 44, 144, 222 }, ys)
            ys = Layout.place({ 0, 50, 80 }, 800, margins, 28, "before_footer", 0, 0)
            assert.same({ 44, 44, 122 }, ys)
            local _, dropped = Layout.place({ 360, 360 }, 800, margins, 28, "before_footer", 0, 0)
            assert.same({}, dropped)
        end)

        it("scales the margins, gap and footer once by the screen", function()
            Layout.screen = screen(1264, 1680)
            local s = function(px) return Layout.screen:scaleBySize(px) end
            local ys = Layout.place({ 100, 0, 50 }, 1680, margins, 28, "before_footer", 26)
            assert.same({ s(44), s(44) + 100, s(44) + 100 + s(28) }, ys)
            ys = Layout.place({ 100, 50 }, 1680, margins, 28, "before_last_row", 0)
            assert.same({ s(44), 1680 - s(36) - 50 }, ys)
        end)
    end)

    describe("arrange and fits", function()
        local heights
        -- The bar's height in device pixels, whatever the look and screen.
        local BAR = 180

        -- Stub widgets whose height is heights[id] (0 when unset).
        local function stub_widgets()
            heights = {}
            local stubs = {}
            for _, id in ipairs({ "date", "clock", "weather", "quote", "stats" }) do
                stubs[id] = {
                    id = id,
                    height = function()
                        return heights[id] or 0
                    end,
                    build = function() end,
                }
            end
            Widgets.get = function(id)
                return stubs[id]
            end
        end

        local function ctx(look, w, h, text_size)
            Layout.screen = screen(w, h)
            return { look = look, screen = Layout.screen, text_size = text_size or "medium" }
        end

        local default = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "quote", share = 1 } },
            { { widget = "weather", share = 1 }, { widget = "stats", share = 1 } },
        }

        before_each(function()
            stub_widgets()
            NavBar.height = function()
                return BAR
            end
        end)

        it("adds Editorial's rule under row 1 and Diner's band to row 1's height", function()
            heights = { date = 60, clock = 50, quote = 100, weather = 20, stats = 30 }
            local c = ctx(editorial, 1264, 1680)
            local s = function(px) return Layout.screen:scaleBySize(px) end
            local arranged = Layout.arrange(default, c)
            assert.same({ 60 + s(17) + s(2) + s(17), 100, 30 }, arranged.heights)
            c = ctx(diner, 1264, 1680)
            arranged = Layout.arrange(default, c)
            assert.same({ s(22) + 60 + s(17) + s(4), 100, 30 }, arranged.heights)
        end)

        it("lays row 1's slots inside the band's padding for Diner and the margins for Editorial", function()
            heights = { date = 60, clock = 50, quote = 100, stats = 30 }
            local s = function(px) return Layout.screen:scaleBySize(px) end
            local arranged = Layout.arrange(default, ctx(diner, 1264, 1680))
            local row = arranged.rows[1]
            assert.equals(s(40), row.slots[1].x)
            assert.equals(1264 - s(40), row.slots[2].x + row.slots[2].w)
            assert.equals(s(22), row.slots[1].y)
            assert.same({ x = 0, y = 0, w = 1264, h = s(22) + 60 + s(17) + s(4) }, arranged.header.band)
            arranged = Layout.arrange(default, ctx(editorial, 1264, 1680))
            row = arranged.rows[1]
            assert.equals(s(40), row.slots[1].x)
            assert.equals(s(33), row.slots[1].y)
            assert.is_nil(arranged.header.band)
            assert.same({ x = s(40), y = s(33) + 60 + s(17), w = 1264 - 2 * s(40), h = s(2) },
                arranged.header.rule)
            -- 17 px below the rule as above it, no row gap after.
            assert.equals(arranged.header.rule.y + s(2) + s(17), arranged.rows[2].y)
        end)

        it("draws no footer in either look", function()
            heights = { date = 60, clock = 50, quote = 100 }
            for _, look in ipairs({ editorial, diner }) do
                assert.is_nil(Layout.arrange(default, ctx(look, 1264, 1680)).footer)
            end
        end)

        it("places the rows above the bar's band and reports the band as nav", function()
            heights = { date = 60, clock = 50, quote = 100, weather = 20, stats = 30 }
            for _, look in ipairs({ editorial, diner }) do
                local c = ctx(look, 1264, 1680)
                local s = function(px) return Layout.screen:scaleBySize(px) end
                local arranged = Layout.arrange(default, c)
                assert.same({ x = 0, y = 1680 - BAR, w = 1264, h = BAR }, arranged.nav)
                assert.equals(1680, arranged.height)
                assert.same({}, arranged.dropped)
                local floor = 1680 - BAR - s(look.home.margin.bottom)
                for i, row in ipairs(arranged.rows) do
                    assert.truthy(row.y + row.h <= floor, i)
                end
                local last = arranged.rows[3]
                if look.home.free_space == "before_last_row" then
                    -- Editorial's last row sits on the bottom margin above the band.
                    assert.equals(floor, last.y + last.h)
                end
            end
        end)

        it("drops the last row of a layout that fits the full height but not the height less the band", function()
            for _, look in ipairs({ editorial, diner }) do
                local c = ctx(look, 1264, 1680)
                local home = look.home
                local first_gap = home.header.rule_color and 0 or nil
                heights = { date = 60, clock = 60, quote = 100, weather = 20, stats = 20 }
                local fixed = Layout.arrange(default, c).heights
                -- The weather row's height that fills the full height exactly, and so overflows
                -- the height less the band.
                local probe = { fixed[1], fixed[2], 0 }
                local ys = Layout.place(probe, 1680, home.margin, home.row_gap, "before_footer", 0, first_gap)
                local s = function(px) return Layout.screen:scaleBySize(px) end
                heights.weather = 1680 - s(home.margin.bottom) - ys[3] - s(home.row_gap)
                local _, full = Layout.place(Layout.arrange(default, c).heights, 1680, home.margin, home.row_gap,
                    home.free_space, 0, first_gap)
                assert.same({}, full, "the layout fits the full height")
                assert.same({ 3 }, Layout.arrange(default, c).dropped)
                assert.equals(1, Layout.overflow(default, c))
                assert.is_false(Layout.fits(default, c))
            end
        end)

        it("draws no header chrome when row 1 measures 0", function()
            heights = { quote = 100 }
            for _, look in ipairs({ editorial, diner }) do
                local arranged = Layout.arrange(default, ctx(look, 1264, 1680))
                assert.equals(0, arranged.heights[1])
                assert.same({}, arranged.header)
            end
        end)

        it("sizes the home by the screen it scales by", function()
            heights = { quote = 100 }
            local c = ctx(diner, 1264, 1680)
            c.screen = screen(600, 800)
            local arranged = Layout.arrange(default, c)
            assert.equals(1264, arranged.width)
            assert.equals(1680, arranged.height)
        end)

        it("gives a widget its slot's width and a missing module no height", function()
            local widths = {}
            Widgets.get = function(id)
                if id == "quote" then
                    return nil
                end
                return {
                    height = function(width)
                        widths[id] = width
                        return 40
                    end,
                }
            end
            local arranged = Layout.arrange(default, ctx(diner, 1264, 1680))
            for _, row in ipairs(arranged.rows) do
                for _, slot in ipairs(row.slots) do
                    if slot.widget ~= "quote" then
                        assert.equals(slot.w, widths[slot.widget], slot.widget)
                    end
                end
            end
            assert.equals(0, arranged.heights[2])
            assert.is_nil(arranged.rows[2].slots[1].module)
        end)

        -- Frosted's plates (looks/frosted.lua plate): row 1 one header plate between the side margins, its slots
        -- inside its keyline and header padding; every other widget on a plate of its own, padded inside its keyline,
        -- measured at the width inside it; the gutters between plates the row and column gaps.
        describe("with plates", function()
            local s = function(px)
                return Layout.screen:scaleBySize(px)
            end

            it("puts row 1 on one header plate between the side margins, its slots inside its keyline", function()
                heights = { date = 60, clock = 50, quote = 100, weather = 20, stats = 30 }
                local arranged = Layout.arrange(default, ctx(frosted, 1264, 1680))
                local row = arranged.rows[1]
                local inset = s(2) + s(14)
                assert.equals(60 + 2 * inset, arranged.heights[1])
                assert.same({ x = s(24), y = s(26), w = 1264 - 2 * s(24), h = 60 + 2 * inset, radius = s(12) },
                    arranged.header.plate)
                assert.equals(s(24) + s(2) + s(18), row.slots[1].x)
                assert.equals(1264 - s(24) - s(2) - s(18), row.slots[2].x + row.slots[2].w)
                assert.equals(s(26) + inset, row.slots[1].y)
                assert.is_nil(row.slots[1].plate)
            end)

            it("puts every other widget on its own plate, padded inside its keyline", function()
                local widths = {}
                heights = { date = 60, clock = 50, quote = 100, weather = 20, stats = 30 }
                local get = Widgets.get
                Widgets.get = function(id)
                    local stub = get(id)
                    return { id = id, build = stub.build, height = function(width)
                        widths[id] = width
                        return stub.height(width)
                    end }
                end
                local arranged = Layout.arrange(default, ctx(frosted, 1264, 1680))
                local quote = arranged.rows[2].slots[1]
                local pad_x, pad_y = s(2) + s(18), s(2) + s(12)
                assert.same({ pad_x, pad_y }, { quote.pad_x, quote.pad_y })
                assert.equals(100 + 2 * pad_y, arranged.heights[2])
                assert.same({ x = s(24), y = quote.y, w = 1264 - 2 * s(24), h = 100 + 2 * pad_y, radius = s(12) },
                    quote.plate)
                assert.equals(1264 - 2 * s(24) - 2 * pad_x, widths.quote)
                local stats = arranged.rows[3].slots[2]
                assert.same({ s(2) + s(14), s(2) + s(8) }, { stats.pad_x, stats.pad_y })
                assert.equals(s(999), stats.plate.radius)
                -- The row's plates share its height, the taller widget's and its padding.
                assert.equals(30 + 2 * (s(2) + s(8)), arranged.heights[3])
                assert.equals(arranged.heights[3], arranged.rows[3].slots[1].plate.h)
            end)

            it("keeps the margins and gutters between plates", function()
                heights = { date = 60, clock = 50, quote = 100, weather = 20, stats = 30 }
                local arranged = Layout.arrange(default, ctx(frosted, 1264, 1680))
                local header, quote = arranged.header.plate, arranged.rows[2].slots[1].plate
                assert.equals(s(26), header.y)
                assert.equals(s(12), quote.y - (header.y + header.h))
                local weather, stats = arranged.rows[3].slots[1].plate, arranged.rows[3].slots[2].plate
                assert.equals(s(24), weather.x)
                assert.equals(s(12), stats.x - (weather.x + weather.w))
                assert.equals(1264 - s(24), stats.x + stats.w)
                -- The last row sits on the bottom margin above the bar.
                assert.equals(1680 - BAR - s(14), stats.y + stats.h)
            end)

            it("puts no plate under a widget that measures 0", function()
                heights = { date = 60, clock = 50, quote = 100, weather = 20 }
                local arranged = Layout.arrange(default, ctx(frosted, 1264, 1680))
                assert.is_table(arranged.rows[3].slots[1].plate)
                assert.is_nil(arranged.rows[3].slots[2].plate)
                heights = { quote = 100 }
                arranged = Layout.arrange(default, ctx(frosted, 1264, 1680))
                assert.is_nil(arranged.header.plate)
            end)

            it("gives a look without plates none, and no padding", function()
                heights = { date = 60, clock = 50, quote = 100, weather = 20, stats = 30 }
                for _, look in ipairs({ editorial, diner }) do
                    local arranged = Layout.arrange(default, ctx(look, 1264, 1680))
                    assert.is_nil(arranged.header.plate)
                    for _, row in ipairs(arranged.rows) do
                        for _, slot in ipairs(row.slots) do
                            assert.is_nil(slot.plate)
                            assert.same({ 0, 0 }, { slot.pad_x, slot.pad_y })
                        end
                    end
                end
            end)
        end)

        it("records a widget's height error and measures its slot as 0", function()
            Widgets.get = function(id)
                return {
                    height = function()
                        if id == "clock" then
                            error("kopanda-test: height failed")
                        end
                        return 40
                    end,
                }
            end
            local rows = { { { widget = "clock", share = 1 } }, { { widget = "quote", share = 1 } } }
            local arranged = Layout.arrange(rows, ctx(editorial, 1264, 1680))
            local clock = arranged.rows[1].slots[1]
            assert.truthy(tostring(clock.error):find("kopanda-test: height failed", 1, true))
            assert.same({ 0, 40 }, arranged.heights)
        end)

        it("is true exactly when the placement drops nothing", function()
            local flipped = false
            for _, look in ipairs({ editorial, diner }) do
                local previous
                for quote = 1000, 1600, 10 do
                    heights = { date = 60, clock = 60, quote = quote, weather = 20, stats = 20 }
                    local c = ctx(look, 1264, 1680)
                    local arranged = Layout.arrange(default, c)
                    local home = look.home
                    local footer = home.footer.height > 0 and home.footer.height + home.footer.edge_width or 0
                    local first_gap = home.header.rule_color and 0 or nil
                    local _, dropped = Layout.place(arranged.heights, 1680 - BAR, home.margin, home.row_gap,
                        home.free_space, footer, first_gap)
                    local fits = Layout.fits(default, c)
                    assert.equals(#dropped == 0, fits, quote)
                    assert.same(dropped, arranged.dropped, quote)
                    if previous ~= nil and previous ~= fits then
                        flipped = true
                    end
                    previous = fits
                end
            end
            assert.is_true(flipped)
        end)

        it("counts no row left out on the Colorsoft and one for a layout one row too tall, logging nothing", function()
            local warned = spy.on(logger, "warn")
            heights = { date = 60, clock = 60, quote = 100, weather = 20, stats = 20 }
            local fitting = Layout.overflow(default, ctx(diner, 1264, 1680))
            heights = { date = 60, clock = 60, quote = 700, weather = 300, stats = 20 }
            local too_tall = Layout.overflow(default, ctx(diner, 1680, 1264))
            warned:revert()
            assert.equals(0, fitting)
            assert.equals(1, too_tall)
            assert.spy(warned).was_not_called()
        end)

        it("counts exactly the rows the placement drops, zero exactly when fits is true", function()
            local counted = {}
            for _, look in ipairs({ editorial, diner }) do
                for quote = 400, 2400, 40 do
                    heights = { date = 60, clock = 60, quote = quote, weather = quote, stats = 20 }
                    local c = ctx(look, 1264, 1680)
                    local overflow = Layout.overflow(default, c)
                    assert.equals(#Layout.arrange(default, c).dropped, overflow, quote)
                    assert.equals(overflow == 0, Layout.fits(default, c), quote)
                    counted[overflow] = true
                end
            end
            assert.is_true(counted[0] and counted[1] and counted[2], "the sweep reaches 0, 1 and 2")
        end)

        it("lays out a landscape screen, dropping what doesn't fit", function()
            heights = { date = 60, clock = 60, quote = 700, weather = 300, stats = 20 }
            local c = ctx(diner, 1680, 1264)
            local ok, arranged = pcall(Layout.arrange, default, c)
            assert.is_true(ok, tostring(arranged))
            assert.same({ 3 }, arranged.dropped)
            assert.is_false(Layout.fits(default, c))
            local s = function(px) return Layout.screen:scaleBySize(px) end
            for i, row in ipairs(arranged.rows) do
                local last = row.slots[#row.slots]
                local inset = i == 1 and s(diner.home.header.padding.side) or s(diner.home.margin.side)
                assert.equals(1680 - inset, last.x + last.w)
            end
        end)

        it("leaves margins and gaps alone at every text size", function()
            heights = { date = 60, clock = 60, quote = 100, weather = 20, stats = 20 }
            local positions = {}
            for _, size in ipairs({ "small", "medium", "large" }) do
                local arranged = Layout.arrange(default, ctx(editorial, 1264, 1680, size))
                local out = {}
                for _, row in ipairs(arranged.rows) do
                    for _, slot in ipairs(row.slots) do
                        out[#out + 1] = { slot.x, slot.y, slot.w }
                    end
                end
                positions[size] = out
            end
            assert.same(positions.medium, positions.small)
            assert.same(positions.medium, positions.large)
        end)

        it("leaves the layout it is given unchanged", function()
            local copy = {}
            for i, row in ipairs(default) do
                copy[i] = {}
                for j, slot in ipairs(row) do
                    copy[i][j] = { widget = slot.widget, share = slot.share }
                end
            end
            heights = { quote = 100 }
            Layout.arrange(default, ctx(diner, 1264, 1680))
            assert.same(copy, default)
        end)
    end)

    -- The schema's default rows with the real widgets and the real bar, in both looks at each text size, on the
    -- Colorsoft and the Paperwhite, with the home fixture's content (2-scenario-home-fixture.lua): populated (a
    -- featured book with its chapter, a weather reading, the quote of the day) and empty (none of them, the fixture's
    -- six launcher entries). Text is measured by Font:getFace at the device screen's scale
    -- (frontend/ui/font.lua:276), so the device screen itself answers as each profile's, as harness.at_colorsoft
    -- makes it the Colorsoft's.
    describe("the default home above the bar", function()
        local harness = require("plugin_harness")
        local Geom = require("ui/geometry")
        local TextWidget = require("ui/widget/textwidget")
        -- The home fixture's frozen time, 2026-10-13 08:42.
        local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 8, min = 42, sec = 0 }

        -- harness.at_colorsoft's stubs at the Paperwhite's 1236×1648, no DPI override.
        local function at_paperwhite(fn)
            local W, H = 1236, 1648
            local function scale(px)
                return math.ceil(px * W / 600)
            end
            local stubs = {
                { Screen, "getWidth", function() return W end },
                { Screen, "getHeight", function() return H end },
                { Screen, "getSize", function() return Geom:new{ x = 0, y = 0, w = W, h = H } end },
                { Screen, "scaleBySize", function(_, px) return scale(px) end },
                { TextWidget, "padding", scale(2) },
            }
            local saved = {}
            for i, stub in ipairs(stubs) do
                saved[i] = rawget(stub[1], stub[2])
                stub[1][stub[2]] = stub[3]
            end
            local ok, err = pcall(fn)
            for i, stub in ipairs(stubs) do
                stub[1][stub[2]] = saved[i]
            end
            if not ok then
                error(err, 0)
            end
        end

        local CONTENT = {
            populated = {
                book = {
                    file = harness.library .. "/frankenstein.epub",
                    title = "Frankenstein",
                    authors = "Mary Shelley",
                    percent = 0.62,
                    status = "reading",
                    pages = 220,
                    seconds_left = 220 * 0.38 * 90,
                    chapter = "Letter IV",
                },
                reading = {
                    fetched_at = NOW - 20 * 60,
                    temperature = 61.4,
                    weather_code = 2,
                    is_day = 1,
                    units = "fahrenheit",
                    latitude = 41.85003,
                    longitude = -87.65005,
                },
            },
            empty = {
                entries = {
                    { kind = "kopanda", target = "library" },
                    { kind = "kopanda", target = "series" },
                    { kind = "kopanda", target = "authors" },
                    { kind = "koreader", target = "history" },
                    { kind = "koreader", target = "wifi" },
                    { kind = "plugin", plugin = "kopanda_absent", action = "terminal", label = "Terminal",
                        icon = "terminal" },
                },
            },
        }

        before_each(function()
            harness.load()
        end)

        -- "profile look content text_size" to the rows Layout.overflow leaves out.
        local function overflows()
            local FeaturedBook = require("featured_book")
            local Looks = require("looks")
            local Schema = require("schema")
            local Settings = require("settings")
            local Weather = require("weather")
            local real_current, real_reading = FeaturedBook.current, Weather.reading
            local defaults = {}
            for _, key in ipairs(Schema.keys) do
                defaults[key.id] = key.default
            end
            local rows = defaults["layout.rows"]
            local counts = {}
            local function count(profile)
                for _, content in ipairs({ "populated", "empty" }) do
                    local c = CONTENT[content]
                    FeaturedBook.current = function() return c.book end
                    Weather.reading = function() return c.reading end
                    assert.is_true(Settings.set("launcher.entries", c.entries or defaults["launcher.entries"]))
                    for _, look in ipairs({ "diner", "editorial" }) do
                        for _, size in ipairs({ "small", "medium", "large" }) do
                            local ctx = {
                                look = Looks.get(look),
                                variant = "day",
                                text_size = size,
                                now = NOW,
                                screen = Screen,
                            }
                            counts[table.concat({ profile, look, content, size }, " ")] =
                                require("layout").overflow(rows, ctx)
                        end
                    end
                end
            end
            local ok, err = pcall(function()
                harness.at_colorsoft(function() count("colorsoft") end)
                at_paperwhite(function() count("paperwhite") end)
            end)
            FeaturedBook.current, Weather.reading = real_current, real_reading
            assert(ok, err)
            return counts
        end

        -- The looks' home spacing is tightened until this holds (looks/diner.lua, looks/editorial.lua).
        -- At large, every case still leaves out the last row, the weather and the stats; that is
        -- reported, not tightened further.
        it("leaves no row out at small and medium on either profile, populated or empty, and one at large", function()
            local counts = overflows()
            local expected, cases = {}, 0
            for key in pairs(counts) do
                expected[key] = key:match(" large$") and 1 or 0
                cases = cases + 1
            end
            -- Two profiles, two looks, two contents, three text sizes.
            assert.equals(24, cases)
            assert.same(expected, counts)
        end)

        -- Page 2's insights with a year of reading, every hour of the day used and a featured book in progress.
        it("fits the page-2 default on the Colorsoft and the Paperwhite at every text size in every look", function()
            local FeaturedBook = require("featured_book")
            local Looks = require("looks")
            local ReadingStats = require("reading_stats")
            local Schema = require("schema")
            local rows
            for _, key in ipairs(Schema.keys) do
                if key.id == "layout.rows_2" then
                    rows = key.default
                end
            end
            local days, hours = {}, {}
            for i = 1, ReadingStats.INSIGHT_DAYS do
                days[i] = i % 6 == 0 and 0 or 1200 + (i * 397) % 3600
            end
            for h = 1, 24 do
                hours[h] = 600 + (h * 731) % 5400
            end
            local insights = { state = "ok", days = days, hours = hours,
                sessions = { count = 312, longest = 6480, average = 1440, pages_per_hour = 41 } }
            local real_insights, real_current = ReadingStats.insights, FeaturedBook.current
            ReadingStats.insights = function() return insights end
            FeaturedBook.current = function()
                return { file = "/x.epub", title = "Frankenstein", percent = 0.62, status = "reading",
                    seconds_left = 7560 }
            end
            local counts, expected, cases = {}, {}, 0
            local function count(profile)
                for _, id in ipairs(Looks.ids()) do
                    for _, size in ipairs({ "small", "medium", "large" }) do
                        local ctx = {
                            look = Looks.get(id),
                            variant = "day",
                            text_size = size,
                            now = os.time{ year = 2026, month = 10, day = 13, hour = 20, min = 42, sec = 0 },
                            screen = Screen,
                        }
                        local key = table.concat({ profile, id, size }, " ")
                        counts[key] = require("layout").overflow(rows, ctx)
                        expected[key] = 0
                        cases = cases + 1
                    end
                end
            end
            local ok, err = pcall(function()
                harness.at_colorsoft(function() count("colorsoft") end)
                harness.at_paperwhite(function() count("paperwhite") end)
            end)
            ReadingStats.insights, FeaturedBook.current = real_insights, real_current
            assert(ok, err)
            -- Two profiles, three text sizes, every look.
            assert.equals(6 * #Looks.ids(), cases)
            assert.same(expected, counts)
        end)
    end)

    describe("font_size", function()
        it("scales by 0.85, 1 and 1.15, rounded", function()
            local wanted = {
                [11] = { small = 9, medium = 11, large = 13 },
                [12] = { small = 10, medium = 12, large = 14 },
                [13] = { small = 11, medium = 13, large = 15 },
                [16] = { small = 14, medium = 16, large = 18 },
                [18] = { small = 15, medium = 18, large = 21 },
                [36] = { small = 31, medium = 36, large = 41 },
                [56] = { small = 48, medium = 56, large = 64 },
            }
            for size, by_text_size in pairs(wanted) do
                for text_size, expected in pairs(by_text_size) do
                    assert.equals(expected, Layout.font_size(size, text_size), size .. " " .. text_size)
                end
            end
        end)
    end)
end)
