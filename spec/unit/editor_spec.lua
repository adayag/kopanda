-- The editor frame (device menus' C5): the full-screen frame edit layout and launcher management
-- draw in, over a shown home. Its header, body and foot in each look, its taps, keys and Back,
-- one paint per show or refresh, its settled signal and a body too tall for the screen. Every
-- stub of Device.hasKeys, the screen and night_mode is restored where it is made.
describe("the editor frame", function()
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
    local Editor, Home, Looks, Paint, Settings

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    local function centre(rect)
        return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
    end

    local function rgb(hex)
        local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
        return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
    end

    -- The grey KOReader draws a TextWidget in for a #rrggbb (frontend/ui/widget/textwidget.lua:369).
    local function grey(hex)
        local v = Blitbuffer.colorFromString(hex):getColor8().a
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

    -- How many pixels of rect in bb are within tolerance of colour.
    local function count(bb, rect, colour, tolerance)
        local n = 0
        for y = rect.y, rect.y + rect.h - 1 do
            for x = rect.x, rect.x + rect.w - 1 do
                if near(colour, pixel(bb, x, y), tolerance) then
                    n = n + 1
                end
            end
        end
        return n
    end

    local function buffer(w, h)
        local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
        bb:fill(Blitbuffer.COLOR_WHITE)
        return bb
    end

    local function editors_on_stack()
        local n = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_editor" then
                n = n + 1
            end
        end
        return n
    end

    -- Wraps t[name] to record each call's arguments, then call through. Returns the calls and a
    -- function that restores t[name].
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

    -- How many of the calls spied on a logger function carry text.
    local function logged(spied, text)
        local n = 0
        for _, call in ipairs(spied.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    n = n + 1
                end
            end
        end
        return n
    end

    -- A card that paints itself on paper inside its outline, as a screen's card would.
    local function card(ctx, w, h, run)
        local tokens = ctx.look.editor
        local palette = Looks.palette(ctx.look, ctx.variant)
        local outline = ctx.screen:scaleBySize(tokens.card_outline_width)
        return {
            kind = "card",
            rect = { x = 0, y = 0, w = w, h = h },
            draw = function(bb, x, y)
                Paint.fill(bb, x, y, w, h, Looks.color(palette.paper))
                Paint.border(bb, x, y, w, h, outline, Looks.color(palette[tokens.card_outline_color]))
            end,
            run = run,
        }
    end

    -- A body of n cards (default two) and a foot of one button; runs[name] counts the taps on
    -- "card<i>" and "foot", built[1] counts the body's builds.
    local function screen_spec(runs, n, built)
        runs, built = runs or {}, built or {}
        local function counter(name)
            return function()
                runs[name] = (runs[name] or 0) + 1
            end
        end
        return {
            screen = "edit_layout",
            aside = "Home",
            title = "Edit layout",
            body = function(ctx, width)
                built[1] = (built[1] or 0) + 1
                local h, gap = ctx.screen:scaleBySize(80), ctx.screen:scaleBySize(ctx.look.editor.card_gap)
                local rows = {}
                for i = 1, n or 2 do
                    local c = card(ctx, width, h, counter("card" .. i))
                    c.rect.y = i > 1 and gap or 0
                    rows[i] = { c }
                end
                return rows
            end,
            foot = function(ctx)
                local size = ctx.screen:scaleBySize(40)
                return { { { kind = "button", rect = { x = 0, y = 0, w = 3 * size, h = size },
                    run = counter("foot") } } }
            end,
        }
    end

    -- The editor's place for the control i of its body (in tap order, after Done), or the foot's.
    local function body_place(editor, i)
        return editor.places[1 + i]
    end

    before_each(function()
        harness.load()
        Editor = require("editor")
        Home = require("home")
        Looks = require("looks")
        Paint = require("paint")
        Settings = require("settings")
        harness.show_fm()
        harness.tick(4)
        assert.equals(Home.shown, harness.top())
    end)

    after_each(function()
        harness.teardown()
    end)

    describe("drawing", function()
        local bb

        after_each(function()
            if bb then
                bb:free()
                bb = nil
            end
        end)

        -- The two-card editor in look id, painted onto bb.
        local function painted(id)
            assert.is_true(Settings.set("look", id))
            Editor.show(screen_spec())
            local editor = Editor.shown
            assert.is_not_nil(editor)
            local size = Screen:getSize()
            bb = buffer(size.w, size.h)
            editor:paintTo(bb, 0, 0)
            local look = Looks.get(id)
            return editor, look, Looks.palette(look, "day")
        end

        local function scale(px)
            return Screen:scaleBySize(px)
        end

        for _, id in ipairs({ "editorial", "diner" }) do
            it("puts " .. id .. "'s header rule in its colour under the header, and Done in its outline", function()
                local editor, look, palette = painted(id)
                local tokens = look.editor
                local rule = editor.rule
                assert.equals(scale(tokens.header_rule_width), rule.h)
                assert.same({ 0, Screen:getWidth() }, { rule.x, rule.w })
                for _, x in ipairs({ 0, math.floor(rule.w / 2), rule.w - 1 }) do
                    local rule_color = rgb(palette[tokens.header_rule_color])
                    assert.is_true(near(rule_color, pixel(bb, x, rule.y), 1), id .. " " .. x)
                end
                local done = editor.done
                assert.truthy(done.y + done.h <= rule.y, "Done above the rule")
                assert.truthy(done.x + done.w <= Screen:getWidth() - scale(tokens.padding.side) + 1, "Done inset")
                local _, mid = centre(done)
                local border = rgb(palette[tokens.button_outline_color])
                assert.is_true(near(border, pixel(bb, done.x, mid), 1), "Done's border")
            end)
        end

        it("fills Diner's header in band with on_band text", function()
            local editor, _, palette = painted("diner")
            assert.is_true(near(rgb(palette.band), pixel(bb, 2, 2), 1))
            local header = editor.header
            assert.same({ 0, 0, Screen:getWidth(), editor.rule.y }, { header.x, header.y, header.w, header.h })
            assert.truthy(count(bb, header, grey(palette.on_band), 8) > 0, "no on_band text")
            assert.is_true(near(rgb(palette.band), pixel(bb, 2, editor.rule.y - 1), 1), "band down to the rule")
        end)

        it("fills Diner's Done in paper inside its outline, over the band", function()
            local editor, look, palette = painted("diner")
            local done, outline = editor.done, scale(look.editor.button_outline_width)
            assert.equals("paper", look.editor.button_fill_color)
            assert.is_true(near(rgb(palette.paper), pixel(bb, done.x + outline + 1, done.y + outline + 1), 1))
        end)

        it("leaves Editorial's header on paper with ink text", function()
            local editor, _, palette = painted("editorial")
            assert.is_true(near(rgb(palette.paper), pixel(bb, 2, 2), 1))
            assert.truthy(count(bb, editor.header, grey(palette.ink), 8) > 0, "no ink text")
        end)

        it("lays the body out from body_gap below the rule and pins the foot above padding.bottom", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                local editor, look = painted(id)
                local tokens = look.editor
                local first, second = body_place(editor, 1).rect, body_place(editor, 2).rect
                local side = scale(tokens.padding.side)
                assert.same({ side, editor.rule.y + editor.rule.h + scale(tokens.body_gap) }, { first.x, first.y }, id)
                assert.equals(Screen:getWidth() - 2 * side, first.w)
                assert.equals(first.y + first.h + scale(tokens.card_gap), second.y)
                local foot = editor.places[#editor.places].rect
                assert.equals(Screen:getHeight() - scale(tokens.padding.bottom), foot.y + foot.h, id)
                assert.equals(side, foot.x, id)
                bb:free()
                bb = nil
                Editor.close()
            end
        end)

        it("casts Diner's 2 px card shadow under a card and Editorial's none", function()
            local editor, _, palette = painted("diner")
            local rect = body_place(editor, 1).rect
            local right, bottom = rect.x + rect.w, rect.y + rect.h
            local mid_x, mid_y = rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
            assert.is_true(near(rgb(palette.shadow), pixel(bb, right + scale(1) - 1, mid_y), 1), "right shadow")
            assert.is_true(near(rgb(palette.shadow), pixel(bb, mid_x, bottom + scale(1) - 1), 1), "bottom shadow")
            assert.is_true(near(rgb(palette.paper), pixel(bb, right + scale(3) - 1, mid_y), 1), "past the right shadow")
            assert.is_true(near(rgb(palette.paper), pixel(bb, mid_x, bottom + scale(3) - 1), 1),
                "past the bottom shadow")
            assert.is_true(near(rgb(palette.paper), pixel(bb, centre(rect)), 1), "the card over its shadow")
            Editor.close()
            bb:free()

            local look
            editor, look, palette = painted("editorial")
            assert.is_false(look.editor.card_shadow.color)
            rect = body_place(editor, 1).rect
            assert.is_true(near(rgb(palette.paper), pixel(bb, rect.x + rect.w + 1, rect.y + rect.h + 1), 1))
        end)
    end)

    describe("taps", function()
        it("on a card run its run once and keep the editor", function()
            local runs = {}
            Editor.show(screen_spec(runs))
            local editor = Editor.shown
            send(harness.gesture("tap", centre(body_place(editor, 2).rect)))
            assert.same({ card2 = 1 }, runs)
            assert.equals(editor, Editor.shown)
            assert.equals(editor, harness.top())
        end)

        it("on the foot's button run it", function()
            local runs = {}
            Editor.show(screen_spec(runs))
            local editor = Editor.shown
            send(harness.gesture("tap", centre(editor.places[#editor.places].rect)))
            assert.same({ foot = 1 }, runs)
        end)

        it("on blank paper run nothing, are consumed and keep the editor", function()
            local runs = {}
            local routed = spy.on(Home.shown, "routeGesture")
            Editor.show(screen_spec(runs))
            local editor = Editor.shown
            local tap = harness.gesture("tap", 2, editor.rule.y + editor.rule.h + 2)
            assert.is_true(editor:handleEvent(Event:new("Gesture", tap)))
            assert.same({}, runs)
            assert.spy(routed).was_not_called()
            assert.equals(editor, harness.top())
        end)

        it("on Done close the editor with a full refresh and leave the home on top", function()
            local runs = {}
            Editor.show(screen_spec(runs))
            local editor = Editor.shown
            local closed, restore = record(UIManager, "close")
            send(harness.gesture("tap", centre(editor.done)))
            restore()
            assert.same({}, runs)
            assert.is_nil(Editor.shown)
            assert.equals(0, editors_on_stack())
            assert.equals(Home.shown, harness.top())
            assert.equals(1, #closed)
            assert.equals(editor, closed[1][2])
            assert.equals("full", closed[1][3])
        end)

        it("on Done run the spec's done in place of closing, read at the tap", function()
            local runs, dones = {}, 0
            local spec = screen_spec(runs)
            Editor.show(spec)
            local editor = Editor.shown
            spec.done = function()
                dones = dones + 1
            end
            local closed, restore = record(UIManager, "close")
            send(harness.gesture("tap", centre(editor.done)))
            assert.equals(1, dones)
            assert.same({}, runs)
            assert.equals(0, #closed)
            assert.equals(editor, Editor.shown)
            assert.equals(editor, harness.top())
            spec.done = nil
            send(harness.gesture("tap", centre(editor.done)))
            restore()
            assert.equals(1, dones)
            assert.is_nil(Editor.shown)
            assert.equals(1, #closed)
        end)

        it("on a disabled control run nothing", function()
            local runs = {}
            local spec = screen_spec(runs)
            local body = spec.body
            spec.body = function(ctx, width)
                local rows = body(ctx, width)
                rows[2][1].disabled = true
                return rows
            end
            Editor.show(spec)
            local editor = Editor.shown
            send(harness.gesture("tap", centre(body_place(editor, 2).rect)))
            assert.same({}, runs)
            assert.equals(editor, harness.top())
        end)

        it("on a control with no run run nothing, log no error and keep the editor", function()
            local runs = {}
            local spec = screen_spec(runs)
            local body = spec.body
            spec.body = function(ctx, width)
                local rows = body(ctx, width)
                local size = ctx.screen:scaleBySize(30)
                rows[#rows + 1] = { { kind = "caption", rect = { x = 0, y = size, w = width, h = size } } }
                return rows
            end
            Editor.show(spec)
            local editor = Editor.shown
            local caption = body_place(editor, 3)
            assert.equals("caption", caption.control.kind)
            local errors = spy.on(logger, "err")
            send(harness.gesture("tap", centre(caption.rect)))
            errors:revert()
            assert.spy(errors).was_not_called()
            assert.same({}, runs)
            assert.equals(editor, Editor.shown)
            assert.equals(editor, harness.top())
        end)

        it("leave holds, hold releases and swipes alone", function()
            local runs = {}
            Editor.show(screen_spec(runs))
            local editor = Editor.shown
            local x, y = centre(body_place(editor, 2).rect)
            send(harness.gesture("hold", x, y))
            send(harness.gesture("hold_release", x, y))
            local swipe = harness.gesture("swipe", x, y)
            swipe.direction = "west"
            swipe.distance = Screen:scaleBySize(300)
            send(swipe)
            assert.same({}, runs)
            assert.equals(editor, Editor.shown)
            assert.equals(editor, harness.top())
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

        it("closes the editor by the Back key on a device with keys", function()
            Device.hasKeys = function() return true end
            Editor.show(screen_spec())
            Device.hasKeys = has_keys
            assert.is_table(Editor.shown.key_events.Close)
            UIManager:sendEvent(Event:new("KeyPress", Key:new("Back", {})))
            assert.is_nil(Editor.shown)
            assert.equals(0, editors_on_stack())
            assert.equals(Home.shown, harness.top())
        end)

        it("binds no key without keys", function()
            Device.hasKeys = function() return false end
            Editor.show(screen_spec())
            Device.hasKeys = has_keys
            assert.is_nil(Editor.shown.key_events.Close)
        end)

        it("closes the editor on the Back event sent to the top widget", function()
            Editor.show(screen_spec())
            UIManager:sendEvent(Event:new("Back"))
            assert.is_nil(Editor.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("logs a raising key handler and leaves no editor on the stack", function()
            Device.hasKeys = function() return true end
            Editor.show(screen_spec())
            Device.hasKeys = has_keys
            local close, failed = UIManager.close, false
            UIManager.close = function(...)
                if not failed then
                    failed = true
                    error("kopanda-test: close failed")
                end
                return close(...)
            end
            local errors = spy.on(logger, "err")
            local ok = pcall(UIManager.sendEvent, UIManager, Event:new("KeyPress", Key:new("Back", {})))
            UIManager.close = close
            errors:revert()
            assert.is_true(ok)
            assert.equals(1, logged(errors, "kopanda-test: close failed"))
            assert.is_nil(Editor.shown)
            assert.equals(0, editors_on_stack())
            assert.equals(Home.shown, harness.top())
        end)
    end)

    it("closes the first editor when a second is shown", function()
        Editor.show(screen_spec())
        local first = Editor.shown
        Editor.show(screen_spec())
        assert.is_not.equals(first, Editor.shown)
        assert.is_false(UIManager:isWidgetShown(first))
        assert.equals(Editor.shown, harness.top())
        assert.equals(1, editors_on_stack())
    end)

    describe("painting", function()
        it("shows with a full refresh and sets no timer", function()
            local shown, restore_show = record(UIManager, "show")
            local scheduled, restore_scheduled = record(UIManager, "scheduleIn")
            Editor.show(screen_spec())
            harness.tick(3)
            restore_show()
            restore_scheduled()
            assert.equals(1, #shown)
            assert.equals(Editor.shown, shown[1][2])
            assert.equals("full", shown[1][3])
            -- The settled signal's ticks, no timer.
            for _, call in ipairs(scheduled) do
                assert.equals(0, call[2])
            end
        end)

        it("rebuilds from the spec on refresh and asks for one ui repaint", function()
            local built = {}
            Editor.show(screen_spec(nil, 2, built))
            harness.tick(3)
            local editor = Editor.shown
            assert.equals(1, built[1])
            local dirty, restore = record(UIManager, "setDirty")
            editor:refresh()
            restore()
            assert.equals(2, built[1])
            assert.equals(1, #dirty)
            assert.equals(editor, dirty[1][2])
            assert.equals("ui", dirty[1][3])
        end)

        it("rebuilds inside the paint, with no repaint of its own, when night mode turns on", function()
            local had_color = G_reader_settings:has("color_rendering")
            local color_rendering = G_reader_settings:readSetting("color_rendering")
            local night_mode = rawget(Screen, "night_mode")
            G_reader_settings:saveSetting("color_rendering", true)
            Screen.night_mode = false
            finally(function()
                Screen.night_mode = night_mode
                if had_color then
                    G_reader_settings:saveSetting("color_rendering", color_rendering)
                else
                    G_reader_settings:delSetting("color_rendering")
                end
            end)
            local built = {}
            Editor.show(screen_spec(nil, 2, built))
            local editor = Editor.shown
            assert.equals("day", editor.ctx.variant)
            local size = Screen:getSize()
            local bb = buffer(size.w, size.h)
            editor:paintTo(bb, 0, 0)
            Screen.night_mode = true
            local dirty = spy.on(UIManager, "setDirty")
            editor:paintTo(bb, 0, 0)
            dirty:revert()
            bb:free()
            assert.equals("night", editor.ctx.variant)
            assert.equals(2, built[1])
            assert.spy(dirty).was_not_called()
        end)

        it("rebuilds at the new size on the paint after a rotation", function()
            Editor.show(screen_spec())
            local editor = Editor.shown
            local size = Screen:getSize()
            local get_size = Screen.getSize
            local rotated = Geom:new{ x = 0, y = 0, w = size.h, h = size.w }
            Screen.getSize = function() return rotated end
            finally(function()
                Screen.getSize = get_size
            end)
            local bb = buffer(size.h, size.w)
            editor:paintTo(bb, 0, 0)
            bb:free()
            assert.same({ size.h, size.w }, { editor.dimen.w, editor.dimen.h })
            assert.equals(size.h, editor.rule.w)
        end)
    end)

    describe("the settled signal", function()
        local signals, listener

        before_each(function()
            signals = {}
            listener = function(args)
                if args.screen ~= "home" then
                    signals[#signals + 1] = args
                end
            end
            UIManager.event_hook:register("KoPandaSettled", listener)
        end)

        after_each(function()
            UIManager.event_hook:unregister("KoPandaSettled", listener)
        end)

        it("follows the first paint once, with the screen and paint_ms from opts.started", function()
            Editor.show(screen_spec(), { started = { wall = time.monotonic() - time.ms(200), cpu = os.clock() } })
            harness.tick(3)
            assert.equals(1, #signals)
            assert.equals("edit_layout", signals[1].screen)
            assert.is_number(signals[1].paint_ms)
            assert.truthy(signals[1].paint_ms >= 200, signals[1].paint_ms)
            harness.tick(3)
            assert.equals(1, #signals)
        end)

        it("counts paint_ms from the show without opts.started", function()
            local spec = screen_spec()
            spec.screen = "launcher"
            Editor.show(spec)
            harness.tick(3)
            assert.equals(1, #signals)
            assert.equals("launcher", signals[1].screen)
            assert.truthy(signals[1].paint_ms < 200, signals[1].paint_ms)
        end)

        -- The editor, its paint moving the CPU clock on by 300 ms once the paint is done, so a
        -- cpu_ms that ran on to the signal would show it.
        local function late_after_paint(editor, cpu)
            editor.paintTo = function(self, ...)
                Editor.paintTo(self, ...)
                cpu.now = cpu.now + 0.3
            end
        end

        it("counts cpu_ms on the CPU clock from opts.started to the first paint", function()
            harness.with_cpu_clock(10, function(cpu)
                local started = { wall = time.monotonic(), cpu = os.clock() }
                cpu.now = 10.2
                local editor = Editor.show(screen_spec(), { started = started })
                cpu.now = 10.25
                late_after_paint(editor, cpu)
                harness.tick(3)
            end)
            assert.equals(1, #signals)
            assert.equals(250, signals[1].cpu_ms)
        end)

        it("counts cpu_ms from the show without opts.started", function()
            harness.with_cpu_clock(5, function(cpu)
                local editor = Editor.show(screen_spec())
                cpu.now = 5.009
                late_after_paint(editor, cpu)
                harness.tick(3)
            end)
            assert.equals(1, #signals)
            assert.equals(9, signals[1].cpu_ms)
        end)

        it("is not sent when the paint fails", function()
            local spec = screen_spec()
            local body = spec.body
            spec.body = function(ctx, width)
                local rows = body(ctx, width)
                rows[1][1].draw = function()
                    error("kopanda-test: draw failed")
                end
                return rows
            end
            Editor.show(spec)
            harness.tick(3)
            assert.equals(0, #signals)
            assert.is_nil(Editor.shown)
        end)

        it("waits under a full-screen window and follows the first paint", function()
            local WidgetContainer = require("ui/widget/container/widgetcontainer")
            Editor.show(screen_spec())
            local cover = WidgetContainer:new{ covers_fullscreen = true, dimen = Screen:getSize() }
            UIManager:show(cover)
            harness.tick(3)
            assert.equals(0, #signals)
            UIManager:close(cover)
            harness.tick(3)
            assert.equals(1, #signals)
        end)
    end)

    it("keeps the body's rows that fit above the foot when too tall, and logs once", function()
        for _, id in ipairs({ "editorial", "diner" }) do
            assert.is_true(Settings.set("look", id))
            local warned = spy.on(logger, "warn")
            Editor.show(screen_spec(nil, 40))
            local editor = Editor.shown
            local size = Screen:getSize()
            local bb = buffer(size.w, size.h)
            editor:paintTo(bb, 0, 0)
            editor:refresh()
            editor:paintTo(bb, 0, 0)
            bb:free()
            warned:revert()
            local kept = #editor.places - 2
            assert.truthy(kept > 0 and kept < 40, id .. ": " .. kept)
            assert.equals(40 - kept, editor.left_out, id)
            local foot = editor.places[#editor.places].rect
            local last = body_place(editor, kept).rect
            assert.truthy(last.y + last.h <= foot.y, id)
            -- One more card and its gap would not have fit.
            local more = last.h + Screen:scaleBySize(Looks.get(id).editor.card_gap)
            assert.truthy(last.y + last.h + more > foot.y, id)
            assert.equals(1, logged(warned, "leaves out"), id)
            Editor.close()
        end
    end)
end)
