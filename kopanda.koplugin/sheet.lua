-- The sheet: a panel of rows drawn in the look over the home, opened by a hold or a tap and
-- closed by a tap outside it, a tap on a row, KOReader's Back or the Back key. It knows nothing
-- about books or the home: its opener hands it a spec,
--   { name, band, header, rows }
-- name: what the settled signal reports; band: which <band>_band_color token Diner's header
-- takes; header: { heading, aside, aside_beside } or a book's { cover, title, author, meta }
-- (cover a built widget, the sheet's to free), or nil; rows: { icon, label, detail, chip,
-- muted, tick, run } each, run called with no arguments.
-- Module state: Sheet.shown, the sheet on screen or nil. One sheet at a time: showing one
-- closes the one shown.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Icons = require("icons")
local InputContainer = require("ui/widget/container/inputcontainer")
local Looks = require("looks")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")

-- A filled rectangle; a colour goes through paintRectRGB32, since paintRect greys it
-- (base/ffi/blitbuffer.lua:1704-1724, :1827).
local function fill(bb, x, y, w, h, color)
    if Blitbuffer.isColor8(color) then
        bb:paintRect(x, y, w, h, color)
    else
        bb:paintRectRGB32(x, y, w, h, color)
    end
end

local function border(bb, x, y, w, h, width, color)
    if Blitbuffer.isColor8(color) then
        bb:paintBorder(x, y, w, h, width, color)
    else
        bb:paintBorderRGB32(x, y, w, h, width, color)
    end
end

-- The built panel: its fills and borders, then its widgets, each at its screen place. The
-- widgets it made are its array part, so free() reaches them; the header's cover is the
-- sheet's and is painted from self.cover.
local Panel = WidgetContainer:extend{
    name = "kopanda_sheet_panel",
}

function Panel:paintTo(bb, x, y)
    for _, part in ipairs(self.fills) do
        if part.border then
            border(bb, x + part.x, y + part.y, part.w, part.h, part.border, part.color)
        else
            fill(bb, x + part.x, y + part.y, part.w, part.h, part.color)
        end
    end
    for i, widget in ipairs(self) do
        widget:paintTo(bb, x + self.places[i].x, y + self.places[i].y)
    end
    if self.cover then
        self.cover:paintTo(bb, x + self.cover_place.x, y + self.cover_place.y)
    end
end

local Sheet = InputContainer:extend{
    name = "kopanda_sheet",
}

Sheet.shown = nil

-- The look's type part name, in muted on a greyed row, as the launcher greys an entry.
local function part_of(look, name, muted)
    local part = look.type[name]
    if not muted then
        return part
    end
    local copy = {}
    for k, v in pairs(part) do
        copy[k] = v
    end
    copy.color = "muted"
    return copy
end

-- Lays out the sheet's spec under ctx in variant into a Panel, and returns it with the panel's
-- rectangle, the rectangle with its shadow, the header's rectangle (or nil) and the rows' places
-- ({ row, rect, label, detail }), all in screen coordinates.
local function build(spec, ctx, variant)
    local look = ctx.look
    local tokens = look.sheet
    local palette = Looks.palette(look, variant)
    local bctx = {}
    for k, v in pairs(ctx) do
        bctx[k] = v
    end
    bctx.variant = variant
    local function color(role)
        return role and Looks.color(palette[role])
    end
    local function scale(px)
        return px and ctx.screen:scaleBySize(px) or 0
    end
    local size = ctx.screen:getSize()

    local panel = Panel:new{ fills = {}, places = {} }
    -- Parts are placed relative to the panel's box first and moved to the screen at the end.
    local fills = panel.fills
    local function add_fill(x, y, w, h, role)
        local c = color(role)
        if c and w > 0 and h > 0 then
            fills[#fills + 1] = { x = x, y = y, w = w, h = h, color = c }
        end
    end
    local function add(widget, x, y)
        panel[#panel + 1] = widget
        panel.places[#panel] = { x = x, y = y }
    end

    local box_w = size.w - 2 * scale(tokens.inset.side)
    local outline = tokens.outline_color and scale(look.stroke.outline) or 0
    local rule = tokens.rule_color and scale(tokens.rule_width) or 0
    local content_x = outline + scale(tokens.padding.side)
    local content_w = box_w - 2 * content_x
    local y = outline + rule + scale(tokens.padding.top)

    -- The header.
    local header_rect
    local header = spec.header
    if header then
        local book = header.cover ~= nil
        local pad = book and tokens.book_header_padding or tokens.header_padding
        local inner_x = content_x + scale(pad.side)
        local inner_w = content_w - 2 * scale(pad.side)
        local inner_y = y + scale(pad.top)
        local inner_h
        if book then
            local cover = header.cover
            local cover_size = cover:getSize()
            local column_x = inner_x + cover_size.w + scale(tokens.cover_gap)
            local column_w = inner_w - cover_size.w - scale(tokens.cover_gap)
            local lines = {}
            for _, line in ipairs({ { "sheet_title", header.title }, { "sheet_author", header.author },
                    { "sheet_meta", header.meta } }) do
                if line[2] then
                    lines[#lines + 1] = {
                        widget = Typeset.line(look.type[line[1]], line[2], column_w, bctx),
                        meta = line[1] == "sheet_meta",
                    }
                end
            end
            local column_h = 0
            for i, line in ipairs(lines) do
                if i > 1 then
                    line.gap = scale(tokens.line_gap) + (line.meta and scale(tokens.meta_gap) or 0)
                    column_h = column_h + line.gap
                end
                column_h = column_h + line.widget:getSize().h
            end
            inner_h = math.max(cover_size.h, column_h)
            panel.cover = cover
            panel.cover_place = { x = inner_x, y = inner_y + math.floor((inner_h - cover_size.h) / 2) }
            local line_y = inner_y + math.floor((inner_h - column_h) / 2)
            for _, line in ipairs(lines) do
                line_y = line_y + (line.gap or 0)
                add(line.widget, column_x, line_y)
                line_y = line_y + line.widget:getSize().h
            end
        else
            local heading = Typeset.line(look.type.sheet_heading, header.heading or "", inner_w, bctx)
            local heading_w = heading:getSize().w
            local parts = { { widget = heading, x = inner_x } }
            if header.aside then
                local gap = scale(tokens.aside_gap)
                local aside = Typeset.line(look.type.sheet_aside, header.aside,
                    math.max(1, inner_w - heading_w - gap), bctx)
                local aside_w = aside:getSize().w
                local x = header.aside_beside and inner_x + heading_w + gap or inner_x + inner_w - aside_w
                parts[#parts + 1] = { widget = aside, x = x }
            end
            -- On one baseline, as the boards align them (HoldHome:35-37).
            local ascent, descent = 0, 0
            for _, part in ipairs(parts) do
                part.baseline = Typeset.baseline(part.widget)
                ascent = math.max(ascent, part.baseline)
                descent = math.max(descent, part.widget:getSize().h - part.baseline)
            end
            inner_h = ascent + descent
            for _, part in ipairs(parts) do
                add(part.widget, part.x, inner_y + ascent - part.baseline)
            end
        end
        local header_h = scale(pad.top) + inner_h + scale(pad.bottom)
        if tokens.header_band and spec.band then
            add_fill(content_x, y, content_w, header_h, tokens[spec.band .. "_band_color"])
        end
        header_rect = { x = content_x, y = y, w = content_w, h = header_h }
        y = y + header_h
        local header_rule = scale(tokens.header_rule_width)
        add_fill(content_x, y, content_w, header_rule, tokens.header_rule_color)
        y = y + header_rule
    end

    -- The rows, each built in full before any is placed.
    local pad_x, pad_y = scale(tokens.row_padding.x), scale(tokens.row_padding.y)
    local icon_size, row_gap = scale(tokens.icon_size), scale(tokens.row_gap)
    local row_w = content_w - 2 * pad_x
    local built = {}
    for _, row in ipairs(spec.rows or {}) do
        local b = { row = row }
        local ink = row.muted and "muted" or "ink"
        local icon_id = row.tick and "check" or row.icon
        local file = icon_id and Icons.path(icon_id)
        if file then
            b.icon = TintedIcon:new{ file = file, size = icon_size, color = color(ink) }
        elseif icon_id then
            logger.warn("KoPanda: the sheet", spec.name, "has no icon", icon_id, "; its place is left blank")
        end
        local room = row_w - icon_size - row_gap
        if row.detail then
            local chip_role = row.chip and tokens[row.chip .. "_chip_color"]
            if chip_role then
                local chip_outline = scale(tokens.chip_outline_width)
                local cx, cy = scale(tokens.chip_padding.x) + chip_outline, scale(tokens.chip_padding.y) + chip_outline
                b.detail = Typeset.line(part_of(look, "sheet_chip", row.muted), row.detail,
                    math.max(1, room - 2 * cx), bctx)
                local text = b.detail:getSize()
                b.chip = { w = text.w + 2 * cx, h = text.h + 2 * cy, inset_x = cx, inset_y = cy,
                    outline = chip_outline, fill = chip_role }
                b.detail_w, b.detail_h = b.chip.w, b.chip.h
            else
                b.detail = Typeset.line(part_of(look, "sheet_detail", row.muted), row.detail, math.max(1, room), bctx)
                local text = b.detail:getSize()
                b.detail_w, b.detail_h = text.w, text.h
            end
            room = room - b.detail_w - row_gap
        end
        b.label = Typeset.line(part_of(look, "sheet_row", row.muted), row.label or "", math.max(1, room), bctx)
        b.content_h = math.max(icon_size, b.label:getSize().h, b.detail_h or 0)
        built[#built + 1] = b
    end

    -- As many rows as fit above the screen's foot less the inset; the last kept one takes the
    -- last row's foot and no rule.
    local row_rule = scale(tokens.row_rule_width)
    local foot = scale(tokens.padding.bottom) + outline
    local last_bottom = scale(tokens.last_row_bottom)
    local max_h = size.h - scale(tokens.inset.bottom)
    local kept = #built
    local function height(n)
        local h = y + foot
        for i = 1, n do
            h = h + pad_y + built[i].content_h + (i < n and pad_y + row_rule or last_bottom)
        end
        return h
    end
    while kept > 0 and height(kept) > max_h do
        kept = kept - 1
    end
    if kept < #built then
        logger.warn("KoPanda: sheet", spec.name, "leaves out", #built - kept, "rows that don't fit")
        for i = kept + 1, #built do
            local b = built[i]
            for _, widget in ipairs({ b.icon, b.detail, b.label }) do
                widget:free()
            end
            built[i] = nil
        end
    end

    local rows = {}
    for i, b in ipairs(built) do
        local last = i == #built
        local row_h = pad_y + b.content_h + (last and last_bottom or pad_y)
        local cy = y + pad_y
        local x = content_x + pad_x
        local function middle(h)
            return cy + math.floor((b.content_h - h) / 2)
        end
        if b.icon then
            add(b.icon, x, middle(icon_size))
        end
        local label_size = b.label:getSize()
        local label = { x = x + icon_size + row_gap, y = middle(label_size.h), w = label_size.w, h = label_size.h }
        add(b.label, label.x, label.y)
        local detail
        if b.detail then
            detail = { x = x + row_w - b.detail_w, y = middle(b.detail_h), w = b.detail_w, h = b.detail_h }
            local chip = b.chip
            if chip then
                add_fill(detail.x, detail.y, detail.w, detail.h, chip.fill)
                local outline_color = color("outline")
                if chip.outline > 0 and outline_color then
                    fills[#fills + 1] = { x = detail.x, y = detail.y, w = detail.w, h = detail.h,
                        border = chip.outline, color = outline_color }
                end
                add(b.detail, detail.x + chip.inset_x, detail.y + chip.inset_y)
            else
                add(b.detail, detail.x, detail.y)
            end
        end
        rows[i] = { row = b.row, rect = { x = content_x, y = y, w = content_w, h = row_h }, label = label,
            detail = detail }
        y = y + row_h
        if not last then
            add_fill(content_x, y, content_w, row_rule, tokens.row_rule_color)
            y = y + row_rule
        end
    end
    local box_h = y + foot

    -- The box's chrome under everything placed so far: the shadow, the fill, Editorial's rule;
    -- Diner's outline over it all.
    local chrome = {}
    local shadow = look.shadow.sheet
    local shadow_x, shadow_y = 0, 0
    local shadow_color = color(shadow.color)
    if shadow_color then
        shadow_x, shadow_y = scale(shadow.x), scale(shadow.y)
        chrome[#chrome + 1] = { x = shadow_x, y = shadow_y, w = box_w, h = box_h, color = shadow_color }
    end
    local fill_color = color(tokens.fill_color)
    if fill_color then
        chrome[#chrome + 1] = { x = 0, y = 0, w = box_w, h = box_h, color = fill_color }
    end
    local rule_color = color(tokens.rule_color)
    if rule > 0 and rule_color then
        chrome[#chrome + 1] = { x = 0, y = 0, w = box_w, h = rule, color = rule_color }
    end
    for _, part in ipairs(fills) do
        chrome[#chrome + 1] = part
    end
    local outline_color = color(tokens.outline_color)
    if outline > 0 and outline_color then
        chrome[#chrome + 1] = { x = 0, y = 0, w = box_w, h = box_h, border = outline, color = outline_color }
    end
    panel.fills = chrome

    -- To the screen: the box on the bottom edge less the inset.
    local box_x = scale(tokens.inset.side)
    local box_y = size.h - scale(tokens.inset.bottom) - box_h
    local function moved(rect)
        return rect and Geom:new{ x = box_x + rect.x, y = box_y + rect.y, w = rect.w, h = rect.h }
    end
    for _, part in ipairs(chrome) do
        part.x, part.y = box_x + part.x, box_y + part.y
    end
    for _, place in ipairs(panel.places) do
        place.x, place.y = box_x + place.x, box_y + place.y
    end
    if panel.cover_place then
        panel.cover_place.x, panel.cover_place.y = box_x + panel.cover_place.x, box_y + panel.cover_place.y
    end
    for _, row in ipairs(rows) do
        row.rect, row.label, row.detail = moved(row.rect), moved(row.label), moved(row.detail)
    end
    panel.dimen = Geom:new{ x = box_x, y = box_y, w = box_w, h = box_h }
    return {
        widget = panel,
        panel = Geom:new{ x = box_x, y = box_y, w = box_w, h = box_h },
        rect = Geom:new{ x = box_x, y = box_y, w = box_w + shadow_x, h = box_h + shadow_y },
        header = moved(header_rect),
        rows = rows,
    }
end

-- Builds the panel in variant into the sheet: panel_widget, panel, rect, header_rect, rows and
-- variant, freeing the panel it replaces.
local function lay_out(sheet, variant)
    local old = sheet.panel_widget
    local laid = build(sheet.spec, sheet.ctx, variant)
    sheet.panel_widget = laid.widget
    sheet.panel = laid.panel
    sheet.rect = laid.rect
    sheet.header_rect = laid.header
    sheet.rows = laid.rows
    sheet.variant = variant
    if old then
        old:free()
    end
end

function Sheet:init()
    local size = self.ctx.screen:getSize()
    -- The whole screen, so every tap reaches the sheet; it paints only its panel.
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    self.ges_events.TapSheet = {
        GestureRange:new{ ges = "tap", range = Geom:new{ x = 0, y = 0, w = size.w, h = size.h } },
    }
    -- As ButtonDialog binds it (frontend/ui/widget/buttondialog.lua:98-108).
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    lay_out(self, self.ctx.variant)
end

local function close_sheet(sheet)
    if Sheet.shown == sheet then
        Sheet.shown = nil
    end
    local ok, err = pcall(UIManager.close, UIManager, sheet, "flashui", sheet.rect)
    if not ok then
        logger.err("KoPanda: could not close the sheet:", err)
    end
end

-- Closes the sheet if still up and the home, leaving the file browser. home.lua reaches this
-- module, so home is required here.
local function close_all(sheet)
    if UIManager:isWidgetShown(sheet) then
        close_sheet(sheet)
    end
    if Sheet.shown == sheet then
        Sheet.shown = nil
    end
    local ok, home_err = pcall(function()
        require("home").close()
    end)
    if not ok then
        logger.err("KoPanda: could not close the home:", home_err)
    end
end

-- A failure anywhere in the sheet: logged, then the sheet and the home closed.
local function fail(sheet, what, err)
    logger.err("KoPanda: the sheet", sheet.spec and sheet.spec.name, what, err)
    close_all(sheet)
end

-- The settled signal, once, after the first paint, as the home sends its own; none when the
-- paint failed. tickAfterNext lands past the repaint only when the clock has moved on since the
-- tick began (uimanager.lua:447-456), so a sheet not yet painted waits for the next one, while
-- it is still shown.
local function settle(sheet, started)
    if sheet.settled or sheet.paint_failed then
        return
    end
    if not sheet.painted_at then
        if UIManager:isWidgetShown(sheet) then
            UIManager:tickAfterNext(function()
                settle(sheet, started)
            end)
        end
        return
    end
    sheet.settled = true
    local ok, err = pcall(function()
        UIManager.event_hook:execute("KoPandaSettled", {
            screen = "sheet",
            name = sheet.spec.name,
            paint_ms = time.to_ms(sheet.painted_at - started),
        })
    end)
    if not ok then
        logger.err("KoPanda: the sheet's settled signal failed:", err)
    end
end

-- Shows the sheet of spec under ctx (the home's), closing the one shown. opts.started is the
-- time.monotonic() its opener took on the hold or tap, which paint_ms runs from; without it, the
-- start of the show. A failure is logged, takes the sheet off the stack and closes the home.
function Sheet.show(spec, ctx, opts)
    local started = opts and opts.started or time.monotonic()
    local sheet
    local ok, err = pcall(function()
        Sheet.close()
        sheet = Sheet:new{ spec = spec, ctx = ctx }
        Sheet.shown = sheet
        UIManager:show(sheet, "ui", sheet.rect)
        -- Lands past the next repaint, so the signal follows the paint.
        UIManager:tickAfterNext(function()
            settle(sheet, started)
        end)
    end)
    if not ok then
        fail(sheet or { spec = spec }, "could not be shown:", err)
    end
end

-- Closes the sheet shown, if any, with a flashui refresh of its rectangle, as ButtonDialog
-- refreshes on close (frontend/ui/widget/buttondialog.lua:333-337). UIManager:close marks the
-- home under it dirty, so it repaints.
function Sheet.close()
    if Sheet.shown then
        close_sheet(Sheet.shown)
    end
end

function Sheet:onCloseWidget()
    if Sheet.shown == self then
        Sheet.shown = nil
    end
    local panel = self.panel_widget
    self.panel_widget = nil
    if panel then
        panel:free()
    end
    local cover = self.spec.header and self.spec.header.cover
    if cover and cover.free then
        cover:free()
    end
end

-- Paints the panel, rebuilt first when the variant changed since its build: night mode toggled
-- marks every window dirty (frontend/device/devicelistener.lua:14-27), so the paint is where
-- the sheet sees it, as the home does, with no repaint of its own.
local function paint(sheet, bb, x, y)
    local variant = Looks.variant()
    if sheet.variant ~= variant then
        lay_out(sheet, variant)
    end
    sheet.panel_widget:paintTo(bb, x, y)
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the sheet and the
-- home from the next tick.
function Sheet:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = time.monotonic()
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the sheet", self.spec.name, "failed to paint:", err)
        UIManager:nextTick(function()
            close_all(self)
        end)
    end
end

-- A tap on a row closes the sheet, then runs the row unless it is ticked; elsewhere on the
-- panel it is consumed; outside the panel it closes the sheet, as ButtonDialog:onTapClose
-- does (frontend/ui/widget/buttondialog.lua:347-352).
local function tap(sheet, ges)
    for _, place in ipairs(sheet.rows) do
        if place.rect:contains(ges.pos) then
            close_sheet(sheet)
            if not place.row.tick and place.row.run then
                place.row.run()
            end
            return
        end
    end
    if not sheet.panel:contains(ges.pos) then
        close_sheet(sheet)
    end
end

function Sheet:onTapSheet(_, ges)
    local ok, err = pcall(tap, self, ges)
    if not ok then
        fail(self, "failed on a tap:", err)
    end
    return true
end

local function guarded_close(sheet, what)
    local ok, err = pcall(close_sheet, sheet)
    if not ok then
        fail(sheet, what, err)
    end
    return true
end

-- The Back key, where the device has keys.
function Sheet:onClose()
    return guarded_close(self, "failed on the Back key:")
end

-- KOReader's Back, sent to the top widget by the dispatcher's fm_back (frontend/dispatcher.lua:169).
function Sheet:onBack()
    return guarded_close(self, "failed on Back:")
end

return Sheet
