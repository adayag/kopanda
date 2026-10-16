-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/push_spec.lua. Active when KOPANDA_NOTICES names a file: every InfoMessage
-- shown (an instance whose class is InfoMessage, frontend/ui/widget/widget.lua:26-31, :40-48)
-- has its text appended to that file as one line, newlines written as \n, before
-- UIManager:show (frontend/ui/uimanager.lua:229) shows it. Installed before any plugin runs
-- (reader.lua:190), so the plugin's own UIManager:show calls go through it.
local notices = os.getenv("KOPANDA_NOTICES")
if not notices or notices == "" then
    return
end

local logger = require("logger")

local ok, err = pcall(function()
    local InfoMessage = require("ui/widget/infomessage")
    local UIManager = require("ui/uimanager")

    local show = UIManager.show
    UIManager.show = function(self, widget, ...)
        if type(widget) == "table" and getmetatable(widget) == InfoMessage then
            local written, write_err = pcall(function()
                local f = assert(io.open(notices, "a"))
                f:write(tostring(widget.text):gsub("\n", "\\n"), "\n")
                f:close()
            end)
            if not written then
                logger.warn("KOPANDA_SCENARIO: could not record a notice", write_err)
            end
        end
        return show(self, widget, ...)
    end
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
