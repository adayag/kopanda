-- The swatch screen (C8): Tools › KoPanda › Swatches in the file manager and the reader shows
-- every look's palettes, faces and the icon registry full screen; a tap closes it, and a failure
-- in its build, paint or gestures leaves the app it was opened from on top and usable.
describe("the swatch screen", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local Geom = require("ui/geometry")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local time = require("ui/time")
    local Fonts, Icons, Looks, Swatch, logged, settled_listener
    local original_paint = InputContainer.paintTo
    local original_color_enabled = Screen.isColorEnabled
    local original_now = time.now
    local original_repaint = UIManager._repaint

    local function swatches_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_swatch" then
                count = count + 1
            end
        end
        return count
    end

    local function find(list, id)
        for _, item in ipairs(list) do
            if item.id == id then
                return item
            end
        end
    end

    local function texts(items)
        local list = {}
        for _, item in ipairs(items) do
            list[#list + 1] = item.text
        end
        return list
    end

    -- Tools › KoPanda in a menu's tabs.
    local function kopanda_item(tabs)
        local tools = find(tabs, "tools")
        assert.is_table(tools)
        local item = find(tools, "kopanda")
        assert.is_table(item)
        return item
    end

    local function swatches_item(tabs)
        for _, item in ipairs(kopanda_item(tabs).sub_item_table) do
            if item.text == "Swatches" then
                return item
            end
        end
        error("no Swatches item")
    end

    local function tap_mid()
        local size = Screen:getSize()
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 2)))
    end

    local function tap_top()
        local size = Screen:getSize()
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", size.w / 2, size.h / 16)))
    end

    -- The file manager with its home closed by a mid-screen tap.
    local function fm_without_home()
        local fm = harness.show_fm()
        harness.tick(2)
        tap_mid()
        assert.equals(fm, harness.top())
        return fm
    end

    -- Runs Tools › KoPanda › Swatches as the menu does: the callback, the menu closing, then the
    -- callback's next tick.
    local function open_from_fm()
        local fm = fm_without_home()
        fm.menu:onShowMenu()
        local item = swatches_item(fm.menu.tab_item_table)
        item.callback()
        fm.menu:onCloseFileManagerMenu()
        harness.tick()
        return fm
    end

    local function open_from_reader()
        local reader = harness.open_reader()
        harness.tick()
        reader.menu:onShowMenu()
        local item = swatches_item(reader.menu.tab_item_table)
        item.callback()
        reader.menu:onCloseReaderMenu()
        harness.tick()
        return reader
    end

    local function logged_error(text)
        for _, call in ipairs(logged.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    -- The file manager is on top with no swatch and takes a tap: one in the top menu zone opens
    -- its menu (filemanagermenu.lua:72-90).
    local function file_manager_usable()
        local fm = FileManager.instance
        assert.equals(0, swatches_on_stack())
        assert.equals(fm, harness.top())
        tap_top()
        assert.is_not_nil(fm.menu.menu_container)
        assert.equals(fm.menu.menu_container, harness.top())
        fm.menu:onCloseFileManagerMenu()
        assert.equals(fm, harness.top())
    end

    -- The reader is on top with no swatch and takes a tap: one in the top menu zone opens its
    -- menu (readermenu.lua:95-107, :495-502).
    local function reader_usable(reader)
        assert.equals(0, swatches_on_stack())
        assert.equals(reader, harness.top())
        tap_top()
        assert.is_not_nil(reader.menu.menu_container)
        reader.menu:onCloseReaderMenu()
    end

    -- Every widget under widget, depth first in child order, widget itself first.
    local function walk(widget, visit)
        visit(widget)
        for _, child in ipairs(widget) do
            walk(child, visit)
        end
    end

    local function collect(widget, pred)
        local found = {}
        walk(widget, function(w)
            if pred(w) then
                found[#found + 1] = w
            end
        end)
        return found
    end

    local function named(name)
        return function(w)
            return w.name == name
        end
    end

    local function has_text(w)
        return type(w.text) == "string"
    end

    local function same_color(a, b)
        a, b = a:getColorRGB32(), b:getColorRGB32()
        return a.r == b.r and a.g == b.g and a.b == b.b
    end

    local function sorted_keys(t)
        local keys = {}
        for key in pairs(t) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        return keys
    end

    before_each(function()
        harness.load()
        Fonts = require("fonts")
        Icons = require("icons")
        Looks = require("looks")
        Swatch = require("swatch")
        logged = spy.on(logger, "err")
    end)

    after_each(function()
        if settled_listener then
            UIManager.event_hook:unregister("KoPandaSettled", settled_listener)
            settled_listener = nil
        end
        time.now = original_now
        UIManager._repaint = original_repaint
        InputContainer.paintTo = original_paint
        Screen.isColorEnabled = original_color_enabled
        G_reader_settings:delSetting("night_mode")
        logger.err:revert()
        harness.teardown()
    end)

    describe("Tools › KoPanda › Swatches", function()
        it("follows Home, Settings and Studio in the file manager's and the reader's Tools", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.same({ "Home", "Settings", "Studio", "Swatches" },
                texts(kopanda_item(fm.menu.tab_item_table).sub_item_table))
            fm.menu:onCloseFileManagerMenu()
            fm:onClose()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            assert.same({ "Home", "Settings", "Studio", "Swatches" },
                texts(kopanda_item(reader.menu.tab_item_table).sub_item_table))
        end)

        it("shows a full-screen swatch over the file manager that a tap closes", function()
            local fm = open_from_fm()
            local top = harness.top()
            assert.equals("kopanda_swatch", top.name)
            assert.is_true(top.covers_fullscreen)
            assert.equals(1, swatches_on_stack())
            tap_mid()
            assert.equals(0, swatches_on_stack())
            assert.equals(fm, harness.top())
        end)

        it("shows a full-screen swatch over the book that a tap closes", function()
            local reader = open_from_reader()
            local top = harness.top()
            assert.equals("kopanda_swatch", top.name)
            assert.is_true(top.covers_fullscreen)
            tap_mid()
            assert.equals(0, swatches_on_stack())
            assert.equals(reader, harness.top())
        end)

        it("announces its first paint with the settled signal on screen swatch", function()
            local events = {}
            settled_listener = function(args)
                events[#events + 1] = args
            end
            UIManager.event_hook:register("KoPandaSettled", settled_listener)
            open_from_fm()
            harness.tick(2)
            local swatch_events = {}
            for _, args in ipairs(events) do
                if args.screen == "swatch" then
                    swatch_events[#swatch_events + 1] = args
                end
            end
            assert.equals(1, #swatch_events)
            assert.is_number(swatch_events[1].paint_ms)
            assert.is_truthy(harness.top().painted_at)
        end)

        -- The swatch's paint moves the CPU clock on by 300 ms once the paint is done, so a cpu_ms
        -- that ran on to the signal would show it.
        it("counts cpu_ms on the CPU clock from the show to the first paint", function()
            local events = {}
            settled_listener = function(args)
                if args.screen == "swatch" then
                    events[#events + 1] = args
                end
            end
            UIManager.event_hook:register("KoPandaSettled", settled_listener)
            fm_without_home()
            harness.with_cpu_clock(3, function(cpu)
                Swatch.show()
                cpu.now = 3.04
                harness.top().paintTo = function(self, ...)
                    Swatch.paintTo(self, ...)
                    cpu.now = cpu.now + 0.3
                end
                harness.tick(3)
            end)
            assert.equals(1, #events)
            assert.equals(40, events[1].cpu_ms)
        end)

        -- UIManager runs a task scheduled during a task in the same pass, before the repaint,
        -- when time.now() hasn't moved past the pass's start (frontend/ui/uimanager.lua:1081-1104,
        -- 447-456, 1537-1564): so a tickAfterNext from the show can land before the first paint.
        describe("while the clock stands still", function()
            -- Holds UIManager's clock (time.now) where it is until the test ends, then opens the
            -- swatch and ticks; returns each swatch signal with the swatch as it stood then and
            -- whether it came from inside UIManager's repaint.
            local function settle_held()
                local frozen = original_now()
                time.now = function()
                    return frozen
                end
                local in_repaint = false
                UIManager._repaint = function(...)
                    in_repaint = true
                    local ok, err = pcall(original_repaint, ...)
                    in_repaint = false
                    if not ok then
                        error(err, 0)
                    end
                end
                local events = {}
                settled_listener = function(args)
                    if args.screen == "swatch" then
                        local top = harness.top()
                        events[#events + 1] = {
                            args = args,
                            painted_at = top.painted_at,
                            started = top.started,
                            in_repaint = in_repaint,
                        }
                    end
                end
                UIManager.event_hook:register("KoPandaSettled", settled_listener)
                open_from_fm()
                harness.tick(3)
                return events
            end

            it("sends the signal once, after the first paint, with that paint's paint_ms", function()
                local events = settle_held()
                assert.equals(1, #events)
                assert.is_not_nil(events[1].painted_at)
                assert.equals(time.to_ms(events[1].painted_at.wall - events[1].started.wall), events[1].args.paint_ms)
                assert.is_false(events[1].in_repaint)
                UIManager:setDirty(harness.top(), "full")
                harness.tick(2)
                assert.equals(1, #events)
            end)

            it("sends no signal for a paint that throws", function()
                InputContainer.paintTo = function(self, ...)
                    if self.name == "kopanda_swatch" then
                        error("kopanda-test: swatch paint failed")
                    end
                    return original_paint(self, ...)
                end
                assert.same({}, settle_held())
                assert.is_true(logged_error("kopanda-test: swatch paint failed"))
                assert.is_false(logged_error("the swatch settled signal failed"))
            end)
        end)
    end)

    -- Screen:isColorEnabled as the device answers it (frontend/device/generic/device.lua:265-271).
    local function color_enabled(on)
        Screen.isColorEnabled = function()
            return on
        end
    end

    describe("its content", function()
        local swatch

        before_each(function()
            color_enabled(true)
            open_from_fm()
            swatch = harness.top()
            assert.equals("kopanda_swatch", swatch.name)
        end)

        it("has six panels, the looks across and day, night and grey down", function()
            local panels = collect(swatch, named("kopanda_swatch_panel"))
            local order = {}
            for _, panel in ipairs(panels) do
                order[#order + 1] = panel.look .. " " .. panel.variant
            end
            local expected = {}
            for _, variant in ipairs({ "day", "night", "grey" }) do
                for _, id in ipairs(Looks.ids()) do
                    expected[#expected + 1] = id .. " " .. variant
                end
            end
            assert.same(expected, order)
        end)

        -- A role the look lacks (false) gets no chip and no line of its own.
        it("draws a chip with role and hex in ink for each role the palette has, in role order", function()
            for _, panel in ipairs(collect(swatch, named("kopanda_swatch_panel"))) do
                local where = panel.look .. " " .. panel.variant
                local palette = Looks.get(panel.look).palettes[panel.variant]
                local ink = Looks.color(palette.ink)
                assert.is_true(same_color(Looks.color(palette.paper), panel.color))
                local chips = collect(panel, named("kopanda_swatch_chip"))
                local labels = collect(panel, has_text)
                local expected_roles, chip_roles, expected_lines, lines = {}, {}, {}, {}
                for _, role in ipairs(sorted_keys(palette)) do
                    local hex = palette[role]
                    if hex then
                        expected_roles[#expected_roles + 1] = role
                        expected_lines[#expected_lines + 1] = role .. " " .. hex
                    end
                end
                for _, chip in ipairs(chips) do
                    chip_roles[#chip_roles + 1] = chip.role
                    assert.is_true(same_color(Looks.color(palette[chip.role]), chip.color), where .. " " .. chip.role)
                    assert.is_true(same_color(ink, chip.border_color))
                end
                table.sort(chip_roles)
                assert.same(expected_roles, chip_roles)
                -- Every line that starts with a role name: the chip labels, in role order.
                for _, w in ipairs(labels) do
                    if palette[w.text:match("^(%S+)")] ~= nil then
                        lines[#lines + 1] = w.text
                        assert.is_true(same_color(ink, w.fgcolor))
                        assert.is_true(same_color(Looks.color(palette.paper), w.bgcolor))
                    end
                end
                assert.same(expected_lines, lines, where)
            end
        end)

        -- Where the line goes is the "where the lacks text goes" cases'.
        it("names the roles a palette lacks, in role order, on one line", function()
            for _, panel in ipairs(collect(swatch, named("kopanda_swatch_panel"))) do
                local where = panel.look .. " " .. panel.variant
                local palette = Looks.get(panel.look).palettes[panel.variant]
                local missing = {}
                for _, role in ipairs(sorted_keys(palette)) do
                    if not palette[role] then
                        missing[#missing + 1] = role
                    end
                end
                assert.truthy(#missing > 0, where .. " lacks nothing; this test needs a lacking role")
                local lacks = collect(panel, named("kopanda_swatch_lacks"))
                assert.equals(1, #lacks, where)
                local line = lacks[1]
                assert.equals("lacks: " .. table.concat(missing, ", "), line.text)
                assert.is_true(same_color(Looks.color(palette.ink), line.fgcolor))
                assert.is_true(same_color(Looks.color(palette.paper), line.bgcolor))
                assert.equals(1, #line.vertical_string_list, where .. " lacks line wraps")
            end
        end)

        it("draws a line per face in that face, naming it", function()
            for _, panel in ipairs(collect(swatch, named("kopanda_swatch_panel"))) do
                local faces = Looks.get(panel.look).faces
                local lines = collect(panel, named("kopanda_swatch_face"))
                local expected = 0
                for _, role in ipairs(sorted_keys(faces)) do
                    local face = faces[role]
                    if face.file then
                        expected = expected + 1
                        local line
                        for _, w in ipairs(lines) do
                            if w.face.realname == Fonts.face_name(face.file) then
                                line = w
                            end
                        end
                        assert.is_table(line, panel.look .. " " .. role)
                        assert.truthy(line.text:find(face.label, 1, true))
                    end
                end
                assert.equals(expected, #lines)
            end
        end)

        -- Each panel's paint stops at its box, but its content paints on past it: content taller
        -- than the panel runs into the panel or the icons below.
        it("fits every panel's content inside its panel, and the panels and icons on the screen", function()
            for _, panel in ipairs(collect(swatch, named("kopanda_swatch_panel"))) do
                local size = panel[1]:getSize()
                local where = panel.look .. " " .. panel.variant
                assert.truthy(size.h <= panel.dimen.h - 2 * panel.inset, where .. " h " .. size.h)
                assert.truthy(size.w <= panel.dimen.w - 2 * panel.inset, where .. " w " .. size.w)
            end
            local frame = swatch[1]
            assert.truthy(frame[1]:getSize().h <= Screen:getHeight() - 2 * frame.padding)
        end)

        it("draws every registered icon with its id beneath", function()
            local icons = collect(swatch, named("kopanda_swatch_icon"))
            assert.equals(#Icons.entries, #icons)
            for i, entry in ipairs(Icons.entries) do
                local cell = icons[i]
                assert.equals(entry.id, cell.icon_id)
                local images = collect(cell, function(w)
                    return w.file ~= nil
                end)
                assert.equals(1, #images)
                assert.equals(Icons.path(entry.id), images[1].file)
                assert.is_true(images[1].alpha)
                local ids = collect(cell, function(w)
                    return w.text == entry.id
                end)
                assert.equals(1, #ids)
            end
        end)

        it("has no night mode note with night mode off", function()
            local notes = collect(swatch, function(w)
                return has_text(w) and w.text:find("Night mode", 1, true) ~= nil
            end)
            assert.same({}, notes)
        end)
    end)

    -- The emulator's grey profile keeps an RGB32 framebuffer (base/ffi/framebuffer_SDL3.lua:20-23,
    -- :85-86), where an RGB32 paint keeps its hue; a grey panel's BB8 framebuffer would grey it by
    -- luminance. The swatch draws those greys itself, so both show what the panel does.
    it("draws every colour in KOReader's luminance grey when colour is off", function()
        color_enabled(false)
        open_from_fm()
        local swatch = harness.top()
        local panels = collect(swatch, named("kopanda_swatch_panel"))
        assert.equals(6, #panels)
        local function grey_of(hex)
            return Looks.color(hex):getColor8()
        end
        for _, panel in ipairs(panels) do
            local palette = Looks.get(panel.look).palettes[panel.variant]
            assert.is_true(Blitbuffer.isColor8(panel.color))
            assert.equals(grey_of(palette.paper).a, panel.color.a)
            for _, chip in ipairs(collect(panel, named("kopanda_swatch_chip"))) do
                assert.is_true(Blitbuffer.isColor8(chip.color))
                assert.equals(grey_of(palette[chip.role]).a, chip.color.a)
                assert.equals(grey_of(palette.ink).a, chip.border_color.a)
            end
            for _, w in ipairs(collect(panel, has_text)) do
                assert.equals(grey_of(palette.ink).a, w.fgcolor.a)
                assert.equals(grey_of(palette.paper).a, w.bgcolor.a)
            end
        end
    end)

    -- The golden profiles' sizes (spec/emulator/profiles.lua), where Diner's 14 chips, on_accent
    -- among them, leave the lacks text no empty cell: every face line still ends inside its
    -- panel.
    it("fits every panel's content inside its panel at the Colorsoft's and the Paperwhite's sizes", function()
        local roles = 0
        for _, hex in pairs(Looks.get("diner").palettes.day) do
            if hex then
                roles = roles + 1
            end
        end
        assert.equals(14, roles)
        color_enabled(true)
        local stubbed = { "getWidth", "getHeight", "getSize" }
        local saved = {}
        for _, name in ipairs(stubbed) do
            saved[name] = rawget(Screen, name)
        end
        finally(function()
            for _, name in ipairs(stubbed) do
                rawset(Screen, name, saved[name])
            end
        end)
        for _, size in ipairs({ { 1264, 1680 }, { 1236, 1648 } }) do
            local w, h = size[1], size[2]
            rawset(Screen, "getWidth", function() return w end)
            rawset(Screen, "getHeight", function() return h end)
            rawset(Screen, "getSize", function() return Geom:new{ x = 0, y = 0, w = w, h = h } end)
            local swatch = Swatch:new{}
            local panels = collect(swatch, named("kopanda_swatch_panel"))
            assert.equals(6, #panels)
            for _, panel in ipairs(panels) do
                local where = w .. "x" .. h .. " " .. panel.look .. " " .. panel.variant
                local content = panel[1]:getSize()
                assert.truthy(content.h <= panel.dimen.h - 2 * panel.inset,
                    where .. ": content " .. content.h .. " in " .. (panel.dimen.h - 2 * panel.inset))
                assert.truthy(content.w <= panel.dimen.w - 2 * panel.inset, where .. " w " .. content.w)
            end
            local frame = swatch[1]
            assert.truthy(frame[1]:getSize().h <= h - 2 * frame.padding, w .. "x" .. h .. " overall")
            swatch:free()
        end
    end)

    it("draws no lacks line for a palette that lacks nothing", function()
        local palette = Looks.get("editorial").palettes.day
        for role, hex in pairs(palette) do
            if not hex then
                palette[role] = "#808080"
            end
        end
        color_enabled(true)
        open_from_fm()
        local swatch = harness.top()
        local checked = 0
        for _, panel in ipairs(collect(swatch, named("kopanda_swatch_panel"))) do
            local lacks = collect(panel, named("kopanda_swatch_lacks"))
            if panel.look == "editorial" and panel.variant == "day" then
                checked = checked + 1
                assert.same({}, lacks)
                assert.same({}, collect(panel, function(w)
                    return has_text(w) and w.text:find("lacks", 1, true) ~= nil
                end))
            else
                assert.equals(1, #lacks, panel.look .. " " .. panel.variant)
            end
        end
        assert.equals(1, checked)
    end)

    describe("where the lacks text goes", function()
        local TextWidget = require("ui/widget/textwidget")

        -- Editorial's day palette with the first `fill` of its lacking roles given a colour, the
        -- swatch painted, and that panel with its lacks text, chip labels and face lines in their
        -- painted places.
        local function editorial_day(fill)
            local palette = Looks.get("editorial").palettes.day
            local filled = 0
            for _, role in ipairs(sorted_keys(palette)) do
                if not palette[role] and filled < fill then
                    palette[role] = "#808080"
                    filled = filled + 1
                end
            end
            color_enabled(true)
            open_from_fm()
            local swatch = harness.top()
            swatch:paintTo(Blitbuffer.new(Screen:getWidth(), Screen:getHeight(), Blitbuffer.TYPE_BBRGB32), 0, 0)
            local panel
            for _, p in ipairs(collect(swatch, named("kopanda_swatch_panel"))) do
                if p.look == "editorial" and p.variant == "day" then
                    panel = p
                end
            end
            local lacks = collect(panel, named("kopanda_swatch_lacks"))
            assert.equals(1, #lacks)
            return {
                panel = panel,
                chips = #collect(panel, named("kopanda_swatch_chip")),
                chip_xs = (function()
                    local xs = {}
                    for _, c in ipairs(collect(panel, named("kopanda_swatch_chip"))) do
                        xs[#xs + 1] = c.dimen.x
                    end
                    return xs
                end)(),
                lacks = lacks[1],
                labels = collect(panel, function(w)
                    return has_text(w) and palette[w.text:match("^(%S+)")] ~= nil
                end),
                faces = collect(panel, named("kopanda_swatch_face")),
            }
        end

        -- The chip labels by column: the right column's x and label width, and each column's
        -- last label.
        local function columns(labels)
            local left_x, right_x = math.huge, -math.huge
            for _, w in ipairs(labels) do
                left_x = math.min(left_x, w.dimen.x)
                right_x = math.max(right_x, w.dimen.x)
            end
            local col = { right_x = right_x }
            for _, w in ipairs(labels) do
                if w.dimen.x == left_x then
                    col.last_left = w
                else
                    col.last_right = w
                end
            end
            col.right_w = col.last_right.width
            return col
        end

        local function text_w(w)
            return TextWidget:new{ text = w.text, face = w.face }:getSize().w
        end

        -- A full-width line at the content's left edge, below every chip label, above the faces.
        local function assert_own_line(placed)
            local lacks = placed.lacks
            local bottom = 0
            for _, w in ipairs(placed.labels) do
                bottom = math.max(bottom, w.dimen.y + w:getSize().h)
            end
            assert.equals(placed.panel.dimen.x + placed.panel.inset, lacks.dimen.x)
            assert.is_true(lacks.dimen.y >= bottom, "lacks y " .. lacks.dimen.y .. " above " .. bottom)
            assert.is_true(lacks.dimen.y + lacks:getSize().h <= placed.faces[1].dimen.y)
            assert.equals(1, #lacks.vertical_string_list)
        end

        it("goes in the empty last cell, from its chip x, for an odd chip count when it fits", function()
            local placed = editorial_day(6)
            assert.equals(1, placed.chips % 2)
            local col = columns(placed.labels)
            local lacks = placed.lacks
            assert.equals("lacks: teal", lacks.text)
            -- The cell's left edge: the right column's chip x, and the whole cell's width.
            local chip_x = math.max(unpack(placed.chip_xs))
            assert.equals(chip_x, lacks.dimen.x)
            assert.equals(col.last_left.dimen.y, lacks.dimen.y)
            assert.is_true(lacks.dimen.y > col.last_right.dimen.y)
            assert.equals(col.right_x - chip_x + col.right_w, lacks.width)
            assert.equals(1, #lacks.vertical_string_list)
            assert.is_true(lacks.dimen.y + lacks:getSize().h <= placed.faces[1].dimen.y)
        end)

        it("goes on the heading's line, from the right column's chip x, for an even chip count when it fits", function()
            local placed = editorial_day(5)
            assert.equals(0, placed.chips % 2)
            local col = columns(placed.labels)
            local lacks = placed.lacks
            assert.equals("lacks: pink, teal", lacks.text)
            local chip_x = math.max(unpack(placed.chip_xs))
            assert.equals(chip_x, lacks.dimen.x)
            assert.equals(col.right_x - chip_x + col.right_w, lacks.width)
            assert.equals(1, #lacks.vertical_string_list)
            -- Above every chip label, inside the panel's padding.
            local top = math.huge
            for _, w in ipairs(placed.labels) do
                top = math.min(top, w.dimen.y)
            end
            assert.is_true(lacks.dimen.y + lacks:getSize().h <= top, "lacks ends below the first chip row")
            assert.is_true(lacks.dimen.y >= placed.panel.dimen.y + placed.panel.inset)
        end)

        it("goes on its own line after the chips for an even chip count wider than a column's label", function()
            local placed = editorial_day(1)
            assert.equals(0, placed.chips % 2)
            assert.is_true(text_w(placed.lacks) > columns(placed.labels).right_w,
                "premise: " .. placed.lacks.text .. " fits a column")
            assert_own_line(placed)
        end)

        it("goes on its own line after the chips when it is wider than a column's label", function()
            local placed = editorial_day(0)
            assert.equals(1, placed.chips % 2)
            assert.is_true(text_w(placed.lacks) > columns(placed.labels).right_w,
                "premise: " .. placed.lacks.text .. " fits a column")
            assert_own_line(placed)
        end)
    end)

    it("still opens, in KOReader's UI font, with a face that won't load, and says so", function()
        Fonts.face = function()
            return nil
        end
        open_from_fm()
        local swatch = harness.top()
        assert.equals("kopanda_swatch", swatch.name)
        local lines = collect(swatch, named("kopanda_swatch_face"))
        assert.truthy(#lines > 0)
        for _, line in ipairs(lines) do
            assert.truthy(line.text:find("(did not load)", 1, true))
        end
    end)

    it("says above the panels that night mode inverts the colours when it is on", function()
        G_reader_settings:saveSetting("night_mode", true)
        open_from_fm()
        local swatch = harness.top()
        local notes = collect(swatch, function(w)
            return has_text(w) and w.text:find("Night mode is on", 1, true) ~= nil
        end)
        assert.equals(1, #notes)
        assert.truthy(notes[1].text:find("Turn it off to judge them", 1, true))
        -- Above the panels: met before the first panel in child order.
        local seen_note, note_first = false, nil
        walk(swatch, function(w)
            if w == notes[1] then
                seen_note = true
            elseif w.name == "kopanda_swatch_panel" and note_first == nil then
                note_first = seen_note
            end
        end)
        assert.is_true(note_first)
    end)

    describe("failing safe", function()
        local function paint_fails()
            InputContainer.paintTo = function(self, ...)
                if self.name == "kopanda_swatch" then
                    error("kopanda-test: swatch paint failed")
                end
                return original_paint(self, ...)
            end
        end

        it("leaves the file manager on top when the build throws", function()
            Swatch.init = function()
                error("kopanda-test: swatch build failed")
            end
            open_from_fm()
            harness.tick(2)
            assert.is_true(logged_error("kopanda-test: swatch build failed"))
            file_manager_usable()
        end)

        it("closes over the file manager when the paint throws", function()
            paint_fails()
            open_from_fm()
            harness.tick(3)
            assert.is_true(logged_error("kopanda-test: swatch paint failed"))
            file_manager_usable()
        end)

        it("closes over the file manager when the tap handler throws", function()
            open_from_fm()
            harness.top().close = function()
                error("kopanda-test: swatch tap failed")
            end
            tap_mid()
            assert.is_true(logged_error("kopanda-test: swatch tap failed"))
            file_manager_usable()
        end)

        it("leaves the reader on top when the build throws", function()
            Swatch.init = function()
                error("kopanda-test: swatch build failed")
            end
            local reader = open_from_reader()
            harness.tick(2)
            assert.is_true(logged_error("kopanda-test: swatch build failed"))
            reader_usable(reader)
        end)

        it("closes over the reader when the paint throws", function()
            paint_fails()
            local reader = open_from_reader()
            harness.tick(3)
            assert.is_true(logged_error("kopanda-test: swatch paint failed"))
            reader_usable(reader)
        end)

        it("closes over the reader when the tap handler throws", function()
            local reader = open_from_reader()
            harness.top().close = function()
                error("kopanda-test: swatch tap failed")
            end
            tap_mid()
            assert.is_true(logged_error("kopanda-test: swatch tap failed"))
            reader_usable(reader)
        end)
    end)
end)
