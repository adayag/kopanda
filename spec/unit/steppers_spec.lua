-- The steppers: each bar a label and value over a − / + pair, drawn into a body in the look's quick_settings
-- tokens, with an area for each − and +; a bar with a level draws its track between them.
describe("the steppers", function()
    local harness = require("plugin_harness")
    local Screen = require("device").screen
    local Looks, Steppers

    local CONTENT_W = 1000

    before_each(function()
        harness.load()
        Looks = require("looks")
        Steppers = require("steppers")
    end)

    after_each(function()
        harness.teardown()
    end)

    local function bctx_for(id)
        return { look = Looks.get(id), variant = "day", text_size = "medium", now = os.time(), screen = Screen }
    end

    -- A bar called id with a level from 0 to 10 at 4, its minus and plus taps and holds recorded in calls.
    local function bar(id, calls)
        local function record(what)
            return function()
                calls[#calls + 1] = id .. "_" .. what
            end
        end
        return {
            id = id,
            label = id,
            value_text = "4",
            level = { value = 4, min = 0, max = 10 },
            minus = { tap = record("minus_tap"), hold = record("minus_hold") },
            plus = { tap = record("plus_tap"), hold = record("plus_hold") },
        }
    end

    -- Draws bars into a fresh body under look id from y: the body, the y under them and the areas.
    local function draw(id, bars, y)
        local body = Steppers.Body:new{ fills = {}, places = {} }
        local under, areas = Steppers.draw(body, bctx_for(id), CONTENT_W, y or 0, bars)
        return body, under, areas
    end

    local function inside(rect, y_from, y_to)
        return rect.x >= 0 and rect.x + rect.w <= CONTENT_W and rect.w > 0 and rect.h > 0
            and rect.y >= y_from and rect.y + rect.h <= y_to
    end

    it("gives two bars four areas, minus then plus for each, inside the width, running their own actions", function()
        for _, id in ipairs(Looks.ids()) do
            local calls = {}
            local body, under, areas = draw(id, { bar("one", calls), bar("two", calls) }, 30)
            assert.same({ "one_minus", "one_plus", "two_minus", "two_plus" },
                { areas[1].id, areas[2].id, areas[3].id, areas[4].id }, id)
            assert.equals(4, #areas, id)
            for _, area in ipairs(areas) do
                assert.is_true(inside(area.rect, 30, under), id .. " " .. area.id)
                area.tap()
                area.hold()
            end
            assert.is_true(areas[1].rect.x < areas[2].rect.x, id)
            assert.is_true(areas[2].rect.y + areas[2].rect.h <= areas[3].rect.y, id)
            assert.same({ "one_minus_tap", "one_minus_hold", "one_plus_tap", "one_plus_hold",
                "two_minus_tap", "two_minus_hold", "two_plus_tap", "two_plus_hold" }, calls, id)
            body:free()
        end
    end)

    it("gives a greyed bar's minus and plus no tap and no hold", function()
        local greyed = bar("one", {})
        greyed.greyed = true
        local body, _, areas = draw("diner", { greyed })
        assert.equals(2, #areas)
        for _, area in ipairs(areas) do
            assert.is_nil(area.tap, area.id)
            assert.is_nil(area.hold, area.id)
        end
        body:free()
    end)

    -- The fills lying wholly between the minus's right edge and the plus's left edge, in their row.
    local function fills_between(body, areas)
        local minus, plus = areas[1].rect, areas[2].rect
        local n = 0
        for _, part in ipairs(body.fills) do
            if part.x >= minus.x + minus.w and part.x + part.w <= plus.x
                and part.y >= minus.y and part.y + part.h <= minus.y + minus.h then
                n = n + 1
            end
        end
        return n
    end

    it("draws the level's track between the buttons, and none for a bar without a level", function()
        for _, id in ipairs(Looks.ids()) do
            local body, _, areas = draw(id, { bar("one", {}) })
            assert.is_true(fills_between(body, areas) > 0, id)
            body:free()
            local bare = bar("one", {})
            bare.level = nil
            body, _, areas = draw(id, { bare })
            assert.equals(0, fills_between(body, areas), id)
            body:free()
        end
    end)

    describe("a bar with another beside it", function()
        -- Bar "one" with "two" beside it, then bar "three" at full width, drawn under look id from y 30.
        local function drawn(id, calls)
            local one = bar("one", calls)
            one.beside = bar("two", calls)
            return draw(id, { one, bar("three", calls) }, 30)
        end

        it("draws both in one row, the pair's areas in order, each running its own actions", function()
            for _, id in ipairs(Looks.ids()) do
                local calls = {}
                local body, under, areas = drawn(id, calls)
                local got = {}
                for i, area in ipairs(areas) do
                    got[i] = area.id
                    assert.is_true(inside(area.rect, 30, under), id .. " " .. area.id)
                    area.tap()
                end
                assert.same({ "one_minus", "one_plus", "two_minus", "two_plus", "three_minus", "three_plus" }, got, id)
                assert.same({ "one_minus_tap", "one_plus_tap", "two_minus_tap", "two_plus_tap", "three_minus_tap",
                    "three_plus_tap" }, calls, id)
                assert.equals(areas[1].rect.y, areas[4].rect.y, id)
                assert.is_true(areas[4].rect.y + areas[4].rect.h <= areas[5].rect.y, id)
                body:free()
            end
        end)

        it("is as tall as one bar", function()
            for _, id in ipairs(Looks.ids()) do
                local single = bar("one", {})
                local paired = bar("one", {})
                paired.beside = bar("two", {})
                local body, single_under = draw(id, { single })
                body:free()
                local other, paired_under = draw(id, { paired })
                other:free()
                assert.equals(single_under, paired_under, id)
            end
        end)

        it("splits the row's width into two halves at the look's pair gap, nothing in the gap", function()
            for _, id in ipairs(Looks.ids()) do
                local body, _, areas = drawn(id, {})
                local gap = Screen:scaleBySize(Looks.get(id).quick_settings.pair_gap)
                local left = areas[2].rect.x + areas[2].rect.w
                local right = areas[3].rect.x
                assert.equals(gap, right - left, id)
                assert.equals(areas[5].rect.x, areas[1].rect.x, id)
                assert.is_true(areas[6].rect.x + areas[6].rect.w - (areas[4].rect.x + areas[4].rect.w) <= 1, id)
                assert.equals(left - areas[1].rect.x, areas[4].rect.x + areas[4].rect.w - right, id)
                local row_top, row_bottom = areas[1].rect.y, areas[5].rect.y
                for i, widget in ipairs(body) do
                    local at, w = body.places[i], widget:getSize().w
                    if at.y >= 30 and at.y < row_bottom and at.y < row_top + areas[1].rect.h then
                        assert.is_true(at.x + w <= left or at.x >= right, id .. " a line in the gap")
                    end
                end
                body:free()
            end
        end)

        it("draws each bar's track between its own buttons", function()
            local body, _, areas = drawn("editorial", {})
            assert.is_true(fills_between(body, { areas[1], areas[2] }) > 0)
            assert.is_true(fills_between(body, { areas[3], areas[4] }) > 0)
            body:free()
        end)

        it("keeps a greyed bar inert beside a live one", function()
            local one = bar("one", {})
            one.greyed = true
            one.beside = bar("two", {})
            local body, _, areas = draw("diner", { one })
            assert.is_nil(areas[1].tap)
            assert.is_nil(areas[2].tap)
            assert.is_function(areas[3].tap)
            assert.is_function(areas[4].tap)
            body:free()
        end)
    end)

    -- Draws cells into a fresh body under look id from y: the body, the y under them and their rects.
    local function draw_cells(id, cells, y)
        local body = Steppers.Body:new{ fills = {}, places = {} }
        local under, rects = Steppers.cells(body, bctx_for(id), CONTENT_W, y or 0, cells)
        return body, under, rects
    end

    it("lays a row of cells side by side across the inner width, one row tall", function()
        for _, id in ipairs(Looks.ids()) do
            local pad_x = Screen:scaleBySize(Looks.get(id).quick_settings.padding_x)
            local cells = {
                { label = "Night", icon = "moon" },
                { label = "Bookmark", icon = "bookmark", on = true },
                { label = "Contents", icon = "list" },
            }
            local body, under, rects = draw_cells(id, cells, 40)
            assert.equals(3, #rects, id)
            assert.equals(pad_x, rects[1].x, id)
            assert.equals(CONTENT_W - pad_x, rects[3].x + rects[3].w, id)
            for i, rect in ipairs(rects) do
                assert.equals(40, rect.y, id)
                assert.equals(under - 40, rect.h, id)
                if i > 1 then
                    assert.is_true(rects[i - 1].x + rects[i - 1].w < rect.x, id)
                end
            end
            body:free()
            body, _, rects = draw_cells(id, { { label = "Home", icon = "home" } })
            assert.equals(1, #rects, id)
            assert.equals(pad_x, rects[1].x, id)
            assert.equals(CONTENT_W - 2 * pad_x, rects[1].w, id)
            body:free()
        end
    end)
end)
