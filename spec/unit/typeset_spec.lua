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
end)
