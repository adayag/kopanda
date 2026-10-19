-- The quick-settings sheet's controls: taps and holds on the brightness and warmth buttons step the power device on
-- the Kindle's 0-24 scales through broadcast events the file manager's DeviceListener handles; Night, Rotation lock
-- and Wi-Fi act with the sheet open and redraw it; Sync books, Sleep and Screenshot close it first; a greyed cell
-- closes it and shows the launcher's note; an action that raises is logged and the sheet stays. Each case reaching
-- KOReader runs over the home and over the bare file browser. Every stub is put back after the test that makes it.
describe("the quick-settings controls", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Device = require("device")
    local DeviceListener = require("device/devicelistener")
    local Dispatcher = require("dispatcher")
    local Event = require("ui/event")
    local EventListener = require("ui/widget/eventlistener")
    local FileManager = require("apps/filemanager/filemanager")
    local NetworkMgr = require("ui/network/manager")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Screen = Device.screen
    local powerd = Device:getPowerDevice()
    local Home, LauncherEntries, Looks, QuickSettings, Settings, Sheet, SheetLayout, Weather

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

    -- G_reader_settings:isTrue(key) raises for the rest of the test; other keys read as before.
    local function unreadable(key)
        local is_true = G_reader_settings.isTrue
        set(G_reader_settings, "isTrue", function(self, k)
            if k == key then
                error("kopanda-test: " .. key .. " read failed")
            end
            return is_true(self, k)
        end)
    end

    -- A spy on t[key] for the rest of the test.
    local function watch(t, key)
        local s = spy.on(t, key)
        undo[#undo + 1] = function()
            s:revert()
        end
        return s
    end

    -- The power device on the Kindle's 0-24 scales (frontend/device/kindle/powerd.lua:8-11), with the warmth scale its
    -- new sets (frontend/device/generic/powerd.lua:38), the light on at intensity and the warmth at native; the
    -- emulator's hardware intensity and resume state, which the setters write, are put back too.
    local function kindle_light(intensity, native)
        set(powerd, "fl_max", 24)
        set(powerd, "fl_warmth_max", 24)
        set(powerd, "warmth_scale", 100 / 24)
        set(powerd, "fl_intensity", intensity)
        set(powerd, "hw_intensity", intensity)
        set(powerd, "is_fl_on", intensity > 0)
        set(powerd, "fl_was_on", intensity > 0)
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

    local function sheets_on_stack()
        local count = 0
        for _, widget in ipairs(harness.stack()) do
            if widget.name == "kopanda_sheet" then
                count = count + 1
            end
        end
        return count
    end

    -- The body's areas in order (quick_settings_spec.lua, "the areas"); the sheet keeps their
    -- order, moved to the screen.
    local IDS = { brightness_minus = 1, brightness_plus = 2, warmth_minus = 3, warmth_plus = 4, wifi = 5, night = 6,
        rotation_lock = 7, sync_books = 8, screenshot = 9, sleep = 10 }

    local function rect_of(id)
        return Sheet.shown.areas[IDS[id]].rect
    end

    -- A tap or hold sent as KOReader sends one, at the centre of the area id.
    local function gesture(ges, id)
        local r = rect_of(id)
        UIManager:sendEvent(Event:new("Gesture",
            harness.gesture(ges, r.x + math.floor(r.w / 2), r.y + math.floor(r.h / 2))))
    end

    local function tap(id)
        gesture("tap", id)
    end

    local function hold(id)
        gesture("hold", id)
    end

    -- A line's text, lower-cased: a TextWidget's, or a tracked line's glyphs joined.
    local function text_of(widget)
        if widget.text then
            return widget.text:lower()
        end
        local parts = {}
        for _, child in ipairs(widget) do
            parts[#parts + 1] = child.text or ""
        end
        return table.concat(parts):lower()
    end

    -- The shown sheet's body widget.
    local function body()
        for _, widget in ipairs(Sheet.shown.panel_widget) do
            if widget.name == "kopanda_quick_settings" then
                return widget
            end
        end
    end

    -- The value line beside the bar labelled label.
    local function value_of(label)
        local b = body()
        for i, widget in ipairs(b) do
            if text_of(widget) == label then
                return text_of(b[i + 1])
            end
        end
    end

    local function shows(text)
        for _, widget in ipairs(body()) do
            if text_of(widget) == text then
                return true
            end
        end
        return false
    end

    -- The pixel just inside cell id's outline, in its top padding, with the sheet painted on a
    -- fresh screen-sized buffer.
    local function cell_fill(id)
        local size = Screen:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        Sheet.shown:paintTo(bb, 0, 0)
        local r = rect_of(id)
        local inset = Screen:scaleBySize(Looks.active().quick_settings.cell_outline_width) + 2
        local c = bb:getPixel(r.x + inset, r.y + inset):getColorRGB32()
        bb:free()
        return { c:getR(), c:getG(), c:getB() }
    end

    -- How many times the sheet's body has been laid out, counted from the open.
    local layouts

    before_each(function()
        undo = {}
        harness.load()
        Home = require("home")
        LauncherEntries = require("launcher_entries")
        Looks = require("looks")
        QuickSettings = require("quick_settings")
        Settings = require("settings")
        Sheet = require("sheet")
        SheetLayout = require("sheet_layout")
        Weather = require("weather")
        -- No weather fetch goes out when a toggle connects the fake Wi-Fi.
        set(Weather, "get", function()
            return nil, "kopanda-test: offline"
        end)
        set(NetworkMgr, "pending_connection", false)
        set(NetworkMgr, "pending_connectivity_check", false)
        layouts = 0
        local made = QuickSettings.body
        set(QuickSettings, "body", function(...)
            layouts = layouts + 1
            return made(...)
        end)
    end)

    after_each(function()
        harness.teardown()
        for i = #undo, 1, -1 do
            undo[i]()
        end
        undo = {}
        Settings._reset()
    end)

    for _, over in ipairs({ "the home", "the bare file browser" }) do
        describe("over " .. over, function()
            -- The file manager, then the home or not, then the sheet over the top one.
            local function open()
                harness.show_fm()
                harness.tick(4)
                if over == "the bare file browser" then
                    Home.close()
                    assert.is_nil(Home.shown)
                else
                    assert.equals(Home.shown, harness.top())
                end
                local beneath = harness.top()
                QuickSettings.open{}
                harness.tick(3)
                assert.equals("quick_settings", Sheet.shown.spec.name)
                assert.equals(Sheet.shown, harness.top())
                assert.equals(beneath, harness.top(2))
            end

            local function still_shown()
                assert.is_not_nil(Sheet.shown)
                assert.equals(Sheet.shown, harness.top())
            end

            it("steps brightness one native step a tap, clamped, through SetFlIntensity", function()
                kindle_light(12, 4)
                local heard = watch(DeviceListener, "onSetFlIntensity")
                open()
                tap("brightness_plus")
                assert.equals(13, powerd:frontlightIntensity())
                assert.equals("13", value_of("brightness"))
                still_shown()
                tap("brightness_minus")
                tap("brightness_minus")
                assert.equals(11, powerd:frontlightIntensity())
                assert.equals("11", value_of("brightness"))
                hold("brightness_plus")
                assert.equals(24, powerd:frontlightIntensity())
                tap("brightness_plus")
                assert.equals(24, powerd:frontlightIntensity())
                assert.equals("24", value_of("brightness"))
                hold("brightness_minus")
                assert.is_true(powerd:isFrontlightOff())
                assert.equals(0, powerd:frontlightIntensity())
                assert.equals("0", value_of("brightness"))
                tap("brightness_minus")
                assert.is_true(powerd:isFrontlightOff())
                assert.equals("0", value_of("brightness"))
                tap("brightness_plus")
                assert.is_true(powerd:isFrontlightOn())
                assert.equals(1, powerd:frontlightIntensity())
                assert.equals("1", value_of("brightness"))
                still_shown()
                local sent = {}
                for i, call in ipairs(heard.calls) do
                    sent[i] = call.vals[2]
                end
                assert.same({ 13, 12, 11, 24, 24, 0, 0, 1 }, sent)
            end)

            it("steps warmth one native step a tap, clamped, through SetFlWarmth", function()
                kindle_light(12, 4)
                local heard = watch(DeviceListener, "onSetFlWarmth")
                open()
                local function native()
                    return powerd:toNativeWarmth(powerd:frontlightWarmth())
                end
                tap("warmth_plus")
                assert.equals(5, native())
                assert.equals("5", value_of("warmth"))
                still_shown()
                tap("warmth_minus")
                tap("warmth_minus")
                assert.equals(3, native())
                assert.equals("3", value_of("warmth"))
                hold("warmth_plus")
                assert.equals(24, native())
                tap("warmth_plus")
                assert.equals(24, native())
                assert.equals("24", value_of("warmth"))
                hold("warmth_minus")
                assert.equals(0, native())
                tap("warmth_minus")
                assert.equals(0, native())
                assert.equals("0", value_of("warmth"))
                still_shown()
                local sent = {}
                for i, call in ipairs(heard.calls) do
                    sent[i] = call.vals[2]
                end
                assert.same({ 5, 4, 3, 24, 24, 0, 0 }, sent)
            end)

            it("toggles night mode through ToggleNightMode and repaints the sheet at night", function()
                setting("color_rendering", true)
                setting("night_mode", false)
                set(Screen, "night_mode", false)
                local heard = watch(DeviceListener, "onToggleNightMode")
                open()
                assert.equals("day", Sheet.shown.variant)
                assert.is_true(shows("night off"))
                tap("night")
                assert.is_true(Screen.night_mode)
                assert.is_true(G_reader_settings:isTrue("night_mode"))
                still_shown()
                harness.tick(2)
                assert.equals("night", Sheet.shown.variant)
                assert.is_true(shows("night on"))
                tap("night")
                assert.is_false(Screen.night_mode)
                assert.is_false(G_reader_settings:isTrue("night_mode"))
                harness.tick(2)
                assert.equals("day", Sheet.shown.variant)
                assert.is_true(shows("night off"))
                assert.spy(heard).was_called(2)
            end)

            it("lays the sheet out once for a Night tap and its paint", function()
                setting("color_rendering", true)
                setting("night_mode", false)
                set(Screen, "night_mode", false)
                open()
                local built = watch(SheetLayout, "build")
                tap("night")
                harness.tick(2)
                assert.equals("night", Sheet.shown.variant)
                assert.is_true(shows("night on"))
                assert.spy(built).was_called(1)
            end)

            it("flips lock_rotation both ways, the cell's fill following", function()
                setting("lock_rotation", false)
                setting("emulator_fake_wifi_connected", true)
                open()
                local off, on = cell_fill("night"), cell_fill("wifi")
                assert.is_not.same(off, on)
                assert.same(off, cell_fill("rotation_lock"))
                tap("rotation_lock")
                assert.is_true(G_reader_settings:isTrue("lock_rotation"))
                still_shown()
                assert.same(on, cell_fill("rotation_lock"))
                tap("rotation_lock")
                assert.is_false(G_reader_settings:isTrue("lock_rotation"))
                assert.same(off, cell_fill("rotation_lock"))
            end)

            it("turns Wi-Fi off and on through NetworkMgr's toggles, following its events", function()
                setting("emulator_fake_wifi_connected", true)
                local off_heard = watch(Home, "onNetworkDisconnected")
                local on_heard = watch(Home, "onNetworkConnected")
                local toggled_off = watch(NetworkMgr, "toggleWifiOff")
                local toggled_on = watch(NetworkMgr, "toggleWifiOn")
                open()
                assert.is_true(shows("wi-fi on"))
                tap("wifi")
                assert.spy(toggled_off).was_called(1)
                assert.equals(true, toggled_off.calls[1].vals[3])
                assert.is_false(NetworkMgr:isWifiOn())
                assert.is_true(shows("wi-fi off"))
                still_shown()
                harness.tick(3)
                assert.is_true(shows("wi-fi off"))
                if over == "the home" then
                    assert.truthy(#off_heard.calls >= 1, "the home missed NetworkDisconnected")
                end
                tap("wifi")
                assert.spy(toggled_on).was_called(1)
                assert.equals(false, toggled_on.calls[1].vals[3])
                assert.equals(true, toggled_on.calls[1].vals[4])
                assert.is_true(NetworkMgr:isWifiOn())
                assert.is_true(shows("wi-fi on"))
                harness.tick(4)
                assert.is_true(shows("wi-fi on"))
                still_shown()
                if over == "the home" then
                    assert.truthy(#on_heard.calls >= 1, "the home missed NetworkConnected")
                end
                -- A radio changed elsewhere redraws the sheet on its event, which still reaches
                -- the home; an event that changes nothing the sheet shows doesn't redraw it.
                local before = layouts
                G_reader_settings:saveSetting("emulator_fake_wifi_connected", false)
                local heard_before = #off_heard.calls
                UIManager:broadcastEvent(Event:new("NetworkDisconnected"))
                assert.equals(before + 1, layouts)
                assert.is_true(shows("wi-fi off"))
                if over == "the home" then
                    assert.equals(heard_before + 1, #off_heard.calls)
                end
                UIManager:broadcastEvent(Event:new("NetworkDisconnected"))
                UIManager:broadcastEvent(Event:new("NetworkConnected"))
                assert.equals(before + 1, layouts)
            end)

            it("prompts through NetworkMgr's promptWifi with Wi-Fi on and not connected", function()
                setting("emulator_fake_wifi_connected", true)
                set(NetworkMgr, "isConnected", function()
                    return false
                end)
                local toggled_off = watch(NetworkMgr, "toggleWifiOff")
                local toggled_on = watch(NetworkMgr, "toggleWifiOn")
                local prompted = {}
                set(NetworkMgr, "promptWifi", function(...)
                    prompted[#prompted + 1] = { ... }
                end)
                open()
                tap("wifi")
                assert.equals(1, #prompted)
                assert.equals(NetworkMgr, prompted[1][1])
                assert.is_nil(prompted[1][2])
                assert.equals(false, prompted[1][3])
                assert.equals(true, prompted[1][4])
                assert.spy(toggled_off).was_not_called()
                assert.spy(toggled_on).was_not_called()
                still_shown()
            end)

            -- The emulator's fake broadcasts each event twice for one toggle: once from its own
            -- connectionChangedEvent (frontend/device/sdl/device.lua:479-487), then from the callback NetworkMgr
            -- hands it, the connectivity check's NetworkConnected (frontend/ui/network/manager.lua:109) or
            -- disableWifi's NetworkDisconnected (:408).
            it("lays the sheet out once for a Wi-Fi-on tap, its NetworkConnected broadcasts and the check", function()
                setting("emulator_fake_wifi_connected", false)
                local checked = watch(NetworkMgr, "connectivityCheck")
                open()
                local built = watch(SheetLayout, "build")
                local heard = watch(Sheet.shown, "onNetworkConnected")
                tap("wifi")
                harness.tick(4)
                assert.spy(checked).was_called(1)
                assert.equals(2, #heard.calls)
                assert.is_false(NetworkMgr.pending_connection)
                assert.is_true(shows("wi-fi on"))
                still_shown()
                assert.spy(built).was_called(1)
            end)

            it("lays the sheet out once for a Wi-Fi-off tap and its NetworkDisconnected broadcasts", function()
                setting("emulator_fake_wifi_connected", true)
                open()
                local built = watch(SheetLayout, "build")
                local heard = watch(Sheet.shown, "onNetworkDisconnected")
                tap("wifi")
                harness.tick(4)
                assert.equals(2, #heard.calls)
                assert.is_true(shows("wi-fi off"))
                still_shown()
                assert.spy(built).was_called(1)
            end)

            it("lays the sheet out once for a Wi-Fi-on tap whose connection fails, the radio shown off", function()
                setting("emulator_fake_wifi_connected", false)
                set(NetworkMgr, "turnOnWifi", function()
                    return false
                end)
                open()
                local built = watch(SheetLayout, "build")
                tap("wifi")
                harness.tick(4)
                assert.is_false(NetworkMgr.pending_connection)
                assert.is_true(shows("wi-fi off"))
                still_shown()
                assert.spy(built).was_called(1)
            end)

            it("lays the sheet out once for a Wi-Fi tap whose prompt is dismissed", function()
                setting("emulator_fake_wifi_connected", true)
                set(NetworkMgr, "isConnected", function()
                    return false
                end)
                open()
                local built = watch(SheetLayout, "build")
                tap("wifi")
                local prompt = harness.top()
                assert.are_not.equal(Sheet.shown, prompt)
                UIManager:close(prompt)
                harness.tick(2)
                assert.is_true(shows("wi-fi on"))
                still_shown()
                assert.spy(built).was_called(1)
            end)

            it("lays the sheet out no more on Wi-Fi events while the radio's read raises", function()
                set(NetworkMgr, "isWifiOn", function()
                    error("kopanda-test: the radio read failed")
                end)
                open()
                local before = layouts
                UIManager:broadcastEvent(Event:new("NetworkDisconnected"))
                UIManager:broadcastEvent(Event:new("NetworkConnected"))
                assert.equals(before, layouts)
                still_shown()
            end)

            for _, bar in ipairs({ { "brightness", "frontlightIntensity", "onSetFlIntensity" },
                    { "warmth", "frontlightWarmth", "onSetFlWarmth" } }) do
                local id, read, handler = bar[1], bar[2], bar[3]
                it("leaves a greyed " .. id .. " bar's buttons inert to taps and holds", function()
                    kindle_light(12, 4)
                    set(powerd, read, function()
                        error("kopanda-test: " .. id .. " read failed")
                    end)
                    local heard = watch(DeviceListener, handler)
                    open()
                    assert.equals("\u{2013}", value_of(id))
                    for _, button in ipairs({ id .. "_minus", id .. "_plus" }) do
                        tap(button)
                        hold(button)
                        still_shown()
                    end
                    assert.spy(heard).was_not_called()
                    assert.equals(12, rawget(powerd, "fl_intensity"))
                    assert.equals(powerd:fromNativeWarmth(4), rawget(powerd, "fl_warmth"))
                    assert.is_true(rawget(powerd, "is_fl_on"))
                end)
            end

            for _, cell in ipairs({
                { "wifi", function()
                    set(NetworkMgr, "isWifiOn", function()
                        error("kopanda-test: radio read failed")
                    end)
                end },
                { "night", function() unreadable("night_mode") end },
                { "rotation_lock", function() unreadable("lock_rotation") end },
            }) do
                local id, fail = cell[1], cell[2]
                it("leaves " .. id .. " inert when its read raised", function()
                    setting("emulator_fake_wifi_connected", true)
                    setting("night_mode", false)
                    setting("lock_rotation", false)
                    -- From the sheet's open on: the file manager reads lock_rotation as it shows
                    -- (frontend/apps/filemanager/filemanager.lua:64).
                    local opens = QuickSettings.open
                    set(QuickSettings, "open", function(...)
                        fail()
                        return opens(...)
                    end)
                    local toggled_off = watch(NetworkMgr, "toggleWifiOff")
                    local toggled_on = watch(NetworkMgr, "toggleWifiOn")
                    local prompted = watch(NetworkMgr, "promptWifi")
                    local ran = watch(LauncherEntries, "run")
                    local night = watch(DeviceListener, "onToggleNightMode")
                    open()
                    local sheet = Sheet.shown
                    local broadcast = watch(UIManager, "broadcastEvent")
                    tap(id)
                    assert.equals(sheet, Sheet.shown)
                    still_shown()
                    assert.spy(toggled_off).was_not_called()
                    assert.spy(toggled_on).was_not_called()
                    assert.spy(prompted).was_not_called()
                    assert.spy(ran).was_not_called()
                    assert.spy(night).was_not_called()
                    assert.spy(broadcast).was_not_called()
                    assert.equals(false, G_reader_settings:readSetting("night_mode"))
                    assert.equals(false, G_reader_settings:readSetting("lock_rotation"))
                end)
            end

            it("closes the sheet, then sends Sync books to the cwngsync plugin", function()
                set(PluginLoader.loaded_plugins, "cwngsync", {})
                Dispatcher:registerAction("cwngsync_sync_now", { category = "none", event = "CWNGSyncSyncNow",
                    title = "Sync now", general = true })
                undo[#undo + 1] = function()
                    Dispatcher:removeAction("cwngsync_sync_now")
                end
                local synced = {}
                local cwngsync = EventListener:new{
                    onCWNGSyncSyncNow = function()
                        synced[#synced + 1] = sheets_on_stack()
                        return true
                    end,
                }
                open()
                local fm = FileManager.instance
                fm:registerModule("cwngsync", cwngsync)
                undo[#undo + 1] = function()
                    for i, module in ipairs(fm) do
                        if module == cwngsync then
                            table.remove(fm, i)
                        end
                    end
                    fm.cwngsync = nil
                end
                tap("sync_books")
                assert.same({ 0 }, synced)
                assert.is_nil(Sheet.shown)
            end)

            it("closes the sheet, then sends Sleep to DeviceListener's RequestSuspend", function()
                local slept = {}
                set(UIManager, "suspend", function()
                    slept[#slept + 1] = sheets_on_stack()
                end)
                local heard = watch(DeviceListener, "onRequestSuspend")
                open()
                tap("sleep")
                assert.spy(heard).was_called(1)
                assert.same({ 0 }, slept)
                assert.is_nil(Sheet.shown)
            end)

            it("closes the sheet and repaints the screen beneath before the Screenshoter's shot", function()
                local closed, repainted = false, false
                local close = UIManager.close
                set(UIManager, "close", function(self, widget, ...)
                    if widget and widget.name == "kopanda_sheet" then
                        closed = true
                    end
                    return close(self, widget, ...)
                end)
                local force = UIManager.forceRePaint
                set(UIManager, "forceRePaint", function(self)
                    if closed then
                        repainted = true
                    end
                    return force(self)
                end)
                local shots = {}
                set(Screen, "shot", function()
                    shots[#shots + 1] = { sheets = sheets_on_stack(), repainted = repainted }
                    return true
                end)
                open()
                tap("screenshot")
                assert.same({ { sheets = 0, repainted = true } }, shots)
                assert.is_nil(Sheet.shown)
            end)

            it("closes the sheet and shows the launcher's note for a greyed Sync books", function()
                open()
                tap("sync_books")
                assert.is_nil(Sheet.shown)
                local top = harness.top()
                assert.equals("Sync books: the cwngsync plugin isn't loaded.", top.text)
            end)

            it("closes the sheet and shows the launcher's note for a greyed Wi-Fi", function()
                local available = LauncherEntries.available
                set(LauncherEntries, "available", function(entry)
                    if entry.target == "wifi" then
                        return false, "not available"
                    end
                    return available(entry)
                end)
                local toggled_off = watch(NetworkMgr, "toggleWifiOff")
                local toggled_on = watch(NetworkMgr, "toggleWifiOn")
                open()
                tap("wifi")
                assert.is_nil(Sheet.shown)
                assert.equals("Wi-Fi isn't available here.", harness.top().text)
                assert.spy(toggled_off).was_not_called()
                assert.spy(toggled_on).was_not_called()
            end)

            it("logs an action that raises and keeps the sheet", function()
                local errored = watch(logger, "err")
                set(NetworkMgr, "queryNetworkState", function()
                    error("kopanda-test: radio query failed")
                end)
                open()
                tap("wifi")
                assert.equals(1, errors(errored, "kopanda-test: radio query failed"))
                still_shown()
            end)

            it("runs nothing on a hold on a cell", function()
                setting("lock_rotation", false)
                setting("night_mode", false)
                open()
                local sheet = Sheet.shown
                hold("rotation_lock")
                hold("night")
                hold("sleep")
                assert.is_false(G_reader_settings:isTrue("lock_rotation"))
                assert.is_false(G_reader_settings:isTrue("night_mode"))
                assert.equals(sheet, Sheet.shown)
                assert.equals(sheet, harness.top())
            end)
        end)
    end
end)
