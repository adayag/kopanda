-- The quick-settings sheet's panel (bars/quick-settings C4): QuickSettings.open shows one sheet
-- named quick_settings over the home or the bare file browser; its header, its brightness and
-- warmth bars read from the power device in native steps, its six cells read from the radio,
-- the settings and the launcher's entries, greyed where they can't run; its paint in both looks
-- by day, at night and in grey; its fit on the Colorsoft at every text size; and its ten areas.
-- Every stub of Device, its power device, NetworkMgr, the plugin list, the dispatcher and
-- G_reader_settings is put back after the test that makes it.
describe("the quick-settings sheet", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Device = require("device")
    local Dispatcher = require("dispatcher")
    local NetworkMgr = require("ui/network/manager")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local time = require("ui/time")
    local Screen = Device.screen
    local powerd = Device:getPowerDevice()
    local Home, Icons, LauncherEntries, Looks, QuickSettings, Settings, Sheet

    -- Undo steps for the running test, run last first after it.
    local undo = {}

    -- t[key] = value for the rest of the test; the raw value it had is put back after.
    local function set(t, key, value)
        local old = rawget(t, key)
        undo[#undo + 1] = function()
            rawset(t, key, old)
        end
        rawset(t, key, value)
    end

    -- G_reader_settings' key saved as value for the rest of the test.
    local function setting(key, value)
        local had, old = G_reader_settings:has(key), G_reader_settings:readSetting(key)
        undo[#undo + 1] = function()
            if had then
                G_reader_settings:saveSetting(key, old)
            else
                G_reader_settings:delSetting(key)
            end
        end
        G_reader_settings:saveSetting(key, value)
    end

    -- The power device on the Kindle's 0-24 scales (frontend/device/kindle/powerd.lua:8-11), with
    -- the warmth scale its new sets (frontend/device/generic/powerd.lua:38), the light on at
    -- intensity and the warmth at native.
    local function kindle_light(intensity, native)
        set(powerd, "fl_max", 24)
        set(powerd, "fl_warmth_max", 24)
        set(powerd, "warmth_scale", 100 / 24)
        set(powerd, "fl_intensity", intensity)
        set(powerd, "is_fl_on", intensity > 0)
        set(powerd, "fl_warmth", powerd:fromNativeWarmth(native))
    end

    local function errors(errored, text)
        local count = 0
        for _, call in ipairs(errored.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    count = count + 1
                end
            end
        end
        return count
    end

    local function scale(px)
        return Screen:scaleBySize(px)
    end

    local function rgb(hex)
        local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
        return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
    end

    -- The grey KOReader draws a TextWidget in for a colour (frontend/ui/widget/textwidget.lua:369).
    local function grey(hex)
        local v = Blitbuffer.colorFromString(hex):getColor8().a
        return { v, v, v }
    end

    local function near(a, b, tolerance)
        tolerance = tolerance or 2
        return math.abs(a[1] - b[1]) <= tolerance and math.abs(a[2] - b[2]) <= tolerance
            and math.abs(a[3] - b[3]) <= tolerance
    end

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    -- The darkest pixel of rect in bb: a line's full-coverage ink.
    local function darkest(bb, rect)
        local best
        for y = rect.y, rect.y + rect.h - 1 do
            for x = rect.x, rect.x + rect.w - 1 do
                local p = pixel(bb, x, y)
                if not best or p[1] + p[2] + p[3] < best[1] + best[2] + best[3] then
                    best = p
                end
            end
        end
        return best
    end

    -- The brightest pixel of rect in bb: a light line's full-coverage ink on a dark fill.
    local function brightest(bb, rect)
        local best
        for y = rect.y, rect.y + rect.h - 1 do
            for x = rect.x, rect.x + rect.w - 1 do
                local p = pixel(bb, x, y)
                if not best or p[1] + p[2] + p[3] > best[1] + best[2] + best[3] then
                    best = p
                end
            end
        end
        return best
    end

    -- The first x from x0 toward x1 (by step) on row y whose pixel is near colour, or nil.
    local function scan(bb, x0, x1, y, colour)
        local step = x1 >= x0 and 1 or -1
        for x = x0, x1, step do
            if near(pixel(bb, x, y), colour) then
                return x
            end
        end
    end

    -- How many pixels from x on row y, rightward, are near colour before one isn't.
    local function run_of(bb, x, y, colour)
        local n = 0
        while near(pixel(bb, x + n, y), colour) do
            n = n + 1
        end
        return n
    end

    -- A line's text: a TextWidget's, or a tracked line's glyphs joined.
    local function text_of(widget)
        if widget.text then
            return widget.text
        end
        local parts = {}
        for _, child in ipairs(widget) do
            parts[#parts + 1] = child.text
        end
        return table.concat(parts)
    end

    -- The body widget's lines and icons, each { text, icon, x, y, w, h }, from origin.
    local function parts_of(body, origin)
        local out = {}
        for i, widget in ipairs(body) do
            local place, size = body.places[i], widget:getSize()
            out[#out + 1] = { text = text_of(widget), icon = widget.file, x = origin.x + place.x,
                y = origin.y + place.y, w = size.w, h = size.h }
        end
        return out
    end

    local function find(parts, text)
        for _, part in ipairs(parts) do
            if part.text == text then
                return part
            end
        end
    end

    local function inside(part, rect)
        return part.x >= rect.x and part.y >= rect.y and part.x + part.w <= rect.x + rect.w
            and part.y + part.h <= rect.y + rect.h
    end

    -- The shown sheet's header lines' texts and the body's parts on the screen.
    local function sheet_parts(sheet)
        local panel, header, body = sheet.panel_widget, {}, nil
        for i, widget in ipairs(panel) do
            if widget.name == "kopanda_quick_settings" then
                body = parts_of(widget, panel.places[i])
            else
                header[#header + 1] = text_of(widget)
            end
        end
        return header, body
    end

    -- QuickSettings.body for look id in variant at the Colorsoft, the sheet's content width,
    -- painted onto the variant's paper; fn(made, bb, areas by id, parts). Freed after.
    local function build(id, variant, fn)
        harness.at_colorsoft(function()
            local look = Looks.get(id)
            local ctx = { look = look, variant = variant, text_size = Settings.get("text_size"), now = os.time(),
                screen = Screen }
            local content_w = 1264 - 2 * scale(look.sheet.inset.side) - 2 * scale(look.sheet.padding.side)
                - (look.sheet.outline_color and 2 * scale(look.stroke.outline) or 0)
            local made = QuickSettings.body(ctx, content_w)
            local size = made.widget:getSize()
            assert.equals(content_w, size.w)
            local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
            bb:paintRectRGB32(0, 0, size.w, size.h, Looks.color(Looks.palette(look, variant).paper))
            made.widget:paintTo(bb, 0, 0)
            local by_id = {}
            for _, area in ipairs(made.areas) do
                by_id[area.id] = area.rect
            end
            local ok, err = pcall(fn, made, bb, by_id, parts_of(made.widget, { x = 0, y = 0 }))
            bb:free()
            made.widget:free()
            if not ok then
                error(err, 0)
            end
        end)
    end

    local CELLS = { "wifi", "night", "rotation_lock", "sync_books", "screenshot", "sleep" }

    -- The cell's label part, inside its rect.
    local function label_in(parts, rect)
        for _, part in ipairs(parts) do
            if part.text ~= "" and inside(part, rect) then
                return part
            end
        end
    end

    local function icon_in(parts, rect)
        for _, part in ipairs(parts) do
            if part.icon and inside(part, rect) then
                return part
            end
        end
    end

    -- A pixel just inside a cell's outline, in its top padding, where nothing but its fill is.
    local function cell_inside(bb, rect, look)
        local outline = scale(look.quick_settings.cell_outline_width)
        return pixel(bb, rect.x + outline + 2, rect.y + outline + 2)
    end

    before_each(function()
        undo = {}
        harness.load()
        Home = require("home")
        Icons = require("icons")
        LauncherEntries = require("launcher_entries")
        Looks = require("looks")
        QuickSettings = require("quick_settings")
        Settings = require("settings")
        Sheet = require("sheet")
        setting("emulator_fake_wifi_connected", true)
        harness.show_fm()
        harness.tick(4)
        assert.equals(Home.shown, harness.top())
    end)

    after_each(function()
        for i = #undo, 1, -1 do
            undo[i]()
        end
        undo = {}
        harness.teardown()
        Settings._reset()
    end)

    describe("opening", function()
        local function sheets_on_stack()
            local count = 0
            for _, widget in ipairs(harness.stack()) do
                if widget.name == "kopanda_sheet" then
                    count = count + 1
                end
            end
            return count
        end

        it("shows one sheet named quick_settings over the home, whose settled signal names it", function()
            local signals = {}
            local function listener(args)
                if args.screen == "sheet" then
                    signals[#signals + 1] = args
                end
            end
            UIManager.event_hook:register("KoPandaSettled", listener)
            undo[#undo + 1] = function()
                UIManager.event_hook:unregister("KoPandaSettled", listener)
            end
            local home = Home.shown
            QuickSettings.open{ started = time.monotonic() }
            harness.tick(3)
            local sheet = Sheet.shown
            assert.equals("quick_settings", sheet.spec.name)
            assert.equals(sheet, harness.top())
            assert.equals(home, harness.top(2))
            assert.equals(1, sheets_on_stack())
            assert.equals(1, #signals)
            assert.equals("quick_settings", signals[1].name)
        end)

        it("shows over the bare file browser with no home", function()
            local fm = harness.top(2)
            Home.close()
            assert.is_nil(Home.shown)
            assert.equals(fm, harness.top())
            QuickSettings.open{}
            local sheet = Sheet.shown
            assert.equals("quick_settings", sheet.spec.name)
            assert.equals(sheet, harness.top())
            assert.equals(fm, harness.top(2))
            assert.equals(1, sheets_on_stack())
        end)
    end)

    describe("the header", function()
        it("reads Quick settings with the battery's capacity at its right, in both looks", function()
            set(powerd, "getCapacity", function() return 84 end)
            for _, id in ipairs({ "editorial", "diner" }) do
                Settings.set("look", id)
                QuickSettings.open{}
                local sheet = Sheet.shown
                local header = sheet_parts(sheet)
                assert.equals(2, #header, id)
                assert.equals("Quick settings", header[1], id)
                assert.equals("battery 84%", header[2]:lower(), id)
                local heading, aside = sheet.panel_widget.places[1], sheet.panel_widget.places[2]
                assert.truthy(aside.x > heading.x, id)
                Sheet.close()
            end
        end)

        it("reads the battery again when the sheet redraws", function()
            set(powerd, "getCapacity", function() return 84 end)
            QuickSettings.open{}
            assert.equals("battery 84%", sheet_parts(Sheet.shown)[2]:lower())
            set(powerd, "getCapacity", function() return 50 end)
            Sheet.redraw()
            local header = sheet_parts(Sheet.shown)
            assert.equals("battery 50%", header[2]:lower())
        end)

        it("has no aside without a battery", function()
            set(Device, "hasBattery", function() return false end)
            QuickSettings.open{}
            assert.same({ "Quick settings" }, (sheet_parts(Sheet.shown)))
        end)
    end)

    describe("the bars", function()
        -- The bar between the minus and plus buttons on their middle row: its outer left and
        -- right x, from the first ink pixel each way, in Editorial by day.
        local function bar(bb, minus, plus, ink)
            local y = minus.y + math.floor(minus.h / 2)
            return scan(bb, minus.x + minus.w, plus.x - 1, y, ink), scan(bb, plus.x - 1, minus.x + minus.w, y, ink), y
        end

        -- How many pixels of the bar's inside are filled, and its inner width, in Editorial by day,
        -- where the fill and the outline are both ink.
        local function filled(bb, minus, plus, ink)
            local left, right, y = bar(bb, minus, plus, ink)
            local outline = scale(Looks.get("editorial").quick_settings.level_outline_width)
            local inner_w = right - left + 1 - 2 * outline
            return run_of(bb, left, y, ink) - outline, inner_w
        end

        it("read the native intensity and warmth and fill each over its scale", function()
            kindle_light(12, 4)
            build("editorial", "day", function(_, bb, by_id, parts)
                local ink = rgb(Looks.get("editorial").palettes.day.ink)
                local label, value = find(parts, "BRIGHTNESS"), find(parts, "12")
                assert.is_table(label)
                assert.is_table(value)
                assert.equals(label.y + label.h, value.y + value.h)
                assert.truthy(value.x > label.x + label.w)
                local fill, inner = filled(bb, by_id.brightness_minus, by_id.brightness_plus, ink)
                assert.truthy(math.abs(fill - math.floor(inner / 2)) <= 1, fill .. " of " .. inner)
                label, value = find(parts, "WARMTH"), find(parts, "4")
                assert.is_table(label)
                assert.is_table(value)
                assert.truthy(label.y > by_id.brightness_minus.y + by_id.brightness_minus.h)
                fill, inner = filled(bb, by_id.warmth_minus, by_id.warmth_plus, ink)
                assert.truthy(math.abs(fill - math.floor(inner / 6)) <= 1, fill .. " of " .. inner)
            end)
        end)

        it("read 0 with no fill with the light off", function()
            kindle_light(0, 4)
            build("editorial", "day", function(_, bb, by_id, parts)
                local ink = rgb(Looks.get("editorial").palettes.day.ink)
                assert.is_table(find(parts, "0"))
                local fill = filled(bb, by_id.brightness_minus, by_id.brightness_plus, ink)
                assert.equals(0, fill)
            end)
        end)

        it("hide both without a frontlight and warmth alone without natural light, the grid moving up", function()
            local first_cell = {}
            build("diner", "day", function(made, _, by_id, parts)
                assert.equals(10, #made.areas)
                assert.is_table(find(parts, "BRIGHTNESS"))
                assert.is_table(find(parts, "WARMTH"))
                first_cell.both = by_id.wifi.y
            end)
            set(Device, "hasNaturalLight", function() return false end)
            build("diner", "day", function(made, _, by_id, parts)
                assert.equals(8, #made.areas)
                assert.is_table(find(parts, "BRIGHTNESS"))
                assert.is_nil(find(parts, "WARMTH"))
                assert.is_nil(by_id.warmth_minus)
                first_cell.brightness = by_id.wifi.y
            end)
            set(Device, "hasNaturalLight", function() return true end)
            set(Device, "hasFrontlight", function() return false end)
            build("diner", "day", function(made, _, by_id, parts)
                assert.equals(6, #made.areas)
                assert.is_nil(find(parts, "BRIGHTNESS"))
                assert.is_nil(find(parts, "WARMTH"))
                assert.is_nil(by_id.brightness_minus)
                first_cell.none = by_id.wifi.y
            end)
            assert.truthy(first_cell.brightness < first_cell.both)
            assert.truthy(first_cell.none < first_cell.brightness)
        end)

        it("grey a bar whose read raises: its value a dash, no fill, logged", function()
            local errored = spy.on(logger, "err")
            undo[#undo + 1] = function()
                errored:revert()
            end
            kindle_light(12, 4)
            set(powerd, "frontlightIntensity", function() error("kopanda-test: intensity failed") end)
            build("editorial", "day", function(_, bb, by_id, parts)
                local ink = rgb(Looks.get("editorial").palettes.day.ink)
                assert.is_table(find(parts, "BRIGHTNESS"))
                assert.is_nil(find(parts, "12"))
                assert.is_table(find(parts, "\u{2013}"))
                assert.equals(0, (filled(bb, by_id.brightness_minus, by_id.brightness_plus, ink)))
                assert.is_table(find(parts, "4"))
            end)
            assert.equals(1, errors(errored, "kopanda-test: intensity failed"))
        end)
    end)

    describe("the cells", function()
        it("are the six in the board's order, three to a row, with their labels and icons", function()
            local wanted = {
                wifi = { "WI-FI ON", "wifi" }, night = { "NIGHT OFF", "moon" },
                rotation_lock = { "ROTATION LOCK", "rotation_lock" }, sync_books = { "SYNC BOOKS", "sync" },
                screenshot = { "SCREENSHOT", "screenshot" }, sleep = { "SLEEP", "power" },
            }
            build("editorial", "day", function(made, _, by_id, parts)
                for i, id in ipairs(CELLS) do
                    assert.equals(id, made.areas[#made.areas - 6 + i].id)
                    local rect = by_id[id]
                    assert.equals(wanted[id][1], label_in(parts, rect).text, id)
                    assert.equals(Icons.path(wanted[id][2]), icon_in(parts, rect).icon, id)
                end
                for row = 0, 1 do
                    local a, b, c = by_id[CELLS[row * 3 + 1]], by_id[CELLS[row * 3 + 2]], by_id[CELLS[row * 3 + 3]]
                    assert.same({ a.y, a.y }, { b.y, c.y })
                    assert.truthy(a.x + a.w < b.x and b.x + b.w < c.x)
                end
                assert.truthy(by_id.sync_books.y > by_id.wifi.y + by_id.wifi.h)
            end)
        end)

        it("draw Wi-Fi on and filled with the radio on, off and unfilled with it off", function()
            local look = Looks.get("editorial")
            local day = look.palettes.day
            build("editorial", "day", function(_, bb, by_id, parts)
                assert.equals("WI-FI ON", label_in(parts, by_id.wifi).text)
                assert.equals(Icons.path("wifi"), icon_in(parts, by_id.wifi).icon)
                assert.truthy(near(rgb(day.ink), cell_inside(bb, by_id.wifi, look)))
                -- The on cell's label and icon in paper on the ink fill.
                assert.truthy(near(grey(day.paper), brightest(bb, label_in(parts, by_id.wifi)), 12))
                assert.truthy(near(grey(day.paper), brightest(bb, icon_in(parts, by_id.wifi)), 12))
            end)
            G_reader_settings:saveSetting("emulator_fake_wifi_connected", false)
            build("editorial", "day", function(_, bb, by_id, parts)
                assert.equals("WI-FI OFF", label_in(parts, by_id.wifi).text)
                assert.equals(Icons.path("wifi_off"), icon_in(parts, by_id.wifi).icon)
                assert.truthy(near(rgb(day.paper), cell_inside(bb, by_id.wifi, look)))
                assert.truthy(near(grey(day.ink), darkest(bb, label_in(parts, by_id.wifi)), 12))
            end)
        end)

        it("fill Night and Rotation lock exactly when their settings are true", function()
            local look = Looks.get("diner")
            local day = look.palettes.day
            for _, case in ipairs({ { false, false }, { true, false }, { false, true }, { true, true } }) do
                local night, lock = case[1], case[2]
                setting("night_mode", night)
                setting("lock_rotation", lock)
                build("diner", "day", function(_, bb, by_id, parts)
                    local where = tostring(night) .. " " .. tostring(lock)
                    assert.equals(night and "NIGHT ON" or "NIGHT OFF", label_in(parts, by_id.night).text, where)
                    for id, on in pairs({ night = night, rotation_lock = lock }) do
                        local fill = on and day.ink or day.paper
                        assert.truthy(near(rgb(fill), cell_inside(bb, by_id[id], look)), id .. " " .. where)
                    end
                end)
            end
        end)

        -- The darkest pixel of a cell's label: its text colour.
        local function label_colour(bb, by_id, parts, id)
            return darkest(bb, label_in(parts, by_id[id]))
        end

        it("grey Sync books without cwngsync, and not with it loaded and its action registered", function()
            local day = Looks.get("editorial").palettes.day
            build("editorial", "day", function(_, bb, by_id, parts)
                assert.truthy(near(grey(day.muted), label_colour(bb, by_id, parts, "sync_books"), 12))
                assert.truthy(near(grey(day.ink), label_colour(bb, by_id, parts, "screenshot"), 12))
            end)
            set(PluginLoader.loaded_plugins, "cwngsync", {})
            build("editorial", "day", function(_, bb, by_id, parts)
                assert.truthy(near(grey(day.muted), label_colour(bb, by_id, parts, "sync_books"), 12))
            end)
            Dispatcher:registerAction("cwngsync_sync_now", { category = "none", event = "CWNGSyncSyncNow",
                title = "Sync now", general = true })
            undo[#undo + 1] = function()
                Dispatcher:removeAction("cwngsync_sync_now")
            end
            build("editorial", "day", function(_, bb, by_id, parts)
                assert.truthy(near(grey(day.ink), label_colour(bb, by_id, parts, "sync_books"), 12))
            end)
        end)

        it("grey Sleep and Wi-Fi when the launcher can't run their entries, Wi-Fi unfilled though on", function()
            local look = Looks.get("editorial")
            local day = look.palettes.day
            local available = LauncherEntries.available
            set(LauncherEntries, "available", function(entry)
                if entry.action == "suspend" or entry.target == "wifi" then
                    return false, "not available"
                end
                return available(entry)
            end)
            build("editorial", "day", function(_, bb, by_id, parts)
                assert.truthy(near(grey(day.muted), label_colour(bb, by_id, parts, "sleep"), 12))
                assert.truthy(near(grey(day.muted), label_colour(bb, by_id, parts, "wifi"), 12))
                assert.truthy(near(rgb(day.paper), cell_inside(bb, by_id.wifi, look)))
                assert.truthy(near(grey(day.ink), label_colour(bb, by_id, parts, "night"), 12))
            end)
        end)

        it("grey Wi-Fi, unfilled, and log once when the radio's read raises", function()
            local errored = spy.on(logger, "err")
            undo[#undo + 1] = function()
                errored:revert()
            end
            local look = Looks.get("diner")
            local day = look.palettes.day
            set(NetworkMgr, "isWifiOn", function() error("kopanda-test: wifi read failed") end)
            build("diner", "day", function(_, bb, by_id, parts)
                assert.truthy(near(grey(day.muted), label_colour(bb, by_id, parts, "wifi"), 12))
                assert.truthy(near(rgb(day.paper), cell_inside(bb, by_id.wifi, look)))
            end)
            assert.equals(1, errors(errored, "kopanda-test: wifi read failed"))
        end)
    end)

    describe("the paint", function()
        -- Runs fn with Looks.variant() answering variant: colour rendering on but for grey, night
        -- mode on for night.
        local function in_variant(variant, fn)
            setting("color_rendering", variant ~= "grey")
            set(Screen, "night_mode", variant == "night")
            assert.equals(variant, Looks.variant())
            fn()
        end

        -- The shown sheet painted onto a white Colorsoft buffer; fn(sheet, bb).
        local function painted(id, variant, fn)
            in_variant(variant, function()
                harness.at_colorsoft(function()
                    Settings.set("look", id)
                    QuickSettings.open{}
                    local sheet = Sheet.shown
                    local bb = Blitbuffer.new(1264, 1680, Blitbuffer.TYPE_BBRGB32)
                    bb:fill(Blitbuffer.COLOR_WHITE)
                    sheet:paintTo(bb, 0, 0)
                    local ok, err = pcall(fn, sheet, bb)
                    bb:free()
                    Sheet.close()
                    if not ok then
                        error(err, 0)
                    end
                end)
            end)
        end

        -- The rows of the column at x from y0 to y1 that aren't near paper, and whether each is
        -- near colour.
        local function column(bb, x, y0, y1, paper, colour)
            local rows, all = 0, true
            for y = y0, y1 do
                local p = pixel(bb, x, y)
                if not near(p, paper) then
                    rows = rows + 1
                    all = all and near(p, colour)
                end
            end
            return rows, all
        end

        for _, variant in ipairs({ "day", "night", "grey" }) do
            it("draws Editorial's outlines, hairline rules and ink fills, " .. variant, function()
                local look = Looks.get("editorial")
                local qs = look.quick_settings
                local palette = Looks.palette(look, variant)
                local ink, paper, hairline = rgb(palette.ink), rgb(palette.paper), rgb(palette.hairline)
                painted("editorial", variant, function(sheet, bb)
                    local areas = sheet.areas
                    assert.equals(10, #areas)
                    local minus, plus, warm_minus = areas[1].rect, areas[2].rect, areas[3].rect
                    local mid = minus.y + math.floor(minus.h / 2)
                    assert.equals(scale(qs.button_outline_width), run_of(bb, minus.x, mid, ink))
                    assert.truthy(near(paper, pixel(bb, minus.x + scale(qs.button_outline_width) + 1, mid)))
                    -- The level bar, half full on the emulator's 50 of 100.
                    local left = scan(bb, minus.x + minus.w, plus.x - 1, mid, ink)
                    local right = scan(bb, plus.x - 1, minus.x + minus.w, mid, ink)
                    local outline = scale(qs.level_outline_width)
                    assert.truthy(near(ink, pixel(bb, left + outline + 2, mid)))
                    assert.truthy(near(paper, pixel(bb, right - outline - 2, mid)))
                    -- The hairline between the sections, in the bar's middle column.
                    local x = math.floor((left + right) / 2)
                    local rows, all = column(bb, x, minus.y + minus.h + 1, warm_minus.y - 1, paper, hairline)
                    assert.equals(scale(qs.section_rule_width), rows)
                    assert.is_true(all)
                    -- Wi-Fi on in ink; Night off unfilled.
                    assert.truthy(near(ink, cell_inside(bb, areas[5].rect, look)))
                    assert.truthy(near(paper, cell_inside(bb, areas[6].rect, look)))
                    assert.equals(scale(qs.cell_outline_width), run_of(bb, areas[6].rect.x,
                        areas[6].rect.y + math.floor(areas[6].rect.h / 2), ink))
                end)
            end)

            it("draws Diner's band header, outlined buttons, mustard levels and the on cell in ink, " .. variant,
                    function()
                local look = Looks.get("diner")
                local qs = look.quick_settings
                local palette = Looks.palette(look, variant)
                local ink, paper, outline = rgb(palette.ink), rgb(palette.paper), rgb(palette.outline)
                painted("diner", variant, function(sheet, bb)
                    local header = sheet.header_rect
                    assert.truthy(near(rgb(palette.band), pixel(bb, header.x + 2, header.y + 2)))
                    local areas = sheet.areas
                    assert.equals(10, #areas)
                    local minus, plus, warm_minus = areas[1].rect, areas[2].rect, areas[3].rect
                    local mid = minus.y + math.floor(minus.h / 2)
                    local width = scale(qs.button_outline_width)
                    assert.equals(width, run_of(bb, minus.x, mid, outline))
                    assert.truthy(near(paper, pixel(bb, minus.x + width + 1, mid)))
                    local left = scan(bb, minus.x + minus.w, plus.x - 1, mid, outline)
                    local right = scan(bb, plus.x - 1, minus.x + minus.w, mid, outline)
                    local level = scale(qs.level_outline_width)
                    assert.equals(level, run_of(bb, left, mid, outline))
                    assert.truthy(near(rgb(palette.mustard), pixel(bb, left + level + 2, mid)))
                    assert.truthy(near(paper, pixel(bb, right - level - 2, mid)))
                    local x = math.floor((left + right) / 2)
                    local rows, all = column(bb, x, minus.y + minus.h + 1, warm_minus.y - 1, paper, outline)
                    assert.equals(scale(qs.section_rule_width), rows)
                    assert.is_true(all)
                    assert.truthy(near(ink, cell_inside(bb, areas[5].rect, look)))
                    assert.truthy(near(paper, cell_inside(bb, areas[6].rect, look)))
                    assert.equals(scale(qs.cell_outline_width), run_of(bb, areas[6].rect.x,
                        areas[6].rect.y + math.floor(areas[6].rect.h / 2), outline))
                end)
            end)
        end
    end)

    describe("the fit", function()
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

        it("puts the whole panel on the Colorsoft, portrait and turned, at every text size, in both looks", function()
            local warned = spy.on(logger, "warn")
            undo[#undo + 1] = function()
                warned:revert()
            end
            for _, id in ipairs({ "editorial", "diner" }) do
                for _, screen in ipairs({ { 1264, 1680 }, { 1680, 1264 } }) do
                    local heights = {}
                    for _, size in ipairs({ "small", "medium", "large" }) do
                        local where = id .. " " .. screen[1] .. "x" .. screen[2] .. " " .. size
                        harness.at_screen(screen[1], screen[2], function()
                            Settings.set("look", id)
                            Settings.set("text_size", size)
                            QuickSettings.open{}
                            local sheet = Sheet.shown
                            local panel = sheet.panel
                            local inset = scale(Looks.get(id).sheet.inset.bottom)
                            assert.truthy(panel.y > 0, where)
                            assert.truthy(panel.y + panel.h <= screen[2] - inset, where)
                            heights[#heights + 1] = panel.h
                            Sheet.close()
                        end)
                    end
                    assert.truthy(heights[1] < heights[2] and heights[2] < heights[3], id)
                end
            end
            assert.equals(0, warnings(warned, "taller than the screen"))
        end)

        it("sets the bars' labels and the cells' labels larger at a larger text size", function()
            local heights = {}
            for _, size in ipairs({ "small", "large" }) do
                Settings.set("text_size", size)
                build("editorial", "day", function(_, _, by_id, parts)
                    heights[size] = { bar = find(parts, "BRIGHTNESS").h, cell = label_in(parts, by_id.screenshot).h }
                end)
            end
            assert.truthy(heights.large.bar > heights.small.bar, heights.small.bar .. " to " .. heights.large.bar)
            assert.truthy(heights.large.cell > heights.small.cell, heights.small.cell .. " to " .. heights.large.cell)
        end)
    end)

    describe("the areas", function()
        local function overlap(a, b)
            return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
        end

        it("are the four buttons and the six cells, each inside the panel, none overlapping", function()
            build("diner", "day", function(made)
                local ids = {}
                for i, area in ipairs(made.areas) do
                    ids[i] = area.id
                end
                assert.same({ "brightness_minus", "brightness_plus", "warmth_minus", "warmth_plus", "wifi", "night",
                    "rotation_lock", "sync_books", "screenshot", "sleep" }, ids)
            end)
            for _, id in ipairs({ "editorial", "diner" }) do
                Settings.set("look", id)
                QuickSettings.open{}
                local sheet = Sheet.shown
                local areas = sheet.areas
                assert.equals(10, #areas, id)
                for i, area in ipairs(areas) do
                    local r, p = area.rect, sheet.panel
                    assert.truthy(r.w > 0 and r.h > 0, id .. " " .. i)
                    assert.truthy(r.x >= p.x and r.y >= p.y and r.x + r.w <= p.x + p.w and r.y + r.h <= p.y + p.h,
                        id .. " " .. i)
                    for j = i + 1, #areas do
                        assert.is_false(overlap(r, areas[j].rect), id .. " " .. i .. " and " .. j)
                    end
                end
                Sheet.close()
            end
        end)
    end)
end)
