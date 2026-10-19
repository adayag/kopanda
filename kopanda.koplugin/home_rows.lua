-- The home's rows: the widget tree a home draws, built from the layout.rows setting as rows of
-- widgets (layout.lua places them, widgets.lua finds them) in the active look, with its header
-- and footer chrome filled beneath them and the nav bar in the band below them. A look that draws
-- a wallpaper (wallpaper.lua) has it over the paper, under everything else; a look with plates
-- (plate.lua) has each row's plates painted over that, under the widgets.
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local Layout = require("layout")
local Looks = require("looks")
local NavBar = require("nav_bar")
local Plate = require("plate")
local Settings = require("settings")
local Wallpaper = require("wallpaper")
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

-- The home's content: the paper, the wallpaper (wallpaper.lua's image held by the key
-- self.wallpaper_key, or nil; asked for at each paint, since another get frees it, and left as
-- paper once it has), the header and footer chrome, the plates (self.plates, each { x, y, w, h,
-- radius }, in self.plate's tokens), then each slot's widget at its place, then the nav bar. The
-- slot widgets and the bar are the array part, so free() and events reach them; the wallpaper is
-- wallpaper.lua's, freed there.
local Rows = WidgetContainer:extend{
    name = "kopanda_home_rows",
}

function Rows:paintTo(bb, x, y)
    fill(bb, x, y, self.fills[1], self.fills[1].color)
    local image = self.wallpaper_key and Wallpaper.current(self.wallpaper_key)
    if image then
        Wallpaper.paint(bb, x, y, image)
    end
    for i = 2, #self.fills do
        local part = self.fills[i]
        fill(bb, x, y, part, part.color)
    end
    for _, plate in ipairs(self.plates) do
        Plate.paint(bb, x + plate.x, y + plate.y, plate.w, plate.h, self.plate, plate.radius)
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

-- The key of the wallpaper for look in variant on home's screen, or nil: wallpaper.lua's, held
-- for home; a failure is logged and draws none.
local function wallpaper_of(home, look, variant)
    local ok, image, key = pcall(Wallpaper.get, look, variant, home.dimen.w, home.dimen.h, home)
    if not ok then
        logger.err("KoPanda: the wallpaper failed; the home draws paper:", image)
        return nil
    end
    return image and key
end

-- Builds home's rows at home.dimen and returns them, the slots (each { widget, rect, module,
-- built }), the context every widget got and the nav bar, Home active, in the band layout.lua
-- leaves below the rows, or nil. A widget is drawn its slot's offset below the slot's top
-- (bottom-aligned in the header row, layout.lua), inside its plate's padding where it has one,
-- at the width inside it. A slot whose widget has no module, or whose height or build raises, is
-- left blank at its column width and logged; the rest of the home still builds. A bar whose build
-- raises is logged and its band left as paper; a band of no height (the bar's height raised) gets
-- no bar. ctx.plate is the look's plate tokens for the variant (Plate.spec, nil without plates),
-- lightening only over a wallpaper, for the launcher's tiles.
function HomeRows.build(home)
    local look = Looks.active()
    local variant = Looks.variant()
    local palette = Looks.palette(look, variant)
    local function color(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
    local wallpaper_key = wallpaper_of(home, look, variant)
    local ctx = {
        look = look,
        variant = variant,
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
        home = home,
        plate = Plate.spec(look, variant, wallpaper_key ~= nil, color, function(px)
            return Screen:scaleBySize(px)
        end),
    }
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
        wallpaper_key = wallpaper_key,
        plate = ctx.plate,
        plates = {},
    }
    if ctx.plate and arranged.header.plate then
        rows.plates[1] = arranged.header.plate
    end
    local slots = {}
    for _, row in ipairs(arranged.rows) do
        for _, slot in ipairs(row.slots) do
            local built, y = nil, slot.y
            local inner_w = slot.w - 2 * slot.pad_x
            if ctx.plate and slot.plate then
                rows.plates[#rows.plates + 1] = slot.plate
            end
            if not slot.module then
                logger.warn("KoPanda: no home widget named", slot.widget, "; its slot is left blank")
            elseif slot.error then
                logger.err("KoPanda: the home widget", slot.widget, "failed to measure:", slot.error)
            else
                local ok, result = pcall(slot.module.build, inner_w, ctx)
                if ok and result then
                    built = result
                    y = slot.y + slot.pad_y + slot.offset
                else
                    logger.err("KoPanda: the home widget", slot.widget, "failed to build:", result)
                end
            end
            built = built or Widget:new{ dimen = Geom:new{ w = inner_w, h = slot.h } }
            rows[#rows + 1] = built
            rows.places[#rows] = { x = slot.x + slot.pad_x, y = y }
            slots[#slots + 1] = {
                widget = slot.widget,
                rect = Geom:new{ x = slot.x, y = slot.y, w = slot.w, h = slot.h },
                module = slot.module,
                built = built,
            }
        end
    end
    local band, bar = arranged.nav, nil
    if band.h > 0 then
        local ok, result = pcall(NavBar.new, {
            look = look,
            variant = variant,
            width = home.dimen.w,
            where = "home",
            listen = false,
        })
        if ok then
            bar = result
            bar.dimen.x, bar.dimen.y = band.x, band.y
            rows[#rows + 1] = bar
            rows.places[#rows] = { x = band.x, y = band.y }
        else
            logger.err("KoPanda: the nav bar failed to build; its band is left blank:", result)
        end
    end
    return rows, slots, ctx, bar
end

return HomeRows
