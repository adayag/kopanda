-- Edit layout: the screen that edits layout.rows (EditLayout.dc.html), in the editor frame
-- (editor.lua). A card per row with its arrows, caption and a box per column; a tap selects a
-- row, a tap on a selected card's box selects that column, and the selected card shows its
-- buttons. The foot adds a row or resets. Each change is a rows_edit operation, checked
-- against the home's fit, written once through Settings.set, then the screen is refreshed once
-- and the shown home once the editor closes. The selection is the screen's, never stored.
local Editor = require("editor")
local Helpers = require("helpers")
local Home = require("home")
local Icons = require("icons")
local Layout = require("layout")
local Looks = require("looks")
local Paint = require("paint")
local RowsEdit = require("rows_edit")
local Settings = require("settings")
local Sheet = require("sheet")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local logger = require("logger")
local util = require("util")

local EditLayout = {}

-- Frees the text and icon widgets of an earlier build.
local function release(widgets)
    for i = #widgets, 1, -1 do
        widgets[i]:free()
        widgets[i] = nil
    end
end

-- What one build draws with under ctx: the editor tokens, scaled lengths, palette colours,
-- and text and icon widgets, each kept in widgets to free on the next build.
local function kit(ctx, widgets)
    local palette = Looks.palette(ctx.look, ctx.variant)
    local k = { tokens = ctx.look.editor }
    function k.scale(px)
        return ctx.screen:scaleBySize(px)
    end
    function k.color(role)
        return role and palette[role] and Looks.color(palette[role])
    end
    -- One line in the type part name, in role in place of the part's colour when given.
    function k.text(name, text, max_w, role)
        local part = ctx.look.type[name]
        if role then
            part = util.tableDeepCopy(part)
            part.color = role
        end
        local line = Typeset.line(part, text, math.max(1, max_w), ctx)
        widgets[#widgets + 1] = line
        return line
    end
    function k.icon(id, size, role)
        local icon = TintedIcon:new{ file = Icons.path(id), size = size, color = k.color(role) }
        widgets[#widgets + 1] = icon
        return icon
    end
    return k
end

-- A filled and outlined w by h box at x, y: fill_role and outline_role may be false.
local function box_paint(k, bb, x, y, w, h, fill_role, outline_role, outline)
    local fill = k.color(fill_role)
    if fill then
        Paint.fill(bb, x, y, w, h, fill)
    end
    local color = k.color(outline_role)
    if color and outline > 0 then
        Paint.border(bb, x, y, w, h, outline, color)
    end
end

-- A button labelled label at most max_w wide: { w, h, draw(bb, x, y) }. opts.disabled draws
-- it in the disabled colour; opts.muted draws its label muted inside a disabled-colour outline,
-- as the board draws Remove row; opts.bare draws its label muted with no outline or fill.
local function button(k, label, opts, max_w)
    local t, s = k.tokens, k.scale
    local outline = opts.bare and 0 or s(t.button_outline_width)
    local pad_x, pad_y = opts.bare and 0 or s(t.button_padding.x), s(t.button_padding.y)
    local role = opts.disabled and t.disabled_color or (opts.muted or opts.bare) and "muted" or nil
    local text = k.text("editor_button", label, max_w - 2 * (outline + pad_x), role)
    local size = text:getSize()
    local w, h = size.w + 2 * (outline + pad_x), size.h + 2 * (outline + pad_y)
    local outline_role = (opts.disabled or opts.muted) and t.disabled_color or t.button_outline_color
    return {
        w = w,
        h = h,
        draw = function(bb, x, y)
            if not opts.bare then
                box_paint(k, bb, x, y, w, h, t.button_fill_color, outline_role, outline)
            end
            text:paintTo(bb, x + outline + pad_x, y + outline + pad_y)
        end,
    }
end

-- Shows a picker sheet headed heading over the screen, in the home's band.
local function picker(state, heading, rows)
    Sheet.show({ name = "picker", band = "home", header = { heading = heading }, rows = rows }, state.editor.ctx)
end

-- What Layout.overflow's count depends on beyond the rows that can change through the editor:
-- the look, the text size and the size of the screen it measures on. A row whose data changes
-- under the editor (a weather reading arriving, the quote of the day turning over) changes the
-- count without changing the key; apply catches that by measuring the rows shown again before
-- it refuses an edit.
local function fit_key(ctx)
    return { look = ctx.look, text_size = ctx.text_size, w = Layout.screen:getWidth(),
        h = Layout.screen:getHeight() }
end

local function same_key(a, b)
    return a.look == b.look and a.text_size == b.text_size and a.w == b.w and a.h == b.h
end

-- Applies an operation's result: its note when refused; "That won't fit on the home." when it
-- leaves out more home rows than the rows shown; otherwise writes it, takes it, its overflow and
-- selection, defers the shown home's refresh to the editor's close and refreshes the screen. The
-- shown rows' overflow is kept in state.fit while its key holds, so an edit measures only its
-- new rows, and the shown rows are measured again only when the edit would be refused. A failed
-- write is logged and changes nothing.
local function apply(state, new, why, selection)
    if not new then
        if why then
            Helpers.note(why)
        end
        return
    end
    local ctx = state.editor.ctx
    local key = fit_key(ctx)
    if not (state.fit and same_key(state.fit.key, key)) then
        state.fit = { key = key, overflow = Layout.overflow(state.rows, ctx) }
    end
    local overflow = Layout.overflow(new, ctx)
    if overflow > state.fit.overflow then
        state.fit.overflow = Layout.overflow(state.rows, ctx)
    end
    if overflow > state.fit.overflow then
        Helpers.note("That won't fit on the home.")
        return
    end
    local ok, err = Settings.set("layout.rows", new)
    if not ok then
        logger.err("KoPanda: could not save the layout:", err)
        Helpers.note("Couldn't save the layout.")
        return
    end
    state.rows = new
    state.fit.overflow = overflow
    state.selected = selection
    if Home.shown then
        Home.shown:defer_refresh()
    end
    state.editor:refresh()
end

local function select_row(state, i, j)
    state.selected = { row = i, column = j or 1 }
    state.editor:refresh()
end

-- Row i moved by delta, the selection following the rows it moves.
local function move(state, i, delta)
    local selected = state.selected
    if selected and (selected.row == i or selected.row == i + delta) then
        selected = { row = selected.row == i and i + delta or i, column = selected.column }
    end
    local new, why = RowsEdit.move(state.rows, i, delta)
    apply(state, new, why, selected)
end

-- The rows of a picker of the unused widgets, each running on_pick with its id.
local function unused_rows(state, on_pick)
    local rows = {}
    for _, id in ipairs(RowsEdit.unused(state.rows)) do
        rows[#rows + 1] = {
            label = RowsEdit.label(id),
            run = function()
                on_pick(id)
            end,
        }
    end
    return rows
end

-- The selected card's buttons, in order: { label, opts, run }.
local function card_buttons(state, i, j)
    local row = state.rows[i]
    local buttons = {
        {
            label = "Add column",
            opts = { disabled = #row >= RowsEdit.max_columns or #RowsEdit.unused(state.rows) == 0 },
            run = function()
                picker(state, "Add a widget", unused_rows(state, function(id)
                    local new, why = RowsEdit.add_column(state.rows, i, id)
                    apply(state, new, why, state.selected)
                end))
            end,
        },
        {
            label = "Change widget",
            opts = {},
            run = function()
                local rows = unused_rows(state, function(id)
                    local new, why = RowsEdit.change_widget(state.rows, i, j, id)
                    apply(state, new, why, state.selected)
                end)
                table.insert(rows, 1, { label = RowsEdit.label(row[j].widget), tick = true })
                picker(state, "Change widget", rows)
            end,
        },
    }
    if #row >= 2 then
        buttons[#buttons + 1] = {
            label = "Width",
            opts = {},
            run = function()
                local rows = {}
                for share = 1, 3 do
                    rows[share] = {
                        label = tostring(share),
                        tick = row[j].share == share or nil,
                        run = function()
                            local new, why = RowsEdit.set_share(state.rows, i, j, share)
                            apply(state, new, why, state.selected)
                        end,
                    }
                end
                picker(state, "Width", rows)
            end,
        }
        buttons[#buttons + 1] = {
            label = "Remove column",
            opts = {},
            run = function()
                local new, why = RowsEdit.remove_column(state.rows, i, j)
                apply(state, new, why, { row = i, column = math.min(j, #row - 1) })
            end,
        }
    end
    buttons[#buttons + 1] = {
        label = "Remove row",
        opts = { muted = true },
        run = function()
            local new, why = RowsEdit.remove_row(state.rows, i)
            local selected = state.selected
            if selected and selected.row == i then
                selected = nil
            end
            apply(state, new, why, selected)
        end,
    }
    return buttons
end

-- Row i's card, width wide, card_gap below the card above it: its controls, arrows, boxes and
-- the selected card's buttons first, so a tap on one runs it, then the card, which draws them
-- all (EditLayout.dc.html:29-58).
local function card(state, k, i, width)
    local t, s = k.tokens, k.scale
    local rows = state.rows
    local row = rows[i]
    local selected = state.selected and state.selected.row == i and state.selected
    local top = i > 1 and s(t.card_gap) or 0
    local outline = s(t.card_outline_width)
    local pad_x, pad_y = s(t.card_padding.x), s(t.card_padding.y)
    local arrow = s(t.arrow_size)
    local gap = s(t.box_gap)
    local inner_x = outline + pad_x + arrow + s(t.arrow_gap)
    local inner_w = width - inner_x - pad_x - outline
    local controls, paints = {}, {}
    local function control(c, x, y, w, h)
        c.row = i
        c.rect = { x = x, y = top + y, w = w, h = h }
        controls[#controls + 1] = c
    end

    local caption = RowsEdit.caption(rows, i, selected and true)
    local caption_line = k.text("editor_caption", caption, inner_w)
    local y = outline + pad_y
    paints[#paints + 1] = { widget = caption_line, x = inner_x, y = y }
    y = y + caption_line:getSize().h + gap

    -- A box per column, sharing the width evenly, its label at the left and its share at the
    -- right; on paper, the selected column's outline one board px heavier.
    local box_out, box_pad_x, box_pad_y = s(t.button_outline_width), s(t.box_padding.x), s(t.box_padding.y)
    local box_w = math.floor((inner_w - (#row - 1) * gap) / #row)
    local box_h = 0
    local boxes = {}
    for j, slot in ipairs(row) do
        local w = j < #row and box_w or inner_w - (#row - 1) * (box_w + gap)
        local room = w - 2 * (box_out + box_pad_x)
        local share = RowsEdit.share_text(row, j)
        local share_line = k.text("editor_share", share, room)
        local label = RowsEdit.label(slot.widget)
        local label_line = k.text("editor_box", label, room - share_line:getSize().w - box_pad_x)
        local content_h = math.max(share_line:getSize().h, label_line:getSize().h)
        box_h = math.max(box_h, content_h + 2 * (box_out + box_pad_y))
        boxes[j] = { x = inner_x + (j - 1) * (box_w + gap), w = w, label = label, share = share,
            label_line = label_line, share_line = share_line }
    end
    for j, b in ipairs(boxes) do
        local width_px = selected and selected.column == j and s(t.button_outline_width + 1) or box_out
        local box_y = y
        paints[#paints + 1] = {
            draw = function(bb, x0, y0)
                box_paint(k, bb, x0 + b.x, y0 + box_y, b.w, box_h, "paper", t.button_outline_color, width_px)
                b.label_line:paintTo(bb, x0 + b.x + box_out + box_pad_x, y0 + box_y + box_out + box_pad_y)
                b.share_line:paintTo(bb, x0 + b.x + b.w - box_out - box_pad_x - b.share_line:getSize().w,
                    y0 + box_y + box_out + box_pad_y)
            end,
        }
        control({
            kind = "box",
            column = j,
            label = b.label,
            share = b.share,
            run = function()
                select_row(state, i, selected and j or 1)
            end,
        }, b.x, box_y, b.w, box_h)
    end
    y = y + box_h

    -- The selected card's buttons, wrapping to another line where one doesn't fit.
    if selected then
        y = y + gap
        local x, line_h = inner_x, 0
        for _, spec in ipairs(card_buttons(state, i, selected.column)) do
            local b = button(k, spec.label, spec.opts, inner_w)
            if x > inner_x and x + b.w > inner_x + inner_w then
                x, y, line_h = inner_x, y + line_h + gap, 0
            end
            local bx, by = x, y
            paints[#paints + 1] = {
                draw = function(bb, x0, y0)
                    b.draw(bb, x0 + bx, y0 + by)
                end,
            }
            control({ kind = "button", label = spec.label, disabled = spec.opts.disabled, run = spec.run },
                bx, by, b.w, b.h)
            x = x + b.w + gap
            line_h = math.max(line_h, b.h)
        end
        y = y + line_h
    end

    local h = math.max(y + pad_y + outline, 2 * (outline + pad_y + arrow) + gap)

    -- The arrows at the card's left, the first row's up and the last row's down greyed.
    local arrow_out = s(t.button_outline_width)
    local icon_size = math.min(s(t.icon_size), arrow - 2 * arrow_out)
    for _, a in ipairs({
        { direction = "up", icon = "chevron_up", y = outline + pad_y, delta = -1, disabled = i == 1 },
        { direction = "down", icon = "chevron_down", y = h - outline - pad_y - arrow, delta = 1,
            disabled = i == #rows },
    }) do
        local role = a.disabled and t.disabled_color or nil
        local icon = k.icon(a.icon, icon_size, role or "ink")
        local ax = outline + pad_x
        paints[#paints + 1] = {
            draw = function(bb, x0, y0)
                box_paint(k, bb, x0 + ax, y0 + a.y, arrow, arrow, false, role or t.button_outline_color, arrow_out)
                local inset = math.floor((arrow - icon_size) / 2)
                icon:paintTo(bb, x0 + ax + inset, y0 + a.y + inset)
            end,
        }
        control({
            kind = "arrow",
            direction = a.direction,
            disabled = a.disabled,
            run = function()
                move(state, i, a.delta)
            end,
        }, ax, a.y, arrow, arrow)
    end

    local fill = selected and t.selected_fill_color or "paper"
    local outline_role = selected and t.selected_outline_color or t.card_outline_color
    control({
        kind = "card",
        caption = caption,
        draw = function(bb, x0, y0)
            box_paint(k, bb, x0, y0, width, h, fill, outline_role, outline)
            for _, p in ipairs(paints) do
                if p.widget then
                    p.widget:paintTo(bb, x0 + p.x, y0 + p.y)
                else
                    p.draw(bb, x0, y0)
                end
            end
        end,
        run = function()
            select_row(state, i, 1)
        end,
    }, 0, 0, width, h)
    return controls
end

-- The screen's spec over state: { rows, selected, editor, body_widgets, foot_widgets }.
local function spec(state)
    return {
        screen = "edit_layout",
        aside = "Home",
        title = "Edit layout",
        body = function(ctx, width)
            release(state.body_widgets)
            local k = kit(ctx, state.body_widgets)
            local rows = {}
            for i = 1, #state.rows do
                rows[i] = card(state, k, i, width)
            end
            return rows
        end,
        -- Add row at the left, greyed when every widget is on the home; Reset at the right, bare
        -- and muted (EditLayout.dc.html:101-104).
        foot = function(ctx, width)
            release(state.foot_widgets)
            local k = kit(ctx, state.foot_widgets)
            local full = #RowsEdit.unused(state.rows) == 0
            local add = button(k, "Add row", { disabled = full }, width)
            local reset = button(k, "Reset to the look's default", { bare = true }, width - add.w)
            local h = math.max(add.h, reset.h)
            return { {
                {
                    kind = "button",
                    label = "Add row",
                    rect = { x = 0, y = h - add.h, w = add.w, h = add.h },
                    draw = add.draw,
                    disabled = full,
                    run = function()
                        picker(state, "Add a widget", unused_rows(state, function(id)
                            local new, why = RowsEdit.add_row(state.rows, id)
                            apply(state, new, why, state.selected)
                        end))
                    end,
                },
                {
                    kind = "button",
                    label = "Reset to the look's default",
                    rect = { x = width - reset.w, y = h - reset.h, w = reset.w, h = reset.h },
                    draw = reset.draw,
                    run = function()
                        apply(state, RowsEdit.reset(), nil, nil)
                    end,
                },
            } }
        end,
    }
end

-- Opens edit layout on the stored layout.rows. opts.started is the PaintClock stamp the tap
-- that opened it took, which the settled signal's paint_ms runs from; opts.selected, a row to
-- start selected. A failure is logged and leaves no screen.
function EditLayout.open(opts)
    opts = opts or {}
    local ok, err = pcall(function()
        -- Settings.get hands back the stored table itself, so the screen works on a copy.
        local state = {
            rows = util.tableDeepCopy(Settings.get("layout.rows")),
            body_widgets = {},
            foot_widgets = {},
        }
        if opts.selected and state.rows[opts.selected] then
            state.selected = { row = opts.selected, column = 1 }
        end
        state.editor = Editor.show(spec(state), { started = opts.started })
    end)
    if not ok then
        logger.err("KoPanda: could not open edit layout:", err)
    end
end

return EditLayout
