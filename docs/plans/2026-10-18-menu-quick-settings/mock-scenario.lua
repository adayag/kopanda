-- Scratch mock: a reader-menu quick-settings tab, last in the bar, drawn by the real emulator.
-- KOPANDA_MOCK=menu shoots the reader's top menu with the tab; KOPANDA_MOCK=sheet taps it.
local logger = require("logger")
local POLL_S, POLL_TRIES = 0.5, 30

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local ReaderUI = require("apps/reader/readerui")
    local ReaderMenu = require("apps/reader/modules/readermenu")
    local Device = require("device")
    local time = require("ui/time")
    local mode = os.getenv("KOPANDA_MOCK") or "menu"
    local book = os.getenv("KOPANDA_MOCK_BOOK")

    local function report_error(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        UIManager.event_hook:execute("KoPandaSettled", { screen = "mock", error = tostring(message) })
    end
    local function guarded(fn)
        return function()
            local run_ok, run_err = pcall(fn)
            if not run_ok then report_error(run_err) end
        end
    end

    local function open_sheet(menu)
        menu:onTapCloseMenu()
        UIManager:nextTick(guarded(function()
            local QuickSettings = package.loaded["quick_settings"]
            if type(QuickSettings) ~= "table" then error("quick_settings not loaded") end
            Device:getPowerDevice().getCapacity = function() return 84 end
            local NetworkMgr = require("ui/network/manager")
            NetworkMgr.isWifiOn = function() return true end
            QuickSettings.open{
                started = { wall = time.monotonic(), cpu = os.clock() },
                beneath = { close = function() end },
            }
        end))
    end

    -- The tab, as the plugin would add it: an order entry, last in the buttons, an item with
    -- an icon and no remembered index.
    local original = ReaderMenu.setUpdateItemTable
    ReaderMenu.setUpdateItemTable = function(self)
        local order = require("ui/elements/reader_menu_order")
        order.kopanda_quick_settings = order.kopanda_quick_settings or {}
        local buttons = order["KOMenu:menu_buttons"]
        if buttons[#buttons] ~= "kopanda_quick_settings" then
            table.insert(buttons, "kopanda_quick_settings")
        end
        table.insert(self.registered_widgets, {
            name = "kopanda_mock",
            addToMainMenu = function(_, items)
                items.kopanda_quick_settings = {
                    icon = "appbar.contrast",
                    remember = false,
                    callback = function() open_sheet(self) end,
                }
            end,
        })
        return original(self)
    end

    local tries = 0
    local function wait_for_reader()
        tries = tries + 1
        local reader = ReaderUI.instance
        if reader and reader.document and reader.menu then
            UIManager:scheduleIn(1.5, guarded(function()
                reader.menu:onShowMenu()
                if mode == "menu" then
                    UIManager:scheduleIn(1.5, function()
                        UIManager:forceRePaint()
                        UIManager.event_hook:execute("KoPandaSettled", { screen = "mock" })
                    end)
                else
                    UIManager:scheduleIn(1.0, guarded(function() open_sheet(reader.menu) end))
                end
            end))
        elseif tries >= POLL_TRIES then
            report_error("the book did not open")
        else
            UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
        end
    end

    local opened = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if opened or not args or args.screen ~= "home" then return end
        opened = true
        UIManager:nextTick(guarded(function()
            ReaderUI:showReader(book)
            UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
        end))
    end)
end)
if not ok then logger.warn("KOPANDA_SCENARIO: patch failed", err) end
