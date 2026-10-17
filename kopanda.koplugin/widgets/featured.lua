-- The featured book: its cover box (featured_cover.lua), then a text column with the label or
-- chip, the title, authors and chapter, and at its foot the progress bar and its caption, per
-- look (Main.dc.html:32-52, HomeRetro.dc.html:27-43). With no book, the first run: the dashed
-- frame and a column pointing at the Library (EmptyStates.dc.html:32-40). Lengths are board
-- pixels, scaled by ctx.screen.
local FeaturedBook = require("featured_book")
local FeaturedCover = require("featured_cover")
local Fonts = require("fonts")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LauncherEntries = require("launcher_entries")
local Layout = require("layout")
local Looks = require("looks")
local Math = require("optmath")
local Paint = require("paint")
local PaintClock = require("paint_clock")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Typeset = require("typeset")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")

local Featured = {
    id = "featured",
    settings_prefix = "featured",
}

-- The column's gap between items (Main.dc.html:38, HomeRetro.dc.html:33).
local ITEM_GAP = 6
-- Above Editorial's chapter: the gap and its 8 px margin (Main.dc.html:38, :42).
local CHAPTER_GAP = 14
-- Between the bar and its caption (Main.dc.html:43, HomeRetro.dc.html:39).
local BAR_GAP = 8
-- Between the first run's lines (EmptyStates.dc.html:35), and above its button, the gap and
-- the button's 6 px margin (:38).
local EMPTY_GAP = 10
local BUTTON_GAP = 16
-- The grey hatch's stripe: hatchRect makes on and off equal, measured along x
-- (base/ffi/blitbuffer.lua:2223), so 5 px matches the board's 7 px period (PWRetro.dc.html:40).
local STRIPE_WIDTH = 5
local TITLE_LINES = 2
local DINER_JOIN = " · "
-- floor(percent × 100) less a hair, so 0.29 reads 29 although 0.29 × 100 is 28.999…
local EPSILON = 1e-9

-- A box box_w by box_h with its shadow below and right of it, its fill, its child inset by its
-- outline and padding, and its outline: Diner's chip and the first run's button. Its rectangle
-- on the screen is kept as screen_rect when it paints.
local Box = WidgetContainer:extend{
    name = "kopanda_featured_box",
}

function Box:paintTo(bb, x, y)
    local w, h = self.box_w, self.box_h
    self.screen_rect = Geom:new{ x = x, y = y, w = w, h = h }
    Paint.backing(bb, x, y, w, h, self)
    self[1]:paintTo(bb, x + self.outline + self.pad_x, y + self.outline + self.pad_y)
    Paint.outline(bb, x, y, w, h, self)
end

-- The progress bar: its track, its fill (self[1]) inside its outline, then the outline.
local Bar = WidgetContainer:extend{
    name = "kopanda_featured_bar",
}

function Bar:paintTo(bb, x, y)
    local w, h = self.dimen.w, self.dimen.h
    if self.track_color then
        Paint.fill(bb, x, y, w, h, self.track_color)
    end
    self[1]:paintTo(bb, x + self.outline, y + self.outline)
    if self.outline > 0 then
        Paint.border(bb, x, y, w, h, self.outline, self.outline_color)
    end
end

-- A plain fill of dimen in color.
local Fill = Widget:extend{
    name = "kopanda_featured_fill",
}

function Fill:paintTo(bb, x, y)
    if self.dimen.w > 0 and self.color then
        Paint.fill(bb, x, y, self.dimen.w, self.dimen.h, self.color)
    end
end

local function is_diner(ctx)
    return ctx.look == Looks.get("diner")
end

local function scaler(ctx)
    return function(px)
        return ctx.screen:scaleBySize(px)
    end
end

local function colorer(ctx)
    local palette = Looks.palette(ctx.look, ctx.variant)
    return function(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
end

-- The percent the book shows: floored, so only a complete book shows 100. The book sheet's
-- meta reads it too.
function Featured.shown_percent(book)
    if book.status == "complete" then
        return 100
    end
    return math.floor(book.percent * 100 + EPSILON)
end

-- "N min left" under an hour, else "H h left" or "H h M min left", rounded to the minute
-- (Main.dc.html:50).
local function time_left(seconds)
    local minutes = Math.round(seconds / 60)
    if minutes < 60 then
        return minutes .. " min left"
    end
    local hours, rest = math.floor(minutes / 60), minutes % 60
    if rest == 0 then
        return hours .. " h left"
    end
    return hours .. " h " .. rest .. " min left"
end

-- The caption's parts for book: the percent, then "Finished", the time left or the pages left,
-- the first that applies, or nothing more.
function Featured.caption(book)
    local parts = { Featured.shown_percent(book) .. "%" }
    if book.status == "complete" then
        parts[2] = "Finished"
    elseif book.seconds_left then
        parts[2] = time_left(book.seconds_left)
    elseif book.pages then
        local left = book.pages - Math.round(book.percent * book.pages)
        parts[2] = left == 1 and "1 page left" or left .. " pages left"
    end
    return parts
end

-- The type part named part_name under ctx, its face, and its line height as TextBoxWidget
-- counts it (frontend/ui/widget/textboxwidget.lua:48, :151). Raises when the font won't load,
-- so the home blanks the slot.
local function face_of(part_name, ctx)
    local part = ctx.look.type[part_name]
    local face = Fonts.face(ctx.look.faces[part.face].file, Layout.font_size(part.size, ctx.text_size))
    if not face then
        error("the font for " .. part_name .. " didn't load")
    end
    return part, face, Math.round((1 + part.line_height) * face.size)
end

-- text in the type part named part_name, wrapped at width in at most max_lines lines, the last
-- ending in an ellipsis when it runs over; a single line is one line high
-- (frontend/ui/widget/textboxwidget.lua:54, :256-260).
local function text_box(part_name, text, width, max_lines, ctx)
    local part, face, line_px = face_of(part_name, ctx)
    local color = colorer(ctx)
    return TextBoxWidget:new{
        text = part.uppercase and text:upper() or text,
        face = face,
        width = width,
        line_height = part.line_height,
        fgcolor = color(part.color),
        bgcolor = color("paper"),
        height = max_lines * line_px,
        height_adjust = true,
        height_overflow_show_ellipsis = true,
    }
end

-- The label at most width wide: Editorial's plain label, or Diner's chip, a Box of chip.fill_color
-- with an outline of featured.chip_outline in chip.outline_color (HomeRetro.dc.html:34).
local function label(width, ctx)
    local look = ctx.look
    local tokens = look.featured
    local text = is_diner(ctx) and "Now reading" or "Continue reading"
    if not tokens.chip_outline then
        return Typeset.line(look.type.featured_label, text, width, ctx)
    end
    local scale, color = scaler(ctx), colorer(ctx)
    local outline = scale(tokens.chip_outline)
    local pad_x, pad_y = scale(tokens.chip_padding.x), scale(tokens.chip_padding.y)
    local line = Typeset.line(look.type.featured_label, text, width - 2 * (outline + pad_x), ctx)
    local size = line:getSize()
    local w, h = size.w + 2 * (outline + pad_x), size.h + 2 * (outline + pad_y)
    return Box:new{
        name = "kopanda_featured_chip",
        dimen = Geom:new{ w = w, h = h },
        box_w = w,
        box_h = h,
        fill_color = color(look.chip.fill_color),
        outline = outline,
        outline_color = color(look.chip.outline_color),
        pad_x = pad_x,
        pad_y = pad_y,
        line,
    }
end

-- The first run's "Open the Library" at most width wide: an outlined Box padded by
-- featured.button_padding, filled and with the tile's shadow where the look has them.
local function button(width, ctx)
    local look = ctx.look
    local tokens = look.featured
    local scale, color = scaler(ctx), colorer(ctx)
    local outline = scale(look.stroke.outline)
    local pad_x, pad_y = scale(tokens.button_padding.x), scale(tokens.button_padding.y)
    local shadow = look.shadow.tile
    local shadow_color = color(shadow.color)
    local shadow_x = shadow_color and scale(shadow.x) or 0
    local shadow_y = shadow_color and scale(shadow.y) or 0
    local line = Typeset.line(look.type.featured_button, "Open the Library",
        width - 2 * (outline + pad_x) - shadow_x, ctx)
    local size = line:getSize()
    local w, h = size.w + 2 * (outline + pad_x), size.h + 2 * (outline + pad_y)
    return Box:new{
        name = "kopanda_featured_button",
        dimen = Geom:new{ w = w + shadow_x, h = h + shadow_y },
        box_w = w,
        box_h = h,
        fill_color = color(tokens.button_fill_color),
        outline = outline,
        outline_color = color(tokens.button_outline_color),
        shadow_color = shadow_color,
        shadow_x = shadow_x,
        shadow_y = shadow_y,
        pad_x = pad_x,
        pad_y = pad_y,
        line,
    }
end

-- A progress bar width wide at percent shown, its track inner_h high (device pixels) inside an
-- outline of outline_width (board pixels) where the look's progress.outline_color is set, filled
-- to floor(inner width × shown / 100) in the look's progress colours: the featured book's bar and
-- the library tiles' strip. Where fill_grey is hatch_135 in the grey variant, the fill is a
-- FrameContainer striped ink over paper, whose hatchRect draws along x + y = constant, the board's
-- 135° (frontend/ui/widget/container/framecontainer.lua:48-50, :128-132;
-- base/ffi/blitbuffer.lua:2209-2235).
function Featured.bar(shown, width, inner_h, outline_width, ctx)
    local tokens = ctx.look.progress
    local scale, color = scaler(ctx), colorer(ctx)
    local outline_color = color(tokens.outline_color)
    local outline = outline_color and scale(outline_width) or 0
    local inner_w = width - 2 * outline
    local fill_w = math.floor(inner_w * shown / 100)
    local filled
    if tokens.fill_grey == "hatch_135" and ctx.variant == "grey" then
        filled = FrameContainer:new{
            background = color("paper"),
            -- hatchRect takes a Color8 (base/ffi/blitbuffer.lua:129, :2217).
            stripe_color = color("ink"):getColor8(),
            stripe_width = scale(STRIPE_WIDTH),
            bordersize = 0,
            padding = 0,
            Widget:new{ dimen = Geom:new{ w = fill_w, h = inner_h } },
        }
    else
        filled = Fill:new{ dimen = Geom:new{ w = fill_w, h = inner_h }, color = color(tokens.fill_color) }
    end
    return Bar:new{
        dimen = Geom:new{ w = width, h = inner_h + 2 * outline },
        track_color = color(tokens.track_color),
        outline = outline,
        outline_color = outline_color,
        filled,
    }
end

-- The caption width wide: Editorial's percent on the left and the rest on the right
-- (Main.dc.html:47-50), Diner's parts joined (HomeRetro.dc.html:41).
local function caption(book, width, ctx)
    local part = ctx.look.type.featured_caption
    local parts = Featured.caption(book)
    if is_diner(ctx) then
        return Typeset.line(part, table.concat(parts, DINER_JOIN), width, ctx)
    end
    local percent = Typeset.line(part, parts[1], width, ctx)
    local room = width - percent:getSize().w - ctx.screen:scaleBySize(ITEM_GAP)
    if not parts[2] or room <= 0 then
        return percent
    end
    local rest = Typeset.line(part, parts[2], room, ctx)
    return HorizontalGroup:new{
        percent,
        HorizontalSpan:new{ width = width - percent:getSize().w - rest:getSize().w },
        rest,
    }
end

-- A VerticalGroup of items ({ widget, gap above }), left-aligned.
local function stack(items)
    local group = VerticalGroup:new{ align = "left" }
    for _, item in ipairs(items) do
        if item[2] > 0 then
            group[#group + 1] = VerticalSpan:new{ width = item[2] }
        end
        group[#group + 1] = item[1]
    end
    return group
end

local function stacked_height(items)
    local h = 0
    for _, item in ipairs(items) do
        h = h + item[2] + item[1]:getSize().h
    end
    return h
end

-- A container exactly w by h holding group.
local function column(group, w, h)
    return WidgetContainer:new{ dimen = Geom:new{ w = w, h = h }, group }
end

-- The book's text column, w by h: the top block and the bottom block with the free height
-- between them, inside featured.column_padding_y. When they don't fit, the chapter, then the
-- authors, are left out, and then the title takes one line.
local function book_column(book, w, h, ctx)
    local look = ctx.look
    local scale = scaler(ctx)
    local pad = scale(look.featured.column_padding_y)
    local top = {
        { label(w, ctx), 0 },
        { text_box("featured_title", book.title or "", w, TITLE_LINES, ctx), scale(look.featured.title_gap) },
    }
    if is_diner(ctx) then
        local joined = {}
        for _, key in ipairs({ "authors", "chapter" }) do
            if book[key] and book[key] ~= "" then
                joined[#joined + 1] = book[key]
            end
        end
        if #joined > 0 then
            top[#top + 1] = { Typeset.line(look.type.featured_authors, table.concat(joined, DINER_JOIN), w, ctx),
                scale(ITEM_GAP) }
        end
    else
        if book.authors and book.authors ~= "" then
            top[#top + 1] = { Typeset.line(look.type.featured_authors, book.authors, w, ctx), scale(ITEM_GAP) }
        end
        if book.chapter and book.chapter ~= "" then
            top[#top + 1] = { Typeset.line(look.type.featured_chapter, book.chapter, w, ctx), scale(CHAPTER_GAP) }
        end
    end
    local progress = look.progress
    local bottom = {
        { Featured.bar(Featured.shown_percent(book), w, scale(progress.height), progress.outline_width, ctx), 0 },
        { caption(book, w, ctx), scale(BAR_GAP) },
    }
    local room = h - 2 * pad - stacked_height(bottom)
    while #top > 2 and stacked_height(top) > room do
        table.remove(top)[1]:free()
    end
    if stacked_height(top) > room then
        top[2][1]:free()
        top[2][1] = text_box("featured_title", book.title or "", w, 1, ctx)
    end
    local free = math.max(0, room - stacked_height(top))
    return column(VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = pad },
        stack(top),
        VerticalSpan:new{ width = free },
        stack(bottom),
    }, w, h)
end

-- The first run's column, w by h, centred vertically (EmptyStates.dc.html:34-38): the label,
-- "Nothing open yet.", the body in the lines that fit, and the button. In a column too short
-- for them the title takes one line and the body is left out. Returns the column and the
-- button.
local function empty_column(w, h, ctx)
    local scale = scaler(ctx)
    local pad = scale(ctx.look.featured.column_padding_y)
    local the_button = button(w, ctx)
    local title = "Nothing open yet."
    local items = {
        { label(w, ctx), 0 },
        { text_box("featured_empty_title", title, w, TITLE_LINES, ctx), scale(EMPTY_GAP) },
    }
    local function room()
        return h - 2 * pad - stacked_height(items) - scale(BUTTON_GAP) - the_button:getSize().h
    end
    if room() < 0 then
        items[2][1]:free()
        items[2][1] = text_box("featured_empty_title", title, w, 1, ctx)
    end
    local _, _, body_line = face_of("featured_empty_body", ctx)
    local lines = math.floor((room() - scale(EMPTY_GAP)) / body_line)
    if lines >= 1 then
        items[#items + 1] = { text_box("featured_empty_body",
            "Open a book from the Library and it will wait for you here.", w, lines, ctx), scale(EMPTY_GAP) }
    end
    items[#items + 1] = { the_button, scale(BUTTON_GAP) }
    local above = math.max(0, math.floor((h - stacked_height(items)) / 2))
    return column(VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = above },
        stack(items),
    }, w, h), the_button
end

-- The cover box's height plus the cover shadow's y, so the shadow is never cut.
function Featured.height(width, ctx)
    local _, h = FeaturedCover.box(width, ctx)
    return h + ctx.screen:scaleBySize(ctx.look.shadow.cover.y)
end

-- The cover box, the gap and the text column, exactly width wide and height(width) high. The
-- built widget keeps the book (nil on the first run), the cover box's size and the first run's
-- button for tap and after_show.
function Featured.build(width, ctx)
    local book = FeaturedBook.current()
    local w, h = FeaturedCover.box(width, ctx)
    local cover = FeaturedCover.build(book, w, h, ctx)
    local column_x = w + ctx.screen:scaleBySize(ctx.look.featured.gap)
    local column_w = width - column_x
    local text, the_button
    if book then
        text = book_column(book, column_w, h, ctx)
    else
        text, the_button = empty_column(column_w, h, ctx)
    end
    return WidgetContainer:new{
        name = "kopanda_featured",
        dimen = Geom:new{ w = width, h = Featured.height(width, ctx) },
        book = book,
        box_w = w,
        box_h = h,
        button = the_button,
        HorizontalGroup:new{
            align = "top",
            cover,
            HorizontalSpan:new{ width = math.max(0, column_x - cover:getSize().w) },
            text,
        },
    }
end

-- A tap in the slot (ges the gesture, built what build returned): opens the book through
-- KOReader's own path to the reader (frontend/apps/filemanager/filemanager.lua:1616-1639),
-- which closes the file manager and the home with it; refreshes the home when the book's file
-- has gone, so the next book is featured. On the first run a tap on the button runs the
-- launcher's library entry, which closes the home and shows the library; a tap elsewhere returns
-- false, so the home's own tap rule applies.
function Featured.tap(ctx, ges, built)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    local book = built and built.book
    if book then
        if lfs.attributes(book.file, "mode") == "file" then
            if fm then
                fm:openFile(book.file)
            end
        else
            ctx.home:refresh()
        end
        return true
    end
    local rect = built and built.button and built.button.screen_rect
    if rect and ges and rect:contains(ges.pos) then
        LauncherEntries.run{ kind = "kopanda", target = "library" }
        return true
    end
    return false
end

-- A hold in the slot: the book's sheet (book_sheet.lua), its paint_ms counted from here, or false
-- on the first run, so the home's sheet opens. book_sheet requires this module, so it is
-- required here, at call time.
function Featured.hold(ctx, _, built)
    local started = PaintClock.now()
    if not (built and built.book) then
        return false
    end
    require("book_sheet").open(ctx, built, { started = started })
    return true
end

-- After the home's first paint: asks the cover box for the book's cover at the box's size.
function Featured.after_show(ctx, built)
    local book = built and built.book
    if book then
        FeaturedCover.after_show(ctx.home, book.file, { max_cover_w = built.box_w, max_cover_h = built.box_h })
    end
end

return Featured
