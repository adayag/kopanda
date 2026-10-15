-- The home's widget registry: a widget id from layout.rows to its module under widgets/. A
-- module is { id, settings_prefix, height(width, ctx), build(width, ctx), tap(ctx)? }: build
-- returns a KOReader widget exactly width wide, height its height there, and tap, when present,
-- is what a tap inside the slot does. ctx carries the look, the palette variant, the text size,
-- the time of the build, the screen and the home.
-- Each module is also required from main.lua, so it loads while the plugin root is on
-- package.path.
local Widgets = {}

-- Module names by id, required when first asked for: a widget module reaches layout.lua, which
-- requires this registry, so none can be required while it loads.
local modules = {
    quote = "widgets/quote",
}

-- The module for id, or nil when this plugin has none.
function Widgets.get(id)
    local name = modules[id]
    return name and require(name)
end

return Widgets
