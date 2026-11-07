-- The focused panel: what it shows for a reader (its header, text size, contrast, light, night and bookmark), each
-- control's action, sent through KOReader's own events, here to a fake reader that records them, its body and its
-- opening as a sheet. The Find and Go to page dialogs themselves are spec/unit/focused_dialogs_spec.lua's.
describe("the focused panel", function()
    local harness = require("plugin_harness")
    local Device = require("device")
    local UIManager = require("ui/uimanager")
    local Clock, FocusedPanel

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

    -- A reader on page 12 of 300 of "Frankenstein", in "Letter 1": a rolling document unless opts.paging, its
    -- configurable from opts.configurable, bookmarked as opts.bookmarked. What reaches it is recorded in its calls,
    -- each event as { name, args... }, and the menu, close and file manager as their names.
    local function fake_ui(opts)
        opts = opts or {}
        local calls = {}
        local ui = {
            calls = calls,
            document = {
                file = "/books/frankenstein.epub",
                info = { has_pages = opts.paging or false },
                configurable = opts.configurable or { font_size = 22, font_gamma = 15, contrast = 1.0 },
                getPageCount = function()
                    return 300
                end,
            },
            doc_props = { display_title = "Frankenstein" },
            toc = {
                getTocTitleByPage = function(_, page)
                    return page == 12 and (opts.chapter or "Letter 1") or ""
                end,
            },
            bookmark = {
                isPageBookmarked = function()
                    return opts.bookmarked or false
                end,
            },
            menu = {
                onShowMenu = function(_, ...)
                    calls[#calls + 1] = { "ShowMenu", select("#", ...) }
                end,
            },
        }
        function ui:getCurrentPage()
            return 12
        end
        function ui:handleEvent(event)
            local call = { event.handler:sub(3) }
            for i = 1, event.args.n do
                call[#call + 1] = event.args[i]
            end
            calls[#calls + 1] = call
            return true
        end
        function ui:onClose()
            calls[#calls + 1] = { "close" }
        end
        function ui:showFileManager(file)
            calls[#calls + 1] = { "showFileManager", file }
        end
        return ui
    end

    -- Every event UIManager broadcasts for the rest of the test, as { name, args... }; none reaches a window.
    local function broadcasts()
        local sent = {}
        set(UIManager, "broadcastEvent", function(_, event)
            local call = { event.handler:sub(3) }
            for i = 1, event.args.n do
                call[#call + 1] = event.args[i]
            end
            sent[#sent + 1] = call
        end)
        return sent
    end

    before_each(function()
        undo = {}
        harness.load()
        Clock = require("widgets/clock")
        FocusedPanel = require("focused_panel")
    end)

    after_each(function()
        for i = #undo, 1, -1 do
            undo[i]()
        end
        harness.teardown()
    end)

    describe("state", function()
        local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 8, min = 42 }

        it("heads the panel: title and chapter, then page, percent, time and battery, and the hint under", function()
            set(Device, "hasBattery", function() return true end)
            set(Device:getPowerDevice(), "getCapacity", function() return 81 end)
            local header = FocusedPanel.state(fake_ui(), NOW).header
            assert.equals("Frankenstein · Letter 1", header.aside)
            assert.is_true(header.aside_above)
            assert.equals("Page 12 of 300 · 4%", header.heading)
            assert.equals(Clock.text(NOW) .. " · 81%", header.label)
            assert.equals("Hold here for all settings", header.hint)
            assert.is_true(header.hint_below)
        end)

        it("heads the panel with the title alone without a chapter, and the time alone without a battery", function()
            set(Device, "hasBattery", function() return false end)
            local header = FocusedPanel.state(fake_ui{ chapter = "" }, NOW).header
            assert.equals("Frankenstein", header.aside)
            assert.equals(Clock.text(NOW), header.label)
        end)

        it("gives a rolling document its font size and font_gamma's steps, at the stored step", function()
            local state = FocusedPanel.state(fake_ui{ configurable = { font_size = 22, font_gamma = 25 } })
            assert.same({ value = 22 }, state.text_size)
            assert.equals("font_gamma", state.contrast.name)
            assert.equals("SetFontGamma", state.contrast.event)
            assert.same({ 10, 15, 25, 30, 36, 43, 49, 56 }, state.contrast.values)
            assert.equals(3, state.contrast.index)
        end)

        it("gives a paging document no text size and contrast's steps, at the nearest step", function()
            local state = FocusedPanel.state(fake_ui{ paging = true, configurable = { contrast = 1.7 } })
            assert.is_nil(state.text_size)
            assert.equals("contrast", state.contrast.name)
            assert.equals("GammaUpdate", state.contrast.event)
            assert.same({ 0.8, 1.0, 1.5, 2.0, 4.0, 6.0, 10.0, 50.0 }, state.contrast.values)
            assert.equals(3, state.contrast.index)
        end)

        it("reads the light as quick settings does, and none without a frontlight", function()
            local QuickSettings = require("quick_settings")
            local light = FocusedPanel.state(fake_ui()).light
            assert.same(QuickSettings.light().brightness, light.brightness)
            assert.same(QuickSettings.light().warmth, light.warmth)
            set(Device, "hasFrontlight", function() return false end)
            assert.is_nil(FocusedPanel.state(fake_ui()).light)
        end)

        it("reads night mode and whether the page is bookmarked", function()
            setting("night_mode", true)
            local state = FocusedPanel.state(fake_ui{ bookmarked = true })
            assert.is_true(state.night)
            assert.is_true(state.bookmarked)
            setting("night_mode", false)
            state = FocusedPanel.state(fake_ui())
            assert.is_false(state.night)
            assert.is_false(state.bookmarked)
        end)
    end)

    describe("actions", function()
        it("steps the text size by one through KOReader's font size events", function()
            local ui = fake_ui()
            local actions = FocusedPanel.actions(ui)
            actions.text_minus()
            actions.text_plus()
            assert.same({ { "DecreaseFontSize", 1 }, { "IncreaseFontSize", 1 } }, ui.calls)
        end)

        it("steps a rolling document's contrast as KOReader's config panel does", function()
            local ui = fake_ui{ configurable = { font_size = 22, font_gamma = 15 } }
            local actions = FocusedPanel.actions(ui)
            actions.contrast_plus()
            assert.same({ { "ConfigChange", "font_gamma", 25 }, { "SetFontGamma", 25 } }, ui.calls)
        end)

        it("steps a paging document's contrast down as KOReader's config panel does", function()
            local ui = fake_ui{ paging = true, configurable = { contrast = 1.5 } }
            FocusedPanel.actions(ui).contrast_minus()
            assert.same({ { "ConfigChange", "contrast", 1.0 }, { "GammaUpdate", 1.0 } }, ui.calls)
        end)

        it("sends nothing for a contrast step past either end", function()
            local ui = fake_ui{ configurable = { font_size = 22, font_gamma = 10 } }
            FocusedPanel.actions(ui).contrast_minus()
            ui.document.configurable.font_gamma = 56
            FocusedPanel.actions(ui).contrast_plus()
            assert.same({}, ui.calls)
        end)

        it("toggles night mode by broadcast", function()
            local sent = broadcasts()
            local ui = fake_ui()
            FocusedPanel.actions(ui).night()
            assert.same({ { "ToggleNightMode" } }, sent)
            assert.same({}, ui.calls)
        end)

        it("toggles the page's bookmark", function()
            local ui = fake_ui()
            FocusedPanel.actions(ui).bookmark()
            assert.same({ { "ToggleBookmark" } }, ui.calls)
        end)

        it("goes home as the reader menu's file browser icon does: closes the book, then shows its folder", function()
            local ui = fake_ui()
            FocusedPanel.actions(ui).home()
            assert.same({ { "close" }, { "showFileManager", "/books/frankenstein.epub" } }, ui.calls)
        end)

        for _, case in ipairs({ { "contents", "chapters", "ShowToc", "table of contents" },
            { "bookmark_list", "bookmarks", "ShowBookmark", "bookmark list" } }) do
            local action, list, event, name = case[1], case[2], case[3], case[4]

            it("shows the " .. list .. " list over the book for " .. action, function()
                local ui = fake_ui()
                local shown = {}
                set(require("goto_screen"), "show", function(opts)
                    shown[#shown + 1] = opts
                    return {}
                end)
                FocusedPanel.actions(ui)[action]()
                assert.equals(1, #shown)
                assert.equals(ui, shown[1].ui)
                assert.equals(list, shown[1].list)
                assert.same({}, ui.calls)
            end)

            it("opens KOReader's " .. name .. " for " .. action .. " when the list isn't shown", function()
                local ui = fake_ui()
                set(require("goto_screen"), "show", function()
                    return nil
                end)
                FocusedPanel.actions(ui)[action]()
                assert.same({ { event } }, ui.calls)
            end)

            it("opens KOReader's " .. name .. " for " .. action .. " when the list raises", function()
                local ui = fake_ui()
                set(require("goto_screen"), "show", function()
                    error("no screen")
                end)
                FocusedPanel.actions(ui)[action]()
                assert.same({ { event } }, ui.calls)
            end)
        end

        for _, case in ipairs({ { "find", "find", "ShowFulltextSearchInput" },
            { "go_to", "go_to", "ShowGotoDialog" } }) do
            local action, dialog, event = case[1], case[2], case[3]

            it("opens the " .. dialog .. " dialog over the book for " .. action, function()
                local ui = fake_ui()
                local shown = {}
                set(require("focused_dialogs"), dialog, function(given)
                    shown[#shown + 1] = given
                end)
                FocusedPanel.actions(ui)[action]()
                assert.same({ ui }, shown)
                assert.same({}, ui.calls)
            end)

            it("sends KOReader's " .. event .. " for " .. action .. " when the dialog can't be shown", function()
                local ui = fake_ui()
                set(require("ui/widget/inputdialog"), "new", function()
                    error("no dialog")
                end)
                FocusedPanel.actions(ui)[action]()
                assert.same({ { event } }, ui.calls)
            end)
        end

        it("opens KOReader's reader menu with its config panel, as a top tap does, for the admin hold", function()
            local ui = fake_ui()
            FocusedPanel.actions(ui).admin()
            assert.same({ { "ShowConfigMenu" }, { "ShowMenu", 0 } }, ui.calls)
        end)

        it("opens KOReader's reader menu alone when its bottom menu is off", function()
            setting("show_bottom_menu", false)
            local ui = fake_ui()
            FocusedPanel.actions(ui).admin()
            assert.same({ { "ShowMenu", 0 } }, ui.calls)
        end)
    end)

    describe("body", function()
        local CONTENT_W = 1000

        -- The sheet's build ctx for ui in look id at text size size, as FocusedPanel.open builds it.
        local function bctx_for(ui, id, size)
            local Looks = require("looks")
            return { look = Looks.get(id or "editorial"), variant = "day", text_size = size or "medium",
                now = os.time(), screen = Device.screen, ui = ui }
        end

        local function ids(areas)
            local out = {}
            for i, area in ipairs(areas) do
                out[i] = area.id
            end
            return out
        end

        local function area(areas, id)
            for _, a in ipairs(areas) do
                if a.id == id then
                    return a
                end
            end
        end

        -- The body's lines' texts, lower-cased: a TextWidget's, or a tracked line's glyphs joined.
        local function texts(widget)
            local out = {}
            for _, child in ipairs(widget) do
                if child.text then
                    out[child.text:lower()] = true
                elseif #child > 0 then
                    local parts = {}
                    for _, glyph in ipairs(child) do
                        parts[#parts + 1] = glyph.text or ""
                    end
                    out[table.concat(parts):lower()] = true
                end
            end
            return out
        end

        it("lays out Night and Bookmark, the steppers, Find and Go to page, then Contents, Bookmarks and Home, "
            .. "inside the body", function()
            local made = FocusedPanel.body(bctx_for(fake_ui()), CONTENT_W)
            assert.same({ "night", "bookmark", "text_minus", "text_plus", "contrast_minus", "contrast_plus",
                "brightness_minus", "brightness_plus", "warmth_minus", "warmth_plus", "find", "go_to", "contents",
                "bookmark_list", "home" }, ids(made.areas))
            local size = made.widget:getSize()
            for _, a in ipairs(made.areas) do
                local r = a.rect
                assert.is_true(r.x >= 0 and r.y >= 0 and r.x + r.w <= CONTENT_W and r.y + r.h <= size.h, a.id)
            end
            made.widget:free()
        end)

        it("sets Brightness and Warmth side by side, Text size and Contrast at full width above them", function()
            local made = FocusedPanel.body(bctx_for(fake_ui()), CONTENT_W)
            local a = made.areas
            local brightness_minus, brightness_plus = area(a, "brightness_minus").rect, area(a, "brightness_plus").rect
            local warmth_minus, warmth_plus = area(a, "warmth_minus").rect, area(a, "warmth_plus").rect
            local contrast_minus, contrast_plus = area(a, "contrast_minus").rect, area(a, "contrast_plus").rect
            assert.equals(brightness_minus.y, warmth_plus.y)
            assert.is_true(brightness_plus.x + brightness_plus.w < warmth_minus.x)
            assert.equals(contrast_minus.x, brightness_minus.x)
            assert.is_true(contrast_plus.x + contrast_plus.w - (warmth_plus.x + warmth_plus.w) <= 1)
            assert.is_true(contrast_plus.y + contrast_plus.h <= brightness_minus.y)
            made.widget:free()
        end)

        it("keeps Brightness at full width on a device without warmth", function()
            local QuickSettings = require("quick_settings")
            local light = QuickSettings.light()
            light.warmth = nil
            set(QuickSettings, "light", function()
                return light
            end)
            local made = FocusedPanel.body(bctx_for(fake_ui()), CONTENT_W)
            assert.is_nil(area(made.areas, "warmth_minus"))
            local plus, contrast_plus = area(made.areas, "brightness_plus").rect, area(made.areas, "contrast_plus").rect
            assert.equals(contrast_plus.x, plus.x)
            made.widget:free()
        end)

        it("sets Find and Go to page in a row of their own above Contents, Bookmarks and Home", function()
            local made = FocusedPanel.body(bctx_for(fake_ui()), CONTENT_W)
            local find, go_to = area(made.areas, "find").rect, area(made.areas, "go_to").rect
            local contents = area(made.areas, "contents").rect
            assert.equals(find.y, go_to.y)
            assert.is_true(find.x + find.w <= go_to.x)
            assert.equals(find.y + find.h + Device.screen:scaleBySize(bctx_for(fake_ui()).look.quick_settings.grid_gap),
                contents.y)
            assert.is_true(texts(made.widget)["find"])
            assert.is_true(texts(made.widget)["go to page"])
            made.widget:free()
        end)

        it("leaves Text size out for a paging document", function()
            local made = FocusedPanel.body(bctx_for(fake_ui{ paging = true, configurable = { contrast = 1.0 } }),
                CONTENT_W)
            assert.is_nil(area(made.areas, "text_minus"))
            assert.is_nil(area(made.areas, "text_plus"))
            assert.is_table(area(made.areas, "contrast_plus"))
            made.widget:free()
        end)

        it("closes the panel before Home, Bookmark, the lists and the dialogs, and keeps it open for Night and the "
            .. "steppers", function()
            local made = FocusedPanel.body(bctx_for(fake_ui()), CONTENT_W)
            for _, a in ipairs(made.areas) do
                local closes = a.id == "home" or a.id == "bookmark" or a.id == "contents" or a.id == "bookmark_list"
                    or a.id == "find" or a.id == "go_to"
                assert.equals(closes, a.close_first == true, a.id)
                assert.is_function(a.tap, a.id)
                assert.is_nil(a.hold, a.id)
            end
            made.widget:free()
        end)

        it("runs each control's action on its tap", function()
            local ui = fake_ui{ configurable = { font_size = 22, font_gamma = 15 } }
            set(require("goto_screen"), "show", function()
                return nil
            end)
            local made = FocusedPanel.body(bctx_for(ui), CONTENT_W)
            area(made.areas, "text_plus").tap()
            area(made.areas, "contrast_minus").tap()
            area(made.areas, "bookmark").tap()
            area(made.areas, "contents").tap()
            area(made.areas, "bookmark_list").tap()
            area(made.areas, "home").tap()
            assert.same({ { "IncreaseFontSize", 1 }, { "ConfigChange", "font_gamma", 10 }, { "SetFontGamma", 10 },
                { "ToggleBookmark" }, { "ShowToc" }, { "ShowBookmark" }, { "close" },
                { "showFileManager", "/books/frankenstein.epub" } }, ui.calls)
            made.widget:free()
        end)

        it("offers Bookmark on a plain page and Remove bookmark on a bookmarked one", function()
            local made = FocusedPanel.body(bctx_for(fake_ui()), CONTENT_W)
            assert.is_true(texts(made.widget)["bookmark"])
            made.widget:free()
            made = FocusedPanel.body(bctx_for(fake_ui{ bookmarked = true }), CONTENT_W)
            assert.is_true(texts(made.widget)["remove bookmark"])
            made.widget:free()
        end)

        it("fits whole on the Paperwhite 7th gen and the Colorsoft at its own size in every look", function()
            local Looks = require("looks")
            local SheetLayout = require("sheet_layout")
            for _, screen in ipairs({ { 1072, 1448 }, { 1264, 1680 } }) do
                harness.at_screen(screen[1], screen[2], function()
                    for _, id in ipairs(Looks.ids()) do
                        local ui = fake_ui()
                        local laid = SheetLayout.build(FocusedPanel.spec(ui),
                            bctx_for(ui, id, FocusedPanel.TEXT_SIZE), "day")
                        local where = id .. " at " .. screen[1] .. "x" .. screen[2]
                        assert.is_false(laid.too_tall, where)
                        assert.equals(0, laid.left_out, where)
                        laid.widget:free()
                    end
                end)
            end
        end)
    end)

    describe("open", function()
        it("shows the panel over the reader, its hold on the header alone opening KOReader's menu", function()
            local Sheet = require("sheet")
            local ui = fake_ui()
            FocusedPanel.open(ui)
            local sheet = Sheet.shown
            assert.is_table(sheet)
            assert.equals("focused_panel", sheet.spec.name)
            assert.is_true(sheet.spec.header_hold)
            assert.equals("Hold here for all settings", sheet.spec.header.hint)
            sheet.spec.hold()
            assert.same({ { "ShowConfigMenu" }, { "ShowMenu", 0 } }, ui.calls)
            Sheet.close()
        end)

        it("draws at one size whatever the text size setting", function()
            local Settings = require("settings")
            local Sheet = require("sheet")
            local heights = {}
            for _, size in ipairs({ "medium", "large", "extra_large" }) do
                Settings.set("text_size", size)
                FocusedPanel.open(fake_ui())
                heights[#heights + 1] = Sheet.shown.rect.h
                Sheet.close()
            end
            assert.equals(heights[1], heights[2])
            assert.equals(heights[1], heights[3])
        end)

        it("heads the panel again after a Text size step, which repaginates the book", function()
            local Sheet = require("sheet")
            local ui = fake_ui()
            FocusedPanel.open(ui)
            ui.document.getPageCount = function()
                return 320
            end
            local plus
            for _, a in ipairs(Sheet.shown.areas) do
                if a.id == "text_plus" then
                    plus = a.rect
                end
            end
            Sheet.shown:onTapSheet(nil, harness.gesture("tap", plus.x + plus.w / 2, plus.y + plus.h / 2))
            assert.same({ { "IncreaseFontSize", 1 } }, ui.calls)
            assert.truthy(Sheet.shown.spec.header.heading:find("of 320", 1, true), Sheet.shown.spec.header.heading)
            Sheet.close()
        end)

        it("closes when the screen turns, leaving the event to the windows beneath", function()
            local Event = require("ui/event")
            local Sheet = require("sheet")
            local turned = { Event:new("SetRotationMode", 1), Event:new("SetDimensions", Device.screen:getSize()) }
            for _, event in ipairs(turned) do
                FocusedPanel.open(fake_ui())
                local sheet = Sheet.shown
                assert.is_falsy(sheet:handleEvent(event), event.handler)
                assert.is_nil(Sheet.shown, event.handler)
                assert.is_false(UIManager:isWidgetShown(sheet), event.handler)
            end
        end)

        it("raises when the panel could not be shown, so its caller can fall back", function()
            local ui = fake_ui()
            ui.document.configurable = nil
            assert.has_error(function()
                FocusedPanel.open(ui)
            end)
        end)
    end)
end)
