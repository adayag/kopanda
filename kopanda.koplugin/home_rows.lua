-- The home's rows: the widget tree a home draws, built from the layout.rows setting as rows of
-- widgets (layout.lua places them, widgets.lua finds them) in the active look, with its header
-- and footer chrome filled beneath them.
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local Layout = require("layout")
local Looks = require("looks")
local Settings = require("settings")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local Screen = require("device").screen

local HomeRows = {}

-- A filled rectangle at (x, y) offset by rect's own. KOReader's paintRect greys any colour by
-- luminance (base/ffi/blitbuffer.lua:1704-1724), so a colour goes through paintRectRGB32
-- (:1827), as the swatch screen paints.
local function fill(bb, x, y, rect, color)
    if Blitbuffer.isColor8(color) then
        bb:paintRect(x + rect.x, y + rect.y, rect.w, rect.h, color)
    else
        bb:paintRectRGB32(x + rect.x, y + rect.y, rect.w, rect.h, color)
    end
end

-- The home's content: the filled chrome (paper, header, footer), then each slot's widget at
-- its place. The slot widgets are the array part, so free() and events reach them.
local Rows = WidgetContainer:extend{
    name = "kopanda_home_rows",
}

function Rows:paintTo(bb, x, y)
    for _, part in ipairs(self.fills) do
        fill(bb, x, y, part, part.color)
    end
    for i, widget in ipairs(self) do
        widget:paintTo(bb, x + self.places[i].x, y + self.places[i].y)
    end
end

-- The rectangles of the header and footer chrome, each with its colour, in drawing order; a
-- part whose colour role the look lacks is left out.
local function chrome(arranged, look, color)
    local parts = {}
    local function add(rect, role)
        local c = role and color(role)
        if rect and c then
            parts[#parts + 1] = { x = rect.x, y = rect.y, w = rect.w, h = rect.h, color = c }
        end
    end
    local header, footer = arranged.header, arranged.footer
    add(header.band, look.home.header.band_color)
    add(header.edge, look.home.header.edge_color)
    add(header.rule, look.home.header.rule_color)
    if footer then
        local tokens = look.home.footer
        add(footer, tokens.gap_color)
        add({ x = footer.x, y = footer.y, w = footer.w, h = footer.edge }, tokens.edge_color)
        local line, pitch = footer.line, footer.pitch
        if line > 0 and pitch > 0 then
            for x = footer.x, footer.x + footer.w - 1, pitch do
                add({
                    x = x,
                    y = footer.y + footer.edge,
                    w = math.min(line, footer.x + footer.w - x),
                    h = footer.h - footer.edge,
                }, tokens.stripe_color)
            end
        end
    end
    return parts
end

-- Builds home's rows at home.dimen and returns them, the slots (each { widget, rect, module,
-- built }) and the context every widget got. A widget is drawn its slot's offset below the
-- slot's top (bottom-aligned in the header row, layout.lua). A slot whose widget has no module,
-- or whose height or build raises, is left blank at its column width and logged; the rest of
-- the home still builds.
function HomeRows.build(home)
    local look = Looks.active()
    local variant = Looks.variant()
    local palette = Looks.palette(look, variant)
    local ctx = {
        look = look,
        variant = variant,
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
        home = home,
    }
    local function color(role)
        return Looks.color(palette[role])
    end
    local arranged = Layout.arrange(Settings.get("layout.rows"), ctx)
    local paper = { x = 0, y = 0, w = home.dimen.w, h = home.dimen.h, color = color("paper") }
    local fills = { paper }
    for _, part in ipairs(chrome(arranged, look, color)) do
        fills[#fills + 1] = part
    end
    local rows = Rows:new{
        dimen = Geom:new{ w = home.dimen.w, h = home.dimen.h },
        fills = fills,
        places = {},
    }
    local slots = {}
    for _, row in ipairs(arranged.rows) do
        for _, slot in ipairs(row.slots) do
            local built, y = nil, slot.y
            if not slot.module then
                logger.warn("KoPanda: no home widget named", slot.widget, "; its slot is left blank")
            elseif slot.error then
                logger.err("KoPanda: the home widget", slot.widget, "failed to measure:", slot.error)
            else
                local ok, result = pcall(slot.module.build, slot.w, ctx)
                if ok and result then
                    built = result
                    y = slot.y + slot.offset
                else
                    logger.err("KoPanda: the home widget", slot.widget, "failed to build:", result)
                end
            end
            built = built or Widget:new{ dimen = Geom:new{ w = slot.w, h = slot.h } }
            rows[#rows + 1] = built
            rows.places[#rows] = { x = slot.x, y = y }
            slots[#slots + 1] = {
                widget = slot.widget,
                rect = Geom:new{ x = slot.x, y = slot.y, w = slot.w, h = slot.h },
                module = slot.module,
                built = built,
            }
        end
    end
    return rows, slots, ctx
end

return HomeRows
