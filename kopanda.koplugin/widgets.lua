-- The home's widget registry: a widget id from layout.rows to its module under widgets/, { id, settings_prefix,
-- height(width, ctx), build(width, ctx), baseline?, tap?, hold?, after_show?, stale? }. A tap or hold that returns
-- false falls through to the home's own rule (a widget without hold opens its settings). Each module is also
-- required from main.lua, so it loads while the plugin root is on package.path.
local Widgets = {}

-- Module names by id, required when first asked for: a widget module reaches layout.lua, which
-- requires this registry, so none can be required while it loads.
local modules = {
    date = "widgets/date",
    clock = "widgets/clock",
    quote = "widgets/quote",
    stats = "widgets/stats",
    weather = "widgets/weather",
    featured = "widgets/featured",
    launcher = "widgets/launcher",
}

-- The module for id, or nil when this plugin has none.
function Widgets.get(id)
    local name = modules[id]
    return name and require(name)
end

return Widgets
