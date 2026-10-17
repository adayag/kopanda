-- The sheet component (sheets' C2): a panel drawn in the look over a shown home, its taps, keys
-- and Back, one sheet at a time, one paint per change, its settled signal, night mode and a
-- sheet too tall for the screen. Every stub of Device.hasKeys, night_mode and color_rendering is
-- restored where it is made.
describe("the sheet", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Device = require("device")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local Key = require("device/key")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local time = require("ui/time")
    local Screen = Device.screen
    local Home, Looks, Sheet

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    local function centre(rect)
        return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
    end

    -- { r, g, b } of a #rrggbb; the grey KOReader draws a TextWidget in for it
    -- (frontend/ui/widget/textwidget.lua:369); and the per-channel inverse of that grey.
    local function rgb(hex)
        local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
        return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
    end

    local function grey(hex)
        local v = Blitbuffer.colorFromString(hex):getColor8().a
        return { v, v, v }
    end

    local function inverse_grey(hex)
        local v = 255 - Blitbuffer.colorFromString(hex):getColor8().a
        return { v, v, v }
    end

    local function near(a, b, tolerance)
        return math.abs(a[1] - b[1]) <= tolerance and math.abs(a[2] - b[2]) <= tolerance
            and math.abs(a[3] - b[3]) <= tolerance
    end

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    -- Every pixel of rect in bb, passed to f.
    local function each_pixel(bb, rect, f)
        for y = rect.y, rect.y + rect.h - 1 do
            for x = rect.x, rect.x + rect.w - 1 do
                f(pixel(bb, x, y))
            end
        end
    end

    -- A white w by h RGB32 buffer, its inverse flag set when night.
    local function buffer(w, h, night)
        local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
        bb:fill(Blitbuffer.COLOR_WHITE)
        if night then
            bb:invert()
        end
        return bb
    end

    -- The Colorsoft's screen, 1264 by 1680, scaled as KOReader scales it by its size
    -- (base/ffi/framebuffer.lua:414).
    local colorsoft = setmetatable({
        getWidth = function() return 1264 end,
        getHeight = function() return 1680 end,
        getSize = function() return Geom:new{ x = 0, y = 0, w = 1264, h = 1680 } end,
    }, { __index = Screen })

    -- The shown home's ctx in look id, on screen (default: the device's).
    local function ctx_for(id, screen)
        local ctx = {}
        for k, v in pairs(Home.shown.ctx) do
            ctx[k] = v
        end
        ctx.look = Looks.get(id)
        ctx.variant = Looks.variant()
        ctx.screen = screen or Screen
        return ctx
    end

    -- A heading sheet of three rows: a plain detail, a status chip and a muted row. runs[i]
    -- counts row i's taps; shown[i] is Sheet.shown when row i ran.
    local function three_rows(runs, shown)
        runs, shown = runs or {}, shown or {}
        local function counter(i)
            return function()
                runs[i] = (runs[i] or 0) + 1
                shown[i] = Sheet.shown or false
            end
        end
        return {
            name = "test",
            band = "home",
            header = { heading = "Home", aside = "KoPanda" },
            rows = {
                { icon = "sun", label = "Refresh weather", detail = "20 min ago", run = counter(1) },
                { icon = "bookmark", label = "Read status", detail = "Reading", chip = "status", run = counter(2) },
                { icon = "moon", label = "Sleep", detail = "not available", muted = true, run = counter(3) },
            },
        }
    end

    -- Wraps t[name] to record each call's arguments as passed (a spy keeps copies), then call
    -- through. Returns the calls and a function that restores t[name].
    local function record(t, name)
        local original, calls = t[name], {}
        t[name] = function(...)
            calls[#calls + 1] = { ... }
            return original(...)
        end
        return calls, function()
            t[name] = original
        end
    end

    local function sheets_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_sheet" then
                count = count + 1
            end
        end
        return count
    end

    -- A stand-in for a book's cover widget, counting its paints and frees; get_size, if given,
    -- replaces its getSize.
    local function stub_cover(get_size)
        local cover = { paints = 0, frees = 0 }
        cover.getSize = get_size or function() return Geom:new{ w = 40, h = 60 } end
        cover.paintTo = function()
            cover.paints = cover.paints + 1
        end
        cover.free = function()
            cover.frees = cover.frees + 1
        end
        return cover
    end

    local function book_sheet(cover)
        local spec = three_rows()
        spec.band = "book"
        spec.header = { cover = cover, title = "A book", author = "An author", meta = "12%" }
        return spec
    end

    -- How many of the calls spied on logger.warn carry text.
    local function warnings(warned, text)
        local count = 0
        for _, call in ipairs(warned.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    count = count + 1
                end
            end
        end
        return count
    end

    before_each(function()
        harness.load()
        Home = require("home")
        Looks = require("looks")
        Sheet = require("sheet")
        harness.show_fm()
        harness.tick(4)
        assert.equals(Home.shown, harness.top())
    end)

    after_each(function()
        harness.teardown()
    end)

    describe("geometry on the Colorsoft", function()
        local bb

        -- The sheet of three_rows in look id at the Colorsoft's size, painted onto bb.
        local function painted(id)
            Sheet.show(three_rows(), ctx_for(id, colorsoft))
            local sheet = Sheet.shown
            assert.is_not_nil(sheet)
            bb = buffer(1264, 1680)
            sheet:paintTo(bb, 0, 0)
            return sheet, Looks.get(id), Looks.palette(Looks.get(id), "day")
        end

        local function scale(px)
            return colorsoft:scaleBySize(px)
        end

        after_each(function()
            if bb then
                bb:free()
                bb = nil
            end
        end)

        it("spans Editorial's panel across the screen on its bottom edge under its ink rule", function()
            local sheet, look, palette = painted("editorial")
            local panel = sheet.panel
            assert.same({ 0, 1264, 1680 }, { panel.x, panel.w, panel.y + panel.h })
            local rule = scale(look.sheet.rule_width)
            assert.truthy(rule > 0)
            for _, x in ipairs({ 0, 632, 1263 }) do
                for y = panel.y, panel.y + rule - 1 do
                    assert.is_true(near(rgb(palette.ink), pixel(bb, x, y), 1), x .. "," .. y)
                end
                assert.is_true(near(rgb(palette.paper), pixel(bb, x, panel.y + rule), 1), "paper under the rule")
            end
            assert.same(panel, sheet.rect)
        end)

        it("insets Diner's panel from the sides and foot in its outline, shadow and band", function()
            local sheet, look, palette = painted("diner")
            local panel, inset = sheet.panel, scale(22)
            assert.same({ inset, 1264 - inset, 1680 - inset }, { panel.x, panel.x + panel.w, panel.y + panel.h })
            local _, mid = centre(panel)
            assert.is_true(near(rgb(palette.outline), pixel(bb, panel.x, mid), 1), "left border")
            assert.is_true(near(rgb(palette.outline), pixel(bb, panel.x + panel.w - 1, mid), 1), "right border")
            local shadow = scale(look.shadow.sheet.x)
            local right, bottom = panel.x + panel.w + shadow - 1, panel.y + panel.h + shadow - 1
            assert.is_true(near(rgb(palette.shadow), pixel(bb, right, bottom), 1), "shadow corner")
            assert.is_true(near({ 255, 255, 255 }, pixel(bb, right + 1, bottom + 1), 1), "past the shadow")
            assert.same({ panel.x, panel.y, panel.w + shadow, panel.h + shadow },
                { sheet.rect.x, sheet.rect.y, sheet.rect.w, sheet.rect.h })
            local header = sheet.header_rect
            assert.is_true(near(rgb(palette.mustard), pixel(bb, header.x + 2, header.y + 2), 1), "home band")
        end)

        it("lays the rows out in order inside the panel, none overlapping", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                local sheet = painted(id)
                assert.equals(3, #sheet.rows, id)
                local panel, above = sheet.panel, sheet.header_rect.y + sheet.header_rect.h
                for i, row in ipairs(sheet.rows) do
                    local rect = row.rect
                    assert.truthy(rect.h > 0, id .. " row " .. i)
                    assert.truthy(rect.y >= above, id .. " row " .. i .. " overlaps the one above")
                    assert.truthy(rect.x >= panel.x and rect.x + rect.w <= panel.x + panel.w, id .. " row " .. i)
                    assert.truthy(rect.y + rect.h <= panel.y + panel.h, id .. " row " .. i)
                    above = rect.y + rect.h
                end
                bb:free()
                bb = nil
                Sheet.close()
            end
        end)

        it("fills Diner's status chip in mustard and leaves Editorial's detail plain", function()
            local sheet, look, palette = painted("diner")
            local chip = sheet.rows[2].detail
            local outline = scale(look.sheet.chip_outline_width)
            local _, mid = centre(chip)
            assert.is_true(near(rgb(palette.outline), pixel(bb, chip.x, mid), 1), "chip outline")
            assert.is_true(near(rgb(palette.mustard), pixel(bb, chip.x + outline + 1, mid), 1), "chip fill")
            Sheet.close()
            bb:free()

            sheet, _, palette = painted("editorial")
            local detail = sheet.rows[2].detail
            local paper, all = 0, 0
            each_pixel(bb, detail, function(p)
                all = all + 1
                if near(rgb(palette.paper), p, 1) then
                    paper = paper + 1
                end
            end)
            assert.truthy(all > 0)
            assert.truthy(paper / all > 0.5, paper .. " of " .. all .. " pixels are paper")
            for _, corner in ipairs({ { detail.x, detail.y }, { detail.x + detail.w - 1, detail.y },
                    { detail.x, detail.y + detail.h - 1 } }) do
                assert.is_true(near(rgb(palette.paper), pixel(bb, corner[1], corner[2]), 1), "corner")
            end
        end)

        it("draws a muted row's label in muted, not ink", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                local sheet, _, palette = painted(id)
                local darkest
                each_pixel(bb, sheet.rows[3].label, function(p)
                    if not darkest or p[1] + p[2] + p[3] < darkest[1] + darkest[2] + darkest[3] then
                        darkest = p
                    end
                end)
                assert.is_false(near(grey(palette.ink), grey(palette.muted), 8), id)
                assert.is_true(near(grey(palette.muted), darkest, 8), id .. " " .. table.concat(darkest, ","))
                Sheet.close()
                bb:free()
                bb = nil
            end
        end)
    end)

    describe("taps", function()
        it("on a row close the sheet, then run that row once", function()
            local runs, shown = {}, {}
            Sheet.show(three_rows(runs, shown), ctx_for("diner"))
            local sheet = Sheet.shown
            send(harness.gesture("tap", centre(sheet.rows[2].rect)))
            assert.same({ [2] = 1 }, runs)
            assert.is_false(shown[2])
            assert.is_nil(Sheet.shown)
            assert.equals(0, sheets_on_stack())
            assert.equals(Home.shown, harness.top())
        end)

        it("on the header run nothing and keep the sheet", function()
            local runs = {}
            Sheet.show(three_rows(runs), ctx_for("editorial"))
            local sheet = Sheet.shown
            -- Consumed, so sendEvent offers it to no window below.
            assert.is_true(sheet:handleEvent(Event:new("Gesture", harness.gesture("tap", centre(sheet.header_rect)))))
            assert.same({}, runs)
            assert.equals(sheet, Sheet.shown)
            assert.equals(sheet, harness.top())
        end)

        it("above the panel close it, run nothing and never reach the home", function()
            local runs = {}
            local home = Home.shown
            local routed = spy.on(home, "routeGesture")
            Sheet.show(three_rows(runs), ctx_for("diner"))
            local sheet = Sheet.shown
            local panel = sheet.panel
            assert.truthy(panel.y > 10)
            local tap = harness.gesture("tap", Screen:getWidth() / 2, math.floor(panel.y / 2))
            assert.is_true(sheet:handleEvent(Event:new("Gesture", tap)))
            assert.same({}, runs)
            assert.is_nil(Sheet.shown)
            assert.spy(routed).was_not_called()
            assert.equals(home, Home.shown)
            assert.equals(home, harness.top())
        end)

        it("on a ticked row only close the sheet", function()
            local runs = {}
            local spec = three_rows(runs)
            spec.rows[1].tick = true
            Sheet.show(spec, ctx_for("editorial"))
            send(harness.gesture("tap", centre(Sheet.shown.rows[1].rect)))
            assert.same({}, runs)
            assert.is_nil(Sheet.shown)
        end)

        it("leave holds, hold releases and swipes in a row alone", function()
            local runs = {}
            Sheet.show(three_rows(runs), ctx_for("diner"))
            local sheet = Sheet.shown
            local x, y = centre(sheet.rows[2].rect)
            send(harness.gesture("hold", x, y))
            send(harness.gesture("hold_release", x, y))
            local swipe = harness.gesture("swipe", x, y)
            swipe.direction = "west"
            swipe.distance = Screen:scaleBySize(300)
            send(swipe)
            assert.same({}, runs)
            assert.equals(sheet, Sheet.shown)
            assert.equals(sheet, harness.top())
            assert.equals(Home.shown, harness.top(2))
        end)
    end)

    describe("a spec's hold", function()
        -- three_rows with a hold that counts its runs in holds.n and records whether the sheet
        -- (holds.sheet) was still up when it ran.
        local function with_hold(runs, holds)
            local spec = three_rows(runs)
            spec.hold = function()
                holds.n = holds.n + 1
                holds.shown = Sheet.shown or false
                holds.stacked = UIManager:isWidgetShown(holds.sheet)
            end
            return spec
        end

        it("runs once on a hold inside the panel, after the sheet has closed", function()
            local runs, holds = {}, { n = 0 }
            Sheet.show(with_hold(runs, holds), ctx_for("editorial"))
            local sheet = Sheet.shown
            holds.sheet = sheet
            send(harness.gesture("hold", centre(sheet.rows[2].rect)))
            assert.equals(1, holds.n)
            assert.is_false(holds.shown)
            assert.is_false(holds.stacked)
            assert.same({}, runs)
            assert.is_nil(Sheet.shown)
            assert.equals(0, sheets_on_stack())
            assert.equals(Home.shown, harness.top())
        end)

        it("runs on a hold on the header too, and the hold_release after it does nothing more", function()
            local runs, holds = {}, { n = 0 }
            Sheet.show(with_hold(runs, holds), ctx_for("diner"))
            local sheet = Sheet.shown
            holds.sheet = sheet
            local x, y = centre(sheet.header_rect)
            send(harness.gesture("hold", x, y))
            send(harness.gesture("hold_release", x, y))
            assert.equals(1, holds.n)
            assert.same({}, runs)
            assert.is_nil(Sheet.shown)
        end)

        it("doesn't run on a hold above the panel, and keeps the sheet", function()
            local runs, holds = {}, { n = 0 }
            Sheet.show(with_hold(runs, holds), ctx_for("diner"))
            local sheet = Sheet.shown
            holds.sheet = sheet
            send(harness.gesture("hold", Screen:getWidth() / 2, math.floor(sheet.panel.y / 2)))
            assert.equals(0, holds.n)
            assert.equals(sheet, Sheet.shown)
            assert.equals(sheet, harness.top())
        end)

        it("closes the sheet and the home and logs when the hold throws", function()
            local errored = spy.on(logger, "err")
            finally(function()
                logger.err:revert()
            end)
            local spec = three_rows()
            spec.hold = function()
                error("kopanda-test: sheet hold failed")
            end
            Sheet.show(spec, ctx_for("editorial"))
            send(harness.gesture("hold", centre(Sheet.shown.rows[1].rect)))
            assert.is_nil(Sheet.shown)
            assert.equals(0, sheets_on_stack())
            assert.is_nil(Home.shown)
            local logged = false
            for _, call in ipairs(errored.calls) do
                for _, arg in ipairs(call.vals) do
                    logged = logged or tostring(arg):find("kopanda-test: sheet hold failed", 1, true) ~= nil
                end
            end
            assert.is_true(logged)
        end)
    end)

    -- The boxes four sheets had before the pickers' additions (cover-grid C10), at the Colorsoft's
    -- size: panel, header, hint, then each row's rect, label and detail, "-" for none. The
    -- iconless rows are the editor's picker sheets (edit_layout.lua:153-212), which keep the indent.
    describe("a sheet with none of the pickers' additions", function()
        local SPECS = {
            plain = three_rows(),
            folder = { name = "t", band = "folder",
                rows = { { icon = "sun", label = "Weather", detail = "KoPanda" } },
                header = { heading = "Tools", aside = "Folder · 3", aside_beside = true, hint = "Hold to edit" } },
            picker = { name = "t", band = "home", header = { heading = "Width" },
                rows = { { label = "1", tick = true }, { label = "2" }, { label = "Clock" } } },
            bare = { name = "t", band = "home", header = { heading = "Add a widget" },
                rows = { { label = "Clock" }, { label = "Weather" } } },
        }
        local BEFORE = {
            editorial = {
                plain = "0 1195 1264 485|85 1200 1094 111|-|"
                    .. "85 1314 1094 111 166 1356 126 27 1102 1359 77 20|"
                    .. "85 1428 1094 111 166 1470 90 27 1121 1473 58 20|"
                    .. "85 1542 1094 79 166 1584 43 27 1077 1587 102 20",
                folder = "0 1423 1264 257|85 1428 1094 111|1088 1482 91 20|"
                    .. "85 1542 1094 79 166 1584 65 27 1117 1587 62 20",
                picker = "0 1195 1264 485|85 1200 1094 111|-|85 1314 1094 111 166 1356 10 27 -|"
                    .. "85 1428 1094 111 166 1470 10 27 -|85 1542 1094 79 166 1584 44 27 -",
                bare = "0 1309 1264 371|85 1314 1094 111|-|85 1428 1094 111 166 1470 44 27 -|"
                    .. "85 1542 1094 79 166 1584 65 27 -",
            },
            diner = {
                plain = "47 1168 1170 465|54 1175 1156 101|-|"
                    .. "54 1283 1156 111 174 1326 140 25 1087 1329 80 19|"
                    .. "54 1399 1156 111 174 1442 100 25 1066 1435 101 38|"
                    .. "54 1515 1156 111 174 1558 47 25 1064 1561 103 19",
                folder = "47 1400 1170 233|54 1407 1156 101|1082 1442 85 32|"
                    .. "54 1515 1156 111 174 1558 71 25 1103 1561 64 19",
                picker = "47 1168 1170 465|54 1175 1156 101|-|54 1283 1156 111 174 1326 6 25 -|"
                    .. "54 1399 1156 111 174 1442 10 25 -|54 1515 1156 111 174 1558 47 25 -",
                bare = "47 1284 1170 349|54 1291 1156 101|-|54 1399 1156 111 174 1442 47 25 -|"
                    .. "54 1515 1156 111 174 1558 71 25 -",
            },
        }

        local function box(rect)
            return rect and table.concat({ rect.x, rect.y, rect.w, rect.h }, " ") or "-"
        end

        for _, id in ipairs({ "editorial", "diner" }) do
            it("keeps the boxes it had before them in " .. id, function()
                for name, spec in pairs(SPECS) do
                    Sheet.show(spec, ctx_for(id, colorsoft))
                    local sheet = Sheet.shown
                    local out = { box(sheet.panel), box(sheet.header_rect), box(sheet.hint_rect) }
                    for _, row in ipairs(sheet.rows) do
                        out[#out + 1] = box(row.rect) .. " " .. box(row.label) .. " " .. box(row.detail)
                    end
                    assert.equals(BEFORE[id][name], table.concat(out, "|"), id .. " " .. name)
                end
            end)
        end
    end)

    -- The sort sheet's shape (SortC.dc.html:38-69): the aside over the heading, a label at the
    -- header's right, iconless rows set flush, each with a second line, the first selected.
    describe("the pickers' additions", function()
        local bb

        after_each(function()
            if bb then
                bb:free()
                bb = nil
            end
        end)

        local function sort_spec()
            return { name = "sort", band = "home", flush = true,
                header = { heading = "Sort", aside = "for this folder", aside_above = true, label = "Library" },
                rows = { { label = "Recent", sublabel = "Last opened first", selected = true },
                    { label = "Title", sublabel = "A to Z" } } }
        end

        -- How many pixels of rect in bb are near colour c.
        local function inked(rect, c)
            local n = 0
            each_pixel(bb, rect, function(p)
                n = n + (near(c, p, 8) and 1 or 0)
            end)
            return n
        end

        for _, id in ipairs({ "editorial", "diner" }) do
            it("build and paint in " .. id, function()
                Sheet.show(sort_spec(), ctx_for(id, colorsoft))
                local sheet, look = Sheet.shown, Looks.get(id)
                local tokens, palette = look.sheet, Looks.palette(look, "day")
                local function scale(px)
                    return colorsoft:scaleBySize(px)
                end
                local header, parts = sheet.header_rect, sheet.header_parts
                assert.equals(parts.heading.x, parts.aside.x)
                assert.equals(parts.aside.y + parts.aside.h + scale(tokens.aside_above_gap), parts.heading.y)
                assert.truthy(parts.aside.y >= header.y and parts.heading.y + parts.heading.h <= header.y + header.h)
                assert.equals(header.x + header.w - scale(tokens.header_padding.side), parts.label.x + parts.label.w)
                assert.truthy(parts.label.x > parts.heading.x + parts.heading.w)
                for i, row in ipairs(sheet.rows) do
                    assert.equals(row.rect.x + scale(tokens.row_padding.x), row.label.x, "flush " .. i)
                    assert.equals(row.label.x, row.sublabel.x, i)
                    assert.equals(row.label.y + row.label.h + scale(tokens.sublabel_gap), row.sublabel.y, i)
                end
                local first, second = sheet.rows[1], sheet.rows[2]
                assert.equals(first.rect.x + first.rect.w - scale(tokens.row_padding.x), first.check.x + first.check.w)
                assert.is_nil(second.check)
                bb = buffer(1264, 1680)
                sheet:paintTo(bb, 0, 0)
                assert.truthy(inked(parts.label, grey(palette[look.type.sheet_label.color])) > 0, "label")
                assert.truthy(inked(parts.aside, grey(palette[look.type.sheet_aside.color])) > 0, "aside")
                assert.truthy(inked(first.sublabel, grey(palette[look.type.sheet_sublabel.color])) > 0, "sublabel")
                assert.truthy(inked(first.check, grey(palette.ink)) > 0, "check")
                local fill = tokens.selected_fill_color and palette[tokens.selected_fill_color] or palette.paper
                assert.is_true(near(rgb(fill), pixel(bb, first.rect.x + 2, first.rect.y + 2), 1), "selected fill")
                assert.is_true(near(rgb(palette.paper), pixel(bb, second.rect.x + 2, second.rect.y + 2), 1), "plain")
            end)
        end
    end)

    -- A sheet's failure closes the screen it was shown over (opts.beneath), the home without one.
    describe("a failure with opts.beneath", function()
        local closed, beneath

        before_each(function()
            closed = 0
            beneath = { close = function() closed = closed + 1 end }
        end)

        it("closes that screen and not the home when a hold throws", function()
            local spec = three_rows()
            spec.hold = function()
                error("kopanda-test: sheet hold failed")
            end
            Sheet.show(spec, ctx_for("editorial"), { beneath = beneath })
            send(harness.gesture("hold", centre(Sheet.shown.rows[1].rect)))
            assert.same({ 1, 0 }, { closed, sheets_on_stack() })
            assert.equals(Home.shown, harness.top())
        end)

        it("closes that screen and not the home when the show raises, or the paint", function()
            Sheet.show(book_sheet(stub_cover(function() error("kopanda-test: cover size failed") end)),
                ctx_for("diner"), { beneath = beneath })
            assert.same({ 1, 0 }, { closed, sheets_on_stack() })
            local cover = stub_cover()
            cover.paintTo = function()
                error("kopanda-test: paint failed")
            end
            Sheet.show(book_sheet(cover), ctx_for("diner"), { beneath = beneath })
            harness.tick(3)
            assert.same({ 2, 0 }, { closed, sheets_on_stack() })
            assert.equals(Home.shown, harness.top())
        end)
    end)

    describe("a heading's hint", function()
        local bb

        after_each(function()
            if bb then
                bb:free()
                bb = nil
            end
        end)

        for _, id in ipairs({ "editorial", "diner" }) do
            it("is drawn in sheet_aside at the header's right, past the heading and its aside, in " .. id, function()
                local spec = three_rows()
                spec.header = { heading = "Tools", aside = "Folder · 3", aside_beside = true, hint = "Hold to edit" }
                Sheet.show(spec, ctx_for(id, colorsoft))
                local sheet = Sheet.shown
                local look = Looks.get(id)
                local palette = Looks.palette(look, "day")
                local header, hint = sheet.header_rect, sheet.hint_rect
                assert.is_table(hint)
                local inner_right = header.x + header.w - colorsoft:scaleBySize(look.sheet.header_padding.side)
                assert.equals(inner_right, hint.x + hint.w)
                assert.truthy(hint.w > 0 and hint.h > 0)
                assert.truthy(hint.x > header.x + header.w / 2, "right of the heading")
                assert.truthy(hint.y >= header.y and hint.y + hint.h <= header.y + header.h)
                bb = buffer(1264, 1680)
                sheet:paintTo(bb, 0, 0)
                local inked = 0
                each_pixel(bb, hint, function(p)
                    if near(grey(palette[look.type.sheet_aside.color]), p, 8) then
                        inked = inked + 1
                    end
                end)
                assert.truthy(inked > 0, "no pixel of the hint in its colour")
            end)
        end

        it("is absent without a hint", function()
            Sheet.show(three_rows(), ctx_for("editorial"))
            assert.is_nil(Sheet.shown.hint_rect)
        end)
    end)

    describe("Back", function()
        local has_keys

        before_each(function()
            has_keys = Device.hasKeys
        end)

        after_each(function()
            Device.hasKeys = has_keys
        end)

        it("closes the sheet by the Back key on a device with keys", function()
            Device.hasKeys = function() return true end
            Sheet.show(three_rows(), ctx_for("diner"))
            Device.hasKeys = has_keys
            assert.is_table(Sheet.shown.key_events.Close)
            UIManager:sendEvent(Event:new("KeyPress", Key:new("Back", {})))
            assert.is_nil(Sheet.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("binds no key without keys", function()
            Device.hasKeys = function() return false end
            Sheet.show(three_rows(), ctx_for("diner"))
            Device.hasKeys = has_keys
            assert.is_nil(Sheet.shown.key_events.Close)
        end)

        it("closes the sheet on the Back event sent to the top widget", function()
            Sheet.show(three_rows(), ctx_for("editorial"))
            UIManager:sendEvent(Event:new("Back"))
            assert.is_nil(Sheet.shown)
            assert.equals(Home.shown, harness.top())
        end)
    end)

    it("closes the first sheet when a second is shown", function()
        Sheet.show(three_rows(), ctx_for("diner"))
        local first = Sheet.shown
        Sheet.show(three_rows(), ctx_for("diner"))
        local second = Sheet.shown
        assert.is_not.equals(first, second)
        assert.is_false(UIManager:isWidgetShown(first))
        assert.equals(second, harness.top())
        assert.equals(1, sheets_on_stack())
    end)

    it("frees the first sheet's cover once when a second is shown over it", function()
        local first = stub_cover()
        Sheet.show(book_sheet(first), ctx_for("diner"))
        assert.equals(0, first.frees)
        local second = stub_cover()
        Sheet.show(book_sheet(second), ctx_for("diner"))
        assert.equals(1, first.frees)
        assert.equals(0, second.frees)
        Sheet.close()
        assert.equals(1, first.frees)
        assert.equals(1, second.frees)
    end)

    describe("a cover whose show fails", function()
        local show = UIManager.show

        after_each(function()
            UIManager.show = show
        end)

        local function failed_once(cover)
            Sheet.show(book_sheet(cover), ctx_for("diner"))
            assert.equals(0, sheets_on_stack())
            assert.is_nil(Sheet.shown)
            assert.equals(1, cover.frees)
        end

        it("is freed once when the build raises", function()
            failed_once(stub_cover(function() error("kopanda-test: cover size failed") end))
        end)

        it("is freed once when UIManager:show raises before stacking the sheet", function()
            UIManager.show = function()
                error("kopanda-test: show failed")
            end
            failed_once(stub_cover())
        end)

        it("is freed once when UIManager:show raises after stacking the sheet", function()
            UIManager.show = function(...)
                show(...)
                error("kopanda-test: show failed late")
            end
            failed_once(stub_cover())
        end)
    end)

    it("does nothing when closed with no sheet shown", function()
        Sheet.close()
        assert.is_nil(Sheet.shown)
        assert.equals(Home.shown, harness.top())
    end)

    describe("painting", function()
        it("asks for one ui refresh of its rectangle on show and sets no timer", function()
            local dirty, restore_dirty = record(UIManager, "setDirty")
            local scheduled, restore_scheduled = record(UIManager, "scheduleIn")
            Sheet.show(three_rows(), ctx_for("diner"))
            harness.tick(3)
            restore_dirty()
            restore_scheduled()
            local sheet = Sheet.shown
            assert.equals(1, #dirty)
            assert.equals(sheet, dirty[1][2])
            assert.equals("ui", dirty[1][3])
            assert.equals(sheet.rect, dirty[1][4])
            -- The settled signal's nextTick, no timer.
            assert.truthy(#scheduled > 0)
            for _, call in ipairs(scheduled) do
                assert.equals(0, call[2])
            end
        end)

        it("closes with a flashui refresh of its rectangle and repaints the home", function()
            Sheet.show(three_rows(), ctx_for("diner"))
            harness.tick(3)
            local sheet, home = Sheet.shown, Home.shown
            local closed, restore = record(UIManager, "close")
            local painted = spy.on(home, "paintTo")
            Sheet.close()
            restore()
            assert.equals(1, #closed)
            assert.equals(sheet, closed[1][2])
            assert.equals("flashui", closed[1][3])
            assert.equals(sheet.rect, closed[1][4])
            harness.tick(1)
            assert.spy(painted).was_called(1)
            assert.is_nil(Sheet.shown)
        end)
    end)

    describe("the settled signal", function()
        local signals, listener

        before_each(function()
            signals = {}
            listener = function(args)
                if args.screen == "sheet" then
                    signals[#signals + 1] = args
                end
            end
            UIManager.event_hook:register("KoPandaSettled", listener)
        end)

        after_each(function()
            UIManager.event_hook:unregister("KoPandaSettled", listener)
        end)

        it("follows the first paint once, with the sheet's name and paint_ms", function()
            Sheet.show(three_rows(), ctx_for("diner"))
            harness.tick(3)
            assert.equals(1, #signals)
            assert.equals("test", signals[1].name)
            assert.is_number(signals[1].paint_ms)
            harness.tick(2)
            assert.equals(1, #signals)
        end)

        it("is not sent when the paint fails", function()
            local spec = three_rows()
            spec.header = {
                title = "A book",
                cover = {
                    getSize = function() return Geom:new{ w = 20, h = 30 } end,
                    paintTo = function() error("kopanda-test: paint failed") end,
                    free = function() end,
                },
            }
            Sheet.show(spec, ctx_for("diner"))
            harness.tick(3)
            assert.equals(0, #signals)
        end)

        it("waits, without polling, under a full-screen window and follows the first paint once", function()
            local WidgetContainer = require("ui/widget/container/widgetcontainer")
            Sheet.show(three_rows(), ctx_for("diner"))
            local cover = WidgetContainer:new{ covers_fullscreen = true, dimen = Screen:getSize() }
            UIManager:show(cover)
            -- A sheet that re-arms while unpainted spins handleInput's loop; this ends it in an error.
            local next_tick, calls = UIManager.nextTick, 0
            UIManager.nextTick = function(...)
                calls = calls + 1
                if calls > 50 then
                    error("kopanda-test: over 50 nextTicks while covered")
                end
                return next_tick(...)
            end
            finally(function()
                UIManager.nextTick = next_tick
            end)
            harness.tick(3)
            assert.is_nil(Sheet.shown.painted_at)
            assert.equals(0, #signals)
            UIManager:close(cover)
            harness.tick(3)
            assert.equals(1, #signals)
            assert.equals("test", signals[1].name)
        end)

        it("counts paint_ms from opts.started, and from the show without it", function()
            Sheet.show(three_rows(), ctx_for("diner"), { started = time.monotonic() - time.ms(200) })
            harness.tick(3)
            assert.equals(1, #signals)
            assert.truthy(signals[1].paint_ms >= 200, signals[1].paint_ms)
            Sheet.show(three_rows(), ctx_for("diner"))
            harness.tick(3)
            assert.equals(2, #signals)
            assert.truthy(signals[2].paint_ms < 200, signals[2].paint_ms)
        end)
    end)

    describe("night mode", function()
        local had_color, color_rendering, night_mode, bb

        before_each(function()
            had_color = G_reader_settings:has("color_rendering")
            color_rendering = G_reader_settings:readSetting("color_rendering")
            night_mode = rawget(Screen, "night_mode")
            G_reader_settings:saveSetting("color_rendering", true)
            Screen.night_mode = false
        end)

        after_each(function()
            Screen.night_mode = night_mode
            if had_color then
                G_reader_settings:saveSetting("color_rendering", color_rendering)
            else
                G_reader_settings:delSetting("color_rendering")
            end
            if bb then
                bb:free()
                bb = nil
            end
        end)

        -- bb's stored pixels, read through a copy with the flag cleared, as Screen:shot does in
        -- night mode (base/ffi/framebuffer.lua:566-581). The caller frees it.
        local function panel_view()
            local view = bb:copy()
            if view:getInverse() == 1 then
                view:invert()
            end
            return view
        end

        it("stores Diner's designed night band and on_accent heading under the inversion", function()
            Screen.night_mode = true
            Sheet.show(three_rows(), ctx_for("diner"))
            local sheet = Sheet.shown
            assert.equals("night", sheet.variant)
            local size = Screen:getSize()
            bb = buffer(size.w, size.h, true)
            sheet:paintTo(bb, 0, 0)
            local view = panel_view()
            local look = Looks.get("diner")
            local night, day = look.palettes.night, look.palettes.day
            local band, heading, day_heading = 0, 0, 0
            each_pixel(view, sheet.header_rect, function(p)
                if near(rgb(night.mustard), p, 1) then
                    band = band + 1
                end
                if near(grey(night.on_accent), p, 8) then
                    heading = heading + 1
                end
                if near(inverse_grey(day.on_accent), p, 8) then
                    day_heading = day_heading + 1
                end
            end)
            view:free()
            assert.truthy(band > 0, "no night mustard")
            assert.truthy(heading > 0, "no night on_accent")
            assert.equals(0, day_heading)
        end)

        it("keeps a book header's cover across a night rebuild and frees it once on close", function()
            local cover = stub_cover()
            Sheet.show(book_sheet(cover), ctx_for("diner"))
            local sheet = Sheet.shown
            local size = Screen:getSize()
            bb = buffer(size.w, size.h, false)
            sheet:paintTo(bb, 0, 0)
            assert.equals(1, cover.paints)
            Screen.night_mode = true
            bb:setInverse(1)
            sheet:paintTo(bb, 0, 0)
            assert.equals("night", sheet.variant)
            assert.equals(0, cover.frees)
            assert.equals(2, cover.paints)
            Sheet.close()
            assert.equals(1, cover.frees)
        end)

        it("logs the rows it leaves out once, not again on a night rebuild", function()
            local spec = three_rows()
            for i = 4, 40 do
                spec.rows[i] = { icon = "list", label = "Entry " .. i, run = function() end }
            end
            local warned = spy.on(logger, "warn")
            Sheet.show(spec, ctx_for("diner"))
            local sheet = Sheet.shown
            local size = Screen:getSize()
            bb = buffer(size.w, size.h, false)
            sheet:paintTo(bb, 0, 0)
            Screen.night_mode = true
            bb:setInverse(1)
            sheet:paintTo(bb, 0, 0)
            warned:revert()
            assert.equals("night", sheet.variant)
            assert.equals(1, warnings(warned, "leaves out"))
        end)

        it("built by day rebuilds inside the first paint after night mode turns on", function()
            Sheet.show(three_rows(), ctx_for("diner"))
            local sheet = Sheet.shown
            assert.equals("day", sheet.variant)
            local size = Screen:getSize()
            bb = buffer(size.w, size.h, false)
            sheet:paintTo(bb, 0, 0)
            local day_panel = sheet.panel_widget
            local dirty = spy.on(UIManager, "setDirty")
            Screen.night_mode = true
            bb:setInverse(1)
            sheet:paintTo(bb, 0, 0)
            dirty:revert()
            assert.equals("night", sheet.variant)
            assert.is_not.equals(day_panel, sheet.panel_widget)
            assert.spy(dirty).was_not_called()
            local view = panel_view()
            local header = sheet.header_rect
            local p = pixel(view, header.x + 2, header.y + 2)
            view:free()
            assert.is_true(near(rgb(Looks.get("diner").palettes.night.mustard), p, 1), table.concat(p, ","))
        end)
    end)

    it("keeps as many rows as fit when too tall for the screen and logs once", function()
        -- Screen heights over more than a row's height (114 px at this scale) in 10 px steps, so
        -- on some of them the room left above the panel is under Diner's foot inset.
        for step = 0, 12 do
            local h = 1680 + 10 * step
            local screen = setmetatable({
                getWidth = function() return 1264 end,
                getHeight = function() return h end,
                getSize = function() return Geom:new{ x = 0, y = 0, w = 1264, h = h } end,
            }, { __index = Screen })
            for _, id in ipairs({ "editorial", "diner" }) do
                local where = id .. " at " .. h
                local warned = spy.on(logger, "warn")
                local spec = three_rows()
                spec.rows = {}
                for i = 1, 40 do
                    spec.rows[i] = { icon = "list", label = "Entry " .. i, detail = "Plugin", run = function() end }
                end
                Sheet.show(spec, ctx_for(id, screen))
                warned:revert()
                local sheet = Sheet.shown
                assert.is_not_nil(sheet, where)
                assert.truthy(#sheet.rows > 0 and #sheet.rows < 40, where .. ": " .. #sheet.rows)
                for i, row in ipairs(sheet.rows) do
                    local rect = row.rect
                    assert.truthy(rect.y >= 0 and rect.y + rect.h <= h, where .. " row " .. i)
                    assert.equals(spec.rows[i], row.row, where .. " row " .. i .. " out of order")
                end
                -- The panel stays on the screen, and one more row (its height and a rule) would not.
                local panel, look = sheet.panel, Looks.get(id)
                assert.truthy(panel.y >= 0, where .. ": panel.y " .. panel.y)
                local more = sheet.rows[1].rect.h + screen:scaleBySize(look.sheet.row_rule_width)
                assert.truthy(panel.y < more, where .. ": " .. panel.y .. " px left, room for a row of " .. more)
                if id == "diner" then
                    assert.equals(h - screen:scaleBySize(22), panel.y + panel.h, where)
                end
                local logged = 0
                for _, call in ipairs(warned.calls) do
                    for _, arg in ipairs(call.vals) do
                        if tostring(arg):find("leaves out", 1, true) then
                            logged = logged + 1
                        end
                    end
                end
                assert.equals(1, logged, where)
                Sheet.close()
            end
        end
    end)

    it("leaves a missing icon's place blank and logs it once per build", function()
        local spec = three_rows()
        spec.rows[1].icon = "kopanda-test-none"
        spec.rows[2].icon = "kopanda-test-none"
        local warned = spy.on(logger, "warn")
        Sheet.show(spec, ctx_for("editorial"))
        warned:revert()
        assert.equals(3, #Sheet.shown.rows)
        assert.equals(1, warnings(warned, "kopanda-test-none"))
    end)

    it("draws a header alone, and rows alone with no header", function()
        local spec = three_rows()
        spec.rows = {}
        Sheet.show(spec, ctx_for("diner"))
        assert.equals(0, #Sheet.shown.rows)
        assert.is_not_nil(Sheet.shown.header_rect)
        spec = three_rows()
        spec.header = nil
        Sheet.show(spec, ctx_for("diner"))
        assert.is_nil(Sheet.shown.header_rect)
        assert.equals(3, #Sheet.shown.rows)
        assert.equals(Sheet.shown, harness.top())
    end)
end)
