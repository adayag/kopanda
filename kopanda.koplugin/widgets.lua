-- The home's widget registry: a widget id from layout.rows to its module under widgets/. A
-- module is { id, settings_prefix, height(width, ctx), build(width, ctx), baseline(width, ctx)?,
-- tap(ctx, ges, built)?, refresh(built, ctx)?, after_show(ctx, built)? }: build returns a
-- KOReader widget exactly width wide, height its height there; baseline, when present, is the y
-- of its last line's baseline from its top, which a row aligned to its bottom (the header's
-- align, layout.lua) sets level with the other slots'; tap, when present, is what a tap inside
-- the slot does, given the gesture and the slot's built widget, and a tap that returns false
-- falls through to the home's own tap rule; refresh, when present, updates a built widget in
-- place when a pre-built home is shown; and after_show, when present, runs once after the
-- home's first paint, from the tick after its settled signal. ctx carries the look, the palette
-- variant, the text size, the time of the build, the screen and the home.
-- Each module is also required from main.lua, so it loads while the plugin root is on
-- package.path.
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
}

-- The module for id, or nil when this plugin has none.
function Widgets.get(id)
    local name = modules[id]
    return name and require(name)
end

return Widgets
