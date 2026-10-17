-- The sheet: a panel of rows drawn in the look over the home, opened by a hold or a tap and
-- closed by a tap outside it, a tap on a row, KOReader's Back or the Back key. It knows nothing
-- about books or the home: its opener hands it a spec,
--   { name, band, header, rows, hold }
-- name: what the settled signal reports; band: which <band>_band_color token Diner's header
-- takes; header: { heading, aside, aside_beside, hint } or a book's { cover, title, author, meta }
-- (cover a built widget, the sheet's to free), or nil; rows: { icon, label, detail, chip,
-- muted, tick, run } each, run called with no arguments; hold, optional, called with no
-- arguments on a hold inside the panel, after the sheet has closed. A sheet without hold
-- ignores holds.
-- Module state: Sheet.shown, the sheet on screen or nil. One sheet at a time: showing one
-- closes the one shown.
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Looks = require("looks")
local SheetLayout = require("sheet_layout")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local time = require("ui/time")

local Sheet = InputContainer:extend{
    name = "kopanda_sheet",
}

Sheet.shown = nil

-- Builds the panel in variant into the sheet: panel_widget, panel, rect, header_rect, rows and
-- variant, freeing the panel it replaces.
local function lay_out(sheet, variant)
    local old = sheet.panel_widget
    local laid = SheetLayout.build(sheet.spec, sheet.ctx, variant)
    -- Logged on the first build only: a rebuild for night mode leaves out the same rows.
    if not old and laid.left_out > 0 then
        logger.warn("KoPanda: sheet", sheet.spec.name, "leaves out", laid.left_out, "rows that don't fit")
    end
    sheet.panel_widget = laid.widget
    sheet.panel = laid.panel
    sheet.rect = laid.rect
    sheet.header_rect = laid.header
    sheet.hint_rect = laid.hint
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
    -- A hold inside the panel, only for a spec with one; the range is a function, so a rebuild's
    -- panel is the one matched (frontend/ui/gesturerange.lua:25-37).
    if self.spec.hold then
        self.ges_events.HoldSheet = {
            GestureRange:new{ ges = "hold", range = function() return self.panel end },
        }
    end
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

-- A failure anywhere in the sheet: logged, then the sheet and the home closed.
local function fail(sheet, what, err)
    logger.err("KoPanda: the sheet", sheet.spec and sheet.spec.name, what, err)
    close_all(sheet)
end

-- The settled signal, once, from the tick after the first paint, which schedules it; a sheet
-- never painted, or whose paint failed, sends none.
local function settle(sheet)
    if sheet.settled or sheet.paint_failed then
        return
    end
    sheet.settled = true
    local ok, err = pcall(function()
        UIManager.event_hook:execute("KoPandaSettled", {
            screen = "sheet",
            name = sheet.spec.name,
            paint_ms = time.to_ms(sheet.painted_at - sheet.started),
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
        sheet = Sheet:new{ spec = spec, ctx = ctx, started = started }
        Sheet.shown = sheet
        UIManager:show(sheet, "ui", sheet.rect)
    end)
    if not ok then
        sheet = sheet or { spec = spec }
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
-- home from the next tick. The first good paint schedules the settled signal for the next tick,
-- which runs past this repaint.
function Sheet:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = time.monotonic()
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

-- A hold inside the panel of a sheet whose spec has hold closes the sheet, then runs it.
function Sheet:onHoldSheet()
    local ok, err = pcall(function()
        close_sheet(self)
        self.spec.hold()
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
