-- The Go to screen's rows: a chapter row indented by its depth with its page at the right, its title right of the
-- toggle column in a nested list, a parent's toggle in it; the current one a line taller with "You are here" under its
-- title; and a bookmark row, its chapter at the left and its page at the right; each row as tall as GotoRows.height
-- says, and nothing past the row's width at Extra large on the Paperwhite 7th gen, in every look.
describe("the Go to rows", function()
    local harness = require("plugin_harness")
    local Screen = require("device").screen
    local text_of = require("library_fixture").text
    local GotoRows, Looks

    setup(function()
        harness.load()
        GotoRows = require("goto_rows")
        Looks = package.loaded["looks"]
    end)

    teardown(function()
        harness.teardown()
    end)

    local function ctx_for(id, text_size)
        return { look = Looks.get(id), variant = "day", text_size = text_size, screen = Screen }
    end

    local function chapter(title, depth, page_label)
        return { title = title, depth = depth, page_label = tostring(page_label), index = 1 }
    end

    local LONG = "The Very Long Chapter Title That Keeps Going Past Any Screen Width Whatever The Text Size Is"

    -- Every child's text in row, lower-cased, in order.
    local function texts(row)
        local out = {}
        for _, child in ipairs(row) do
            local text = text_of(child)
            if text then
                out[#out + 1] = text:lower()
            end
        end
        return out
    end

    -- The place of row's child whose text is text, in any case.
    local function place_of(row, text)
        for i, child in ipairs(row) do
            local own = text_of(child)
            if own and own:lower() == text:lower() then
                return row.places[i], child
            end
        end
    end

    it("starts a depth-2 title two indent steps right of a depth-0 title", function()
        local ctx = ctx_for("editorial")
        local top = GotoRows.chapter(chapter("One", 0, 3), false, 800, ctx)
        local deep = GotoRows.chapter(chapter("Two", 2, 9), false, 800, ctx)
        local step = Screen:scaleBySize(ctx.look.shelf.list.side)
        assert.equals(place_of(top, "One").x + 2 * step, place_of(deep, "Two").x)
        top:free()
        deep:free()
    end)

    it("puts the page at the right and the title at the left", function()
        local ctx = ctx_for("editorial")
        local row = GotoRows.chapter(chapter("One", 0, 123), false, 800, ctx)
        local page_place, page = place_of(row, "123")
        assert.is_not_nil(page)
        local pad = Screen:scaleBySize(ctx.look.shelf.author.padding.x)
        assert.equals(800 - pad, page_place.x + page:getSize().w)
        assert.equals(pad, place_of(row, "One").x)
        row:free()
    end)

    -- row's toggle icon: the child drawn from an icon file, and its place.
    local function toggle_of(row)
        for i, child in ipairs(row) do
            if child.file then
                return child, row.places[i]
            end
        end
    end

    it("draws a parent's toggle in the toggle column after its indent, closed or open, and none on a leaf", function()
        local Icons = package.loaded["icons"]
        for _, id in ipairs(Looks.ids()) do
            local ctx = ctx_for(id)
            local column = GotoRows.toggle_width(ctx)
            assert.is_true(column >= GotoRows.height("chapter", true, ctx), id)
            local indent = Screen:scaleBySize(ctx.look.shelf.list.side)
            local pad = Screen:scaleBySize(ctx.look.shelf.author.padding.x)
            local parent = chapter("One", 1, 3)
            parent.has_children = true
            local closed = GotoRows.chapter(parent, false, 800, ctx, true, false)
            local open = GotoRows.chapter(parent, true, 800, ctx, true, true)
            local leaf = GotoRows.chapter(chapter("Two", 1, 9), false, 800, ctx, true, false)
            assert.is_nil(toggle_of(leaf), id)
            for _, case in ipairs({ { closed, "forward" }, { open, "chevron_down" } }) do
                local icon, place = toggle_of(case[1])
                assert.is_not_nil(icon, id)
                assert.equals(Icons.path(case[2]), icon.file, id)
                assert.is_true(place.x >= indent and place.x + icon:getSize().w <= indent + column, id)
                assert.is_true(place.x + icon:getSize().w <= place_of(case[1], "One").x, id)
            end
            assert.is_true(place_of(closed, "One").x >= indent + column, id)
            assert.equals(place_of(closed, "One").x, place_of(leaf, "Two").x, id)
            local page_place, page = place_of(closed, "3")
            local leaf_place, leaf_page = place_of(leaf, "9")
            assert.equals(800 - pad, page_place.x + page:getSize().w, id)
            assert.equals(800 - pad, leaf_place.x + leaf_page:getSize().w, id)
            closed:free()
            open:free()
            leaf:free()
        end
    end)

    it("makes the current row taller, with you are here under its title", function()
        for _, id in ipairs(Looks.ids()) do
            local ctx = ctx_for(id)
            local plain, plain_h = GotoRows.chapter(chapter("One", 1, 3), false, 800, ctx)
            local here, here_h = GotoRows.chapter(chapter("One", 1, 3), true, 800, ctx)
            assert.is_true(here_h > plain_h, id)
            assert.equals(plain_h, GotoRows.height("chapter", false, ctx), id)
            assert.equals(here_h, GotoRows.height("chapter", true, ctx), id)
            assert.equals(plain_h, plain:getSize().h, id)
            assert.equals(here_h, here:getSize().h, id)
            assert.is_falsy(table.concat(texts(plain), "|"):find("you are here", 1, true), id)
            local found
            for _, text in ipairs(texts(here)) do
                found = found or text == "you are here"
            end
            assert.is_true(found, id)
            local title_place = place_of(here, "One")
            local note_place = place_of(here, "You are here")
            assert.equals(title_place.x, note_place.x, id)
            assert.is_true(note_place.y > title_place.y, id)
            plain:free()
            here:free()
        end
    end)

    it("draws a bookmark's chapter at the left and its page at the right, one line", function()
        local ctx = ctx_for("diner")
        local row, h = GotoRows.bookmark({ chapter = "Letter 1", page_label = "12" }, 800, ctx)
        assert.same({ "letter 1", "12" }, texts(row))
        assert.equals(GotoRows.height("bookmark", false, ctx), h)
        assert.equals(GotoRows.height("chapter", false, ctx), h)
        row:free()
    end)

    it("keeps every text inside the row at Extra large on the Paperwhite 7th gen, in every look", function()
        harness.at_screen(1072, 1448, function()
            for _, id in ipairs(Looks.ids()) do
                local ctx = ctx_for(id, "extra_large")
                local width = 1072 - 2 * Screen:scaleBySize(ctx.look.shelf.list.side)
                local parent = chapter(LONG, 2, 1234)
                parent.has_children = true
                local rows = {
                    GotoRows.chapter(chapter(LONG, 0, 1234), false, width, ctx),
                    GotoRows.chapter(chapter(LONG, 2, 1234), true, width, ctx),
                    (GotoRows.bookmark({ chapter = LONG, page_label = "1234" }, width, ctx)),
                    GotoRows.chapter(parent, false, width, ctx, true, false),
                    GotoRows.chapter(parent, true, width, ctx, true, true),
                    (GotoRows.chapter(chapter(LONG, 2, 1234), true, width, ctx, true, false)),
                }
                for n, row in ipairs(rows) do
                    for i, child in ipairs(row) do
                        local place, size = row.places[i], child:getSize()
                        assert.is_true(place.x >= 0 and place.x + size.w <= width,
                            id .. " row " .. n .. " child " .. i .. " runs past the row")
                        assert.is_true(place.y >= 0 and place.y + size.h <= row:getSize().h,
                            id .. " row " .. n .. " child " .. i .. " runs below the row")
                    end
                    row:free()
                end
            end
        end)
    end)
end)
