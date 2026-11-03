-- Focused mode's switch: whether focused.on is set, read where a gesture decides, so turning the mode off takes
-- effect at once.
local Settings = require("settings")
local logger = require("logger")

local Focused = {}

-- A read that raises reads as off, logged.
function Focused.on()
    local ok, on = pcall(Settings.get, "focused.on")
    if not ok then
        logger.err("KoPanda: could not read focused.on:", on)
        return false
    end
    return on == true
end

return Focused
