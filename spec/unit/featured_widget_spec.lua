-- The featured widget (C6): the cover box and the text column in each look, its size, the
-- caption's wording, the progress bar, the first run and the tap. FeaturedBook.current is
-- stubbed per case; bookinfomanager is unrequirable, so the cover box draws its placeholder;
-- FileManager.instance and Home.close are replaced by recorders. Each case restores them.
describe("the featured widget", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local TextWidget = require("ui/widget/textwidget")
    local Screen = require("device").screen
    local util = require("util")
    local Featured, FeaturedBook, FeaturedCover, Fonts, Home, Layout, Looks, FileManager

    local EXISTING = harness.library .. "/frankenstein.epub"
    local GONE = "/kopanda-spec/no-such-book.epub"

    local function record(fields)
        local book = {
            file = EXISTING,
            title = "Piranesi",
            authors = "Susanna Clarke",
            percent = 0.62,
            status = "reading",
            pages = 220,
            seconds_left = 7800,
            chapter = "Part 3, The Prophet",
        }
        -- false in fields leaves that field out.
        for k, v in pairs(fields or {}) do
            if v == false then
                book[k] = nil
            else
                book[k] = v
            end
        end
        return book
    end

    local function ctx_for(id, opts)
        opts = opts or {}
        return {
            look = Looks.get(id),
            variant = opts.variant or "day",
            text_size = opts.text_size or "medium",
            now = os.time(),
            screen = Screen,
            home = opts.home,
        }
    end

    -- Whether group is a tracked line from Typeset.line: one TextWidget per character.
    local function is_tracked(group)
        local glyphs = 0
        for _, child in ipairs(group) do
            if getmetatable(child) == TextWidget then
                if #util.splitToChars(child.text) ~= 1 then
                    return false
                end
                glyphs = glyphs + 1
            end
        end
        return glyphs > 0
    end

    -- The lines a built widget draws, in tree order: each { text, glyphs }, glyphs the
    -- TextWidgets or TextBoxWidget drawing it; a truncated TextWidget's ellipsis is included.
    local function lines(widget)
        local out = {}
        local function walk(w)
            local mt = getmetatable(w)
            if mt == TextWidget then
                local fitted, ellipsis = w:getFittedText()
                out[#out + 1] = { text = fitted .. (ellipsis and "…" or ""), glyphs = { w } }
            elseif mt == TextBoxWidget then
                out[#out + 1] = { text = w.text, glyphs = { w } }
            elseif mt == HorizontalGroup and is_tracked(w) then
                local line = { text = "", glyphs = {} }
                for _, child in ipairs(w) do
                    if getmetatable(child) == TextWidget then
                        line.text = line.text .. child.text
                        line.glyphs[#line.glyphs + 1] = child
                    end
                end
                out[#out + 1] = line
            else
                for _, child in ipairs(w) do
                    walk(child)
                end
            end
        end
        walk(widget)
        return out
    end

    local function texts(widget)
        local out = {}
        for i, line in ipairs(lines(widget)) do
            out[i] = line.text
        end
        return out
    end

    local function line_of(widget, text)
        for _, line in ipairs(lines(widget)) do
            if line.text == text then
                return line
            end
        end
    end

    -- The first widget in built's tree named name.
    local function find(widget, name)
        if widget.name == name then
            return widget
        end
        for _, child in ipairs(widget) do
            local found = find(child, name)
            if found then
                return found
            end
        end
    end

    local function same_color(a, b)
        a, b = a:getColorRGB32(), b:getColorRGB32()
        return a.r == b.r and a.g == b.g and a.b == b.b
    end

    -- Asserts line is set in the look's type part under ctx.
    local function assert_styled(line, part_name, ctx)
        local where = ctx.look == Looks.get("diner") and "diner" or "editorial"
        where = where .. " " .. part_name .. " " .. tostring(line and line.text)
        assert.is_table(line, where)
        local part = ctx.look.type[part_name]
        local file = Fonts.path(ctx.look.faces[part.face].file)
        local size = Screen:scaleBySize(Layout.font_size(part.size, ctx.text_size))
        local color = Looks.color(ctx.look.palettes[ctx.variant][part.color])
        for _, glyph in ipairs(line.glyphs) do
            assert.equals(file, glyph.face.realname, where)
            assert.equals(size, glyph.face.size, where)
            assert.is_true(same_color(color, glyph.fgcolor), where)
        end
    end

    local SENTINEL = Blitbuffer.ColorRGB32(0, 255, 0, 255)
    local MARGIN = 20

    -- built painted at (MARGIN, MARGIN) on a buffer MARGIN wider on every side, of the sentinel
    -- green; returns the buffer.
    local function paint(built)
        local size = built:getSize()
        local bb = Blitbuffer.new(size.w + 2 * MARGIN, size.h + 2 * MARGIN, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, bb:getWidth(), bb:getHeight(), SENTINEL)
        built:paintTo(bb, MARGIN, MARGIN)
        return bb
    end

    -- The pixels outside the widget's own rectangle that are not the sentinel.
    local function spilled(bb, w, h)
        local n = 0
        for y = 0, bb:getHeight() - 1 do
            for x = 0, bb:getWidth() - 1 do
                local inside = x >= MARGIN and x < MARGIN + w and y >= MARGIN and y < MARGIN + h
                if not inside then
                    local c = bb:getPixel(x, y):getColorRGB32()
                    if c.r ~= 0 or c.g ~= 255 or c.b ~= 0 then
                        n = n + 1
                    end
                end
            end
        end
        return n
    end

    local current, file_manager, closed, after_show, real_box, loaded, preload, calls

    before_each(function()
        Featured = require("widgets/featured")
        FeaturedBook = require("featured_book")
        FeaturedCover = require("featured_cover")
        Fonts = require("fonts")
        Home = require("home")
        Layout = require("layout")
        Looks = require("looks")
        FileManager = require("apps/filemanager/filemanager")
        loaded, preload = package.loaded.bookinfomanager, package.preload.bookinfomanager
        package.loaded.bookinfomanager = nil
        package.preload.bookinfomanager = function() error("CoverBrowser is disabled") end
        current, file_manager, closed = FeaturedBook.current, FileManager.instance, Home.close
        after_show, real_box = FeaturedCover.after_show, FeaturedCover.box
        calls = { current = 0, log = {}, opened = {}, after_show = {} }
        FeaturedBook.current = function()
            calls.current = calls.current + 1
            return calls.book
        end
        FileManager.instance = {
            openFile = function(_, file)
                calls.opened[#calls.opened + 1] = file
                calls.log[#calls.log + 1] = "openFile"
            end,
            onHome = function()
                calls.log[#calls.log + 1] = "onHome"
            end,
        }
        Home.close = function()
            calls.log[#calls.log + 1] = "close"
        end
        FeaturedCover.after_show = function(home, file, specs)
            calls.after_show[#calls.after_show + 1] = { home = home, file = file, specs = specs }
        end
    end)

    after_each(function()
        FeaturedBook.current, FileManager.instance, Home.close = current, file_manager, closed
        FeaturedCover.after_show, FeaturedCover.box = after_show, real_box
        package.loaded.bookinfomanager = loaded
        package.preload.bookinfomanager = preload
    end)

    describe("size", function()
        it("is exactly the column wide and height(width) high in each look at both profiles' widths", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                for _, width in ipairs({ 1236, 1264 }) do
                    for _, book in ipairs({ record(), false }) do
                        calls.book = book or nil
                        local ctx = ctx_for(id)
                        local built = Featured.build(width, ctx)
                        local where = id .. " " .. width .. (book and " book" or " first run")
                        assert.equals(width, built:getSize().w, where)
                        assert.equals(Featured.height(width, ctx), built:getSize().h, where)
                        built:free()
                    end
                end
            end
        end)

        it("is the cover box height plus the cover shadow's y", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                local ctx = ctx_for(id)
                for _, width in ipairs({ 1264, 300 }) do
                    local _, h = FeaturedCover.box(width, ctx)
                    assert.equals(h + Screen:scaleBySize(ctx.look.shadow.cover.y), Featured.height(width, ctx), id)
                end
            end
        end)

        it("paints nothing outside itself at 600 px or in a half-width column, at the large text size", function()
            local long = record{
                title = string.rep("A Very Long Title Indeed ", 6),
                authors = string.rep("Somebody Withaverylongname, ", 5),
                chapter = string.rep("Chapter the Endless ", 6),
                seconds_left = 99999,
            }
            for _, id in ipairs({ "editorial", "diner" }) do
                for _, width in ipairs({ 600, 253 }) do
                    for _, book in ipairs({ long, record(), false }) do
                        calls.book = book or nil
                        local built = Featured.build(width, ctx_for(id, { text_size = "large" }))
                        local size = built:getSize()
                        local bb = paint(built)
                        local where = id .. " " .. width .. (book and " book" or " first run")
                        assert.equals(width, size.w, where)
                        assert.equals(0, spilled(bb, size.w, size.h), where)
                        bb:free()
                        built:free()
                    end
                end
            end
        end)

        it("reads the featured book once per build", function()
            calls.book = record()
            local built = Featured.build(1264, ctx_for("editorial"))
            assert.equals(1, calls.current)
            built:free()
        end)
    end)

    describe("text column", function()
        it("sets Editorial's label, title, authors, chapter and caption in their parts", function()
            calls.book = record()
            for _, variant in ipairs({ "day", "grey" }) do
                local ctx = ctx_for("editorial", { variant = variant })
                for _, width in ipairs({ 1236, 1264 }) do
                    local built = Featured.build(width, ctx)
                    assert_styled(line_of(built, "CONTINUE READING"), "featured_label", ctx)
                    assert_styled(line_of(built, "Piranesi"), "featured_title", ctx)
                    assert_styled(line_of(built, "Susanna Clarke"), "featured_authors", ctx)
                    assert_styled(line_of(built, "Part 3, The Prophet"), "featured_chapter", ctx)
                    assert_styled(line_of(built, "62%"), "featured_caption", ctx)
                    assert_styled(line_of(built, "2 h 10 min left"), "featured_caption", ctx)
                    built:free()
                end
            end
        end)

        it("sets Diner's chip, title, authors and chapter, and caption in their parts", function()
            calls.book = record()
            for _, variant in ipairs({ "day", "grey" }) do
                local ctx = ctx_for("diner", { variant = variant })
                for _, width in ipairs({ 1236, 1264 }) do
                    local built = Featured.build(width, ctx)
                    assert_styled(line_of(built, "NOW READING"), "featured_label", ctx)
                    assert_styled(line_of(built, "Piranesi"), "featured_title", ctx)
                    assert_styled(line_of(built, "Susanna Clarke · Part 3, The Prophet"), "featured_authors", ctx)
                    assert_styled(line_of(built, "62% · 2 h 10 min left"), "featured_caption", ctx)
                    built:free()
                end
            end
        end)

        it("draws Diner's chip in chip.fill_color with an outline of featured.chip_outline", function()
            calls.book = record()
            local ctx = ctx_for("diner")
            local built = Featured.build(1264, ctx)
            local bb = paint(built)
            -- The chip's outline is the outline role, its fill pink.
            local chip = find(built, "kopanda_featured_chip")
            assert.is_table(chip)
            local rect = chip.screen_rect
            local outline = Screen:scaleBySize(ctx.look.featured.chip_outline)
            local function at(x, y)
                local c = bb:getPixel(x, y):getColorRGB32()
                return { c.r, c.g, c.b }
            end
            local function rgb(role)
                local c = Looks.color(ctx.look.palettes.day[role])
                return { c:getR(), c:getG(), c:getB() }
            end
            assert.same(rgb("outline"), at(rect.x, rect.y + math.floor(rect.h / 2)))
            assert.same(rgb("outline"), at(rect.x + outline - 1, rect.y + math.floor(rect.h / 2)))
            assert.same(rgb("pink"), at(rect.x + outline, rect.y + outline))
            bb:free()
            built:free()
        end)

        -- The harness's screen scales by 1, so at both profiles' widths a 120-character title
        -- fits in two lines; at the harness's own 600 px it runs over.
        it("sets a 120-character title in at most two lines, cut with an ellipsis where it runs over", function()
            local title = string.rep("Strange Titles ", 8)
            assert.equals(120, #title)
            calls.book = record{ title = title }
            for _, id in ipairs({ "editorial", "diner" }) do
                for _, width in ipairs({ 1236, 1264 }) do
                    local built = Featured.build(width, ctx_for(id))
                    local box = line_of(built, title).glyphs[1]
                    assert.truthy(#box.vertical_string_list <= 2, id .. " " .. width)
                    built:free()
                end
                local built = Featured.build(600, ctx_for(id))
                local box = line_of(built, title).glyphs[1]
                assert.truthy(#box.vertical_string_list > 2, id .. " title fits in two lines at 600")
                assert.equals(2, box.lines_per_page, id)
                assert.equals(2, box.line_with_ellipsis, id)
                built:free()
            end
        end)

        it("gives a one-line title one line's height", function()
            calls.book = record()
            for _, id in ipairs({ "editorial", "diner" }) do
                local built = Featured.build(1264, ctx_for(id))
                local box = line_of(built, "Piranesi").glyphs[1]
                assert.equals(1, #box.vertical_string_list, id)
                assert.truthy(box:getSize().h < 2 * box.line_height_px, id)
                built:free()
            end
        end)

        it("reads Diner's authors alone with no chapter, the chapter alone with no authors, and neither", function()
            local ctx = ctx_for("diner")
            calls.book = record{ chapter = false }
            local built = Featured.build(1264, ctx)
            assert.is_table(line_of(built, "Susanna Clarke"))
            for _, text in ipairs(texts(built)) do
                assert.is_falsy(text:find(" · $"), text)
            end
            built:free()
            calls.book = record{ authors = false }
            built = Featured.build(1264, ctx)
            assert.is_table(line_of(built, "Part 3, The Prophet"))
            built:free()
            calls.book = record{ authors = false, chapter = false, seconds_left = false, pages = false }
            built = Featured.build(1264, ctx)
            -- The cover's placeholder title, then the column.
            assert.same({ "PIRANESI", "NOW READING", "Piranesi", "62%" }, texts(built))
            built:free()
        end)

        it("leaves out Editorial's missing authors and chapter lines", function()
            calls.book = record{ authors = false, chapter = false }
            local built = Featured.build(1264, ctx_for("editorial"))
            assert.is_nil(line_of(built, "Susanna Clarke"))
            assert.is_nil(line_of(built, "Part 3, The Prophet"))
            assert.is_table(line_of(built, "Piranesi"))
            built:free()
        end)

        -- The column's states as its height falls a pixel at a time from 600 to 20, the cover
        -- box's height replaced so the column's height is free while its width is the real one:
        -- each state names the lines under the title the column draws, by the text they hold
        -- however cut, and the title's lines; repeats are folded.
        local function overflow(id, width, book)
            local column_h
            FeaturedCover.box = function(w, ctx)
                return (real_box(w, ctx)), column_h
            end
            local states = {}
            for h = 600, 20, -1 do
                column_h = h
                calls.book = book
                local built = Featured.build(width, ctx_for(id, { text_size = "large" }))
                local held, title_lines = {}, nil
                local function walk(w)
                    local mt = getmetatable(w)
                    if mt == TextBoxWidget and w.text == book.title then
                        title_lines = w.lines_per_page
                    elseif mt == TextWidget then
                        held[#held + 1] = w.text
                    end
                    for _, child in ipairs(w) do
                        walk(child)
                    end
                end
                -- The text column, past the cover box and the gap.
                walk(built[1][3])
                local all = table.concat(held, "\n")
                local parts = {}
                if all:find(book.authors, 1, true) then
                    parts[#parts + 1] = "authors"
                end
                if all:find(book.chapter, 1, true) then
                    parts[#parts + 1] = "chapter"
                end
                parts[#parts + 1] = "title " .. tostring(title_lines)
                local state = table.concat(parts, ", ")
                if states[#states] ~= state then
                    states[#states + 1] = state
                end
                built:free()
            end
            return states
        end

        it("in a column too short, drops Editorial's chapter, then its authors, then the title's 2nd line", function()
            local long = record{
                title = string.rep("A Very Long Title Indeed ", 6),
                authors = string.rep("Somebody Withaverylongname, ", 5),
                chapter = string.rep("Chapter the Endless ", 6),
            }
            assert.same({ "authors, chapter, title 2", "authors, title 2", "title 2", "title 1" },
                overflow("editorial", 253, long))
        end)

        -- Diner's authors and chapter share one line in one part, so the authors alone are no
        -- shorter and the line goes whole.
        it("in a column too short, drops Diner's authors and chapter line, then the title's second line", function()
            local book = record{ title = string.rep("A Very Long Title Indeed ", 6) }
            assert.same({ "authors, chapter, title 2", "title 2", "title 1" }, overflow("diner", 253, book))
        end)
    end)

    describe("caption", function()
        local function caption(fields)
            return Featured.caption(record(fields))
        end

        it("reads the percent and the time left, rounded to the minute", function()
            assert.same({ "62%", "2 h 10 min left" }, caption{ seconds_left = 7800 })
            assert.same({ "62%", "45 min left" }, caption{ seconds_left = 2700 })
            assert.same({ "62%", "1 h left" }, caption{ seconds_left = 3600 })
            assert.same({ "62%", "2 h 11 min left" }, caption{ seconds_left = 7830 })
        end)

        it("falls back to the pages left without a rate", function()
            assert.same({ "62%", "84 pages left" }, caption{ seconds_left = false, pages = 220 })
            assert.same({ "99%", "1 page left" }, caption{ seconds_left = false, pages = 220, percent = 219 / 220 })
        end)

        it("reads the percent alone with neither", function()
            assert.same({ "62%" }, caption{ seconds_left = false, pages = false })
        end)

        it("reads 100% and Finished for a complete book", function()
            assert.same({ "100%", "Finished" }, caption{ status = "complete", percent = 0.62 })
        end)

        it("floors the percent, so a book reads 100% only when complete", function()
            assert.same("99%", caption{ percent = 0.999 }[1])
            assert.same("29%", caption{ percent = 0.29 }[1])
            assert.same("0%", caption{ percent = 0 }[1])
        end)
    end)

    describe("progress bar", function()
        -- The pixels of colour on the bar's middle row, and the bar.
        local function filled(id, fields, variant)
            calls.book = record(fields)
            local ctx = ctx_for(id, { variant = variant })
            local built = Featured.build(1264, ctx)
            local bar = find(built, "kopanda_featured_bar")
            local size = bar:getSize()
            local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
            bar:paintTo(bb, 0, 0)
            local fill = Looks.color(ctx.look.palettes[ctx.variant][ctx.look.progress.fill_color]):getColorRGB32()
            local n = 0
            local y = math.floor(size.h / 2)
            for x = 0, size.w - 1 do
                local c = bb:getPixel(x, y):getColorRGB32()
                if c.r == fill.r and c.g == fill.g and c.b == fill.b then
                    n = n + 1
                end
            end
            local outline = ctx.look.progress.outline_color and Screen:scaleBySize(ctx.look.progress.outline_width) or 0
            bb:free()
            built:free()
            return n, size.w - 2 * outline, bar
        end

        it("fills to the shown percent of its inner width in both looks", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                local n = filled(id, { percent = 0 })
                assert.equals(0, n, id .. " at 0")
                local inner
                n, inner = filled(id, { percent = 0.62 })
                assert.equals(math.floor(inner * 62 / 100), n, id .. " at 0.62")
                n, inner = filled(id, { percent = 0.999 })
                assert.equals(math.floor(inner * 99 / 100), n, id .. " at 0.999")
                n, inner = filled(id, { percent = 1 })
                assert.equals(inner, n, id .. " at 1")
                n, inner = filled(id, { percent = 0.62, status = "complete" })
                assert.equals(inner, n, id .. " complete")
            end
        end)

        it("is outlined in Diner and bare in Editorial, at the progress token's height", function()
            local _, _, bar = filled("diner", {})
            local p = Looks.get("diner").progress
            assert.equals(Screen:scaleBySize(p.height) + 2 * Screen:scaleBySize(p.outline_width), bar:getSize().h)
            _, _, bar = filled("editorial", {})
            assert.equals(Screen:scaleBySize(Looks.get("editorial").progress.height), bar:getSize().h)
        end)

        it("fills Diner's grey bar with a striped FrameContainer and Editorial's with a plain fill", function()
            for _, case in ipairs({ { "diner", true }, { "editorial", false } }) do
                calls.book = record()
                local built = Featured.build(1264, ctx_for(case[1], { variant = "grey" }))
                local fill = find(built, "kopanda_featured_bar")[1]
                if case[2] then
                    assert.equals(FrameContainer, getmetatable(fill))
                    assert.equals(Screen:scaleBySize(5), fill.stripe_width)
                    assert.is_not_nil(fill.stripe_color)
                else
                    assert.is_not.equals(FrameContainer, getmetatable(fill))
                    assert.is_nil(fill.stripe_width)
                end
                built:free()
            end
        end)
    end)

    describe("first run", function()
        it("shows No book yet, the label, the empty title, the body and the button, in order", function()
            calls.book = nil
            local body = "Open a book from the Library and it will wait for you here."
            for id, label in pairs({ editorial = "CONTINUE READING", diner = "NOW READING" }) do
                local ctx = ctx_for(id)
                local built = Featured.build(1264, ctx)
                assert.same({ "NO BOOK YET", label, "Nothing open yet.", body, "OPEN THE LIBRARY" }, texts(built), id)
                assert_styled(line_of(built, "Nothing open yet."), "featured_empty_title", ctx)
                assert_styled(line_of(built, body), "featured_empty_body", ctx)
                assert_styled(line_of(built, "OPEN THE LIBRARY"), "featured_button", ctx)
                built:free()
            end
        end)

        -- The glyphs painted inside rect, joined, spaces left out.
        local function painted_in(built, rect)
            local paint_to = TextWidget.paintTo
            local found = {}
            TextWidget.paintTo = function(self, bb, x, y)
                if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                    found[#found + 1] = self.text
                end
                return paint_to(self, bb, x, y)
            end
            local ok, err = pcall(function()
                paint(built):free()
            end)
            TextWidget.paintTo = paint_to
            assert(ok, err)
            return (table.concat(found):gsub(" ", ""))
        end

        it("closes the home and opens the file browser on a tap on the button", function()
            calls.book = nil
            for _, id in ipairs({ "editorial", "diner" }) do
                calls.log = {}
                local ctx = ctx_for(id)
                local built = Featured.build(1264, ctx)
                paint(built):free()
                local rect = built.button.screen_rect
                assert.equals("OPENTHELIBRARY", painted_in(built, rect), id)
                local ges = harness.gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))
                assert.is_true(Featured.tap(ctx, ges, built), id)
                assert.same({ "close", "onHome" }, calls.log, id)
                built:free()
            end
        end)

        it("returns false on a tap outside the button, doing nothing", function()
            calls.book = nil
            local ctx = ctx_for("editorial")
            local built = Featured.build(1264, ctx)
            paint(built):free()
            local rect = built.button.screen_rect
            -- Geom:contains takes the far edges in (frontend/ui/geometry.lua:255-266).
            for _, pos in ipairs({ { MARGIN + 10, MARGIN + 10 }, { rect.x - 1, rect.y },
                    { rect.x, rect.y + rect.h + 1 } }) do
                assert.is_false(Featured.tap(ctx, harness.gesture("tap", pos[1], pos[2]), built))
            end
            assert.same({}, calls.log)
            built:free()
        end)

        it("asks for no cover after the show", function()
            calls.book = nil
            local ctx = ctx_for("editorial", { home = {} })
            local built = Featured.build(1264, ctx)
            Featured.after_show(ctx, built)
            assert.same({}, calls.after_show)
            built:free()
        end)
    end)

    describe("with a book", function()
        it("opens a book whose file exists through FileManager:openFile, once", function()
            calls.book = record()
            local refreshes = 0
            local ctx = ctx_for("diner", { home = { refresh = function() refreshes = refreshes + 1 end } })
            local built = Featured.build(1264, ctx)
            assert.is_true(Featured.tap(ctx, harness.gesture("tap", 5, 5), built))
            assert.same({ EXISTING }, calls.opened)
            assert.same({ "openFile" }, calls.log)
            assert.equals(0, refreshes)
            built:free()
        end)

        it("refreshes the home, opening nothing, when the book's file is gone", function()
            calls.book = record{ file = GONE }
            local refreshes = 0
            local ctx = ctx_for("editorial", { home = { refresh = function() refreshes = refreshes + 1 end } })
            local built = Featured.build(1264, ctx)
            assert.is_true(Featured.tap(ctx, harness.gesture("tap", 5, 5), built))
            assert.equals(1, refreshes)
            assert.same({}, calls.opened)
            built:free()
        end)

        it("asks the cover box after the show for its file at the box's size", function()
            calls.book = record()
            for _, id in ipairs({ "editorial", "diner" }) do
                calls.after_show = {}
                local home = {}
                local ctx = ctx_for(id, { home = home })
                local built = Featured.build(1264, ctx)
                Featured.after_show(ctx, built)
                local w, h = FeaturedCover.box(1264, ctx)
                assert.equals(1, #calls.after_show, id)
                assert.equals(home, calls.after_show[1].home, id)
                assert.equals(EXISTING, calls.after_show[1].file, id)
                assert.same({ max_cover_w = w, max_cover_h = h }, calls.after_show[1].specs, id)
                built:free()
            end
        end)
    end)
end)
