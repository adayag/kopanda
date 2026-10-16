-- Test fixture: a shell plugin named ennui that does nothing. KoPanda's coexistence guard
-- matches enabled plugins by lower-cased runtime name (kopanda.koplugin/guards.lua:11-17), so
-- while this is enabled KoPanda refuses its home, and a pull disables it by this exact name.
local WidgetContainer = require("ui/widget/container/widgetcontainer")

return WidgetContainer:extend{
    name = "ennui",
    is_doc_only = false,
}
