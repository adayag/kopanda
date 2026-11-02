-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/focused_panel_spec.lua. Once the home is up it opens the one book in the
-- library, and once the reader has its document it runs the step KOPANDA_FOCUSED_STEP names, each
-- reporting on a "scenario" KoPandaSettled signal; any failure is reported there as error, so the
-- spec fails with the message.
--   probe (the default)  shows a one-row probe sheet over the book, built as QuickSettings.open builds
--                        its ctx; on the sheet's settled signal taps the row, and on the next tick reports
--                        sheet_painted, sheet_closed (no sheet shown) and reader_shown (the reader still
--                        on the window stack).
--   panel                opens the focused panel through FocusedPanel.open; on its settled signal reports
--                        its areas, panel_top and panel_bottom against screen_h, then taps Text size's plus
--                        and on the next tick reports panel_shown and font_size_before and font_size.
--   hooks                swipes up from the middle of DTAP_ZONE_CONFIG in the reader and on the next tick
--                        records swipe_panel_shown and swipe_config_shown (KOReader's config menu up), then
--                        closes either; then taps the middle of DTAP_ZONE_MENU and on the next tick reports
--                        those, panel_shown and menu_shown (KOReader's reader menu up); with the panel up, on
--                        its settled signal holds its header and on the next tick reports menu_after_hold and
--                        panel_after_hold.
--   goto                 bookmarks the page shown and the next through ui.bookmark:onToggleBookmark(), opens the
--                        panel and on its settled signal taps Go to; on the Go to screen's settled signal records
--                        tab, rows, has_current, has_nav, page and pages; taps the Bookmarks chip, holds the first
--                        bookmark row and on the sheet's settled signal taps Remove bookmark, recording
--                        bookmarks_before and bookmarks_after; then taps the Chapters chip and the first closed
--                        parent's toggle on the page, recording visible_before and visible_after (the rows
--                        listed) and toggle_kept (the screen still shown), then the page's last chapter row that
--                        starts off the current page, and on the next tick reports goto_closed and page_changed.
local logger = require("logger")

local POLL_S = 0.5
local POLL_TRIES = 20 -- 10 s for the book to open

local ok, err = pcall(function()
    local Device = require("device")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local Geom = require("ui/geometry")
    local ReaderUI = require("apps/reader/readerui")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")

    local NOOP = { close = function() end }

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local reported = false
    local function fail(message)
        if reported then
            return
        end
        reported = true
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        report{ error = tostring(message) }
    end

    -- Runs fn from the UI loop, any error reported as the scenario's.
    local function guarded(fn)
        return function()
            local run_ok, run_err = pcall(fn)
            if not run_ok then
                fail(run_err)
            end
        end
    end

    -- main.lua requires every KoPanda module at load; a userpatch can't require it by name once
    -- the plugin's path is gone (HOOKS.md, "`package.path` during plugin load").
    local function loaded(name)
        local module = package.loaded[name]
        if type(module) ~= "table" then
            error("the " .. name .. " module is not loaded")
        end
        return module
    end

    local function the_book()
        local dir = FileManager.instance.file_chooser.path
        local books = {}
        for entry in lfs.dir(dir) do
            if entry:match("%.epub$") then
                books[#books + 1] = dir .. "/" .. entry
            end
        end
        if #books ~= 1 then
            error(string.format("expected one .epub in %s, found %d", dir, #books))
        end
        return books[1]
    end

    local STEP = os.getenv("KOPANDA_FOCUSED_STEP") or "probe"

    local Sheet
    local probe_shown = false
    local panel_opened = false
    local result = {}

    -- A tap, hold or swipe in direction sent as KOReader sends one (frontend/ui/gesturerange.lua:21-51), at the
    -- centre of r; a swipe's pos is where it starts (frontend/device/gesturedetector.lua:762).
    local function gesture(ges, r, direction)
        local pos = Geom:new{ x = r.x + math.floor(r.w / 2), y = r.y + math.floor(r.h / 2), w = 0, h = 0 }
        logger.info(string.format("KOPANDA_SCENARIO: %s at %d,%d", ges, pos.x, pos.y))
        UIManager:sendEvent(Event:new("Gesture", { ges = ges, pos = pos, time = time.now(), direction = direction,
            distance = direction and math.floor(r.h / 2) or nil }))
    end

    local check_closed = guarded(function()
        local reader = ReaderUI.instance
        reported = true
        report{
            sheet_painted = true,
            sheet_closed = Sheet.shown == nil,
            reader_shown = reader ~= nil and UIManager:isWidgetShown(reader) or false,
        }
    end)

    -- The fields GestureRange:match reads (frontend/ui/gesturerange.lua:21-51).
    local tap_row = guarded(function()
        local sheet = Sheet.shown
        if not sheet then
            error("the probe sheet is not shown at its settled signal")
        end
        local r = sheet.rows[1] and sheet.rows[1].rect
        if not r then
            error("the probe sheet has no row")
        end
        local pos = Geom:new{ x = r.x + math.floor(r.w / 2), y = r.y + math.floor(r.h / 2), w = 0, h = 0 }
        logger.info(string.format("KOPANDA_SCENARIO: tap the probe row at %d,%d", pos.x, pos.y))
        UIManager:sendEvent(Event:new("Gesture", { ges = "tap", pos = pos, time = time.now() }))
        UIManager:nextTick(check_closed)
    end)

    local check_font = guarded(function()
        local reader = ReaderUI.instance
        local sheet = Sheet.shown
        result.panel_shown = sheet ~= nil and sheet.spec.name == "focused_panel" and UIManager:isWidgetShown(sheet)
        result.font_size = reader.document.configurable.font_size
        reported = true
        report(result)
    end)

    -- The shown sheet's area with id.
    local function area(id)
        for _, a in ipairs(Sheet.shown.areas) do
            if a.id == id then
                return a
            end
        end
        error("the focused panel has no " .. id .. " area")
    end

    local measure_panel = guarded(function()
        local sheet = Sheet.shown
        if not sheet or sheet.spec.name ~= "focused_panel" then
            error("the focused panel is not shown at its settled signal")
        end
        result.areas = #sheet.areas
        result.panel_top = sheet.panel.y
        result.panel_bottom = sheet.panel.y + sheet.panel.h
        result.screen_h = Device.screen:getHeight()
        result.font_size_before = ReaderUI.instance.document.configurable.font_size
        gesture("tap", area("text_plus").rect)
        UIManager:nextTick(check_font)
    end)

    -- KOReader's reader menu is up: ReaderMenu:onShowMenu keeps its container
    -- (frontend/apps/reader/modules/readermenu.lua:436-441).
    local function menu_shown()
        local container = ReaderUI.instance.menu.menu_container
        return container ~= nil and UIManager:isWidgetShown(container)
    end

    -- KOReader's config menu is up: ReaderConfig:onShowConfigMenu keeps its dialog
    -- (frontend/apps/reader/modules/readerconfig.lua:134-152).
    local function config_shown()
        local dialog = ReaderUI.instance.config.config_dialog
        return dialog ~= nil and UIManager:isWidgetShown(dialog)
    end

    local function panel_shown()
        local sheet = Sheet.shown
        return sheet ~= nil and sheet.spec.name == "focused_panel" and UIManager:isWidgetShown(sheet)
    end

    local check_hold = guarded(function()
        result.menu_after_hold = menu_shown()
        result.panel_after_hold = panel_shown()
        reported = true
        report(result)
    end)

    local hold_header = guarded(function()
        gesture("hold", Sheet.shown.header_rect)
        UIManager:nextTick(check_hold)
    end)

    local check_tap = guarded(function()
        result.panel_shown = panel_shown()
        result.menu_shown = menu_shown()
        if not result.panel_shown then
            reported = true
            report(result)
        end
    end)

    -- The middle of DTAP_ZONE_MENU, the top eighth (defaults.lua:59).
    local tap_top = guarded(function()
        panel_opened = true
        local size = Device.screen:getSize()
        gesture("tap", { x = 0, y = 0, w = size.w, h = math.floor(size.h / 8) })
        UIManager:nextTick(check_tap)
    end)

    -- Records what the swipe opened and closes it (readerconfig.lua:183-187), then taps the top.
    local check_swipe = guarded(function()
        result.swipe_panel_shown = panel_shown()
        result.swipe_config_shown = config_shown()
        Sheet.close()
        ReaderUI.instance.config:onCloseConfigMenu()
        UIManager:nextTick(tap_top)
    end)

    -- Up from the middle of DTAP_ZONE_CONFIG, the bottom eighth (defaults.lua:61).
    local swipe_up = guarded(function()
        Sheet = loaded("sheet")
        local size = Device.screen:getSize()
        local eighth = math.floor(size.h / 8)
        gesture("swipe", { x = 0, y = size.h - eighth, w = size.w, h = eighth }, "north")
        UIManager:nextTick(check_swipe)
    end)

    -- The reader's bookmarks: its annotations with no drawer (readerbookmark.lua:417-440).
    local function bookmark_count()
        local n = 0
        for _, item in ipairs(ReaderUI.instance.annotation.annotations) do
            if not item.drawer then
                n = n + 1
            end
        end
        return n
    end

    local GotoScreen
    local goto_opened = false
    local goto_removing = false
    local goto_window, page_before_jump

    local check_jump = guarded(function()
        result.goto_closed = GotoScreen.shown == nil and not UIManager:isWidgetShown(goto_window)
        result.page_changed = ReaderUI.instance:getCurrentPage() ~= page_before_jump
        reported = true
        report(result)
    end)

    local jump = guarded(function()
        local screen = GotoScreen.shown
        gesture("tap", screen.chips.chapters)
        local parent
        for _, row in ipairs(screen.rows) do
            if row.toggle and not screen.expanded[row.chapter.index] then
                parent = parent or row
            end
        end
        if not parent then
            error("the Go to screen's Chapters page has no closed parent")
        end
        result.visible_before = screen.count
        gesture("tap", parent.toggle)
        result.visible_after = screen.count
        result.toggle_kept = GotoScreen.shown == screen
        local rows = screen.rows
        if #rows == 0 then
            error("the Go to screen's Chapters tab has no rows")
        end
        goto_window = screen
        page_before_jump = ReaderUI.instance:getCurrentPage()
        local target
        for _, row in ipairs(rows) do
            if row.chapter.page ~= page_before_jump then
                target = row
            end
        end
        if not target then
            error("every chapter row on the Go to screen's page starts on the current page")
        end
        gesture("tap", target.rect)
        UIManager:nextTick(check_jump)
    end)

    local check_removed = guarded(function()
        result.bookmarks_after = bookmark_count()
        result.sheet_closed = Sheet.shown == nil
        result.tab_after_remove = GotoScreen.shown and GotoScreen.shown.tab
        UIManager:nextTick(jump)
    end)

    local remove_bookmark = guarded(function()
        local sheet = Sheet.shown
        if not sheet or sheet.spec.name ~= "goto_bookmark" then
            error("the Remove bookmark sheet is not shown at its settled signal")
        end
        gesture("tap", sheet.rows[1].rect)
        UIManager:nextTick(check_removed)
    end)

    local measure_goto = guarded(function()
        local screen = GotoScreen.shown
        if not screen then
            error("the Go to screen is not shown at its settled signal")
        end
        result.tab = screen.tab
        result.rows = #screen.rows
        result.has_current = false
        for _, row in ipairs(screen.rows) do
            result.has_current = result.has_current or row.current == true
        end
        result.has_nav = screen.nav ~= nil
        result.page = screen.page
        result.pages = screen.pages
        result.bookmarks_before = bookmark_count()
        gesture("tap", screen.chips.bookmarks)
        if screen.tab ~= "bookmarks" or #screen.rows == 0 then
            error("the Bookmarks chip did not show the bookmarks")
        end
        goto_removing = true
        gesture("hold", screen.rows[1].rect)
    end)

    local tap_go_to = guarded(function()
        local sheet = Sheet.shown
        if not sheet or sheet.spec.name ~= "focused_panel" then
            error("the focused panel is not shown at its settled signal")
        end
        goto_opened = true
        gesture("tap", area("go_to").rect)
    end)

    local open_goto = guarded(function()
        Sheet = loaded("sheet")
        GotoScreen = loaded("goto_screen")
        local reader = ReaderUI.instance
        reader.bookmark:onToggleBookmark()
        reader:handleEvent(Event:new("GotoViewRel", 1))
        reader.bookmark:onToggleBookmark()
        panel_opened = true
        loaded("focused_panel").open(reader)
    end)

    local open_panel = guarded(function()
        Sheet = loaded("sheet")
        panel_opened = true
        loaded("focused_panel").open(ReaderUI.instance)
    end)

    -- ctx as QuickSettings.open builds it (kopanda.koplugin/quick_settings.lua:429-436).
    local show_probe = guarded(function()
        Sheet = loaded("sheet")
        local Looks = loaded("looks")
        local Settings = loaded("settings")
        local ctx = {
            look = Looks.active(),
            variant = Looks.variant(),
            text_size = Settings.get("text_size"),
            now = os.time(),
            screen = Device.screen,
        }
        probe_shown = true
        Sheet.show({ name = "probe", rows = { { label = "Close", run = function() end } } }, ctx, { beneath = NOOP })
        if not Sheet.shown then
            error("Sheet.show left no sheet shown over the reader")
        end
    end)

    local tries = 0
    local function wait_for_reader()
        tries = tries + 1
        local reader = ReaderUI.instance
        if reader and reader.document then
            local steps = { panel = open_panel, hooks = swipe_up, ["goto"] = open_goto }
            UIManager:nextTick(steps[STEP] or show_probe)
        elseif tries >= POLL_TRIES then
            fail(string.format("the book did not open within %.0f s", POLL_S * POLL_TRIES))
        else
            UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
        end
    end

    local open_book = guarded(function()
        ReaderUI:showReader(the_book())
        UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
    end)

    local homes = 0
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if not args then
            return
        end
        if args.screen == "home" then
            homes = homes + 1
            if homes == 1 then
                UIManager:nextTick(open_book)
            end
        elseif args.screen == "sheet" and args.name == "probe" and probe_shown then
            UIManager:nextTick(tap_row)
        elseif args.screen == "sheet" and args.name == "focused_panel" and panel_opened then
            local next_step = { hooks = hold_header, ["goto"] = tap_go_to }
            UIManager:nextTick(next_step[STEP] or measure_panel)
        elseif args.screen == "goto" and goto_opened then
            UIManager:nextTick(measure_goto)
        elseif args.screen == "sheet" and args.name == "goto_bookmark" and goto_removing then
            UIManager:nextTick(remove_bookmark)
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
