-- The editor frame: the full-screen screen edit layout and launcher management draw in, over
-- whatever is shown (the home, the file browser or a book), in the active look. Its opener hands
-- it a spec,
--   { screen, aside, title, body, foot, done }
-- screen: what the settled signal reports ("edit_layout" or "launcher"); aside over title on
-- the header's left, Done on its right; done, optional, what Done runs in place of closing the
-- editor, read at the tap; body and foot: functions (ctx, width) returning rows,
-- each row a list of controls { kind, rect, draw, run, disabled }. kind is one of card, button,
-- arrow, box, kind_button, caption, note or row; rect { x, y, w, h } is the control's place in
-- its row, the row as tall as its lowest control; draw(bb, x, y) paints it at its screen place;
-- run is called with no arguments on a tap, unless disabled. A card casts the editor's card shadow.
-- Module state: Editor.shown, the editor on screen or nil. One at a time: showing one closes the
-- one shown.
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Looks = require("looks")
local Paint = require("paint")
local PaintClock = require("paint_clock")
local Settings = require("settings")
local Typeset = require("typeset")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local Screen = Device.screen

-- The built frame: its fills and borders, then its text widgets, then the cards' shadows and
-- every control's own draw, each at its screen place. The text widgets are its array part, so
-- free() reaches them.
local Frame = WidgetContainer:extend{
    name = "kopanda_editor_frame",
}

function Frame:paintTo(bb, x, y)
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
    for _, shadow in ipairs(self.shadows) do
        Paint.fill(bb, x + shadow.x, y + shadow.y, shadow.w, shadow.h, shadow.color)
    end
    for _, place in ipairs(self.drawn) do
        place.control.draw(bb, x + place.rect.x, y + place.rect.y)
    end
end

local Editor = InputContainer:extend{
    name = "kopanda_editor",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
}

Editor.shown = nil

-- Takes the editor off the stack with a full refresh, as the home closes. Raises when the close
-- does; callers guard it.
local function close_editor(editor)
    if Editor.shown == editor then
        Editor.shown = nil
    end
    UIManager:close(editor, "full")
end

-- Closes the editor, logging a close that fails.
local function safe_close(editor)
    local ok, err = pcall(close_editor, editor)
    if not ok then
        logger.err("KoPanda: could not close the editor:", err)
    end
end

-- A failure anywhere in the editor: logged, then the editor closed, leaving what was beneath.
local function fail(editor, what, err)
    logger.err("KoPanda: the editor", editor.spec and editor.spec.screen, what, err)
    safe_close(editor)
end

-- A row's height: its lowest control's foot.
local function row_height(row)
    local h = 0
    for _, control in ipairs(row) do
        h = math.max(h, control.rect.y + control.rect.h)
    end
    return h
end

-- Lays out the editor's spec under ctx into a Frame, and returns it with the places of its
-- controls ({ control, rect } in screen coordinates, Done first, then the body's and the foot's
-- in order), the header's, the rule's and Done's rectangles, and how many body rows it left out.
local function lay_out(editor, ctx)
    local spec, look = editor.spec, ctx.look
    local tokens = look.editor
    local palette = Looks.palette(look, ctx.variant)
    local function color(role)
        return role and palette[role] and Looks.color(palette[role])
    end
    local function scale(px)
        return px and ctx.screen:scaleBySize(px) or 0
    end
    local size = ctx.screen:getSize()
    local frame = Frame:new{ fills = {}, places = {}, shadows = {}, drawn = {} }
    local fills = frame.fills
    local function add_fill(x, y, w, h, role)
        local c = color(role)
        if c and w > 0 and h > 0 then
            fills[#fills + 1] = { x = x, y = y, w = w, h = h, color = c }
        end
    end
    local function add(widget, x, y)
        frame[#frame + 1] = widget
        frame.places[#frame] = { x = x, y = y }
    end

    add_fill(0, 0, size.w, size.h, "paper")
    local side, top = scale(tokens.padding.side), scale(tokens.padding.top)
    local content_w = size.w - 2 * side

    -- Done: its label inside the button's padding and outline.
    local outline = scale(tokens.button_outline_width)
    local pad_x, pad_y = scale(tokens.button_padding.x), scale(tokens.button_padding.y)
    local label = Typeset.line(look.type.editor_button, "Done", content_w, ctx)
    local label_size = label:getSize()
    local done_w, done_h = label_size.w + 2 * (pad_x + outline), label_size.h + 2 * (pad_y + outline)

    -- The aside over the title, beside Done with the header gap between them.
    local column_w = math.max(1, content_w - done_w - scale(tokens.header_gap))
    local aside = spec.aside and Typeset.line(look.type.editor_aside, spec.aside, column_w, ctx)
    local title = Typeset.line(look.type.editor_title, spec.title or "", column_w, ctx)
    local aside_h = aside and aside:getSize().h or 0
    local column_h = aside_h + title:getSize().h
    -- Done's foot level with the title's (EditLayout.dc.html:19, align-items: flex-end).
    local header_h = math.max(column_h, done_h)
    local foot_y = top + header_h
    if aside then
        add(aside, side, foot_y - column_h)
    end
    add(title, side, foot_y - column_h + aside_h)
    local done = Geom:new{ x = size.w - side - done_w, y = foot_y - done_h, w = done_w, h = done_h }
    local rule_y = foot_y + scale(tokens.header_gap)
    local header = Geom:new{ x = 0, y = 0, w = size.w, h = rule_y }
    add_fill(header.x, header.y, header.w, header.h, tokens.header_band_color)
    local rule = Geom:new{ x = 0, y = rule_y, w = size.w, h = scale(tokens.header_rule_width) }
    add_fill(rule.x, rule.y, rule.w, rule.h, tokens.header_rule_color)
    add_fill(done.x, done.y, done.w, done.h, tokens.button_fill_color)
    local outline_color = color(tokens.button_outline_color)
    if outline > 0 and outline_color then
        fills[#fills + 1] = { x = done.x, y = done.y, w = done.w, h = done.h, border = outline, color = outline_color }
    end
    add(label, done.x + outline + pad_x, done.y + outline + pad_y)

    local places = { {
        control = {
            kind = "button",
            run = function()
                if spec.done then
                    spec.done()
                else
                    close_editor(editor)
                end
            end,
        },
        rect = done,
    } }
    local function place_row(row, y)
        for _, control in ipairs(row) do
            local rect = control.rect
            local place = {
                control = control,
                rect = Geom:new{ x = side + rect.x, y = y + rect.y, w = rect.w, h = rect.h },
            }
            places[#places + 1] = place
            if control.draw then
                frame.drawn[#frame.drawn + 1] = place
            end
        end
    end

    -- The foot, pinned above the bottom padding; then as many of the body's rows, in order, as
    -- fit between body_gap below the rule and the foot.
    local foot_rows = spec.foot(ctx, content_w) or {}
    local foot_h = 0
    for _, row in ipairs(foot_rows) do
        foot_h = foot_h + row_height(row)
    end
    local foot_top = size.h - scale(tokens.padding.bottom) - foot_h
    local body_rows = spec.body(ctx, content_w) or {}
    local y = rule.y + rule.h + scale(tokens.body_gap)
    local kept = 0
    for _, row in ipairs(body_rows) do
        local h = row_height(row)
        if y + h > foot_top then
            break
        end
        place_row(row, y)
        kept = kept + 1
        y = y + h
    end
    y = foot_top
    for _, row in ipairs(foot_rows) do
        place_row(row, y)
        y = y + row_height(row)
    end

    -- A card casts the editor's card shadow, under every control.
    local shadow = tokens.card_shadow
    local shadow_color = color(shadow.color)
    if shadow_color then
        local sx, sy = scale(shadow.x), scale(shadow.y)
        for _, place in ipairs(places) do
            if place.control.kind == "card" then
                local rect = place.rect
                frame.shadows[#frame.shadows + 1] = { x = rect.x + sx, y = rect.y + sy, w = rect.w, h = rect.h,
                    color = shadow_color }
            end
        end
    end

    frame.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    return {
        frame = frame,
        places = places,
        header = header,
        rule = rule,
        done = done,
        left_out = #body_rows - kept,
    }
end

-- Builds the frame from the spec into the editor under a fresh ctx, built as the home builds its
-- own (HomeRows.build) with no home, freeing the frame it replaces. The rows left out are logged
-- once per editor.
local function build(editor)
    local ctx = {
        look = Looks.active(),
        variant = Looks.variant(),
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
    }
    local laid = lay_out(editor, ctx)
    local old = editor.frame
    editor.ctx = ctx
    editor.frame = laid.frame
    editor.places = laid.places
    editor.header = laid.header
    editor.rule = laid.rule
    editor.done = laid.done
    editor.left_out = laid.left_out
    editor.dimen = laid.frame.dimen
    if laid.left_out > 0 and not editor.left_out_logged then
        editor.left_out_logged = true
        logger.warn("KoPanda: the editor", editor.spec.screen, "leaves out", laid.left_out, "rows that don't fit")
    end
    if old then
        old:free()
    end
end

function Editor:init()
    -- The whole screen, so every tap reaches the editor.
    self.ges_events.TapEditor = {
        GestureRange:new{ ges = "tap", range = function() return self.dimen end },
    }
    -- As the sheet binds it (frontend/ui/widget/buttondialog.lua:98-108).
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    build(self)
end

-- The settled signal, once, after the first paint: from tickAfterNext after the show, or, when
-- that finds no paint yet (a full-screen window over the editor), from the tick after the first
-- paint. A failed paint sends none.
local function settle(editor)
    if editor.settled or editor.paint_failed then
        return
    end
    if not editor.painted_at then
        editor.settle_waiting = true
        return
    end
    editor.settled = true
    PaintClock.settled("the editor's", editor.started, editor.painted_at, { screen = editor.spec.screen })
end

-- Shows the editor of spec, closing the one shown, and returns it. opts.started is the
-- PaintClock stamp its opener took, which paint_ms and cpu_ms run from; without it, the start of
-- the show.
-- A failure is logged, takes the editor off the stack and returns nil.
function Editor.show(spec, opts)
    local started = opts and opts.started or PaintClock.now()
    local editor
    local ok, err = pcall(function()
        Editor.close()
        editor = Editor:new{ spec = spec, started = started }
        Editor.shown = editor
        UIManager:show(editor, "full")
        -- Lands past the next repaint, so the signal follows the paint.
        UIManager:tickAfterNext(function()
            settle(editor)
        end)
    end)
    if ok then
        return editor
    end
    logger.err("KoPanda: could not show the editor", spec and spec.screen, err)
    if editor and UIManager:isWidgetShown(editor) then
        safe_close(editor)
    end
    Editor.shown = nil
    return nil
end

-- Closes the editor shown, if any.
function Editor.close()
    if Editor.shown then
        safe_close(Editor.shown)
    end
end

-- Rebuilds the frame from the spec's functions and repaints it once. A failure closes it.
function Editor:refresh()
    if Editor.shown ~= self then
        return
    end
    local ok, err = pcall(function()
        build(self)
        UIManager:setDirty(self, "ui")
    end)
    if not ok then
        fail(self, "could not be rebuilt:", err)
    end
end

-- The home under the editor is never painted (covers_fullscreen), so an editor's change defers
-- the home's refresh (Home:defer_refresh) and the close runs it, once. CloseWidget comes before
-- UIManager:close takes the editor off the stack and queues its "full" refresh
-- (frontend/ui/uimanager.lua:300, :308-354), which the home's "ui" one, queued by its setDirty
-- (:740), merges into (:1266-1281). home is required here: its gestures reach the menus that open the editor.
local function run_deferred_home_refresh()
    local Home = require("home")
    if Home.shown then
        Home.shown:run_deferred_refresh()
    end
end

function Editor:onCloseWidget()
    if Editor.shown == self then
        Editor.shown = nil
    end
    local frame = self.frame
    self.frame = nil
    if frame then
        frame:free()
    end
    local ok, err = pcall(run_deferred_home_refresh)
    if not ok then
        logger.err("KoPanda: the home could not catch up after the editor:", err)
    end
end

-- Paints the frame, rebuilt first when the variant changed since its build (night mode toggled
-- marks every window dirty, frontend/device/devicelistener.lua:14-27, as the home sees it) or
-- the screen's size did (a rotation), with no repaint of its own.
local function paint(editor, bb, x, y)
    local size = Screen:getSize()
    if editor.ctx.variant ~= Looks.variant() or size.w ~= editor.dimen.w or size.h ~= editor.dimen.h then
        build(editor)
    end
    editor.frame:paintTo(bb, x, y)
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the editor from the
-- next tick.
function Editor:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = PaintClock.now()
        if self.settle_waiting then
            UIManager:nextTick(function()
                settle(self)
            end)
        end
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the editor", self.spec.screen, "failed to paint:", err)
        UIManager:nextTick(function()
            safe_close(self)
        end)
    end
end

-- A tap runs the first control under it, unless disabled; anywhere else it does nothing. Every
-- tap is consumed.
local function tap(editor, ges)
    for _, place in ipairs(editor.places) do
        if place.rect:contains(ges.pos) then
            local control = place.control
            if control.run and not control.disabled then
                control.run()
            end
            return
        end
    end
end

function Editor:onTapEditor(_, ges)
    local ok, err = pcall(tap, self, ges)
    if not ok then
        fail(self, "failed on a tap:", err)
    end
    return true
end

local function guarded_close(editor, what)
    local ok, err = pcall(close_editor, editor)
    if not ok then
        fail(editor, what, err)
    end
    return true
end

-- The Back key, where the device has keys.
function Editor:onClose()
    return guarded_close(self, "failed on the Back key:")
end

-- KOReader's Back, sent to the top widget by the dispatcher's fm_back (frontend/dispatcher.lua:169).
function Editor:onBack()
    return guarded_close(self, "failed on Back:")
end

return Editor
