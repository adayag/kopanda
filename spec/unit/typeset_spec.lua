describe("typeset", function()
    local harness = require("plugin_harness")
    local Screen = require("device").screen
    local Looks, TextWidget, Typeset

    before_each(function()
        harness.load()
        TextWidget = require("ui/widget/textwidget")
        Looks = package.loaded["looks"]
        Typeset = package.loaded["typeset"]
    end)

    after_each(function()
        harness.teardown()
    end)

    local function ctx_for(look_id)
        return { look = Looks.get(look_id), variant = "day", text_size = "medium", screen = Screen }
    end

    -- TextWidget:paintTo measures first (frontend/ui/widget/textwidget.lua:339), but a patch that
    -- replaces it may not: Bookends' bookends_textwidget_patch.lua draws a colour fgcolor's
    -- glyphs from _xtext straight away, so a line painted before it was ever measured has
    -- nothing to shape. A line from Typeset.line is measured when it is made.
    -- Every TextWidget a line holds: the line itself, or each character of a tracked group.
    local function text_widgets(line)
        if getmetatable(line) == TextWidget then
            return { line }
        end
        local found = {}
        for _, child in ipairs(line) do
            if getmetatable(child) == TextWidget then
                found[#found + 1] = child
            end
        end
        return found
    end

    local Blitbuffer = require("ffi/blitbuffer")

    local function rgb(hex)
        local c = Looks.color(hex)
        return { c:getR(), c:getG(), c:getB() }
    end

    -- line painted at (0, 0) on a buffer of its size filled with paper; the caller frees it.
    local function painted(line, paper)
        local size = line:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, size.w, size.h, Looks.color(paper))
        line:paintTo(bb, 0, 0)
        return bb
    end

    -- The pixels of bb exactly color ({ r, g, b }): their count and the bounding box of them.
    local function extent(bb, color)
        local count, x0, y0, x1, y1 = 0, math.huge, math.huge, -1, -1
        for y = 0, bb:getHeight() - 1 do
            for x = 0, bb:getWidth() - 1 do
                local c = bb:getPixel(x, y):getColorRGB32()
                if c:getR() == color[1] and c:getG() == color[2] and c:getB() == color[3] then
                    count = count + 1
                    x0, y0 = math.min(x0, x), math.min(y0, y)
                    x1, y1 = math.max(x1, x), math.max(y1, y)
                end
            end
        end
        return { count = count, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    end

    -- Whether KOReader colours a and b have the same red, green and blue.
    local function same_rgb(a, b)
        local x, y = a:getColorRGB32(), b:getColorRGB32()
        return x.r == y.r and x.g == y.g and x.b == y.b
    end

    -- look with its misregistration replaced, the rest shared.
    local function with_misregister(look, misregister)
        return setmetatable({ misregister = misregister }, { __index = look })
    end

    -- riso.md: display type printed twice, the pink 3 right and 2 down under the ink.
    describe("a misregistered look", function()
        it("prints a display part twice, the offset copy in the token's colour under the part's own", function()
            local ctx = ctx_for("riso")
            local palette = ctx.look.palettes.day
            local part = ctx.look.type.clock
            local line = Typeset.line(part, "8:42", Screen:getWidth(), ctx)
            local plain_ctx = { look = with_misregister(ctx.look, { x = 0, y = 0, color = false }),
                variant = "day", text_size = "medium", screen = Screen }
            local plain = Typeset.line(part, "8:42", Screen:getWidth(), plain_ctx)
            local dx, dy = Screen:scaleBySize(3), Screen:scaleBySize(2)
            assert.same({ plain:getSize().w + dx, plain:getSize().h + dy }, { line:getSize().w, line:getSize().h })
            assert.equals(Typeset.baseline(plain), Typeset.baseline(line))
            local bb = painted(line, palette.paper)
            local ink, pink = extent(bb, rgb(palette.ink)), extent(bb, rgb(palette.pink))
            assert.truthy(ink.count > 100, "ink pixels: " .. ink.count)
            assert.truthy(pink.count > 0, "pink pixels: " .. pink.count)
            -- The pink copy shows past the ink on the right and below, and the ink is on top of it.
            -- (within a pixel: the ink's anti-aliased edge blends over the pink beneath it)
            assert.truthy(math.abs(ink.x1 + dx - pink.x1) <= 1, ink.x1 .. " + " .. dx .. " against " .. pink.x1)
            assert.truthy(math.abs(ink.y1 + dy - pink.y1) <= 1, ink.y1 .. " + " .. dy .. " against " .. pink.y1)
            assert.truthy(pink.x0 >= dx, "pink starts at " .. pink.x0)
            -- The ink copy is on top and whole: as many ink pixels as with the pink copy far below it.
            local apart_ctx = { look = with_misregister(ctx.look, { x = 0, y = 400, color = "pink" }),
                variant = "day", text_size = "medium", screen = Screen }
            local apart = Typeset.line(part, "8:42", Screen:getWidth(), apart_ctx)
            local reference = painted(apart, palette.paper)
            -- (to 1 %: where neighbouring glyphs' anti-aliased edges meet, they blend over the pink)
            local whole = extent(reference, rgb(palette.ink)).count
            assert.truthy(ink.count >= 0.99 * whole, ink.count .. " ink pixels against " .. whole)
            apart:free()
            bb:free()
            reference:free()
            line:free()
            plain:free()
        end)

        -- bb holds a misregistered print and reference the same print with its offset copy far
        -- away: the pink copy shows past the ink by the offset, right and below, and the ink is on
        -- top and whole (to 1 %: where the ink's anti-aliased edges meet the pink, they blend).
        local function assert_pink_under_ink(bb, reference, palette, dx, dy)
            local ink, pink = extent(bb, rgb(palette.ink)), extent(bb, rgb(palette.pink))
            assert.truthy(ink.count > 100, "ink pixels: " .. ink.count)
            assert.truthy(pink.count > 0, "pink pixels: " .. pink.count)
            assert.truthy(math.abs(ink.x1 + dx - pink.x1) <= 1, ink.x1 .. " + " .. dx .. " against " .. pink.x1)
            assert.truthy(math.abs(ink.y1 + dy - pink.y1) <= 1, ink.y1 .. " + " .. dy .. " against " .. pink.y1)
            assert.truthy(pink.x0 >= ink.x0 + dx - 1, "pink starts at x " .. pink.x0 .. ", ink at " .. ink.x0)
            assert.truthy(pink.y0 >= ink.y0 + dy - 1, "pink starts at y " .. pink.y0 .. ", ink at " .. ink.y0)
            local whole = extent(reference, rgb(palette.ink)).count
            assert.truthy(ink.count >= 0.99 * whole, ink.count .. " ink pixels against " .. whole)
        end

        it("prints an untracked display line twice, the offset copy under the ink", function()
            local ctx = ctx_for("riso")
            local palette = ctx.look.palettes.day
            local part = ctx.look.type.sheet_title
            assert.equals(0, part.tracking)
            local line = Typeset.line(part, "Frankenstein", Screen:getWidth(), ctx)
            assert.equals(TextWidget, getmetatable(line))
            local plain_ctx = { look = with_misregister(ctx.look, { x = 0, y = 0, color = false }),
                variant = "day", text_size = "medium", screen = Screen }
            local plain = Typeset.line(part, "Frankenstein", Screen:getWidth(), plain_ctx)
            local dx, dy = Screen:scaleBySize(3), Screen:scaleBySize(2)
            assert.same({ plain:getSize().w + dx, plain:getSize().h + dy }, { line:getSize().w, line:getSize().h })
            local apart_ctx = { look = with_misregister(ctx.look, { x = 0, y = 400, color = "pink" }),
                variant = "day", text_size = "medium", screen = Screen }
            local apart = Typeset.line(part, "Frankenstein", Screen:getWidth(), apart_ctx)
            local bb, reference = painted(line, palette.paper), painted(apart, palette.paper)
            assert_pink_under_ink(bb, reference, palette, dx, dy)
            bb:free()
            reference:free()
            apart:free()
            line:free()
            plain:free()
        end)

        describe("a text box", function()
            local Font = require("ui/font")
            local TextBoxWidget = require("ui/widget/textboxwidget")

            -- Typeset.printed's make for a TextBoxWidget of text, keeping each box it makes and the
            -- colours it was asked for in made.
            local function box_maker(text, made)
                return function(width, fgcolor, bgcolor)
                    local box = TextBoxWidget:new{
                        text = text,
                        face = Font:getFace("cfont", 40),
                        width = width,
                        fgcolor = fgcolor,
                        bgcolor = bgcolor,
                    }
                    made[#made + 1] = { box = box, width = width, fgcolor = fgcolor, bgcolor = bgcolor }
                    return box
                end
            end

            it("prints a misregistered part twice through a mask, freed once with the widget", function()
                local ctx = ctx_for("riso")
                local palette = ctx.look.palettes.day
                local part = ctx.look.type.featured_title
                local made = {}
                local printed = Typeset.printed(part, 600, ctx, box_maker("Frankenstein", made))
                assert.equals(1, #made)
                local dx, dy = Screen:scaleBySize(3), Screen:scaleBySize(2)
                assert.equals(600 - dx, made[1].width)
                local box = made[1].box:getSize()
                assert.same({ box.w + dx, box.h + dy }, { printed:getSize().w, printed:getSize().h })
                local apart_ctx = { look = with_misregister(ctx.look, { x = 0, y = 400, color = "pink" }),
                    variant = "day", text_size = "medium", screen = Screen }
                local apart = Typeset.printed(part, 600, apart_ctx, box_maker("Frankenstein", {}))
                local bb, reference = painted(printed, palette.paper), painted(apart, palette.paper)
                assert_pink_under_ink(bb, reference, palette, dx, dy)
                assert.is_not_nil(printed.mask)
                local mask, frees = printed.mask, 0
                printed.mask = {
                    free = function()
                        frees = frees + 1
                        mask:free()
                    end,
                }
                printed:free()
                printed:free()
                assert.equals(1, frees)
                assert.is_nil(printed.mask)
                bb:free()
                reference:free()
                apart:free()
            end)

            it("makes a part of a look with no misregistration in its colour on paper, printed once", function()
                local ctx = ctx_for("diner")
                local palette = ctx.look.palettes.day
                local part = ctx.look.type.featured_title
                local made = {}
                local printed = Typeset.printed(part, 600, ctx, box_maker("Frankenstein", made))
                assert.equals(1, #made)
                assert.equals(made[1].box, printed)
                assert.equals(600, made[1].width)
                assert.is_true(same_rgb(Looks.color(palette[part.color]), made[1].fgcolor))
                assert.is_true(same_rgb(Looks.color(palette.paper), made[1].bgcolor))
                printed:free()
            end)
        end)

        it("prints a part in another face once", function()
            local ctx = ctx_for("riso")
            local palette = ctx.look.palettes.day
            local line = Typeset.line(ctx.look.type.date, "October 13", Screen:getWidth(), ctx)
            assert.is_nil(line.misregistration)
            local bb = painted(line, palette.paper)
            assert.equals(0, extent(bb, rgb(palette.pink)).count)
            assert.truthy(extent(bb, rgb(palette.ink)).count > 0)
            bb:free()
            line:free()
        end)

        it("prints in the grey palette's colour of the role in grey", function()
            local ctx = ctx_for("riso")
            ctx.variant = "grey"
            local palette = ctx.look.palettes.grey
            local line = Typeset.line(ctx.look.type.clock, "8", Screen:getWidth(), ctx)
            local bb = painted(line, palette.paper)
            assert.truthy(extent(bb, rgb(palette.pink)).count > 0)
            assert.truthy(extent(bb, rgb(palette.ink)).count > 0)
            bb:free()
            line:free()
        end)
    end)

    -- TextWidget paints its glyphs through colorblitFrom (frontend/ui/widget/textwidget.lua:369),
    -- which takes a colour's luminance grey (getColor8A, base/ffi/blitbuffer.lua:1405-1407, :489-491).
    describe("the colour of a line", function()
        it("paints a line in a chromatic ink in that colour, not its grey, on every look", function()
            for _, look_id in ipairs(Looks.ids()) do
                local ctx = ctx_for(look_id)
                local look = setmetatable({ palettes = { day = setmetatable({ ink = "#22509f" },
                    { __index = ctx.look.palettes.day }) } }, { __index = ctx.look })
                ctx.look = look
                local blue = { 0x22, 0x50, 0x9f }
                for _, name in ipairs({ "featured_label", "date", "sheet_row" }) do
                    local part = setmetatable({ color = "ink", size = 40 }, { __index = look.type[name] })
                    local line = Typeset.line(part, "Library", Screen:getWidth(), ctx)
                    local bb = painted(line, look.palettes.day.paper)
                    assert.truthy(extent(bb, blue).count > 0, look_id .. " " .. name .. ": no pixel in the ink")
                    local c = Looks.color("#22509f"):getColor8()
                    assert.equals(0, extent(bb, { c.a, c.a, c.a }).count, look_id .. " " .. name .. ": greyed")
                    bb:free()
                    line:free()
                end
            end
        end)

        it("paints a line in the grey palette's grey on a grey buffer", function()
            local ctx = ctx_for("riso")
            ctx.variant = "grey"
            local palette = ctx.look.palettes.grey
            local line = Typeset.line(ctx.look.type.featured_label, "Library", Screen:getWidth(), ctx)
            local size = line:getSize()
            local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BB8)
            bb:fill(Blitbuffer.COLOR_WHITE)
            line:paintTo(bb, 0, 0)
            local want = Looks.color(palette[ctx.look.type.featured_label.color]):getColor8().a
            local found = 0
            for y = 0, size.h - 1 do
                for x = 0, size.w - 1 do
                    if bb:getPixel(x, y):getColor8().a == want then
                        found = found + 1
                    end
                end
            end
            assert.truthy(found > 0)
            bb:free()
            line:free()
        end)
    end)

    -- Typeset.paint_glyphs reads TextWidget's private fields, which a KOReader other than the
    -- pinned build may not have: a failing paint falls back to TextWidget:paintTo's grey.
    describe("a paint that fails", function()
        local logger = require("logger")

        it("paints a line in its colour's grey, warning once, when its glyph paint raises", function()
            local ctx = ctx_for("diner")
            ctx.look = setmetatable({ palettes = { day = setmetatable({ ink = "#22509f" },
                { __index = ctx.look.palettes.day }) } }, { __index = ctx.look })
            local part = setmetatable({ color = "ink", size = 40, tracking = 0 }, { __index = ctx.look.type.date })
            local line = Typeset.line(part, "Library", Screen:getWidth(), ctx)
            assert.equals(TextWidget, getmetatable(line))
            local fgcolor = line.fgcolor
            local paint_glyphs, warn = Typeset.paint_glyphs, logger.warn
            local warned = 0
            Typeset.paint_glyphs = function()
                error("a TextWidget internal moved")
            end
            logger.warn = function()
                warned = warned + 1
            end
            finally(function()
                Typeset.paint_glyphs, logger.warn = paint_glyphs, warn
            end)
            local bb = painted(line, "#ffffff")
            line:paintTo(bb, 0, 0)
            local c = Looks.color("#22509f"):getColor8()
            assert.truthy(extent(bb, { c.a, c.a, c.a }).count > 0, "no pixel in the colour's grey")
            assert.equals(1, warned)
            assert.equals(fgcolor, line.fgcolor)
            bb:free()
            line:free()
        end)

        it("clears a tracked line's offset colour and prints its ink when the offset pass raises", function()
            local ctx = ctx_for("riso")
            local palette = ctx.look.palettes.day
            local part = ctx.look.type.clock
            local line = Typeset.line(part, "8:42", Screen:getWidth(), ctx)
            assert.is_not_equal(TextWidget, getmetatable(line), "the clock is tracked")
            local pink = line.misregistration.color
            local paint_glyphs, paint_to, warn = Typeset.paint_glyphs, TextWidget.paintTo, logger.warn
            -- The offset pass fails all the way down: its glyph paint and TextWidget:paintTo both.
            Typeset.paint_glyphs = function(text, bb, x, y, color)
                if same_rgb(color, pink) then
                    error("the offset pass failed")
                end
                return paint_glyphs(text, bb, x, y, color)
            end
            TextWidget.paintTo = function(self, bb, x, y)
                if same_rgb(self.fgcolor, pink) then
                    error("the offset pass failed")
                end
                return paint_to(self, bb, x, y)
            end
            logger.warn = function() end
            finally(function()
                Typeset.paint_glyphs, TextWidget.paintTo, logger.warn = paint_glyphs, paint_to, warn
            end)
            local ok, bb = pcall(painted, line, palette.paper)
            for _, child in ipairs(text_widgets(line)) do
                assert.is_nil(child.print_color)
                assert.is_true(same_rgb(Looks.color(palette[part.color]), child.fgcolor))
            end
            assert.is_true(ok, tostring(bb))
            assert.truthy(extent(bb, rgb(palette.ink)).count > 100, "the ink pass painted")
            assert.equals(0, extent(bb, rgb(palette.pink)).count)
            bb:free()
            line:free()
        end)
    end)

    it("prints every part once for a look whose misregistration has no colour", function()
        for _, look_id in ipairs({ "diner", "editorial" }) do
            local ctx = ctx_for(look_id)
            local line = Typeset.line(ctx.look.type.featured_title, "Frankenstein", Screen:getWidth(), ctx)
            assert.is_nil(line.misregistration, look_id)
            assert.same(TextWidget.getSize(line), line:getSize(), look_id)
            line:free()
        end
    end)

    it("measures a line's text when it is made, so a paint that skips updateSize finds it", function()
        for _, look_id in ipairs({ "diner", "editorial" }) do
            local ctx = ctx_for(look_id)
            local plain = Typeset.line(ctx.look.type.quote, "Library", Screen:getWidth(), ctx)
            local tracked = Typeset.line(ctx.look.type.stats, "Library", Screen:getWidth(), ctx)
            assert.equals(TextWidget, getmetatable(plain), look_id .. ": the quote part is a plain line")
            assert.is_not_equal(TextWidget, getmetatable(tracked), look_id .. ": the stats part is tracked")
            for _, line in ipairs({ plain, tracked }) do
                local widgets = text_widgets(line)
                assert.is_true(#widgets > 0)
                for _, widget in ipairs(widgets) do
                    assert.is_true(widget._updated == true, look_id .. ": measured")
                    if widget.use_xtext then
                        assert.is_not_nil(widget._xtext, look_id .. ": shaped text")
                    end
                end
                line:free()
            end
        end
    end)

    it("measures a part's line height as its face's, whatever the text", function()
        for _, look_id in ipairs({ "diner", "editorial" }) do
            local ctx = ctx_for(look_id)
            local part = ctx.look.type.library_count
            local line = Typeset.line(part, "gjÅ", math.huge, ctx)
            assert.equals(line:getSize().h, Typeset.line_height(part, ctx), look_id)
            line:free()
        end
    end)
end)
