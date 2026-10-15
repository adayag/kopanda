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
local function place(row_heights, avail_h, margins, row_gap, free_space, footer_h)
    local top, bottom = scale(margins.top), scale(margins.bottom)
    local gap, footer = scale(row_gap), scale(footer_h)
    local space = avail_h - top - bottom - footer

    -- The height rows 1 to n take, with a gap between each two that have a height.
    local function stacked(n)
        local sum, tall = 0, 0
        for i = 1, n do
            if row_heights[i] > 0 then
                sum = sum + row_heights[i]
                tall = tall + 1
            end
        end
        return sum + math.max(tall - 1, 0) * gap
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
            if tall > 0 then
                y = y + gap
            end
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
-- together at the top. row_heights and avail_h are device pixels; margins ({ top, bottom }),
-- row_gap and footer_h are board pixels.
function Layout.place(row_heights, avail_h, margins, row_gap, free_space, footer_h)
    local ys, dropped = place(row_heights, avail_h, margins, row_gap, free_space, footer_h)
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

-- The whole home for layout rows under ctx ({ look, screen, ... }, passed on to each widget's
-- height): every row's height, the rows that fit with their slots measured and placed, the
-- dropped row indexes, and the header and footer chrome, in device pixels. Row 1 carries the
-- header: a band (full width) or a box between the side margins, its padding around the slots,
-- then its bottom edge or its rule. A slot whose widget has no module, or whose height raises,
-- measures 0; slot.module is the module and slot.error the height's error. rows is not changed.
local function arrange(rows, ctx, placer)
    local home = ctx.look.home
    local header = home.header
    local width, height = ctx.screen:getWidth(), ctx.screen:getHeight()
    local side = scale(home.margin.side)

    local measured, heights = {}, {}
    for i, row in ipairs(rows) do
        local inset = side
        if i == 1 then
            inset = header.band_color and scale(header.padding.side) or side + scale(header.padding.side)
        end
        local slots, content_h = {}, 0
        for j, column in ipairs(Layout.columns(width - 2 * inset, row, home.column_gap)) do
            local slot = { widget = row[j].widget, x = inset + column.x, w = column.w, h = 0 }
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
        local chrome_top, chrome = 0, 0
        if i == 1 and content_h > 0 then
            chrome_top = scale(header.padding.top)
            chrome = chrome_top + scale(header.padding.bottom) + scale(header.edge_width)
            if header.rule_color then
                chrome = chrome + scale(header.rule_space) + scale(header.rule_width)
            end
        end
        measured[i] = { slots = slots, h = content_h + chrome, content_top = chrome_top, content_h = content_h }
        heights[i] = content_h + chrome
    end

    local ys, dropped = placer(heights, height, home.margin, home.row_gap, home.free_space, footer_height(home))
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
            arranged.header.rule = { x = side, y = bottom - rule, w = width - 2 * side, h = rule }
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
        }
    end
    return arranged
end

-- The home for rows under ctx, each dropped row logged. See arrange above.
function Layout.arrange(rows, ctx)
    return arrange(rows, ctx, Layout.place)
end

-- Whether every row of rows fits ctx's screen: true exactly when the placement drops nothing.
-- What the edit-layout screen asks before it adds a row.
function Layout.fits(rows, ctx)
    return #arrange(rows, ctx, place).dropped == 0
end

local TEXT_SCALE = { small = 0.85, medium = 1, large = 1.15 }

-- A look's font size at the text_size setting, rounded to a whole size.
function Layout.font_size(size, text_size)
    return math.floor(size * (TEXT_SCALE[text_size] or 1) + 0.5)
end

return Layout
