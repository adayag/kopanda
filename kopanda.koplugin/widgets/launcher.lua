-- The launcher: launcher.entries as a grid on the home, in list order, left to right then top to
-- bottom, each entry drawn from LauncherEntries.resolve. Editorial draws text rows, each its
-- icon, its label and a hairline under it (Main.dc.html:60-62); Diner draws outlined tiles with
-- the hard tile shadow, the first three on the look's accents, the icon at the top and the label
-- at the foot (HomeRetro.dc.html:55-64); Toybox draws rounded blocks, each its icon in a ringed
-- round badge of the next of six fills and its label beside it (toybox.md). A tap on an entry
-- runs it; a tap between entries falls through to the home. A hold anywhere on it opens launcher
-- management.
local Geom = require("ui/geometry")
local Icons = require("icons")
local LauncherEntries = require("launcher_entries")
local Layout = require("layout")
local Looks = require("looks")
local Paint = require("paint")
local PaintClock = require("paint_clock")
local Settings = require("settings")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local Launcher = {
    id = "launcher",
    settings_prefix = "launcher",
}

-- One entry, dimen its rectangle: its shadow, fill and rule, its children (icon and lines) at
-- self.places, then its outline, as widgets/quote.lua paints its tile. The shadow, fill and
-- outline are rounded by radius, square without one (paint.lua).
local Entry = WidgetContainer:extend{
    name = "kopanda_launcher_entry",
    fill_color = nil,
    outline = 0,
    outline_color = nil,
    shadow_color = nil,
    shadow_x = 0,
    shadow_y = 0,
    rule = 0,
    rule_color = nil,
    radius = nil,
}

function Entry:paintTo(bb, x, y)
    local w, h = self.dimen.w, self.dimen.h
    if self.shadow_color then
        Paint.fill(bb, x + self.shadow_x, y + self.shadow_y, w, h, self.shadow_color, self.radius)
    end
    if self.fill_color then
        Paint.fill(bb, x, y, w, h, self.fill_color, self.radius)
    end
    if self.rule_color and self.rule > 0 then
        Paint.fill(bb, x, y + h - self.rule, w, self.rule, self.rule_color)
    end
    for i, child in ipairs(self) do
        child:paintTo(bb, x + self.places[i].x, y + self.places[i].y)
    end
    if self.outline > 0 then
        Paint.border(bb, x, y, w, h, self.outline, self.outline_color, self.radius)
    end
end

-- A tile's badge, dimen a square: a disc of fill_color, its icon (self[1]) at icon_place, then a
-- ring wide in ring_color round its edge (toybox.md: a 42 px round badge, a 2.5 px ink ring).
local Badge = WidgetContainer:extend{
    name = "kopanda_launcher_badge",
    fill_color = nil,
    ring = 0,
    ring_color = nil,
}

function Badge:paintTo(bb, x, y)
    local size = self.dimen.w
    local radius = math.floor(size / 2)
    if self.fill_color then
        Paint.fill(bb, x, y, size, size, self.fill_color, radius)
    end
    if self[1] then
        self[1]:paintTo(bb, x + self.icon_place.x, y + self.icon_place.y)
    end
    if self.ring > 0 and self.ring_color then
        Paint.border(bb, x, y, size, size, self.ring, self.ring_color, radius)
    end
end

-- The grid: each entry (the array part) at its rectangle in self.rects, relative to the grid's
-- top left. It keeps the settings' entries for tap, the drawn Wi-Fi state for stale, and where
-- it was last painted, so a tap on the screen finds its entry.
local Grid = WidgetContainer:extend{
    name = "kopanda_launcher",
}

function Grid:paintTo(bb, x, y)
    self.painted_at = { x = x, y = y }
    for i, entry in ipairs(self) do
        entry:paintTo(bb, x + self.rects[i].x, y + self.rects[i].y)
    end
end

-- part with its colour role replaced.
local function recolored(part, role)
    local copy = {}
    for k, v in pairs(part) do
        copy[k] = v
    end
    copy.color = role
    return copy
end

-- The label and, when the view has one, the suffix, at most width wide: { { widget, x, y } },
-- and the block's height. The suffix goes on the label's line, suffix_gap after it and on its
-- baseline, the label cut to leave it room; or, with suffix_below, on its own line under it.
local function text_block(view, width, ctx)
    local look = ctx.look
    local tokens = look.launcher
    local label_part, suffix_part = look.type.launcher_label, look.type.launcher_suffix
    if view.state == "unavailable" then
        label_part, suffix_part = recolored(label_part, "muted"), recolored(suffix_part, "muted")
    end
    if not view.suffix then
        local label = Typeset.line(label_part, view.label, width, ctx)
        return { { widget = label, x = 0, y = 0 } }, label:getSize().h
    end
    if tokens.suffix_below then
        local label = Typeset.line(label_part, view.label, width, ctx)
        local suffix = Typeset.line(suffix_part, view.suffix, width, ctx)
        local label_h = label:getSize().h
        return { { widget = label, x = 0, y = 0 }, { widget = suffix, x = 0, y = label_h } },
            label_h + suffix:getSize().h
    end
    local gap = ctx.screen:scaleBySize(tokens.suffix_gap)
    local suffix = Typeset.line(suffix_part, view.suffix, width, ctx)
    local label = Typeset.line(label_part, view.label, math.max(1, width - gap - suffix:getSize().w), ctx)
    local label_base, suffix_base = Typeset.baseline(label), Typeset.baseline(suffix)
    local base = math.max(label_base, suffix_base)
    local label_y, suffix_y = base - label_base, base - suffix_base
    return {
        { widget = label, x = 0, y = label_y },
        { widget = suffix, x = label:getSize().w + gap, y = suffix_y },
    }, math.max(label_y + label:getSize().h, suffix_y + suffix:getSize().h)
end

-- The view's icon at size in its colour, or nil for an id the registry doesn't hold, logged once
-- per build through unknown.
local function icon_of(view, size, ctx, unknown)
    local path = Icons.path(view.icon)
    if not path then
        if not unknown[view.icon] then
            unknown[view.icon] = true
            logger.warn("KoPanda: the launcher has no icon named", view.icon, "; its entry is drawn without one")
        end
        return nil
    end
    local role = view.state == "unavailable" and "muted" or "ink"
    return TintedIcon:new{ file = path, size = size, color = Looks.color(Looks.palette(ctx.look, ctx.variant)[role]) }
end

-- The grid for the entries' views at width under ctx.
local function make(width, ctx)
    local entries = Settings.get("launcher.entries")
    local n = #entries
    if n == 0 then
        return WidgetContainer:new{ dimen = Geom:new{ w = width, h = 0 } }
    end
    local look = ctx.look
    local tokens = look.launcher
    local palette = Looks.palette(look, ctx.variant)
    local function color(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
    local function scale(px)
        return ctx.screen:scaleBySize(px)
    end

    local views, wifi_off = {}, nil
    for i, entry in ipairs(entries) do
        views[i] = LauncherEntries.resolve(entry)
        if entry.kind == "koreader" and entry.target == "wifi" and views[i].state ~= "unavailable" then
            wifi_off = views[i].state == "off"
        end
    end

    local columns = tokens.columns
    local slots = {}
    for i = 1, columns do
        slots[i] = { share = 1 }
    end
    local cols = Layout.columns(width, slots, tokens.column_gap)
    local icon_px = scale(tokens.icon_size)
    local pad_x, pad_y = scale(tokens.padding.x), scale(tokens.padding.y)
    local box = look.tile.box
    local shadow = look.shadow.tile
    local shadow_x, shadow_y = 0, 0
    if box and shadow.color then
        shadow_x, shadow_y = scale(shadow.x), scale(shadow.y)
    end
    local outline = box and scale(look.stroke.outline) or 0
    local rule = box and 0 or scale(look.stroke.hairline)
    local radius = box and look.radius.box > 0 and scale(look.radius.box) or nil
    -- A boxed tile with a badge sets its icon in the badge and its label beside it.
    local badge = tokens.badge
    local badge_px = box and badge.size > 0 and scale(badge.size) or 0
    local unknown = {}

    -- Each entry's icon and text block, laid out in its column.
    local parts, block_h = {}, 0
    for i, view in ipairs(views) do
        local col = cols[(i - 1) % columns + 1]
        local inner_w
        if box and badge_px > 0 then
            inner_w = col.w - shadow_x - 2 * (outline + pad_x) - badge_px - scale(tokens.icon_gap)
        elseif box then
            inner_w = col.w - shadow_x - 2 * (outline + pad_x)
        else
            inner_w = col.w - 2 * pad_x - icon_px - scale(tokens.icon_gap)
        end
        local placed, h = text_block(view, math.max(1, inner_w), ctx)
        parts[i] = { icon = icon_of(view, icon_px, ctx, unknown), placed = placed, h = h }
        block_h = math.max(block_h, h)
    end

    local entry_h
    if box then
        entry_h = scale(tokens.tile_height)
    else
        entry_h = 2 * pad_y + math.max(icon_px, block_h) + rule
    end
    local row_gap = scale(tokens.row_gap)
    local rows = math.ceil(n / columns)

    local grid = Grid:new{
        dimen = Geom:new{ w = width, h = rows * entry_h + (rows - 1) * row_gap + shadow_y },
        entries = entries,
        views = views,
        wifi_off = wifi_off,
        rects = {},
    }
    for i, part in ipairs(parts) do
        local col = cols[(i - 1) % columns + 1]
        local row = math.floor((i - 1) / columns)
        local rect = Geom:new{ x = col.x, y = row * (entry_h + row_gap), w = col.w - shadow_x, h = entry_h }
        local entry = Entry:new{ dimen = Geom:new{ w = rect.w, h = rect.h }, places = {} }
        local function add(widget, x, y)
            entry[#entry + 1] = widget
            entry.places[#entry] = { x = x, y = y }
        end
        if box and badge_px > 0 then
            entry.fill_color = color(look.tile.fill_color)
            entry.outline, entry.outline_color = outline, color(look.tile.outline_color)
            entry.shadow_color, entry.shadow_x, entry.shadow_y = color(shadow.color), shadow_x, shadow_y
            entry.radius = radius
            local inset = part.icon and math.floor((badge_px - part.icon.size) / 2) or 0
            local disc = Badge:new{
                dimen = Geom:new{ w = badge_px, h = badge_px },
                fill_color = color(badge["fill_" .. ((i - 1) % 6 + 1) .. "_color"]),
                ring = scale(badge.outline_width),
                ring_color = color(badge.outline_color),
                icon_place = { x = inset, y = inset },
                part.icon,
            }
            local inner, inner_h = outline + pad_x, entry_h - 2 * outline
            add(disc, inner, outline + math.floor((inner_h - badge_px) / 2))
            local text_x = inner + badge_px + scale(tokens.icon_gap)
            local text_y = outline + math.floor((inner_h - part.h) / 2)
            for _, p in ipairs(part.placed) do
                add(p.widget, text_x + p.x, text_y + p.y)
            end
        elseif box then
            entry.fill_color = (i <= 3 and color(tokens["accent_" .. i .. "_color"])) or color(look.tile.fill_color)
            entry.outline, entry.outline_color = outline, color(look.tile.outline_color)
            entry.shadow_color, entry.shadow_x, entry.shadow_y = color(shadow.color), shadow_x, shadow_y
            entry.radius = radius
            local inner = outline + pad_x
            if part.icon then
                add(part.icon, inner, outline + pad_y)
            end
            local top = rect.h - outline - pad_y - part.h
            for _, p in ipairs(part.placed) do
                add(p.widget, inner + p.x, top + p.y)
            end
        else
            entry.rule, entry.rule_color = rule, color(look.tile.rule_color)
            local content_h = entry_h - 2 * pad_y - rule
            if part.icon then
                add(part.icon, pad_x, pad_y + math.floor((content_h - icon_px) / 2))
            end
            local text_x = pad_x + icon_px + scale(tokens.icon_gap)
            local text_y = pad_y + math.floor((content_h - part.h) / 2)
            for _, p in ipairs(part.placed) do
                add(p.widget, text_x + p.x, text_y + p.y)
            end
        end
        grid[i] = entry
        grid.rects[i] = rect
    end
    return grid
end

-- The height at width and the build that hands that grid over, so each entry resolves once per
-- build (typeset.lua's pairing).
Launcher.height, Launcher.build = Typeset.measured(make)

-- A tap at ges.pos on the screen: runs the entry under it, from the grid's last paint origin,
-- and consumes the tap; anywhere else returns false, so the home's next step runs. A raising run
-- reaches Home:onGesture's pcall.
function Launcher.tap(ctx, ges, built)
    local origin = built and built.painted_at
    if not (origin and built.rects and ges and ges.pos) then
        return false
    end
    local at = Geom:new{ x = ges.pos.x - origin.x, y = ges.pos.y - origin.y, w = 0, h = 0 }
    for i, rect in ipairs(built.rects) do
        if rect:contains(at) then
            LauncherEntries.run(built.entries[i], ctx)
            return true
        end
    end
    return false
end

-- A hold inside the slot opens launcher management's top level, its paint_ms from now, and
-- returns nothing, so the home takes the hold as done. launcher_manage is required here, not at
-- load, so loading the widget doesn't load the editor and picker chain.
function Launcher.hold()
    require("launcher_manage").open{ started = PaintClock.now() }
end

-- True when the grid drew a Wi-Fi entry whose on or off no longer matches NetworkMgr:isWifiOn()
-- (frontend/ui/network/manager.lua:182-186).
function Launcher.stale(built, ctx)
    local drawn_off = built and built.wifi_off
    if drawn_off == nil then
        return false
    end
    return drawn_off == require("ui/network/manager"):isWifiOn()
end

return Launcher
