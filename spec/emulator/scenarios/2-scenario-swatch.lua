-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/swatch_golden_spec.lua. Once the first home has settled it opens the swatch
-- screen as a user does, through the file manager's Tools › KoPanda › Swatches: the menu shown,
-- the item's callback run, the menu closed (frontend/ui/widget/touchmenu.lua:913-926). The
-- swatch's own settled signal (screen "swatch") is what the capture shoots on. Any failure is
-- reported as a "swatch" signal with error, so the spec fails at once with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local FileManager = require("apps/filemanager/filemanager")

    local function fail(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        UIManager.event_hook:execute("KoPandaSettled", { screen = "swatch", error = tostring(message) })
    end

    local function find(list, id)
        for _, item in ipairs(list) do
            if item.id == id then
                return item
            end
        end
    end

    local function open_swatches()
        local menu = FileManager.instance.menu
        menu:onShowMenu()
        local tools = assert(find(menu.tab_item_table, "tools"), "no Tools tab")
        local kopanda = assert(find(tools, "kopanda"), "no Tools › KoPanda")
        local swatches
        for _, item in ipairs(kopanda.sub_item_table) do
            if item.text == "Swatches" then
                swatches = item
            end
        end
        assert(swatches, "no Tools › KoPanda › Swatches")
        swatches.callback()
        menu:onCloseFileManagerMenu()
    end

    local opened = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if opened or not args or args.screen ~= "home" then
            return
        end
        opened = true
        UIManager:nextTick(function()
            local run_ok, run_err = pcall(open_swatches)
            if not run_ok then
                fail(run_err)
            end
        end)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
