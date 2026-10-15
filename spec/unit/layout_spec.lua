-- The row engine's maths (C3): column widths by share, rows stacked from the top margin with the
-- free height where the look puts it, rows dropped from the end when they overflow, Layout.fits
-- in agreement with the placement, and the text size scale.
describe("Layout", function()
    require("plugin_harness")
    local Screen = require("device").screen
    local logger = require("logger")
    local Layout = require("layout")
    local Widgets = require("widgets")
    local editorial = require("looks/editorial")
    local diner = require("looks/diner")
    local real_get = Widgets.get

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

        before_each(stub_widgets)

        it("adds Editorial's rule under row 1 and Diner's band to row 1's height", function()
            heights = { date = 60, clock = 50, quote = 100, weather = 20, stats = 30 }
            local c = ctx(editorial, 1264, 1680)
            local s = function(px) return Layout.screen:scaleBySize(px) end
            local arranged = Layout.arrange(default, c)
            assert.same({ 60 + s(22) + s(2), 100, 30 }, arranged.heights)
            c = ctx(diner, 1264, 1680)
            arranged = Layout.arrange(default, c)
            assert.same({ s(36) + 60 + s(28) + s(4), 100, 30 }, arranged.heights)
        end)

        it("lays row 1's slots inside the band's padding for Diner and the margins for Editorial", function()
            heights = { date = 60, clock = 50 }
            local s = function(px) return Layout.screen:scaleBySize(px) end
            local arranged = Layout.arrange(default, ctx(diner, 1264, 1680))
            local row = arranged.rows[1]
            assert.equals(s(40), row.slots[1].x)
            assert.equals(1264 - s(40), row.slots[2].x + row.slots[2].w)
            assert.equals(s(36), row.slots[1].y)
            assert.same({ x = 0, y = 0, w = 1264, h = s(36) + 60 + s(28) + s(4) }, arranged.header.band)
            arranged = Layout.arrange(default, ctx(editorial, 1264, 1680))
            row = arranged.rows[1]
            assert.equals(s(40), row.slots[1].x)
            assert.equals(s(44), row.slots[1].y)
            assert.is_nil(arranged.header.band)
            assert.same({ x = s(40), y = s(44) + 60 + s(22), w = 1264 - 2 * s(40), h = s(2) },
                arranged.header.rule)
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
                    local _, dropped = Layout.place(arranged.heights, 1680, home.margin, home.row_gap,
                        home.free_space, footer)
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
