-- NavBar (the nav bar's C2): its five tabs, its height per look whatever the text size, its five
-- columns, its paint in each look and variant, and what a tap, a hold and anything else on it do.
-- Nothing here places the bar on a screen; each case sets the bar's dimen as a screen would.
describe("the nav bar", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local Screen = require("device").screen
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local NavBar, Icons, Layout, Looks, Settings, Typeset

    before_each(function()
        harness.load()
        NavBar = package.loaded["nav_bar"]
        Icons = package.loaded["icons"]
        Layout = package.loaded["layout"]
        Looks = package.loaded["looks"]
        Settings = package.loaded["settings"]
        Typeset = package.loaded["typeset"]
    end)

    -- What spy replaced, put back after each case, latest first.
    local restores = {}

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        harness.teardown()
    end)

    local function scale(px)
        return Screen:scaleBySize(px)
    end

    -- The feature's height: edge, the active rule's overhang, the tab's padding, icon and gap and
    -- the taller of the two label lines, each length scaled, the lines set with no text size.
    local function formula(look)
        local nav = look.nav
        local ctx = { look = look, variant = "day" }
        local label = 0
        for _, part in ipairs({ look.type.nav_label, look.type.nav_label_active }) do
            local line = Typeset.line(part, "Home", Screen:getWidth(), ctx)
            label = math.max(label, line:getSize().h)
            line:free()
        end
        local edge = scale(nav.edge_width)
        return edge + math.max(0, scale(nav.active_rule_width) - edge) + scale(nav.padding_top)
            + scale(nav.icon_size) + scale(nav.icon_gap) + label + scale(nav.padding_bottom)
    end

    -- A bar across the screen's width in look id, placed on the screen's bottom edge.
    local function bar_for(id, where, options)
        options = options or {}
        local bar = NavBar.new{
            look = Looks.get(id),
            variant = options.variant or "day",
            width = Screen:getWidth(),
            where = where,
            listen = options.listen,
        }
        bar.dimen.x, bar.dimen.y = 0, Screen:getHeight() - bar.dimen.h
        return bar
    end

    -- The screen x of column i's left edge and its width.
    local function column(bar, i)
        local pad = scale(bar.look.nav.padding_x)
        local col = bar.columns[i]
        return bar.dimen.x + pad + col.x, col.w
    end

    local function centre(bar, i)
        local x, w = column(bar, i)
        return x + math.floor(w / 2), bar.dimen.y + math.floor(bar.dimen.h / 2)
    end

    -- Replaces t[name] with a recorder of each call's arguments, raising raises when given; the
    -- original comes back after the case.
    local function spy(t, name, raises)
        local calls, original = {}, rawget(t, name)
        restores[#restores + 1] = function()
            t[name] = original
        end
        t[name] = function(...)
            calls[#calls + 1] = { ... }
            if raises then
                error(raises)
            end
        end
        return calls
    end

    describe("tabs", function()
        it("are Home, Library, Authors, History and Settings in order, each with a registry icon", function()
            local ids, labels, icons = {}, {}, {}
            for i, tab in ipairs(NavBar.TABS) do
                ids[i], labels[i], icons[i] = tab.id, tab.label, tab.icon
                local path = Icons.path(tab.icon)
                assert.is_string(path, tab.id)
                assert.equals("file", lfs.attributes(path, "mode"), path)
            end
            assert.same({ "home", "library", "authors", "history", "settings" }, ids)
            assert.same({ "Home", "Library", "Authors", "History", "Settings" }, labels)
            assert.same({ "home", "library", "authors", "history", "settings" }, icons)
        end)
    end)

    describe("height", function()
        it("is the formula from each look's tokens at the unit screen and at the Colorsoft", function()
            for _, id in ipairs(Looks.ids()) do
                local look = Looks.get(id)
                assert.equals(formula(look), NavBar.height(look, Screen), id)
                harness.at_colorsoft(function()
                    assert.equals(formula(look), NavBar.height(look, Screen), id .. " at the Colorsoft")
                    assert.is_true(NavBar.height(look, Screen) > scale(68), id .. " at the Colorsoft")
                end)
            end
        end)

        it("doesn't follow the stored text size", function()
            for _, size in ipairs({ "small", "medium", "large" }) do
                assert.is_true(Settings.set("text_size", size))
                for _, id in ipairs(Looks.ids()) do
                    local look = Looks.get(id)
                    assert.equals(formula(look), NavBar.height(look, Screen), id .. " " .. size)
                    harness.at_colorsoft(function()
                        assert.equals(formula(look), NavBar.height(look, Screen),
                            id .. " " .. size .. " at the Colorsoft")
                    end)
                end
            end
        end)

        it("differs between the two looks", function()
            harness.at_colorsoft(function()
                assert.is_not.equals(NavBar.height(Looks.get("editorial"), Screen),
                    NavBar.height(Looks.get("diner"), Screen))
            end)
        end)

        it("is the widget's height", function()
            for _, id in ipairs(Looks.ids()) do
                local bar = bar_for(id, "home")
                assert.same({ Screen:getWidth(), NavBar.height(Looks.get(id), Screen) },
                    { bar:getSize().w, bar:getSize().h }, id)
                bar:free()
            end
        end)
    end)

    describe("columns", function()
        it("are five equal shares of the width less the side padding, filling it", function()
            for _, id in ipairs(Looks.ids()) do
                local bar = bar_for(id, "home")
                local pad = scale(Looks.get(id).nav.padding_x)
                local inner = Screen:getWidth() - 2 * pad
                local shares = {}
                for i = 1, 5 do
                    shares[i] = { share = 1 }
                end
                assert.same(Layout.columns(inner, shares, 0), bar.columns, id)
                local last = bar.columns[5]
                assert.equals(inner, last.x + last.w, id)
                bar:free()
            end
        end)

        it("give the tab under a point, and none in the side padding or off the bar", function()
            for _, id in ipairs(Looks.ids()) do
                local bar = bar_for(id, "home")
                local y = bar.dimen.y + 1
                for i, tab in ipairs(NavBar.TABS) do
                    local x, w = column(bar, i)
                    assert.equals(tab, bar:column_at({ x = x, y = y }), id .. " " .. tab.id)
                    assert.equals(tab, bar:column_at({ x = x + w - 1, y = bar.dimen.y + bar.dimen.h - 1 }),
                        id .. " " .. tab.id)
                end
                assert.is_nil(bar:column_at({ x = 10, y = bar.dimen.y - 1 }), id .. " above")
                bar:free()
            end
            local editorial = bar_for("editorial", "home")
            assert.is_nil(editorial:column_at({ x = 1, y = editorial.dimen.y + 5 }))
            assert.is_nil(editorial:column_at({ x = Screen:getWidth() - 1, y = editorial.dimen.y + 5 }))
            editorial:free()
        end)
    end)

    describe("paint", function()
        local function pixel(bb, x, y)
            local c = bb:getPixel(x, y):getColorRGB32()
            return { c:getR(), c:getG(), c:getB() }
        end

        local function rgb(hex)
            local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
            return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
        end

        local function near(a, b, tolerance)
            return math.abs(a[1] - b[1]) <= tolerance and math.abs(a[2] - b[2]) <= tolerance
                and math.abs(a[3] - b[3]) <= tolerance
        end

        -- The bar painted at (0, 0) of a white RGB32 buffer of its size, the buffer, its palette and
        -- a check that (x, y) holds role's colour.
        local function painted(id, where, variant)
            local bar = bar_for(id, where, { variant = variant })
            local size = bar:getSize()
            local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
            bb:fill(Blitbuffer.COLOR_WHITE)
            bar:paintTo(bb, 0, 0)
            local palette = Looks.palette(Looks.get(id), variant)
            local function holds(role, x, y, what)
                local got = pixel(bb, x, y)
                assert.is_true(near(rgb(palette[role]), got, 2), ("%s %s %s: %s at %d,%d is %d,%d,%d"):format(
                    id, variant, what, role, x, y, got[1], got[2], got[3]))
            end
            return bar, bb, holds
        end

        it("draws Editorial's 1 px ink edge across the top and its 3 px rule over the active column only", function()
            harness.at_colorsoft(function()
                for _, variant in ipairs({ "day", "night", "grey" }) do
                    for active, where in ipairs({ "home", "file_browser" }) do
                        local bar, bb, holds = painted("editorial", where, variant)
                        local w = bar:getSize().w
                        local edge, rule = scale(1), scale(3)
                        for _, x in ipairs({ 0, math.floor(w / 2), w - 1 }) do
                            holds("ink", x, 0, where .. " edge top")
                            holds("ink", x, edge - 1, where .. " edge bottom")
                        end
                        local active_x = column(bar, active) + 2
                        holds("ink", active_x, rule - 1, where .. " the rule's bottom")
                        holds("paper", active_x, rule, where .. " under the rule")
                        holds("paper", 2, rule - 1, where .. " the side padding beside the rule")
                        for i = 1, 5 do
                            if i ~= active then
                                holds("paper", column(bar, i) + 2, edge, where .. " column " .. i .. " under the edge")
                                holds("paper", column(bar, i) + 2, rule - 1,
                                    where .. " column " .. i .. " at the rule's bottom")
                            end
                        end
                        bar:free()
                        bb:free()
                    end
                end
            end)
        end)

        it("draws Diner's 4 px ink edge, the mustard active block and outline dividers right of tabs 1-4", function()
            harness.at_colorsoft(function()
                for _, variant in ipairs({ "day", "night", "grey" }) do
                    for active, where in ipairs({ "home", "file_browser" }) do
                        local bar, bb, holds = painted("diner", where, variant)
                        local size = bar:getSize()
                        local edge, divider = scale(4), scale(3)
                        for _, x in ipairs({ 0, math.floor(size.w / 2), size.w - 1 }) do
                            holds("ink", x, 0, where .. " edge top")
                            holds("ink", x, edge - 1, where .. " edge bottom")
                        end
                        for i = 1, 5 do
                            local x, w = column(bar, i)
                            local fill = i == active and "mustard" or "band"
                            holds(fill, x + 2, edge, where .. " column " .. i .. " under the edge")
                            holds(fill, x + 2, size.h - 2, where .. " column " .. i .. " at its foot")
                            holds(fill, x + w - divider - 1, size.h - 2,
                                where .. " column " .. i .. " left of its divider")
                            if i < 5 then
                                holds("outline", x + w - 1, edge, where .. " divider " .. i .. " top")
                                holds("outline", x + w - divider, size.h - 1, where .. " divider " .. i .. " foot")
                            else
                                holds("band", x + w - 1, size.h - 2, where .. " no divider after the last")
                            end
                        end
                        bar:free()
                        bb:free()
                    end
                end
            end)
        end)

        -- The pixels near rgb, within tolerance, in column i's box from y for h rows, short of
        -- trim px at the column's right.
        local function count(bar, bb, i, y0, h, rgb_color, tolerance, trim)
            local x0, w = column(bar, i)
            local n = 0
            for y = y0, y0 + h - 1 do
                for x = x0, x0 + w - (trim or 0) - 1 do
                    if near(rgb_color, pixel(bb, x, y), tolerance) then
                        n = n + 1
                    end
                end
            end
            return n
        end

        it("sets Diner's active label and icon in on_accent, which no other column draws, at night", function()
            harness.at_colorsoft(function()
                local bar, bb = painted("diner", "home", "night")
                local on_accent = rgb(Looks.palette(Looks.get("diner"), "night").on_accent)
                local icon_top, icon_h = scale(4) + scale(14), scale(28)
                local label_top = icon_top + icon_h + scale(6)
                local label_h = bar:getSize().h - label_top
                local boxes = {
                    { "icon", icon_top, icon_h },
                    { "label", label_top, label_h },
                }
                for _, box in ipairs(boxes) do
                    local what, y0, h = box[1], box[2], box[3]
                    local active = count(bar, bb, 1, y0, h, on_accent, 8, scale(3))
                    assert.is_true(active > 0, "the active tab's " .. what .. " has no on_accent pixel")
                    assert.equals(0, count(bar, bb, 2, y0, h, on_accent, 8, scale(3)), "column 2's " .. what)
                end
                bar:free()
                bb:free()
            end)
        end)

        it("sets Editorial's active icon in ink and the others in text, at night", function()
            harness.at_colorsoft(function()
                local bar, bb = painted("editorial", "home", "night")
                local palette = Looks.palette(Looks.get("editorial"), "night")
                local ink, text = rgb(palette.ink), rgb(palette.text)
                local icon_top, icon_h = scale(1) + (scale(3) - scale(1)) + scale(16), scale(26)
                local function counts(i)
                    return count(bar, bb, i, icon_top, icon_h, ink, 2), count(bar, bb, i, icon_top, icon_h, text, 2)
                end
                local active_ink, active_text = counts(1)
                local other_ink, other_text = counts(2)
                assert.is_true(active_ink > 0, "the active icon has no ink pixel")
                assert.equals(0, active_text, "the active icon's text pixels")
                assert.equals(0, other_ink, "column 2's icon's ink pixels")
                assert.is_true(other_text > 0, "column 2's icon has no text pixel")
                bar:free()
                bb:free()
            end)
        end)
    end)

    describe("a tap", function()
        it("in a column runs that tab once with the bar's place and is consumed", function()
            for _, id in ipairs(Looks.ids()) do
                for _, where in ipairs({ "home", "file_browser" }) do
                    local bar = bar_for(id, where)
                    for i, tab in ipairs(NavBar.TABS) do
                        local calls = spy(NavBar, "run")
                        assert.is_true(bar:handle(harness.gesture("tap", centre(bar, i))), tab.id)
                        assert.same({ { tab.id, where } }, calls, id .. " " .. where .. " " .. tab.id)
                    end
                    bar:free()
                end
            end
        end)

        it("in Editorial's side padding is consumed and runs nothing", function()
            local bar = bar_for("editorial", "home")
            local calls = spy(NavBar, "run")
            assert.is_true(bar:handle(harness.gesture("tap", 2, bar.dimen.y + 5)))
            assert.is_true(bar:handle(harness.gesture("tap", Screen:getWidth() - 2, bar.dimen.y + 5)))
            assert.same({}, calls)
            bar:free()
        end)

        it("above the bar is not consumed and runs nothing", function()
            local bar = bar_for("diner", "home")
            local calls = spy(NavBar, "run")
            local x = centre(bar, 1)
            assert.is_false(bar:handle(harness.gesture("tap", x, bar.dimen.y - 1)))
            assert.same({}, calls)
            bar:free()
        end)

        it("on a tab whose run raises is logged with the tab's name and still consumed", function()
            local entries = package.loaded["launcher_entries"]
            spy(entries, "run", "boom")
            local logged = spy(logger, "err")
            local bar = bar_for("diner", "home")
            assert.is_true(bar:handle(harness.gesture("tap", centre(bar, 2))))
            local found = false
            for _, call in ipairs(logged) do
                local text = table.concat({ tostring(call[1]), tostring(call[2]), tostring(call[3]) }, " ")
                found = found or (text:find("Library", 1, true) ~= nil and text:find("boom", 1, true) ~= nil)
            end
            assert.is_true(found, "no log names the Library tab and its error")
            bar:free()
        end)
    end)

    describe("a tab's run", function()
        it("sends Library, Authors and Settings to KoPanda's entries and History to KOReader's", function()
            local entries = package.loaded["launcher_entries"]
            for _, where in ipairs({ "home", "file_browser" }) do
                local calls = spy(entries, "run")
                NavBar.run("library", where)
                NavBar.run("authors", where)
                NavBar.run("history", where)
                NavBar.run("settings", where)
                local passed = {}
                for i, call in ipairs(calls) do
                    passed[i] = call[1]
                end
                assert.same({
                    { kind = "kopanda", target = "library" },
                    { kind = "kopanda", target = "authors" },
                    { kind = "koreader", target = "history" },
                    { kind = "kopanda", target = "settings" },
                }, passed, where)
            end
        end)

        it("Home does nothing on the home and shows the home from the file browser", function()
            local entries = package.loaded["launcher_entries"]
            local entry_calls = spy(entries, "run")
            local fm = harness.show_fm()
            local home_calls = spy(fm.kopanda, "goHome")
            NavBar.run("home", "home")
            assert.same({}, home_calls)
            NavBar.run("home", "file_browser")
            assert.equals(1, #home_calls)
            assert.equals(fm.kopanda, home_calls[1][1])
            assert.same({}, entry_calls)
        end)
    end)

    describe("a hold and other gestures", function()
        it("a hold on any column is consumed and runs nothing", function()
            for _, id in ipairs(Looks.ids()) do
                local bar = bar_for(id, "home")
                local calls = spy(NavBar, "run")
                for i = 1, 5 do
                    assert.is_true(bar:handle(harness.gesture("hold", centre(bar, i))), id .. " " .. i)
                end
                assert.same({}, calls)
                bar:free()
            end
        end)

        it("a swipe on the bar or a hold above it is not consumed", function()
            local bar = bar_for("diner", "home")
            local calls = spy(NavBar, "run")
            local swipe = harness.gesture("swipe", centre(bar, 3))
            swipe.direction = "north"
            assert.is_false(bar:handle(swipe))
            local x = centre(bar, 3)
            assert.is_false(bar:handle(harness.gesture("hold", x, bar.dimen.y - 1)))
            assert.same({}, calls)
            bar:free()
        end)
    end)

    describe("listening", function()
        it("with listen, takes a tap and a hold sent as a Gesture event through handle", function()
            local bar = bar_for("editorial", "home", { listen = true })
            local handled = {}
            bar.handle = function(_, ges)
                handled[#handled + 1] = ges.ges
                return true
            end
            local tap = harness.gesture("tap", centre(bar, 2))
            local hold = harness.gesture("hold", centre(bar, 4))
            assert.is_true(bar:handleEvent(Event:new("Gesture", tap)))
            assert.is_true(bar:handleEvent(Event:new("Gesture", hold)))
            assert.is_falsy((bar:handleEvent(Event:new("Gesture", harness.gesture("tap", 10, bar.dimen.y - 1)))))
            assert.same({ "tap", "hold" }, handled)
            bar:free()
        end)

        it("without listen, has no gesture events", function()
            local bar = bar_for("editorial", "home")
            assert.is_nil(next(bar.ges_events or {}))
            bar:free()
        end)
    end)
end)
