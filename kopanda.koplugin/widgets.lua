-- The home's widget registry: a widget id from layout.rows to its module under widgets/. A
-- module is { id, settings_prefix, height(width, ctx), build(width, ctx), baseline(width, ctx)?,
-- tap(ctx, ges, built)?, hold(ctx, ges, built)?, after_show(ctx, built)?, stale(built, ctx)? }:
-- build returns a KOReader widget exactly width wide, height its height there; baseline, when
-- present, is the y of its last line's baseline from its top, which a row aligned to its bottom
-- (the header's align, layout.lua) sets level with the other slots'; tap, when present, is what
-- a tap inside the slot does, given the gesture and the slot's built widget, and a tap that
-- returns false falls through to the home's own tap rule; hold, when present, is what a hold
-- inside the slot does, given the same, and a hold that returns false opens the home's sheet,
-- while a widget without hold opens its settings; after_show, when present, runs once after the
-- home's first paint, from the tick after its settled signal; and stale, when present, is true
-- when a built widget no longer shows the state it draws, which the home asks on a network
-- change and rebuilds for. ctx carries the look, the palette variant, the text size, the time of
-- the build, the screen and the home.
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
    launcher = "widgets/launcher",
}

-- The module for id, or nil when this plugin has none.
function Widgets.get(id)
    local name = modules[id]
    return name and require(name)
end

return Widgets
