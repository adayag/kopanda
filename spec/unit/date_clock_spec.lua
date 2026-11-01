-- The date and clock widgets: their strings from KOReader's translation tables and its 12-hour clock setting, drawn
-- in each look's type tokens, at most their column wide, with height the built widget's height.
describe("the date and clock widgets", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local TextWidget = require("ui/widget/textwidget")
    local Screen = require("device").screen
    local Date, Clock, Fonts, Layout, Looks, Widgets

    -- Local times, so the strings are the same in any time zone.
    local function at(year, month, day, hour, min)
        return os.time{ year = year, month = month, day = day, hour = hour, min = min, sec = 0 }
    end
    local TUESDAY_0842 = at(2026, 10, 13, 8, 42)

    local function ctx_for(id, opts)
        opts = opts or {}
        return {
            look = Looks.get(id),
            variant = opts.variant or "day",
            text_size = opts.text_size or "medium",
            now = opts.now or TUESDAY_0842,
            screen = Screen,
        }
    end

    -- The lines a built widget draws, top to bottom: each { text, glyphs, widget }, where glyphs
    -- are the TextWidgets drawing it (one, or one per character for a tracked line), text what
    -- they draw together, a truncated TextWidget's ellipsis included, and widget the line.
    local function lines(widget)
        local out = {}
        local function walk(w)
            local mt = getmetatable(w)
            if mt == TextWidget then
                local fitted, ellipsis = w:getFittedText()
                out[#out + 1] = { text = fitted .. (ellipsis and "…" or ""), glyphs = { w }, widget = w }
            elseif mt == HorizontalGroup then
                local line = { text = "", glyphs = {}, widget = w }
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

    local function drawn(widget)
        local texts = {}
        for i, line in ipairs(lines(widget)) do
            texts[i] = line.text
        end
        return texts
    end

    local function same_color(a, b)
        a, b = a:getColorRGB32(), b:getColorRGB32()
        return a.r == b.r and a.g == b.g and a.b == b.b
    end

    -- Asserts every glyph of line is set in the look's type part under ctx.
    local function assert_styled(line, part_name, ctx)
        local part = ctx.look.type[part_name]
        local file = Fonts.face_name(ctx.look.faces[part.face].file)
        local size = Screen:scaleBySize(Layout.font_size(part.size, ctx.text_size))
        local color = Looks.color(ctx.look.palettes[ctx.variant][part.color])
        assert.truthy(#line.glyphs > 0)
        for _, glyph in ipairs(line.glyphs) do
            local where = part_name .. " " .. ctx.variant .. " " .. ctx.text_size .. " " .. line.text
            assert.equals(file, glyph.face.realname, where)
            assert.equals(size, glyph.face.size, where)
            assert.is_true(same_color(color, glyph.fgcolor), where)
        end
    end

    -- The width of one of three equal columns in a row of the harness's 600 px screen.
    local function third(look)
        local content = 600 - 2 * Screen:scaleBySize(40)
        return Layout.columns(content, { { share = 1 }, { share = 1 }, { share = 1 } }, look.home.column_gap)[1].w
    end

    before_each(function()
        harness.load()
        Date = require("widgets/date")
        Clock = require("widgets/clock")
        Fonts = require("fonts")
        Layout = require("layout")
        Looks = require("looks")
        Widgets = require("widgets")
        G_reader_settings:delSetting("twelve_hour_clock")
    end)

    after_each(function()
        G_reader_settings:delSetting("twelve_hour_clock")
        harness.teardown()
    end)

    it("are in the registry as date and clock, with no tap", function()
        assert.equals(Date, Widgets.get("date"))
        assert.equals(Clock, Widgets.get("clock"))
        assert.equals("date", Date.id)
        assert.equals("clock", Clock.id)
        assert.is_nil(Date.tap)
        assert.is_nil(Clock.tap)
    end)

    describe("the date", function()
        it("reads the weekday over the month and day in Editorial", function()
            assert.same({ "Tuesday", "October 13" }, Date.lines(Looks.get("editorial"), TUESDAY_0842))
            assert.same({ "TUESDAY", "October 13" }, drawn(Date.build(520, ctx_for("editorial"))))
        end)

        it("reads one line in Diner, drawn uppercase", function()
            assert.same({ "Tuesday, October 13" }, Date.lines(Looks.get("diner"), TUESDAY_0842))
            assert.same({ "TUESDAY, OCTOBER 13" }, drawn(Date.build(520, ctx_for("diner"))))
        end)

        -- The line count is the look's home.date_lines, not which look it is.
        it("reads as many lines as the look's date_lines", function()
            local editorial, diner = Looks.get("editorial"), Looks.get("diner")
            finally(function()
                editorial.home.date_lines, diner.home.date_lines = 2, 1
            end)
            editorial.home.date_lines, diner.home.date_lines = 1, 2
            assert.same({ "Tuesday, October 13" }, Date.lines(editorial, TUESDAY_0842))
            assert.same({ "Tuesday", "October 13" }, Date.lines(diner, TUESDAY_0842))
        end)

        it("reads KOReader's short weekday and month names when asked for short", function()
            local t = at(2026, 9, 30, 12, 0)
            assert.same({ "Wed", "Sep 30" }, Date.lines(Looks.get("editorial"), t, true))
            assert.same({ "Wed, Sep 30" }, Date.lines(Looks.get("diner"), t, true))
        end)

        it("draws the short names only where the long ones don't fit whole at the smallest size", function()
            harness.at_colorsoft(function()
                local ctx = ctx_for("diner", { text_size = "extra_large", now = at(2026, 9, 30, 12, 0) })
                local slot = Layout.arrange({ { { widget = "date", share = 1 }, { widget = "clock", share = 1 } } },
                    ctx).rows[1].slots[1]
                assert.same({ "WED, SEP 30" }, drawn(Date.build(slot.w, ctx)))
                ctx.now = at(2026, 5, 3, 12, 0)
                assert.same({ "SUNDAY, MAY 3" }, drawn(Date.build(slot.w, ctx)))
            end)
        end)

        it("has no leading zero on the day", function()
            local fifth = at(2026, 11, 5, 12, 0)
            assert.same({ "Thursday", "November 5" }, Date.lines(Looks.get("editorial"), fifth))
            assert.same({ "Thursday, November 5" }, Date.lines(Looks.get("diner"), fifth))
        end)

        it("names all seven weekdays and twelve months", function()
            local days = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
            for i, name in ipairs(days) do
                -- 2026-10-12 is a Monday.
                local t = at(2026, 10, 11 + i, 12, 0)
                assert.same({ name, "October " .. (11 + i) }, Date.lines(Looks.get("editorial"), t))
            end
            local months = { "January", "February", "March", "April", "May", "June", "July", "August",
                "September", "October", "November", "December" }
            for i, name in ipairs(months) do
                assert.equals(name .. " 1", Date.lines(Looks.get("editorial"), at(2026, i, 1, 12, 0))[2])
            end
        end)

        it("sets a date too wide for its column smaller, a step at a time, until it fits whole", function()
            local ctx = ctx_for("diner", { now = at(2026, 9, 30, 12, 0) })
            local part = ctx.look.type.date
            local whole = require("typeset").line(part, "WEDNESDAY, SEPTEMBER 30", math.huge, ctx)
            local width = math.floor(whole:getSize().w * 0.85)
            whole:free()
            local built = Date.build(width, ctx)
            assert.equals(width, built:getSize().w)
            local line = lines(built)[1]
            assert.equals("WEDNESDAY, SEPTEMBER 30", line.text)
            assert.truthy(line.glyphs[1].face.orig_size < Layout.font_size(part.size, ctx.text_size))
            assert.truthy(line.widget:getSize().w <= width)
        end)

        it("is cut with an ellipsis where even the short names don't fit at the smallest size, never wider than its "
            .. "column", function()
            local ctx = ctx_for("diner", { now = at(2026, 9, 30, 12, 0) })
            local width = math.floor(third(ctx.look) / 3)
            local built = Date.build(width, ctx)
            assert.equals(width, built:getSize().w)
            local line = lines(built)[1]
            assert.equals(1, #line.glyphs)
            assert.truthy(line.text:match("…$"), line.text)
            assert.truthy(line.glyphs[1]:getSize().w <= width)
        end)
    end)

    -- Each look's header row on each profile at large and extra_large: every day of a year's date and the
    -- widest times, 23:58 and, on the 12-hour clock, 12:58.
    it("fits every date of the year and the widest times whole in the header row", function()
        local Schema = require("schema")
        local header
        for _, key in ipairs(Schema.keys) do
            if key.id == "layout.rows" then
                header = key.default[1]
            end
        end
        local cut = {}
        local function check(profile)
            for _, id in ipairs(Looks.ids()) do
                for _, size in ipairs({ "large", "extra_large" }) do
                    local ctx = ctx_for(id, { text_size = size })
                    local slots = Layout.arrange({ header }, ctx).rows[1].slots
                    local function whole(module, now, where)
                        for _, slot in ipairs(slots) do
                            if slot.widget == module.id then
                                ctx.now = now
                                local built = module.build(slot.w - 2 * slot.pad_x, ctx)
                                for _, line in ipairs(lines(built)) do
                                    if line.text:match("…$") then
                                        cut[#cut + 1] = table.concat({ profile, id, size, where, line.text }, " ")
                                    end
                                end
                                built:free()
                            end
                        end
                    end
                    for day = 0, 364 do
                        whole(Date, at(2026, 1, 1 + day, 12, 0), "date")
                    end
                    whole(Clock, at(2026, 10, 13, 23, 58), "24-hour")
                    G_reader_settings:saveSetting("twelve_hour_clock", true)
                    whole(Clock, at(2026, 10, 13, 12, 58), "12-hour")
                    G_reader_settings:delSetting("twelve_hour_clock")
                end
            end
        end
        harness.at_colorsoft(function() check("colorsoft") end)
        harness.at_paperwhite(function() check("paperwhite") end)
        harness.at_screen(1072, 1448, function() check("paperwhite7") end)
        assert.same({}, cut)
    end)

    describe("the clock", function()
        local function reads(t)
            return Clock.text(t), drawn(Clock.build(260, ctx_for("editorial", { now = t })))[1]
        end

        local cases = {
            -- { time, with twelve_hour_clock true, with it false or unset }
            { at(2026, 10, 13, 8, 42), "8:42", "8:42" },
            { at(2026, 10, 13, 20, 42), "8:42", "20:42" },
            { at(2026, 10, 13, 0, 0), "12:00", "0:00" },
            { at(2026, 10, 13, 12, 5), "12:05", "12:05" },
        }

        it("reads the 12-hour time with no leading zero and no AM/PM when twelve_hour_clock is true", function()
            G_reader_settings:saveSetting("twelve_hour_clock", true)
            for _, case in ipairs(cases) do
                local text, shown = reads(case[1])
                assert.equals(case[2], text)
                assert.equals(case[2], shown)
            end
        end)

        it("reads the 24-hour time with no leading zero when twelve_hour_clock is unset or false", function()
            for _, value in ipairs({ "unset", false }) do
                if value ~= "unset" then
                    G_reader_settings:saveSetting("twelve_hour_clock", value)
                end
                for _, case in ipairs(cases) do
                    local text, shown = reads(case[1])
                    assert.equals(case[3], text)
                    assert.equals(case[3], shown)
                end
            end
        end)
    end)

    describe("in each look", function()
        local function each_ctx(f)
            for _, id in ipairs({ "editorial", "diner" }) do
                for _, variant in ipairs({ "day", "grey" }) do
                    for _, text_size in ipairs({ "small", "medium", "large" }) do
                        f(ctx_for(id, { variant = variant, text_size = text_size }))
                    end
                end
            end
        end

        it("draw each line in the look's face, size and colour for its part", function()
            each_ctx(function(ctx)
                local date = lines(Date.build(520, ctx))
                if ctx.look == Looks.get("editorial") then
                    assert.equals(2, #date)
                    assert_styled(date[1], "date_label", ctx)
                    assert_styled(date[2], "date", ctx)
                else
                    assert.equals(1, #date)
                    assert_styled(date[1], "date", ctx)
                end
                local clock = lines(Clock.build(260, ctx))
                assert.equals(1, #clock)
                assert_styled(clock[1], "clock", ctx)
            end)
        end)

        it("build exactly the column wide, with height the built widget's height", function()
            each_ctx(function(ctx)
                for _, module in ipairs({ Date, Clock }) do
                    for _, width in ipairs({ 520, 253, third(ctx.look) }) do
                        local h = module.height(width, ctx)
                        local built = module.build(width, ctx)
                        assert.equals(width, built:getSize().w)
                        assert.equals(h, built:getSize().h)
                        local again = module.build(width, ctx)
                        assert.is_not.equals(built, again)
                        assert.equals(h, again:getSize().h)
                        assert.truthy(h > 0)
                    end
                end
            end)
        end)

        it("set a tracked line glyph by glyph, wider for positive tracking and narrower for negative", function()
            -- Editorial's label is tracked 0.14 em, Diner's clock -0.02 em.
            local label = lines(Date.build(520, ctx_for("editorial")))[1]
            assert.equals(#"TUESDAY", #label.glyphs)
            local plain = TextWidget:new{ text = label.text, face = label.glyphs[1].face }
            assert.truthy(label.widget:getSize().w > plain:getSize().w)
            local clock = lines(Clock.build(260, ctx_for("diner", { now = at(2026, 10, 13, 20, 42) })))[1]
            assert.equals(#"20:42", #clock.glyphs)
            local plain_clock = TextWidget:new{ text = clock.text, face = clock.glyphs[1].face }
            assert.truthy(clock.widget:getSize().w < plain_clock:getSize().w)
        end)

        it("keep a widget measured under one ctx from a build under another", function()
            local width = 260
            local a = ctx_for("editorial")
            local b = ctx_for("editorial", { now = at(2026, 10, 13, 20, 42) })
            Clock.height(width, a)
            assert.same({ "20:42" }, drawn(Clock.build(width, b)))
            local large = ctx_for("editorial", { now = at(2026, 10, 13, 20, 42), text_size = "large" })
            Clock.height(width, a)
            local built = Clock.build(width, large)
            assert.same({ "20:42" }, drawn(built))
            assert_styled(lines(built)[1], "clock", large)
            local h_large = Clock.build(width, ctx_for("editorial", { text_size = "large" })):getSize().h
            assert.is_not.equals(Clock.height(width, a), h_large)
            Clock.height(width, a)
            assert.equals(h_large, Clock.height(width, large))
        end)

        it("set the clock at its part's line height: Diner's CSS 0.9, Editorial's the face's own", function()
            for _, text_size in ipairs({ "small", "medium", "large" }) do
                local diner = Clock.build(260, ctx_for("diner", { text_size = text_size }))
                local face = lines(diner)[1].glyphs[1].face
                assert.equals(math.floor(0.9 * face.size + 0.5), diner:getSize().h, text_size)
                local editorial = Clock.build(260, ctx_for("editorial", { text_size = text_size }))
                local line = lines(editorial)[1]
                local plain = TextWidget:new{ text = line.text, face = line.glyphs[1].face }
                assert.equals(plain:getSize().h, editorial:getSize().h, text_size)
            end
        end)

        it("draw the date at its column's left and the clock at its column's right", function()
            local bb = Blitbuffer.new(700, 200, Blitbuffer.TYPE_BBRGB32)
            -- The x each built widget paints its content at, and the content's width.
            local function content_x(built)
                local content, x = built[1], nil
                local paint = content.paintTo
                content.paintTo = function(self, buffer, px, py)
                    x = px
                    return paint(self, buffer, px, py)
                end
                built:paintTo(bb, 100, 0)
                return x, content:getSize().w
            end
            for _, id in ipairs({ "editorial", "diner" }) do
                local date_x, date_w = content_x(Date.build(520, ctx_for(id)))
                assert.truthy(date_w < 520, id)
                assert.equals(100, date_x, id .. " date")
                local clock_x, clock_w = content_x(Clock.build(520, ctx_for(id)))
                assert.truthy(clock_w < 520, id)
                assert.equals(100 + 520 - clock_w, clock_x, id .. " clock")
            end
            bb:free()
        end)

        it("paint", function()
            local bb = Blitbuffer.new(600, 200, Blitbuffer.TYPE_BBRGB32)
            each_ctx(function(ctx)
                Date.build(253, ctx):paintTo(bb, 0, 0)
                Clock.build(253, ctx):paintTo(bb, 300, 0)
            end)
            bb:free()
        end)
    end)
end)
