-- The sheet's text block: a spec's paragraphs wrapped under the header and above the rows, the block at most 60% of the
-- screen with its end ellipsised, every paragraph keeping a line; the row still on screen at Extra large on the
-- Paperwhite 7th gen, either way up, in every look; and each paragraph freed with the panel.
describe("the sheet's text block", function()
    local harness = require("plugin_harness")
    local Screen = require("device").screen
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local fixture = require("sheet_fixture")
    local Looks, SheetLayout

    setup(function()
        harness.load()
        Looks = package.loaded["looks"]
        SheetLayout = require("sheet_layout")
    end)

    teardown(function()
        harness.teardown()
    end)

    local LONG = ("It was the best of times, it was the worst of times, it was the age of wisdom. "):rep(120)

    local function ctx_for(id, text_size)
        return { look = Looks.get(id), variant = "day", text_size = text_size, screen = Screen }
    end

    local function spec_with(text)
        return {
            name = "test",
            header = { heading = "Chapter", aside = "Page 3", aside_above = true, label = "Bookmarks" },
            text = text,
            rows = { { label = "Remove highlight", run = function() end } },
            flush = true,
        }
    end

    -- The block laid out in laid: its widget and place.
    local function block_of(laid)
        for i, widget in ipairs(laid.widget) do
            if getmetatable(widget) == VerticalGroup then
                return widget, laid.widget.places[i]
            end
        end
    end

    -- The TextBoxWidgets of block, on a plate or not, in order.
    local function boxes_of(block)
        local out = {}
        for _, widget in ipairs(block) do
            local box = getmetatable(widget) == TextBoxWidget and widget or widget[1]
            if box and getmetatable(box) == TextBoxWidget then
                out[#out + 1] = box
            end
        end
        return out
    end

    local function ellipsised(box)
        return box.line_with_ellipsis ~= nil
    end

    it("sets its paragraphs in order between the header and the rows, at the heading's left, in every look", function()
        for _, id in ipairs(Looks.ids()) do
            local laid = SheetLayout.build(spec_with({ { part = "quote", text = "It was the best" },
                { part = "book_description", text = "Dickens" } }), ctx_for(id), "day")
            local block, place = block_of(laid)
            assert.is_not_nil(block, id)
            local boxes = boxes_of(block)
            assert.same({ "It was the best", "Dickens" }, { boxes[1].text, boxes[2].text }, id)
            assert.is_false(ellipsised(boxes[1]), id)
            assert.is_false(ellipsised(boxes[2]), id)
            assert.equals(laid.header_parts.heading.x, place.x, id)
            assert.is_true(place.y >= laid.header.y + laid.header.h, id)
            assert.is_true(place.y + block:getSize().h <= laid.rows[1].rect.y, id)
            laid.widget:free()
        end
    end)

    it("paints its text in every look, by night too", function()
        for _, variant in ipairs({ "day", "night" }) do
            for _, id in ipairs(Looks.ids()) do
                local ctx = ctx_for(id)
                ctx.variant = variant
                local spec = spec_with({ { part = "quote", text = "It was the best" } })
                local laid = SheetLayout.build(spec, ctx, variant)
                local block, place = block_of(laid)
                local size = Screen:getSize()
                local bb = fixture.buffer(size.w, size.h)
                laid.widget:paintTo(bb, 0, 0)
                local palette = Looks.palette(Looks.get(id), variant)
                local paper = fixture.rgb(palette.paper)
                local inked = false
                fixture.each_pixel(bb, { x = place.x, y = place.y, w = block:getSize().w, h = block:getSize().h },
                    function(rgb)
                        inked = inked or not fixture.near(paper, rgb, 40)
                    end)
                assert.is_true(inked, id .. " " .. variant)
                bb:free()
                laid.widget:free()
            end
        end
    end)

    it("wraps a paragraph to the lines it needs, its breaks kept", function()
        local laid = SheetLayout.build(spec_with({ { part = "book_description", text = "One\nTwo\nThree" } }),
            ctx_for("editorial"), "day")
        local box = boxes_of(block_of(laid))[1]
        assert.equals(3, #box.vertical_string_list)
        assert.equals(3 * box.line_height_px, box:getSize().h)
        laid.widget:free()
    end)

    it("stops at 60% of the screen, within a line of it, its end ellipsised", function()
        for _, id in ipairs(Looks.ids()) do
            local laid = SheetLayout.build(spec_with({ { part = "quote", text = LONG } }), ctx_for(id), "day")
            local block = block_of(laid)
            local box = boxes_of(block)[1]
            local cap = math.floor(Screen:getSize().h * 0.6)
            assert.is_true(block:getSize().h <= cap, id)
            assert.is_true(block:getSize().h > cap - box.line_height_px, id)
            assert.is_true(ellipsised(box), id)
            laid.widget:free()
        end
    end)

    it("keeps a line for the note under a highlight that fills the block, every end ellipsised", function()
        local laid = SheetLayout.build(spec_with({ { part = "quote", text = LONG },
            { part = "book_description", text = LONG } }), ctx_for("editorial"), "day")
        local block = block_of(laid)
        local boxes = boxes_of(block)
        assert.equals(2, #boxes)
        assert.is_true(ellipsised(boxes[1]))
        assert.is_true(ellipsised(boxes[2]))
        assert.equals(boxes[2].line_height_px, boxes[2]:getSize().h)
        assert.is_true(block:getSize().h <= math.floor(Screen:getSize().h * 0.6))
        laid.widget:free()
    end)

    it("gives a short highlight's note the room left", function()
        local laid = SheetLayout.build(spec_with({ { part = "quote", text = "Short" },
            { part = "book_description", text = LONG } }), ctx_for("editorial"), "day")
        local block = block_of(laid)
        local boxes = boxes_of(block)
        local cap = math.floor(Screen:getSize().h * 0.6)
        assert.is_false(ellipsised(boxes[1]))
        assert.is_true(ellipsised(boxes[2]))
        assert.is_true(block:getSize().h <= cap)
        assert.is_true(block:getSize().h > cap - boxes[2].line_height_px)
        laid.widget:free()
    end)

    it("leaves the row on the screen at Extra large on the Paperwhite 7th gen, either way up, in every look", function()
        for _, screen in ipairs({ { 1072, 1448 }, { 1448, 1072 } }) do
            harness.at_screen(screen[1], screen[2], function()
                for _, id in ipairs(Looks.ids()) do
                    local where = id .. " " .. screen[1]
                    local laid = SheetLayout.build(spec_with({ { part = "quote", text = LONG },
                        { part = "book_description", text = LONG } }), ctx_for(id, "extra_large"), "day")
                    assert.equals(1, #laid.rows, where)
                    assert.equals(0, laid.left_out, where)
                    assert.is_true(laid.panel.y >= 0, where)
                    local row = laid.rows[1].rect
                    assert.is_true(row.y + row.h <= screen[2], where)
                    assert.is_true(block_of(laid):getSize().h <= math.floor(screen[2] * 0.6), where)
                    laid.widget:free()
                end
            end)
        end
    end)

    it("frees each paragraph with the panel, in every look", function()
        local free = TextBoxWidget.free
        local freed = {}
        TextBoxWidget.free = function(self, ...)
            freed[self] = true
            return free(self, ...)
        end
        local ok, err = pcall(function()
            for _, id in ipairs(Looks.ids()) do
                local laid = SheetLayout.build(spec_with({ { part = "quote", text = "It was" },
                    { part = "book_description", text = "Dickens" } }), ctx_for(id), "day")
                local boxes = boxes_of(block_of(laid))
                assert.equals(2, #boxes, id)
                laid.widget:free()
                assert.is_true(freed[boxes[1]] and freed[boxes[2]], id)
            end
        end)
        TextBoxWidget.free = free
        assert(ok, err)
    end)
end)
