-- KoPanda's settings, opened from Tools › KoPanda › Settings and from the home. KoPanda has no
-- settings yet, so this says so.
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local SettingsMenu = {}

function SettingsMenu.open()
    UIManager:show(InfoMessage:new{
        text = "KoPanda has no settings yet.",
    })
end

return SettingsMenu
