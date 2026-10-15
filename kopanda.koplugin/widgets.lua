-- The home's widget registry: a widget id from layout.rows to its module under widgets/. A
-- module is { id, settings_prefix, height(width, ctx), build(width, ctx), tap(ctx)? }: build
-- returns a KOReader widget exactly width wide, height its height there, and tap, when present,
-- is what a tap inside the slot does. ctx carries the look, the palette variant, the text size,
-- the time of the build, the screen and the home.
-- Each module is also required from main.lua, so it loads while the plugin root is on
-- package.path.
local Widgets = {}

local modules = {}

-- The module for id, or nil when this plugin has none.
function Widgets.get(id)
    return modules[id]
end

return Widgets
