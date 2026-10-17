-- The quick-settings sheet: a sheet whose body is the device's light and toggles, opened over the
-- home or the bare file browser. Under the header "Quick settings" and the battery's capacity, a
-- Brightness bar and a Warmth bar, each a label row over a minus button, a level bar and a plus
-- button, in native steps; then a grid of six cells, Wi-Fi, Night, Rotation lock, Sync books,
-- Screenshot and Sleep, the on ones filled, the ones that can't run greyed. Everything is read
-- from the device when the sheet lays out; nothing here writes a setting. The body's areas carry
-- an id each and no handler yet.
--
-- The minus and plus are the text "−" (U+2212) and "+" in the quick_button part (open fact F1,
-- outcome a): set by Typeset.line at the Colorsoft and painted, each differs in both looks from
-- U+0378, a code point Unicode leaves unassigned, which both draw as the missing-glyph box
-- (Editorial's text face: a 23 by 60 cell, a bar of 51 inked pixels and a cross of 98; Diner's
-- strong face: a 20 by 56 cell, 64 and 108; U+0378 an outlined box in both).
local Device = require("device")
local Geom = require("ui/geometry")
local Icons = require("icons")
local LauncherEntries = require("launcher_entries")
local Layout = require("layout")
local Looks = require("looks")
local NetworkMgr = require("ui/network/manager")
local Paint = require("paint")
local Settings = require("settings")
local Sheet = require("sheet")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local Screen = Device.screen

local QuickSettings = {}

local MINUS, PLUS = "\u{2212}", "+"
-- A bar whose read failed shows this in place of its value.
local DASH = "\u{2013}"

-- The launcher's entries whose availability greys a cell (launcher_entries.lua:60-80).
local WIFI = { kind = "koreader", target = "wifi" }
local SYNC = { kind = "plugin", plugin = "cwngsync", action = "cwngsync_sync_now", label = "Sync books" }
local SLEEP = { kind = "action", action = "suspend", label = "Sleep" }

-- f()'s value, or nil and true when it raises, which is logged as reading what.
local function read(what, f)
    local ok, value = pcall(f)
    if not ok then
        logger.err("KoPanda: quick settings could not read " .. what .. ":", value)
        return nil, true
    end
    return value, false
end

-- Whether the launcher could run entry here; a check that raises reads as no.
local function can_run(entry, what)
    local available = read("whether " .. what .. " can run", function()
        return (LauncherEntries.available(entry))
    end)
    return available == true
end

-- The battery's capacity in percent, or nil without a battery or when the read raises.
local function battery()
    return (read("the battery", function()
        if Device:hasBattery() then
            return Device:getPowerDevice():getCapacity()
        end
    end))
end

-- A bar's reading: nil when hidden, { greyed = true } when f raises, else f's { value, min, max }.
local function reading(what, f)
    local value, failed = read(what, f)
    if failed then
        return { greyed = true }
    end
    return value or nil
end

-- The device's state as the sheet shows it: { battery, brightness, warmth, cells }. battery is a
-- percent or nil; brightness and warmth are nil when hidden (warmth needs the frontlight too),
-- { greyed = true } when their read raised, else { value, min, max } in native steps; cells are
-- the six in the grid's order, each { id, label, icon, on, greyed }. Each read is guarded: one
-- that raises is logged and greys its control.
function QuickSettings.state()
    local powerd = Device:getPowerDevice()
    local brightness = reading("the frontlight", function()
        if Device:hasFrontlight() then
            return { value = powerd:frontlightIntensity(), min = 0, max = powerd.fl_max }
        end
    end)
    local warmth = reading("the warmth", function()
        if Device:hasFrontlight() and Device:hasNaturalLight() then
            return { value = powerd:toNativeWarmth(powerd:frontlightWarmth()), min = powerd.fl_warmth_min,
                max = powerd.fl_warmth_max }
        end
    end)
    local wifi, wifi_failed = read("the radio", function()
        return NetworkMgr:isWifiOn() and true or false
    end)
    local night, night_failed = read("night mode", function()
        return G_reader_settings:isTrue("night_mode")
    end)
    local lock, lock_failed = read("the rotation lock", function()
        return G_reader_settings:isTrue("lock_rotation")
    end)
    return {
        battery = battery(),
        brightness = brightness,
        warmth = warmth,
        cells = {
            { id = "wifi", label = wifi and "Wi-Fi on" or "Wi-Fi off", icon = wifi and "wifi" or "wifi_off",
                on = wifi == true, greyed = wifi_failed or not can_run(WIFI, "Wi-Fi") },
            { id = "night", label = night and "Night on" or "Night off", icon = "moon", on = night == true,
                greyed = night_failed },
            { id = "rotation_lock", label = "Rotation lock", icon = "rotation_lock", on = lock == true,
                greyed = lock_failed },
            { id = "sync_books", label = "Sync books", icon = "sync", on = false,
                greyed = not can_run(SYNC, "Sync books") },
            { id = "screenshot", label = "Screenshot", icon = "screenshot", on = false, greyed = false },
            { id = "sleep", label = "Sleep", icon = "power", on = false, greyed = not can_run(SLEEP, "Sleep") },
        },
    }
end

-- The body: its fills and outlines ({ x, y, w, h, color, border }), then its lines and icons, the
-- array part, each at places[i], all from the body's top-left; free() reaches the array part.
local Body = WidgetContainer:extend{
    name = "kopanda_quick_settings",
}

function Body:paintTo(bb, x, y)
    for _, part in ipairs(self.fills) do
        if part.border then
            Paint.border(bb, x + part.x, y + part.y, part.w, part.h, part.border, part.color)
        else
            Paint.fill(bb, x + part.x, y + part.y, part.w, part.h, part.color)
        end
    end
    for i, widget in ipairs(self) do
        widget:paintTo(bb, x + self.places[i].x, y + self.places[i].y)
    end
end

-- A copy of a type part in another palette role.
local function in_role(part, role)
    local copy = {}
    for k, v in pairs(part) do
        copy[k] = v
    end
    copy.color = role
    return copy
end

-- The sheet's body under bctx (the sheet's build ctx) content_w wide: { widget, areas }, areas
-- { id, rect } from the widget's top-left, the bars' minus and plus then the cells, in order.
-- The layout is the quick-settings feature's ("The panel"), from look.quick_settings.
function QuickSettings.body(bctx, content_w)
    local look = bctx.look
    local qs = look.quick_settings
    local palette = Looks.palette(look, bctx.variant)
    local function color(role)
        return role and Looks.color(palette[role])
    end
    local function scale(px)
        return bctx.screen:scaleBySize(px)
    end
    local state = QuickSettings.state()
    local body = Body:new{ fills = {}, places = {} }
    local fills, areas = body.fills, {}
    local function add(widget, x, y)
        body[#body + 1] = widget
        body.places[#body] = { x = x, y = y }
    end
    local function fill(x, y, w, h, role)
        local c = color(role)
        if c and w > 0 and h > 0 then
            fills[#fills + 1] = { x = x, y = y, w = w, h = h, color = c }
        end
    end
    -- An outline width wide inside the rectangle; its width, 0 without a colour.
    local function outline(x, y, w, h, width, role)
        local c = color(role)
        if not c then
            return 0
        end
        local px = scale(width)
        if px > 0 then
            fills[#fills + 1] = { x = x, y = y, w = w, h = h, border = px, color = c }
        end
        return px
    end

    local pad_x = scale(qs.padding_x)
    local inner_w = content_w - 2 * pad_x
    local y = 0

    -- The bars, each a section closed by a rule.
    local bars = {}
    if state.brightness then
        bars[#bars + 1] = { id = "brightness", label = "Brightness", reading = state.brightness }
    end
    if state.warmth then
        bars[#bars + 1] = { id = "warmth", label = "Warmth", reading = state.warmth }
    end
    local label_part, button_part = look.type.quick_label, look.type.quick_button
    for i, bar in ipairs(bars) do
        local pad = i == 1 and qs.first_section_padding or qs.section_padding
        y = y + scale(pad.top)
        local r = bar.reading
        local value = Typeset.line(label_part, r.greyed and DASH or tostring(r.value), inner_w, bctx)
        local value_size = value:getSize()
        local label = Typeset.line(label_part, bar.label, math.max(1, inner_w - value_size.w), bctx)
        local label_size = label:getSize()
        local row_h = math.max(label_size.h, value_size.h)
        add(label, pad_x, y + row_h - label_size.h)
        add(value, pad_x + inner_w - value_size.w, y + row_h - value_size.h)
        y = y + row_h + scale(qs.section_gap)

        -- The control row: minus, the level bar centred on the buttons, plus.
        local bw, bh, gap = scale(qs.button_w), scale(qs.button_h), scale(qs.control_gap)
        for _, button in ipairs({ { "_minus", pad_x, MINUS }, { "_plus", pad_x + inner_w - bw, PLUS } }) do
            local x = button[2]
            fill(x, y, bw, bh, qs.button_fill_color)
            outline(x, y, bw, bh, qs.button_outline_width, qs.button_outline_color)
            local glyph = Typeset.line(button_part, button[3], bw, bctx)
            local size = glyph:getSize()
            add(glyph, x + math.floor((bw - size.w) / 2), y + math.floor((bh - size.h) / 2))
            areas[#areas + 1] = { id = bar.id .. button[1], rect = { x = x, y = y, w = bw, h = bh } }
        end
        local level_outline = qs.level_outline_color and scale(qs.level_outline_width) or 0
        local level_h = scale(qs.level_h) + 2 * level_outline
        local level_x, level_w = pad_x + bw + gap, inner_w - 2 * (bw + gap)
        local level_y = y + math.floor((bh - level_h) / 2)
        fill(level_x, level_y, level_w, level_h, qs.level_track_color)
        if not r.greyed and r.max > r.min then
            local share = math.min(1, math.max(0, (r.value - r.min) / (r.max - r.min)))
            fill(level_x + level_outline, level_y + level_outline,
                math.floor((level_w - 2 * level_outline) * share), level_h - 2 * level_outline, qs.level_fill_color)
        end
        outline(level_x, level_y, level_w, level_h, qs.level_outline_width, qs.level_outline_color)
        y = y + bh + scale(pad.bottom)
        local rule = qs.section_rule_color and scale(qs.section_rule_width) or 0
        fill(0, y, content_w, rule, qs.section_rule_color)
        y = y + rule
    end

    -- The grid: three columns, two rows, each row as tall as its tallest cell.
    y = y + scale(qs.grid_padding.top)
    local columns = Layout.columns(inner_w, { { share = 1 }, { share = 1 }, { share = 1 } }, qs.grid_gap)
    local icon_size = scale(qs.cell_icon_size)
    local cell_outline = qs.cell_outline_color and scale(qs.cell_outline_width) or 0
    local cell_top = cell_outline + scale(qs.cell_padding.top)
    local cell_bottom = scale(qs.cell_padding.bottom) + cell_outline
    for row = 0, 1 do
        if row > 0 then
            y = y + scale(qs.grid_gap)
        end
        local built, row_h = {}, 0
        for c = 1, 3 do
            local cell = state.cells[row * 3 + c]
            local w = columns[c].w
            local filled = cell.on and not cell.greyed
            local role = cell.greyed and "muted" or filled and qs.on_text_color or look.type.quick_cell.color
            local label = Typeset.line(in_role(look.type.quick_cell, role), cell.label,
                math.max(1, w - 2 * cell_outline), bctx)
            local file = Icons.path(cell.icon)
            local icon = file and TintedIcon:new{ file = file, size = icon_size, color = color(role) }
            built[c] = { cell = cell, label = label, icon = icon, filled = filled }
            row_h = math.max(row_h, cell_top + icon_size + scale(qs.cell_gap) + label:getSize().h + cell_bottom)
        end
        for c, b in ipairs(built) do
            local x, w = pad_x + columns[c].x, columns[c].w
            fill(x, y, w, row_h, b.filled and qs.on_fill_color or qs.cell_fill_color)
            outline(x, y, w, row_h, qs.cell_outline_width, qs.cell_outline_color)
            if b.icon then
                add(b.icon, x + math.floor((w - icon_size) / 2), y + cell_top)
            end
            local size = b.label:getSize()
            add(b.label, x + math.floor((w - size.w) / 2), y + cell_top + icon_size + scale(qs.cell_gap))
            areas[#areas + 1] = { id = b.cell.id, rect = { x = x, y = y, w = w, h = row_h } }
        end
        y = y + row_h
    end
    y = y + scale(qs.grid_padding.bottom)

    body.dimen = Geom:new{ w = content_w, h = y }
    return { widget = body, areas = areas }
end

-- The sheet's header. SheetLayout reads header.aside at each layout (sheet_layout.lua:161-162),
-- so the battery is read there, each time.
local function header()
    return setmetatable({ heading = "Quick settings" }, {
        __index = function(_, key)
            if key == "aside" then
                local capacity = battery()
                return capacity and ("Battery " .. capacity .. "%") or nil
            end
        end,
    })
end

-- Shows the sheet over whatever is on top, the home or the bare file browser: it needs no home.
-- opts.started, the time.monotonic() the opener took, is passed to Sheet.show for paint_ms.
function QuickSettings.open(opts)
    local ctx = {
        look = Looks.active(),
        variant = Looks.variant(),
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
    }
    Sheet.show({
        name = "quick_settings",
        band = "quick_settings",
        header = header(),
        body = QuickSettings.body,
        refresh_on = { "NetworkConnected", "NetworkDisconnected" },
    }, ctx, opts)
end

return QuickSettings
