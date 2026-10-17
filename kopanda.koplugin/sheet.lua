-- The sheet: a panel of rows drawn in the look over the home or the library, opened by a hold or
-- a tap and closed by a tap outside it, a tap on a row, KOReader's Back or the Back key. It knows
-- nothing about books or the home: its opener hands it a spec,
--   { name, band, header, rows, body, refresh_on, stale, hold, flush, more }
-- name: what the settled signal reports; band: which <band>_band_color token Diner's header
-- takes; header: { heading, aside, aside_beside, aside_above, hint, label } or a book's { cover,
-- title, author, meta } (cover a built widget, the sheet's to free), or nil; aside_above stacks
-- the aside over the heading, label is set at the header's right (a label takes the header's
-- right, so a sheet with one has no hint and its aside beside or above); rows: { icon, label,
-- sublabel, detail, chip, muted, tick, selected, run } each, sublabel a second line under the
-- label, selected filling the row and setting a check at its right, run called with no
-- arguments; hold, optional, called with no arguments on a hold inside the panel, after the sheet
-- has closed. A sheet without hold ignores holds, but for its body's; flush, for a sheet whose
-- rows have no icons, sets their labels without the icon's indent. body, in place of rows (a spec
-- with both keeps its rows), is called at every layout as body(bctx, content_w) and returns
-- { widget, areas }: widget (getSize, paintTo, free) is drawn under the header and freed with the
-- panel; areas are { rect, tap, hold, close_first }, rect from the widget's top-left. A tap or
-- hold in an area runs its tap or hold with the sheet left open, then redraws it, or closes it
-- first with close_first. refresh_on, optional, lists events on each of which the sheet redraws;
-- with stale, only when stale(), called with no arguments, says what the sheet shows has
-- changed since its last layout (a stale that raises is logged and the sheet redraws).
-- more, { label, run }, for a list that may not fit: when rows are left out, the last slot that
-- fits beside a row is a More row (label, default "More…", with the list icon when any row has
-- an icon), and a tap on it closes the sheet and calls run with the rows not shown, in order.
-- A sheet without more leaves those rows out, logged once.
-- Every field but name and rows or body is optional.
-- Module state: Sheet.shown, the sheet on screen or nil. One sheet at a time: showing one
-- closes the one shown.
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Looks = require("looks")
local PaintClock = require("paint_clock")
local SheetLayout = require("sheet_layout")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local Sheet = InputContainer:extend{
    name = "kopanda_sheet",
}

Sheet.shown = nil

-- Builds the panel in variant into the sheet: panel_widget, panel, rect, header_rect, rows,
-- areas and variant, freeing the panel it replaces.
local function lay_out(sheet, variant)
    local old = sheet.panel_widget
    local laid = SheetLayout.build(sheet.spec, sheet.ctx, variant)
    -- Logged on the first build only: a rebuild for night mode leaves out the same rows, and a
    -- redraw is the same sheet.
    if not old and laid.left_out > 0 then
        logger.warn("KoPanda: sheet", sheet.spec.name, "leaves out", laid.left_out, "rows that don't fit")
    end
    if not old and laid.too_tall then
        logger.warn("KoPanda: sheet", sheet.spec.name, "is taller than the screen; its panel sits at the top")
    end
    sheet.panel_widget = laid.widget
    sheet.panel = laid.panel
    sheet.rect = laid.rect
    sheet.header_rect = laid.header
    sheet.hint_rect = laid.hint
    sheet.header_parts = laid.header_parts
    sheet.rows = laid.rows
    sheet.areas = laid.areas
    sheet.variant = variant
    if old then
        old:free()
    end
end

-- Redraws a shown sheet in place; defined with the failures it reaches, below.
local redraw

function Sheet:init()
    if self.spec.rows and self.spec.body then
        logger.warn("KoPanda: the sheet", self.spec.name, "has both rows and a body; it shows its rows")
    end
    local size = self.ctx.screen:getSize()
    -- The whole screen, so every tap reaches the sheet; it paints only its panel.
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    self.ges_events.TapSheet = {
        GestureRange:new{ ges = "tap", range = Geom:new{ x = 0, y = 0, w = size.w, h = size.h } },
    }
    -- A hold inside the panel, only for a spec with one or a body; the range is a function, so a
    -- rebuild's panel is the one matched (frontend/ui/gesturerange.lua:25-37).
    if self.spec.hold or self.spec.body then
        self.ges_events.HoldSheet = {
            GestureRange:new{ ges = "hold", range = function() return self.panel end },
        }
    end
    -- As ButtonDialog binds it (frontend/ui/widget/buttondialog.lua:98-108).
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    -- Each returns nothing, though a broadcast reaches every window whatever its handlers
    -- return (frontend/ui/uimanager.lua:1042-1061), so the windows beneath hear it too.
    for _, event in ipairs(self.spec.refresh_on or {}) do
        self["on" .. event] = function()
            local stale = self.spec.stale
            if stale then
                local ok, changed = pcall(stale)
                if not ok then
                    logger.err("KoPanda: the sheet", self.spec.name, "could not tell whether it is stale:", changed)
                elseif not changed then
                    return
                end
            end
            redraw(self)
        end
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

-- Closes the sheet if still up and the screen it was shown over (sheet.beneath, default the
-- home), leaving the file browser. home.lua reaches this module, so home is required here.
local function close_all(sheet)
    if UIManager:isWidgetShown(sheet) then
        close_sheet(sheet)
    end
    if Sheet.shown == sheet then
        Sheet.shown = nil
    end
    local ok, beneath_err = pcall(function()
        (sheet.beneath or require("home")).close()
    end)
    if not ok then
        logger.err("KoPanda: could not close the screen beneath the sheet:", beneath_err)
    end
end

-- Frees the header's cover, the sheet's to free, once: on close, or after a failed show, which
-- may or may not have reached the close. A cover that fails to free is logged.
local function free_cover(sheet)
    if sheet.cover_freed then
        return
    end
    sheet.cover_freed = true
    local ok, err = pcall(function()
        local cover = sheet.spec.header and sheet.spec.header.cover
        if cover and cover.free then
            cover:free()
        end
    end)
    if not ok then
        logger.err("KoPanda: the sheet", sheet.spec.name, "could not free its cover:", err)
    end
end

-- A failure anywhere in the sheet: logged, then the sheet and the screen beneath closed.
local function fail(sheet, what, err)
    logger.err("KoPanda: the sheet", sheet.spec and sheet.spec.name, what, err)
    close_all(sheet)
end

-- Re-lays a shown sheet out in its variant and asks for one ui refresh of its old and new
-- rectangles together, so a panel that changed height leaves nothing stale; a sheet no longer
-- shown is left alone. When the variant changed since the build (night mode toggled), the paint
-- lays it out again in the new one (paint, below), so this only marks it dirty. A failure is the
-- sheet's.
redraw = function(sheet)
    if not UIManager:isWidgetShown(sheet) then
        return
    end
    local ok, err = pcall(function()
        if Looks.variant() ~= sheet.variant then
            UIManager:setDirty(sheet, "ui", sheet.rect)
            return
        end
        local old = sheet.rect
        lay_out(sheet, sheet.variant)
        UIManager:setDirty(sheet, "ui", old:combine(sheet.rect))
    end)
    if not ok then
        fail(sheet, "could not redraw:", err)
    end
end

-- The settled signal, once, from the tick after the first paint, which schedules it; a sheet
-- never painted, or whose paint failed, sends none.
local function settle(sheet)
    if sheet.settled or sheet.paint_failed then
        return
    end
    sheet.settled = true
    local ok, err = pcall(function()
        local paint_ms, cpu_ms = PaintClock.ms(PaintClock.since(sheet.started, sheet.painted_at))
        UIManager.event_hook:execute("KoPandaSettled", {
            screen = "sheet",
            name = sheet.spec.name,
            paint_ms = paint_ms,
            cpu_ms = cpu_ms,
        })
    end)
    if not ok then
        logger.err("KoPanda: the sheet's settled signal failed:", err)
    end
end

-- Shows the sheet of spec under ctx (the screen's beneath), closing the one shown. opts.started is
-- the PaintClock stamp its opener took on the hold or tap, which paint_ms and cpu_ms run from;
-- without it, the start of the show. opts.beneath is the screen the sheet is shown over, a table
-- whose close() closes it; without it, the home. A failure is logged, takes the sheet off the
-- stack and closes that screen.
function Sheet.show(spec, ctx, opts)
    local started = opts and opts.started or PaintClock.now()
    local beneath = opts and opts.beneath
    local sheet
    local ok, err = pcall(function()
        Sheet.close()
        sheet = Sheet:new{ spec = spec, ctx = ctx, started = started, beneath = beneath }
        Sheet.shown = sheet
        UIManager:show(sheet, "ui", sheet.rect)
    end)
    if not ok then
        sheet = sheet or { spec = spec, beneath = beneath }
        fail(sheet, "could not be shown:", err)
        free_cover(sheet)
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
    free_cover(self)
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
-- screen beneath from the next tick. The first good paint schedules the settled signal for the next tick,
-- which runs past this repaint.
function Sheet:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = PaintClock.now()
        UIManager:nextTick(function()
            settle(self)
        end)
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the sheet", self.spec.name, "failed to paint:", err)
        UIManager:nextTick(function()
            close_all(self)
        end)
    end
end

-- The body's area at pos, or nil.
local function area_at(sheet, pos)
    for _, area in ipairs(sheet.areas) do
        if area.rect:contains(pos) then
            return area
        end
    end
end

-- Runs an area's tap or hold (what) with the sheet open, then redraws it; with close_first,
-- closes it first. One that raises is logged and leaves the sheet as it was otherwise.
local function act(sheet, area, what)
    if area.close_first then
        close_sheet(sheet)
    end
    local ok, err = pcall(area[what])
    if not ok then
        logger.err("KoPanda: the sheet", sheet.spec.name, "failed on its body's " .. what .. ":", err)
    end
    if not area.close_first then
        redraw(sheet)
    end
end

-- A tap in a body's area runs its tap, and one with none is consumed; a tap on a row closes
-- the sheet, then runs the row unless it is ticked; elsewhere on the panel it is consumed;
-- outside the panel it closes the sheet, as ButtonDialog:onTapClose does
-- (frontend/ui/widget/buttondialog.lua:347-352).
local function tap(sheet, ges)
    local area = area_at(sheet, ges.pos)
    if area then
        if area.tap then
            act(sheet, area, "tap")
        end
        return
    end
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

-- A hold inside the panel: in a body's area with hold, runs it as a tap runs an area's tap;
-- elsewhere, for a spec with hold, closes the sheet, then runs it; otherwise consumed.
function Sheet:onHoldSheet(_, ges)
    local ok, err = pcall(function()
        local area = area_at(self, ges.pos)
        if area and area.hold then
            act(self, area, "hold")
        elseif self.spec.hold then
            close_sheet(self)
            self.spec.hold()
        end
    end)
    if not ok then
        fail(self, "failed on a hold:", err)
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
