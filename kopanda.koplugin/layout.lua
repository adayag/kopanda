-- The home's layout maths: rows of slots placed on the screen from the look's home tokens. No
-- KOReader UI: the widgets are reached through the registry only to measure them.
--
-- Look tokens arrive in board pixels and are scaled once here by Screen:scaleBySize
-- (base/ffi/framebuffer.lua:414-425); widths and heights measured on the screen are device
-- pixels. Font sizes are not scaled here: Font:getFace scales them itself (frontend/ui/font.lua:276).
local Widgets = require("widgets")
local logger = require("logger")

local Layout = {}

-- The screen lengths are scaled for; the spec puts a screen of another size here.
Layout.screen = require("device").screen

local function scale(px)
    return Layout.screen:scaleBySize(px)
end

-- Each slot's { x, w } across content_w, x from the content's left edge: the width less the
-- gaps between columns, shared by share, each column floor(available × share / total) and the
-- last the remainder, so columns and gaps fill content_w exactly. gap is in board pixels.
function Layout.columns(content_w, slots, gap)
    local gap_px = scale(gap)
    local available = content_w - (#slots - 1) * gap_px
    local total = 0
    for _, slot in ipairs(slots) do
        total = total + slot.share
    end
    local columns, x, used = {}, 0, 0
    for i, slot in ipairs(slots) do
        local w
        if i < #slots then
            w = math.floor(available * slot.share / total)
        else
            w = available - used
        end
        columns[i] = { x = x, w = w }
        x = x + w + gap_px
        used = used + w
    end
    return columns
end

-- The placement without logging; see Layout.place.
local function place(row_heights, avail_h, margins, row_gap, free_space, footer_h, first_gap)
    local top, bottom = scale(margins.top), scale(margins.bottom)
    local gap, footer = scale(row_gap), scale(footer_h)
    local space = avail_h - top - bottom - footer

    -- The gap above a row with a height whose previous row with a height is prev, or 0 for the
    -- first row with a height.
    local function gap_after(prev)
        if not prev then
            return 0
        elseif prev == 1 and first_gap then
            return scale(first_gap)
        end
        return gap
    end

    -- The height rows 1 to n take, with a gap between each two that have a height.
    local function stacked(n)
        local sum, prev = 0, nil
        for i = 1, n do
            if row_heights[i] > 0 then
                sum = sum + gap_after(prev) + row_heights[i]
                prev = i
            end
        end
        return sum
    end

    local kept = #row_heights
    while kept > 0 and stacked(kept) > space do
        kept = kept - 1
    end
    local dropped = {}
    for i = kept + 1, #row_heights do
        dropped[#dropped + 1] = i
    end

    local ys, y, last, tall = {}, top, nil, 0
    for i = 1, kept do
        local h = row_heights[i]
        if h > 0 then
            y = y + gap_after(last)
            tall = tall + 1
            last = i
        end
        ys[i] = y
        y = y + h
    end
    -- The last row with a height, and any empty rows after it, moved down onto the bottom
    -- margin (above the footer).
    if free_space == "before_last_row" and tall >= 2 then
        local shift = avail_h - bottom - footer - (ys[last] + row_heights[last])
        for i = last, kept do
            ys[i] = ys[i] + shift
        end
    end
    return ys, dropped
end

-- The y of each row that fits and the indexes of those that don't. Rows stack from the top
-- margin with row_gap between rows that have a height; a row of height 0 takes no gap. When
-- the rows overflow avail_h less the margins and footer_h, rows are dropped from the end until
-- the rest fit, each drop logged. free_space "before_last_row" moves the last row down onto
-- the bottom margin when two or more rows have a height; "before_footer" leaves the rows
-- together at the top. first_gap, when given, is the gap below row 1 in place of row_gap.
-- row_heights and avail_h are device pixels; margins ({ top, bottom }), row_gap, footer_h and
-- first_gap are board pixels.
function Layout.place(row_heights, avail_h, margins, row_gap, free_space, footer_h, first_gap)
    local ys, dropped = place(row_heights, avail_h, margins, row_gap, free_space, footer_h, first_gap)
    for _, i in ipairs(dropped) do
        logger.warn("KoPanda: home row " .. i .. " doesn't fit the screen and is left out")
    end
    return ys, dropped
end

-- The footer's height in board pixels: its stripe and its edge, or 0 for a look without one.
local function footer_height(home)
    if home.footer.height > 0 then
        return home.footer.height + home.footer.edge_width
    end
    return 0
end

-- Bottom-aligns slots measured at their heights in a row content_h tall: sets each slot's
-- offset, the drop of its widget from the row's top, and returns the row's height. A slot whose
-- module gives a baseline (its last line's, from its top) for column width w under ctx sits with
-- it on the row's one baseline, which lies as low as the deepest drop below a baseline allows,
-- and the row grows to hold the tallest rise above it; any other slot with a height sits on the
-- row's bottom.
local function align_bottom(slots, content_h, ctx)
    local above, below = 0, 0
    for _, slot in ipairs(slots) do
        if slot.h > 0 and slot.module.baseline then
            local ok, baseline = pcall(slot.module.baseline, slot.w, ctx)
            if ok and type(baseline) == "number" then
                slot.baseline = baseline
                above = math.max(above, baseline)
                below = math.max(below, slot.h - baseline)
            end
        end
    end
    content_h = math.max(content_h, above + below)
    for _, slot in ipairs(slots) do
        if slot.baseline then
            slot.offset = content_h - below - slot.baseline
        elseif slot.h > 0 then
            slot.offset = content_h - slot.h
        end
    end
    return content_h
end

-- The whole home for layout rows under ctx ({ look, screen, ... }, passed on to each widget's
-- height): every row's height, the rows that fit with their slots measured and placed, the
-- dropped row indexes, and the header and footer chrome, in device pixels. Row 1 carries the
-- header: a band (full width) or a box between the side margins, its padding around the slots,
-- then its bottom edge, or its rule with rule_space above and below and no row gap after; with
-- the header's align "bottom", its slots are bottom-aligned on one baseline (align_bottom). A
-- slot is { widget, module, x, y, w, h, offset, error }, h its row's content height and offset
-- the drop of its widget from y (0 but in an aligned row). A slot whose widget has no module, or
-- whose height raises, measures 0; slot.error is the height's error. rows is not changed. The
-- home is sized by Layout.screen, the screen its lengths are scaled for.
local function arrange(rows, ctx, placer)
    local home = ctx.look.home
    local header = home.header
    local width, height = Layout.screen:getWidth(), Layout.screen:getHeight()
    local side = scale(home.margin.side)

    local measured, heights = {}, {}
    for i, row in ipairs(rows) do
        local inset = side
        if i == 1 then
            inset = header.band_color and scale(header.padding.side) or side + scale(header.padding.side)
        end
        local slots, content_h = {}, 0
        for j, column in ipairs(Layout.columns(width - 2 * inset, row, home.column_gap)) do
            local slot = { widget = row[j].widget, x = inset + column.x, w = column.w, h = 0, offset = 0 }
            slot.module = Widgets.get(slot.widget)
            if slot.module then
                local ok, h = pcall(slot.module.height, column.w, ctx)
                if ok and type(h) == "number" then
                    slot.h = h
                elseif ok then
                    slot.error = "height returned " .. tostring(h)
                else
                    slot.error = h
                end
            end
            content_h = math.max(content_h, slot.h)
            slots[j] = slot
        end
        if i == 1 and header.align == "bottom" then
            content_h = align_bottom(slots, content_h, ctx)
        end
        local chrome_top, chrome = 0, 0
        if i == 1 and content_h > 0 then
            chrome_top = scale(header.padding.top)
            chrome = chrome_top + scale(header.padding.bottom) + scale(header.edge_width)
            if header.rule_color then
                chrome = chrome + 2 * scale(header.rule_space) + scale(header.rule_width)
            end
        end
        measured[i] = { slots = slots, h = content_h + chrome, content_top = chrome_top, content_h = content_h }
        heights[i] = content_h + chrome
    end

    local first_gap = header.rule_color and 0 or nil
    local ys, dropped = placer(heights, height, home.margin, home.row_gap, home.free_space, footer_height(home),
        first_gap)
    local arranged = { width = width, height = height, heights = heights, rows = {}, dropped = dropped, header = {} }
    for i, y in ipairs(ys) do
        local row = measured[i]
        row.y = y
        for _, slot in ipairs(row.slots) do
            slot.y = y + row.content_top
            slot.h = row.content_h
        end
        arranged.rows[i] = row
    end

    local first = arranged.rows[1]
    if first and first.h > 0 then
        local bottom = first.y + first.h
        local edge = scale(header.edge_width)
        if header.band_color then
            arranged.header.band = { x = 0, y = first.y, w = width, h = first.h }
        end
        if edge > 0 then
            arranged.header.edge = { x = 0, y = bottom - edge, w = width, h = edge }
        end
        if header.rule_color then
            local rule = scale(header.rule_width)
            arranged.header.rule = {
                x = side,
                y = bottom - scale(header.rule_space) - rule,
                w = width - 2 * side,
                h = rule,
            }
        end
    end
    local footer = footer_height(home)
    if footer > 0 then
        local h = scale(footer)
        arranged.footer = {
            x = 0,
            y = height - scale(home.margin.bottom) - h,
            w = width,
            h = h,
            edge = scale(home.footer.edge_width),
            line = scale(home.footer.line_width),
            pitch = scale(home.footer.line_pitch),
        }
    end
    return arranged
end

-- The home for rows under ctx, each dropped row logged. See arrange above.
function Layout.arrange(rows, ctx)
    return arrange(rows, ctx, Layout.place)
end

-- Whether every row of rows fits ctx's screen: true exactly when the placement drops nothing.
-- The edit-layout screen asks Layout.overflow instead.
function Layout.fits(rows, ctx)
    return #arrange(rows, ctx, place).dropped == 0
end

-- How many rows of rows the placement leaves out on ctx's screen, unlogged: what the
-- edit-layout screen compares before and after a change.
function Layout.overflow(rows, ctx)
    return #arrange(rows, ctx, place).dropped
end

local TEXT_SCALE = { small = 0.85, medium = 1, large = 1.15 }

-- A look's font size at the text_size setting, rounded to a whole size.
function Layout.font_size(size, text_size)
    return math.floor(size * (TEXT_SCALE[text_size] or 1) + 0.5)
end

return Layout
