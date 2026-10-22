-- The home sheet, on a shown home over a real file manager: its header, its seven
-- rows in order with their icons and details, and what a tap on each does, never writing the
-- settings file. Each row is tapped where the sheet laid it out.
describe("the home sheet", function()
    local harness = require("plugin_harness")
    -- spec/home_gestures.lua, required before harness.load() puts the plugin's own home_gestures in
    -- the require cache.
    local gestures = require("home_gestures")
    local Dispatcher = require("dispatcher")
    local Event = require("ui/event")
    local InfoMessage = require("ui/widget/infomessage")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local Home, HomeSheet, Sheet

    -- Undo steps for the running test, run last first after it. busted keeps only a test's last
    -- finally, so the helpers can't each register one.
    local cleanups = {}
    local function cleanup(fn)
        cleanups[#cleanups + 1] = fn
    end

    local function set_wifi(on)
        G_reader_settings:saveSetting("emulator_fake_wifi_connected", on)
    end

    -- Dispatcher.getDisplayList lists nothing, for the rest of the test, so no dispatcher id
    -- is available.
    local function no_actions()
        local s = stub(Dispatcher, "getDisplayList", function()
            return {}
        end)
        cleanup(function()
            s:revert()
        end)
    end

    -- A cache holding a reading for the default location and units, fetched at fetched_at, as
    -- weather_spec.lua writes one.
    local function write_weather(fetched_at)
        local Settings = require("settings")
        local location = Settings.get("weather.location")
        lfs.mkdir(harness.state_dir)
        local f = assert(io.open(harness.weather_file, "wb"))
        f:write(string.format('return { ["fetched_at"] = %d, ["temperature"] = 61.4, ["weather_code"] = 2, '
            .. '["is_day"] = 1, ["latitude"] = %s, ["longitude"] = %s, ["units"] = %q }\n',
            fetched_at, tostring(location.latitude), tostring(location.longitude), Settings.get("weather.units")))
        f:close()
    end

    -- A file manager with its home up and the home sheet shown over it.
    local function open_sheet()
        local fm = harness.show_fm()
        harness.tick(2)
        assert.equals(Home.shown, harness.top())
        HomeSheet.open(Home.shown.ctx)
        assert.equals(Sheet.shown, harness.top())
        assert.equals(Home.shown, harness.top(2))
        return fm
    end

    -- The shown sheet's row labelled label, as given and as laid out.
    local function row(label)
        for _, place in ipairs(Sheet.shown.rows) do
            if place.row.label == label then
                return place.row, place
            end
        end
        error("no row " .. label)
    end

    local function tap(label)
        local _, place = row(label)
        local rect = place.rect
        UIManager:sendEvent(Event:new("Gesture",
            harness.gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))))
    end

    -- The InfoMessage on the stack, or nil.
    local function message()
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == InfoMessage then
                return widget
            end
        end
    end

    before_each(function()
        harness.load()
        Home = require("home")
        HomeSheet = require("home_sheet")
        Sheet = require("sheet")
    end)

    after_each(function()
        for i = #cleanups, 1, -1 do
            cleanups[i]()
        end
        cleanups = {}
        harness.teardown()
        set_wifi(false)
        -- No case writes the settings file: harness.load removed it, and it is still absent.
        assert.is_nil(lfs.attributes(harness.settings_file, "mode"))
    end)

    it("is headed Home with KoPanda aside, in the home's band, and lists its seven rows in order", function()
        open_sheet()
        local spec = Sheet.shown.spec
        assert.equals("home", spec.name)
        assert.equals("home", spec.band)
        assert.equals("Home", spec.header.heading)
        assert.equals("KoPanda", spec.header.aside)
        local rows = {}
        for i, r in ipairs(spec.rows) do
            rows[i] = { r.label, r.icon }
        end
        assert.same({
            { "Edit layout", "layout" },
            { "Edit page 2", "layout" },
            { "Open the file browser", "folder" },
            { "Refresh weather", "sun" },
            { "Wi-Fi", "wifi_off" },
            { "KoPanda settings", "settings" },
            { "Sleep", "moon" },
        }, rows)
        -- Every row was laid out.
        assert.equals(7, #Sheet.shown.rows)
        -- Only Refresh weather and Wi-Fi carry a detail while every action is available.
        for _, label in ipairs({ "Edit layout", "Edit page 2", "Open the file browser", "KoPanda settings",
            "Sleep" }) do
            assert.is_nil(row(label).detail, label)
        end
    end)

    describe("Edit layout", function()
        it("opens the edit layout screen over the home, with no note", function()
            open_sheet()
            local home = Home.shown
            tap("Edit layout")
            local Editor = require("editor")
            assert.is_not_nil(Editor.shown)
            assert.equals("edit_layout", Editor.shown.spec.screen)
            assert.equals(Editor.shown, harness.top())
            assert.equals(home, harness.top(2))
            assert.equals(home, Home.shown)
            assert.is_nil(message())
            assert.is_nil(Sheet.shown)
        end)
    end)

    describe("Edit page 2", function()
        it("opens edit layout on page 2's key, from a stamped tap", function()
            local EditLayout = require("edit_layout")
            local opened = spy.on(EditLayout, "open")
            cleanup(function()
                opened:revert()
            end)
            open_sheet()
            tap("Edit page 2")
            assert.spy(opened).was.called(1)
            local opts = opened.calls[1].vals[1]
            assert.equals("layout.rows_2", opts.key)
            assert.is_not_nil(opts.started)
            local Editor = require("editor")
            assert.equals("Edit page 2", Editor.shown.spec.title)
            assert.is_nil(Sheet.shown)
        end)
    end)

    describe("Open the file browser", function()
        it("closes the sheet and the home, leaving the file manager on top", function()
            local fm = open_sheet()
            tap("Open the file browser")
            assert.is_nil(Sheet.shown)
            assert.is_nil(Home.shown)
            assert.equals(fm, harness.top())
        end)
    end)

    describe("Refresh weather", function()
        it("calls Weather.tap once with the home", function()
            open_sheet()
            local home = Home.shown
            -- Recorded by hand: a spy deep-copies its arguments, and the home holds buffers.
            local Weather = require("weather")
            local original, homes = Weather.tap, {}
            Weather.tap = function(h)
                homes[#homes + 1] = h
            end
            cleanup(function()
                Weather.tap = original
            end)
            tap("Refresh weather")
            assert.equals(1, #homes)
            assert.equals(home, homes[1])
        end)

        it("shows the cached reading's age, read at the sheet's opening", function()
            write_weather(os.time() - 20 * 60)
            local fm = harness.show_fm()
            harness.tick(2)
            assert.equals(Home.shown, harness.top())
            -- A home built an hour before the reading: the age is the reading's now, not the
            -- build's.
            Home.shown.ctx.now = os.time() - 3600
            HomeSheet.open(Home.shown.ctx)
            assert.equals(Sheet.shown, harness.top())
            assert.equals(fm, harness.top(3))
            assert.equals("20 min ago", row("Refresh weather").detail)
        end)

        it("shows never fetched with no cached reading", function()
            open_sheet()
            assert.equals("never fetched", row("Refresh weather").detail)
        end)
    end)

    describe("Wi-Fi", function()
        it("shows Off with the Wi-Fi off icon in the state chip when the Wi-Fi is off", function()
            set_wifi(false)
            open_sheet()
            local r = row("Wi-Fi")
            assert.equals("Off", r.detail)
            assert.equals("wifi_off", r.icon)
            assert.equals("state", r.chip)
            assert.is_falsy(r.muted)
        end)

        it("shows On with the Wi-Fi icon in the state chip when the Wi-Fi is on", function()
            set_wifi(true)
            open_sheet()
            local r = row("Wi-Fi")
            assert.equals("On", r.detail)
            assert.equals("wifi", r.icon)
            assert.equals("state", r.chip)
            assert.is_falsy(r.muted)
        end)

        it("toggles the Wi-Fi through the file manager's network listener once", function()
            local fm = open_sheet()
            local toggle = stub(fm.networklistener, "onToggleWifi", function()
                return true
            end)
            cleanup(function()
                toggle:revert()
            end)
            tap("Wi-Fi")
            assert.stub(toggle).was.called(1)
            assert.is_nil(Sheet.shown)
        end)

        it("is muted with not available when the dispatcher lists no toggle, and a tap only says so", function()
            no_actions()
            open_sheet()
            local r = row("Wi-Fi")
            assert.is_true(r.muted)
            assert.equals("not available", r.detail)
            local execute = spy.on(Dispatcher, "execute")
            cleanup(function()
                execute:revert()
            end)
            tap("Wi-Fi")
            assert.spy(execute).was_not.called()
            local note = message()
            assert.is_not_nil(note)
            assert.equals("Wi-Fi isn't available here.", note.text)
        end)
    end)

    describe("KoPanda settings", function()
        it("opens the full settings list once", function()
            open_sheet()
            local open = spy.on(require("settings_menu"), "open")
            cleanup(function()
                open:revert()
            end)
            tap("KoPanda settings")
            assert.spy(open).was.called(1)
            assert.spy(open).was.called_with()
            local menu = gestures.settings_menu()
            assert.is_not_nil(menu)
            assert.equals(#require("schema").keys, #menu[1].tab_item_table[1])
        end)
    end)

    describe("Sleep", function()
        it("sends RequestSuspend once to the file manager's device listener", function()
            local fm = open_sheet()
            local suspend = stub(fm.devicelistener, "onRequestSuspend", function()
                return true
            end)
            cleanup(function()
                suspend:revert()
            end)
            tap("Sleep")
            assert.stub(suspend).was.called(1)
            assert.is_nil(Sheet.shown)
        end)

        it("is muted with not available when the dispatcher lists no suspend, and a tap only says so", function()
            no_actions()
            open_sheet()
            local r = row("Sleep")
            assert.is_true(r.muted)
            assert.equals("not available", r.detail)
            local execute = spy.on(Dispatcher, "execute")
            cleanup(function()
                execute:revert()
            end)
            tap("Sleep")
            assert.spy(execute).was_not.called()
            local note = message()
            assert.is_not_nil(note)
            assert.equals("Sleep isn't available here.", note.text)
        end)
    end)
end)
