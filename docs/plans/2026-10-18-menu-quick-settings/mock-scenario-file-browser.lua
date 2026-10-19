-- Scratch mock: the file browser's top menu with a quick-settings tab last in the bar.
local logger = require("logger")
local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local FMMenu = require("apps/filemanager/filemanagermenu")
    local FileManager = require("apps/filemanager/filemanager")
    local original = FMMenu.setUpdateItemTable
    FMMenu.setUpdateItemTable = function(self)
        local order = require("ui/elements/filemanager_menu_order")
        order.kopanda_quick_settings = order.kopanda_quick_settings or {}
        local buttons = order["KOMenu:menu_buttons"]
        if buttons[#buttons] ~= "kopanda_quick_settings" then
            table.insert(buttons, "kopanda_quick_settings")
        end
        table.insert(self.registered_widgets, {
            name = "kopanda_mock",
            addToMainMenu = function(_, items)
                items.kopanda_quick_settings = { icon = "appbar.contrast", remember = false, callback = function() end }
            end,
        })
        return original(self)
    end
    local opened = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if opened or not args or args.screen ~= "home" then return end
        opened = true
        UIManager:scheduleIn(1.0, function()
            local run_ok, run_err = pcall(function() FileManager.instance.menu:onShowMenu() end)
            if not run_ok then logger.warn("KOPANDA_SCENARIO: " .. tostring(run_err)) end
            UIManager:scheduleIn(1.5, function()
                UIManager:forceRePaint()
                UIManager.event_hook:execute("KoPandaSettled",
                    { screen = "mock", error = not run_ok and tostring(run_err) or nil })
            end)
        end)
    end)
end)
if not ok then logger.warn("KOPANDA_SCENARIO: patch failed", err) end
