-- The home's layout maths: rows of slots placed on the screen from the look's home tokens. No KOReader UI:
-- the widgets are reached through the registry only to measure them. Look tokens arrive in board pixels
-- and are scaled once here by Screen:scaleBySize (base/ffi/framebuffer.lua:414-425); measured widths and
-- heights are device pixels. Font sizes are not scaled here: Font:getFace does (frontend/ui/font.lua:276).
local Widgets = require("widgets")
local logger = require("logger")

local Layout = {}

-- The screen lengths are scaled for; a spec puts a screen of another size here.
Layout.screen = require("device").screen

-- The home's rows, top to bottom; each row's slots, left to right, take its width by share.
Layout.rows = {
    { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
    { { widget = "featured", share = 1 } },
    { { widget = "quote", share = 1 } },
    { { widget = "launcher", share = 1 } },
}

local function scale(px)
    return Layout.screen:scaleBySize(px)
end

-- Each slot's { x, w } across content_w, x from the content's left edge: the width less the gaps
-- between columns, shared by share, the last column taking the remainder. gap is in board pixels.
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

    -- Each row with a height whose gap above takes a share of the free height: every one after the first,
    -- but the one first_gap holds under row 1.
    local ys, y, last, opened = {}, top, nil, {}
    for i = 1, kept do
        local h = row_heights[i]
        if h > 0 then
            y = y + gap_after(last)
            if last and not (last == 1 and first_gap) then
                opened[#opened + 1] = i
            end
            last = i
        end
        ys[i] = y
        y = y + h
    end
    -- The free height split over those gaps, the last taking the remainder, so the last row with a
    -- height (and any empty rows after it) sits on the bottom margin above the footer.
    if free_space == "between_rows" and #opened > 0 then
        local free = avail_h - bottom - footer - (ys[last] + row_heights[last])
        local share = math.floor(free / #opened)
        local shift, k = 0, 1
        for i = 1, kept do
            if opened[k] == i then
                shift = shift + (k == #opened and free - share * (#opened - 1) or share)
                k = k + 1
            end
            ys[i] = ys[i] + shift
        end
    end
    return ys, dropped
end

-- The y of each row that fits and the indexes of those that don't. Rows stack from the top margin with
-- row_gap between rows that have a height; when they overflow avail_h less the margins and footer_h,
-- rows are dropped from the end, each logged. free_space "between_rows" spreads the free height over the
-- gaps so the last row sits on the bottom margin; "before_footer" leaves the rows at the top. first_gap,
-- when given, replaces row_gap below row 1. row_heights and avail_h are device pixels, the rest board pixels.
function Layout.place(row_heights, avail_h, margins, row_gap, free_space, footer_h, first_gap)
    local ys, dropped = place(row_heights, avail_h, margins, row_gap, free_space, footer_h, first_gap)
    for _, i in ipairs(dropped) do
        logger.warn("KoPanda: home row " .. i .. " doesn't fit the screen and is left out")
    end
    return ys, dropped
end

-- The footer's height in board pixels, 0 for a look without one.
local function footer_height(home)
    if home.footer.height > 0 then
        return home.footer.height + home.footer.edge_width
    end
    return 0
end

-- The nav bar's height in look on Layout.screen at text_size, in device pixels, or 0, logged, when it
-- raises, so the home still lays out. nav_bar is required at call time: it requires this module.
local function bar_height(look, text_size)
    local ok, h = pcall(function()
        return require("nav_bar").height(look, Layout.screen, text_size)
    end)
    if ok and type(h) == "number" then
        return h
    end
    logger.err("KoPanda: the nav bar's height failed; the home has no band:", ok and tostring(h) or h)
    return 0
end

-- Bottom-aligns slots measured at their heights in a row content_h tall: sets each slot's offset (the drop
-- of its widget from the row's top) and returns the row's height. Slots whose module gives a baseline sit
-- on the row's one baseline and the row grows to hold the tallest rise above it; any other slot sits on
-- the row's bottom.
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

-- The whole home for rows under ctx ({ look, screen, ... }): measured heights, the rows that fit with slots placed, the
-- dropped row indexes and the chrome, in device pixels. The quote's row drops first, staying as an empty row, then rows
-- from the end, each drop logged once. A slot that fails to measure reads 0 (slot.error); plates go round row 1 and
-- plate.slots' widgets.
function Layout.arrange(rows, ctx)
    local home = ctx.look.home
    local header = home.header
    local width, height = Layout.screen:getWidth(), Layout.screen:getHeight()
    local side = scale(home.margin.side)
    local bar = bar_height(ctx.look, ctx.text_size)
    local above = height - bar
    local plates = ctx.look.plate
    local keyline = plates.fill_color and scale(plates.keyline) or 0

    local measured, heights = {}, {}
    for i, row in ipairs(rows) do
        local inset = side
        if i == 1 then
            inset = header.band_color and scale(header.padding.side) or side + scale(header.padding.side)
            inset = inset + keyline
        end
        local slots, content_h = {}, 0
        for j, column in ipairs(Layout.columns(width - 2 * inset, row, home.column_gap)) do
            local slot = { widget = row[j].widget, x = inset + column.x, w = column.w, h = 0, offset = 0,
                pad_x = 0, pad_y = 0 }
            local plate = i > 1 and plates.fill_color and plates.slots[slot.widget]
            if plate then
                slot.pad_x, slot.pad_y = keyline + scale(plate.x), keyline + scale(plate.y)
                slot.radius = scale(plate.radius)
            end
            slot.module = Widgets.get(slot.widget)
            if slot.module then
                local ok, h = pcall(slot.module.height, column.w - 2 * slot.pad_x, ctx)
                if ok and type(h) == "number" then
                    slot.h = h
                elseif ok then
                    slot.error = "height returned " .. tostring(h)
                else
                    slot.error = h
                end
            end
            -- A plate round a widget with a height; none round one that measures 0.
            slot.plated = plate and slot.h > 0
            if slot.plated then
                slot.h = slot.h + 2 * slot.pad_y
            end
            content_h = math.max(content_h, slot.h)
            slots[j] = slot
        end
        if i == 1 and header.align == "bottom" then
            content_h = align_bottom(slots, content_h, ctx)
        end
        local chrome_top, chrome = 0, 0
        if i == 1 and content_h > 0 then
            chrome_top = scale(header.padding.top) + keyline
            chrome = chrome_top + scale(header.padding.bottom) + keyline + scale(header.edge_width)
            if header.rule_color then
                chrome = chrome + 2 * scale(header.rule_space) + scale(header.rule_width)
            end
        end
        measured[i] = { slots = slots, h = content_h + chrome, content_top = chrome_top, content_h = content_h }
        heights[i] = content_h + chrome
    end

    local first_gap = header.rule_color and 0 or nil
    local spans = { unpack(heights) }
    local function fit(placement)
        return placement(spans, above, home.margin, home.row_gap, home.free_space, footer_height(home), first_gap)
    end
    -- Unlogged: a row that only overflows with the quote in place isn't dropped, so it mustn't be logged.
    local _, overflowing = fit(place)
    local quote_row
    if #overflowing > 0 then
        for i, row in ipairs(measured) do
            if row.h > 0 and row.slots[1] and row.slots[1].widget == "quote" then
                quote_row = i
                measured[i] = { slots = {}, h = 0, content_top = 0, content_h = 0 }
                spans[i] = 0
                break
            end
        end
    end
    local ys, dropped = fit(Layout.place)
    -- The quote's row sits among the kept rows, so it comes before any row still dropped.
    if quote_row and not (dropped[1] and dropped[1] <= quote_row) then
        table.insert(dropped, 1, quote_row)
        logger.warn("KoPanda: the quote doesn't fit the screen and is left out")
    end
    local arranged = {
        width = width,
        height = height,
        heights = heights,
        rows = {},
        dropped = dropped,
        header = {},
        nav = { x = 0, y = above, w = width, h = bar },
    }
    for i, y in ipairs(ys) do
        local row = measured[i]
        row.y = y
        for _, slot in ipairs(row.slots) do
            slot.y = y + row.content_top
            slot.h = row.content_h
            if slot.plated then
                slot.plate = { x = slot.x, y = slot.y, w = slot.w, h = slot.h, radius = slot.radius }
            end
            slot.plated, slot.radius = nil, nil
        end
        arranged.rows[i] = row
    end

    local first = arranged.rows[1]
    if first and first.h > 0 then
        local bottom = first.y + first.h
        if plates.fill_color then
            arranged.header.plate = { x = side, y = first.y, w = width - 2 * side, h = first.h,
                radius = scale(plates.radius) }
        end
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
            y = above - scale(home.margin.bottom) - h,
            w = width,
            h = h,
            edge = scale(home.footer.edge_width),
            line = scale(home.footer.line_width),
            pitch = scale(home.footer.line_pitch),
        }
    end
    return arranged
end

local TEXT_SCALE = { small = 0.85, medium = 1, large = 1.15, extra_large = 1.3 }

-- A look's font size at the text_size setting, rounded to a whole size; at extra_large a size
-- under 12 is lifted to 12 first.
function Layout.font_size(size, text_size)
    if text_size == "extra_large" and size < 12 then
        size = 12
    end
    return math.floor(size * (TEXT_SCALE[text_size] or 1) + 0.5)
end

-- A length that grows with the text, such as an icon or a cover, at the text_size setting, rounded: only
-- extra_large grows lengths, every other step keeps today's geometry.
function Layout.size_at(px, text_size)
    if text_size ~= "extra_large" then
        return px
    end
    return math.floor(px * TEXT_SCALE.extra_large + 0.5)
end

-- The text size a bar's or tile's label is set at for text_size: Large's at Extra large, so labels side by side
-- still fit with space between them while their icons grow.
function Layout.label_size(text_size)
    return text_size == "extra_large" and "large" or text_size
end

-- Outside the home's rows, only Extra large changes the type; the other steps keep today's shell.
function Layout.shell_text_size(text_size)
    if text_size == "extra_large" then
        return text_size
    end
    return nil
end

return Layout
