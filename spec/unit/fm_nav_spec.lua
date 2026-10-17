-- FmNav (the nav bar's C4 and C5): the upgrade tripwire on KOReader's unwrapped
-- FileManager.setupLayout, then the wrapper's layout, taps, re-layouts, night mode, refusal,
-- single install, settled signal and failure paths on a real file manager.
describe("the file browser's nav bar", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Event = require("ui/event")
    local FileChooser = require("ui/widget/filechooser")
    local FileManager = require("apps/filemanager/filemanager")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local PathChooser = require("ui/widget/pathchooser")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local FmNav, Home, Looks, NavBar, logged

    before_each(function()
        harness.load()
        FmNav = package.loaded["fm_nav"]
        Home = package.loaded["home"]
        Looks = package.loaded["looks"]
        NavBar = package.loaded["nav_bar"]
        logged = spy.on(logger, "err")
    end)

    -- What a case replaced outside KoPanda's modules, put back after it, latest first.
    local restores = {}

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        logger.err:revert()
        harness.teardown()
    end)

    local function band()
        return NavBar.height(Looks.active(), Screen)
    end

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    -- How many logger.err calls mention text.
    local function logged_count(text)
        local count = 0
        for _, call in ipairs(logged.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    count = count + 1
                    break
                end
            end
        end
        return count
    end

    -- A file manager on top with its home closed, painted.
    local function fm_on_top()
        local fm = harness.show_fm()
        harness.tick(2)
        Home.close()
        harness.tick()
        assert.equals(fm, harness.top())
        return fm
    end

    -- The file manager is on top and still takes input: a tap in KOReader's top menu zone opens
    -- its menu (filemanagermenu.lua:72-90), which is then closed again.
    local function usable(fm)
        assert.equals(fm, harness.top())
        send(harness.gesture("tap", Screen:getWidth() / 2, Screen:getHeight() / 16))
        assert.is_not_nil(fm.menu.menu_container)
        assert.equals(fm.menu.menu_container, harness.top())
        fm.menu:onCloseFileManagerMenu()
        assert.equals(fm, harness.top())
    end

    -- The centre of tab i's column on the frame's bar, in screen coordinates.
    local function tab_centre(bar, i)
        local column = bar.columns[i]
        return bar.dimen.x + bar.padding_x + column.x + math.floor(column.w / 2),
            bar.dimen.y + math.floor(bar.dimen.h / 2)
    end

    -- A tap zone on the file manager over rect's ratios, recording what reaches it.
    local function zone_on(fm, ges, ratios)
        local received = {}
        fm:registerTouchZones{ {
            id = "kopanda_spec_fm_nav_" .. ges,
            ges = ges,
            screen_zone = ratios,
            handler = function(g)
                received[#received + 1] = g
                return true
            end,
        } }
        return received
    end

    -- LauncherEntries.run replaced with a recorder of its entries.
    local function record_runs()
        local runs = {}
        package.loaded["launcher_entries"].run = function(entry)
            runs[#runs + 1] = entry
        end
        return runs
    end

    local function rgb_at(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local function hex_rgb(hex)
        local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
        return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
    end

    describe("the upgrade tripwire", function()
        -- When a case here fails, KOReader has moved or reshaped what fm_nav.lua relies on:
        -- re-read FileManager.setupLayout and every line HOOKS.md cites under "The nav bar in the
        -- file browser", change fm_nav.lua and HOOKS.md to match, then change the pin here.
        it("finds setupLayout at filemanager.lua:116, unwrapped until a file manager loads KoPanda", function()
            assert.equals(harness.fm_setup_layout, FileManager.setupLayout)
            local info = debug.getinfo(harness.fm_setup_layout, "S")
            local suffix = "frontend/apps/filemanager/filemanager.lua"
            assert.equals(suffix, info.source:sub(-#suffix), info.source)
            assert.equals(116, info.linedefined)
        end)

        it("lays out one FrameContainer holding only the file chooser, at the screen's height", function()
            local fm = harness.show_fm()
            harness.fm_setup_layout(fm)
            local fm_ui = fm[1]
            assert.equals(FrameContainer, getmetatable(fm_ui))
            assert.equals(1, #fm_ui)
            assert.equals(fm.file_chooser, fm_ui[1])
            assert.equals("filemanager", fm.file_chooser.name)
            assert.equals(Screen:getHeight(), fm.file_chooser.dimen.h)
        end)

        -- A chooser outside the file manager reads its folder shortcuts through ui
        -- (frontend/ui/widget/filechooser.lua:336-337).
        it("builds a chooser at the height given it or carried on FileChooser", function()
            local fm = harness.show_fm()
            assert.equals(500, FileChooser:new{ path = harness.library, height = 500, ui = fm }.dimen.h)
            FileChooser.height = 500
            local ok, chooser = pcall(FileChooser.new, FileChooser, { path = harness.library, ui = fm })
            FileChooser.height = nil
            assert.is_true(ok, tostring(chooser))
            assert.equals(500, chooser.dimen.h)
        end)
    end)

    describe("the layout", function()
        it("builds the chooser short of the band and the bar in it with Library active", function()
            local fm = fm_on_top()
            local w, h = Screen:getWidth(), Screen:getHeight()
            assert.equals(h - band(), fm.file_chooser.dimen.h)
            local footer = fm.file_chooser.page_info_text.dimen
            assert.truthy(footer.y + footer.h <= h - band(), footer.y + footer.h)
            local frame = fm[1]
            assert.equals(FmNav.Frame, getmetatable(frame))
            assert.equals(frame.bar, frame[1])
            assert.equals(fm.file_chooser, frame[2][1])
            assert.equals("library", NavBar.TABS[frame.bar.active].id)
            assert.same({ 0, h - band(), w, band() },
                { frame.bar.dimen.x, frame.bar.dimen.y, frame.bar.dimen.w, frame.bar.dimen.h })
            assert.equals(fm.file_chooser.layout, fm.layout)
            assert.is_nil(rawget(FileChooser, "height"))
            assert.equals(h, PathChooser:new{ path = harness.library, ui = fm }.dimen.h)
        end)

        it("leaves setupLayout KOReader's when KoPanda is refused", function()
            package.loaded["guards"].refused = function()
                return true
            end
            local fm = harness.show_fm()
            assert.equals(harness.fm_setup_layout, FileManager.setupLayout)
            assert.equals(FrameContainer, getmetatable(fm[1]))
            assert.equals(Screen:getHeight(), fm.file_chooser.dimen.h)
        end)

        it("runs the original alone for a refused instance once the wrapper is in", function()
            harness.show_fm():onClose()
            package.loaded["guards"].refused = function()
                return true
            end
            local fm = harness.show_fm()
            assert.is_true(fm.kopanda.refused)
            assert.is_not.equals(harness.fm_setup_layout, FileManager.setupLayout)
            assert.equals(FrameContainer, getmetatable(fm[1]))
            assert.equals(Screen:getHeight(), fm.file_chooser.dimen.h)
        end)

        it("wraps once for two file managers in a row, each short of the band", function()
            local first = harness.show_fm()
            local wrapper = FileManager.setupLayout
            assert.is_not.equals(harness.fm_setup_layout, wrapper)
            first:onClose()
            local second = harness.show_fm()
            assert.equals(wrapper, FileManager.setupLayout)
            assert.equals(Screen:getHeight() - band(), second.file_chooser.dimen.h)
            assert.equals(FmNav.Frame, getmetatable(second[1]))
        end)
    end)

    describe("a tap or hold in the bar", function()
        -- cover-grid C8: Library's entry shows the library over the file browser.
        it("runs Library's entry, which shows the library over the file browser", function()
            local fixture = require("library_fixture")
            fixture.install({ [fixture.ROOT] = { books = fixture.books(2) } })
            finally(fixture.restore)
            local fm = fm_on_top()
            local homes = 0
            fm.onHome = function()
                homes = homes + 1
                return true
            end
            local runs = spy.on(package.loaded["launcher_entries"], "run")
            finally(function()
                runs:revert()
            end)
            send(harness.gesture("tap", tab_centre(fm[1].bar, 2)))
            local Library = package.loaded["library"]
            assert.spy(runs).was.called(1)
            assert.spy(runs).was.called_with({ kind = "kopanda", target = "library" })
            assert.is_not_nil(Library.shown)
            assert.equals(Library.shown, harness.top())
            assert.equals(fm, harness.top(2))
            assert.equals(0, homes)
        end)

        it("shows the home from Home", function()
            local fm = fm_on_top()
            send(harness.gesture("tap", tab_centre(fm[1].bar, 1)))
            assert.is_not_nil(Home.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("runs Authors, History and Settings through the launcher's entries", function()
            local fm = fm_on_top()
            local runs = record_runs()
            for i = 3, 5 do
                send(harness.gesture("tap", tab_centre(fm[1].bar, i)))
            end
            assert.same({
                { kind = "kopanda", target = "authors" },
                { kind = "koreader", target = "history" },
                { kind = "kopanda", target = "settings" },
            }, runs)
        end)

        -- series-and-authors C8, D17.
        it("shows the Authors list over the file browser from Authors", function()
            local fixture = require("shelf_fixture")
            fixture.install({ fixture.book("Earthsea", { authors = { "Ursula K. Le Guin" } }) })
            local fm = fm_on_top()
            send(harness.gesture("tap", tab_centre(fm[1].bar, 3)))
            local screen = package.loaded["authors_screen"].shown
            assert.is_not_nil(screen)
            assert.equals(screen, harness.top())
            assert.equals(fm, harness.top(2))
            assert.same({ { kind = "list" }, 1 }, { screen:view(), screen.page })
        end)

        it("runs Settings and not a corner zone bound on the file manager", function()
            local fm = fm_on_top()
            local runs = record_runs()
            local zone = zone_on(fm, "tap", { ratio_x = 7 / 8, ratio_y = 7 / 8, ratio_w = 1 / 8, ratio_h = 1 / 8 })
            send(harness.gesture("tap", Screen:getWidth() - 10, Screen:getHeight() - 10))
            assert.same({ { kind = "kopanda", target = "settings" } }, runs)
            assert.same({}, zone)
        end)

        it("runs nothing for a hold outside Settings, which reaches no zone beneath", function()
            local fm = fm_on_top()
            local runs = record_runs()
            local homes = 0
            fm.onHome = function()
                homes = homes + 1
            end
            local zone = zone_on(fm, "hold", { ratio_x = 0, ratio_y = 7 / 8, ratio_w = 1, ratio_h = 1 / 8 })
            for i = 1, 4 do
                send(harness.gesture("hold", tab_centre(fm[1].bar, i)))
            end
            assert.same({}, runs)
            assert.equals(0, homes)
            assert.is_nil(Home.shown)
            assert.is_nil(package.loaded["sheet"].shown)
            assert.equals(fm, harness.top())
            assert.same({}, zone)
        end)

        -- bars/quick-settings' C8: over the bare file browser, the Settings hold opens the
        -- quick-settings sheet, whose Night cell (its sixth area, quick_settings_spec.lua, "the
        -- areas") then toggles night mode.
        it("opens the quick-settings sheet over the file manager on a hold on Settings", function()
            local night_mode = rawget(Screen, "night_mode")
            local had, setting = G_reader_settings:has("night_mode"), G_reader_settings:readSetting("night_mode")
            restores[#restores + 1] = function()
                Screen.night_mode = night_mode
                if had then
                    G_reader_settings:saveSetting("night_mode", setting)
                else
                    G_reader_settings:delSetting("night_mode")
                end
            end
            G_reader_settings:saveSetting("night_mode", false)
            Screen.night_mode = false
            local fm = fm_on_top()
            local Sheet = package.loaded["sheet"]
            local zone = zone_on(fm, "hold", { ratio_x = 0, ratio_y = 7 / 8, ratio_w = 1, ratio_h = 1 / 8 })
            send(harness.gesture("hold", tab_centre(fm[1].bar, 5)))
            assert.is_not_nil(Sheet.shown)
            assert.equals("quick_settings", Sheet.shown.spec.name)
            assert.equals(Sheet.shown, harness.top())
            assert.equals(fm, harness.top(2))
            assert.is_nil(Home.shown)
            assert.same({}, zone)
            harness.tick(3)
            local night = Sheet.shown.areas[6].rect
            send(harness.gesture("tap", night.x + math.floor(night.w / 2), night.y + math.floor(night.h / 2)))
            assert.is_true(Screen.night_mode)
            assert.is_true(G_reader_settings:isTrue("night_mode"))
            -- Back to day through the same cell, so the screen's inversion is KOReader's to undo.
            harness.tick(2)
            night = Sheet.shown.areas[6].rect
            send(harness.gesture("tap", night.x + math.floor(night.w / 2), night.y + math.floor(night.h / 2)))
            assert.is_false(Screen.night_mode)
        end)

        it("leaves a tap on a book row above the band to the chooser", function()
            local fm = fm_on_top()
            local selected = {}
            fm.file_chooser.onFileSelect = function(_, item)
                selected[#selected + 1] = item
                return true
            end
            local row
            for _, widget in ipairs(fm.file_chooser.item_group) do
                if not row and widget.entry and widget.entry.is_file then
                    row = widget
                end
            end
            assert.truthy(row.dimen.y + row.dimen.h <= fm[1].bar.dimen.y)
            send(harness.gesture("tap", row.dimen.x + row.dimen.w / 2, row.dimen.y + row.dimen.h / 2))
            assert.equals(1, #selected)
            assert.equals(row.entry.path, selected[1].path)
        end)
    end)

    describe("a re-layout", function()
        local function laid_out(fm)
            local frame = fm[1]
            assert.equals(FmNav.Frame, getmetatable(frame))
            assert.equals(Screen:getWidth(), frame.bar.dimen.w)
            assert.equals(Screen:getHeight() - band(), frame.bar.dimen.y)
            assert.equals(Screen:getHeight() - band(), fm.file_chooser.dimen.h)
            assert.equals(Screen:getWidth(), fm.file_chooser.dimen.w)
        end

        it("keeps the bar and the short chooser through reinit", function()
            local fm = fm_on_top()
            local before = fm[1]
            fm:reinit()
            assert.is_not.equals(before, fm[1])
            laid_out(fm)
        end)

        it("follows a rotation to landscape and back", function()
            local fm = fm_on_top()
            local mode = Screen:getRotationMode()
            restores[#restores + 1] = function()
                Screen:setRotationMode(mode)
            end
            fm:onSetRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE)
            assert.truthy(Screen:getWidth() > Screen:getHeight())
            laid_out(fm)
            fm:onSetRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
            assert.truthy(Screen:getWidth() < Screen:getHeight())
            laid_out(fm)
        end)
    end)

    describe("night mode", function()
        it("rebuilds the bar once in the paint after it turns on and fills the band inverted", function()
            local night_mode = rawget(Screen, "night_mode")
            restores[#restores + 1] = function()
                Screen.night_mode = night_mode
            end
            Screen.night_mode = false
            local fm = fm_on_top()
            local frame = fm[1]
            local day_bar = frame.bar
            assert.equals("day", frame.variant)
            Screen.night_mode = true
            local w, h = Screen:getWidth(), Screen:getHeight()
            local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
            frame:paintTo(bb, 0, 0)
            local night_bar = frame.bar
            assert.is_not.equals(day_bar, night_bar)
            assert.equals(night_bar, frame[1])
            assert.equals("night", frame.variant)
            frame:paintTo(bb, 0, 0)
            assert.equals(night_bar, frame.bar)
            local look = Looks.active()
            local night = hex_rgb(look.palettes.night[look.nav.fill_color])
            assert.same({ 255 - night[1], 255 - night[2], 255 - night[3] }, rgb_at(bb, 1, h - 2))
            bb:free()
        end)
    end)

    describe("the settled signal", function()
        local signals, listener

        before_each(function()
            signals = {}
            listener = function(payload)
                if payload.screen == "file_browser" then
                    signals[#signals + 1] = payload
                end
            end
            UIManager.event_hook:register("KoPandaSettled", listener)
        end)

        after_each(function()
            UIManager.event_hook:unregister("KoPandaSettled", listener)
        end)

        it("goes out once after a paint on top, and not after the next", function()
            local fm = fm_on_top()
            harness.tick(2)
            assert.equals(1, #signals)
            assert.equals("number", type(signals[1].paint_ms))
            assert.truthy(signals[1].paint_ms > 0)
            UIManager:setDirty(fm, "ui")
            harness.tick(2)
            assert.equals(1, #signals)
        end)

        -- A reinit lays out a new frame: its band's height, read once the layout has begun, takes
        -- 2 ms of CPU, the wait for the repaint 500 ms and the file browser's paint 4 ms.
        it("counts cpu_ms on the CPU clock over the layout and the paint, not the time between", function()
            local fm = fm_on_top()
            harness.tick(2)
            assert.equals(1, #signals)
            local setup, height = FileManager.setupLayout, NavBar.height
            restores[#restores + 1] = function()
                FileManager.setupLayout, NavBar.height = setup, height
            end
            harness.with_cpu_clock(1, function(cpu)
                local laying_out, counted = false, false
                FileManager.setupLayout = function(...)
                    laying_out = true
                    setup(...)
                    laying_out = false
                end
                NavBar.height = function(...)
                    if laying_out and not counted then
                        counted = true
                        cpu.now = cpu.now + 0.002
                    end
                    return height(...)
                end
                fm:reinit()
                assert.is_true(counted)
                cpu.now = cpu.now + 0.5
                local fm_ui = fm[1].fm_ui
                local fm_ui_paint = fm_ui.paintTo
                fm_ui.paintTo = function(...)
                    cpu.now = cpu.now + 0.004
                    return fm_ui_paint(...)
                end
                harness.tick(3)
            end)
            assert.equals(2, #signals)
            assert.equals(6, signals[2].cpu_ms)
        end)

        -- The frame painted first is replaced before its signal's tick, so only the frame that
        -- replaced it, painted next, sends one.
        it("goes out once when a reinit replaces the frame before its paint settles", function()
            local fm = harness.show_fm()
            harness.tick(2)
            Home.close()
            assert.equals(fm, harness.top())
            fm[1]:paintTo(Screen.bb, 0, 0)
            fm:reinit()
            harness.tick(2)
            UIManager:setDirty(fm, "ui")
            harness.tick(2)
            assert.equals(1, #signals)
        end)

        it("does not go out for a paint under the home", function()
            local fm = harness.show_fm()
            harness.tick(2)
            assert.equals(Home.shown, harness.top())
            fm[1]:paintTo(Screen.bb, 0, 0)
            harness.tick(2)
            assert.same({}, signals)
        end)
    end)

    describe("failing safe", function()
        it("runs the original alone at full height when the band raises", function()
            NavBar.height = function()
                error("kopanda-test: band failed")
            end
            local fm = fm_on_top()
            assert.equals(FrameContainer, getmetatable(fm[1]))
            assert.equals(Screen:getHeight(), fm.file_chooser.dimen.h)
            assert.truthy(logged_count("kopanda-test: band failed") > 0)
            usable(fm)
        end)

        it("re-raises the original's own error unchanged with FileChooser's height put back", function()
            local real = FileManager.setupLayout
            local failure = { "kopanda-test: setupLayout failed" }
            local failing = false
            FileManager.setupLayout = function(...)
                if failing then
                    error(failure, 0)
                end
                return real(...)
            end
            local fm = fm_on_top()
            failing = true
            local ok, err = pcall(fm.reinit, fm)
            failing = false
            assert.is_false(ok)
            assert.equals(failure, err)
            assert.is_nil(rawget(FileChooser, "height"))
            failure = "kopanda-test: setupLayout failed"
            failing = true
            ok, err = pcall(fm.reinit, fm)
            failing = false
            assert.is_false(ok)
            assert.equals(failure, err)
            assert.is_nil(rawget(FileChooser, "height"))
            usable(fm)
        end)

        it("leaves the original's layout in fm[1] when the bar's build raises", function()
            NavBar.new = function()
                error("kopanda-test: bar failed")
            end
            local fm = fm_on_top()
            assert.equals(FrameContainer, getmetatable(fm[1]))
            assert.equals(fm.file_chooser, fm[1][1])
            assert.truthy(logged_count("kopanda-test: bar failed") > 0)
            local w, h = Screen:getWidth(), Screen:getHeight()
            local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
            bb:fill(Blitbuffer.COLOR_BLACK)
            fm:paintTo(bb, 0, 0)
            assert.same({ 255, 255, 255 }, rgb_at(bb, math.floor(w / 2), h - 2))
            bb:free()
            usable(fm)
        end)

        it("logs a raising bar paint once over two paints and leaves the band blank", function()
            local fm = fm_on_top()
            local frame = fm[1]
            frame.bar.paintTo = function()
                error("kopanda-test: bar paint failed")
            end
            local w, h = Screen:getWidth(), Screen:getHeight()
            local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
            bb:fill(Blitbuffer.COLOR_BLACK)
            frame:paintTo(bb, 0, 0)
            frame:paintTo(bb, 0, 0)
            assert.same({ 255, 255, 255 }, rgb_at(bb, math.floor(w / 2), h - 2))
            bb:free()
            assert.equals(1, logged_count("kopanda-test: bar paint failed"))
            usable(fm)
        end)

        it("logs a raising tab and consumes its tap", function()
            local fm = fm_on_top()
            package.loaded["launcher_entries"].run = function()
                error("kopanda-test: tab failed")
            end
            local zone = zone_on(fm, "tap", { ratio_x = 0, ratio_y = 7 / 8, ratio_w = 1, ratio_h = 1 / 8 })
            send(harness.gesture("tap", tab_centre(fm[1].bar, 5)))
            assert.same({}, zone)
            assert.equals(1, logged_count("kopanda-test: tab failed"))
            usable(fm)
        end)

        it("logs a raising reinit in a relayout and keeps the layout", function()
            local fm = fm_on_top()
            local frame = fm[1]
            fm.reinit = function()
                error("kopanda-test: reinit failed")
            end
            FmNav.relayout()
            assert.equals(frame, fm[1])
            assert.equals(1, logged_count("kopanda-test: reinit failed"))
            usable(fm)
        end)
    end)
end)
