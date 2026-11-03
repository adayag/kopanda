-- The book status page: a read-only window on the chrome (library_chrome.lua) for one Books record, its sections
-- (book_status.lua) drawn in the look, the cover beside the book's lines, then the progress, the reading history and
-- the description, which runs on full width over later pages turned by swipes. Back shows the screen it was opened
-- from again (KoPanda:showOpener). Text wraps in TextBoxWidget, a paragraph's lines counted by getAllLineCount and a
-- page's share of them shown through scrollLines (frontend/ui/widget/textboxwidget.lua:1174, :1443).
local BookCovers = require("book_covers")
local BookStatus = require("book_status")
local Books = require("books")
local Featured = require("widgets/featured")
local FeaturedCover = require("featured_cover")
local Fonts = require("fonts")
local Geom = require("ui/geometry")
local Layout = require("layout")
local LibraryChrome = require("library_chrome")
local LibraryTiles = require("library_tiles")
local Math = require("optmath")
local ReadingStats = require("reading_stats")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Typeset = require("typeset")
local logger = require("logger")
local Screen = require("device").screen

local BookStatusScreen = LibraryChrome.Window:extend{
    name = "kopanda_book_status",
    screen = "book_status",
    fields = { "drawn", "chips", "bar", "description", "cover_box" },
    record = nil,
    opener = nil,
}

-- The back control's label, by the screen it shows again.
local LABELS = { home = "Home", library = "Library", series = "Series", authors = "Authors", subjects = "Subjects",
    search = "Search" }
local VIEW = { kind = "book" }
local TITLE_LINES, AUTHOR_LINES, CHIP_ROWS = 2, 2, 2

local function scale(px)
    return Screen:scaleBySize(px)
end

-- f(...) caught: its result, or nil with the failure logged as what.
local function read(what, f, ...)
    local ok, result = pcall(f, ...)
    if not ok then
        logger.err("KoPanda: the book status could not read " .. what .. ":", result)
        return nil
    end
    return result
end

-- The book's Statistics history with its rate and the pages the rate counts, as BookStatus.sections takes them, in
-- a table of its own (book_history's is its memo's); nil for no md5 or no history.
local function statistics(md5)
    if not md5 then
        return nil
    end
    local history = read("the reading history", ReadingStats.book_history, md5)
    if type(history) ~= "table" then
        return nil
    end
    local out = {}
    for k, v in pairs(history) do
        out[k] = v
    end
    local ok, rate, pages = pcall(ReadingStats.seconds_per_page, md5)
    if ok then
        out.rate, out.rate_pages = rate, pages
    else
        logger.err("KoPanda: the book status could not read the reading speed:", rate)
    end
    return out
end

-- The record's progress, details and Statistics are read once per show, each failure leaving out what it gives.
function BookStatusScreen:init()
    local record = self.record
    local progress = read("the progress", Books.progress, record) or { status = "new" }
    local details = read("the details", Books.details, record) or {}
    self.sections = BookStatus.sections(record, progress, details, statistics(progress.md5), os.time())
    LibraryChrome.Window.init(self)
end

function BookStatusScreen:view()
    return VIEW
end

-- part's face under ctx and its line height as TextBoxWidget counts it (textboxwidget.lua:151). Raises when the
-- font won't load.
local function face_of(part, ctx)
    local face = Fonts.face(ctx.look.faces[part.face].file, Layout.font_size(part.size, ctx.text_size))
    if not face then
        error("the font for the book status didn't load")
    end
    return face, Math.round((1 + part.line_height) * face.size)
end

-- text in part wrapped at width: all its lines, or lines of them from line first (default 1), the last ending in an
-- ellipsis when first is nil and the text runs over. Printed through Typeset.printed, so on a plate its ground shows.
local function text_box(part, text, width, ctx, lines, first)
    local face, line_px = face_of(part, ctx)
    return Typeset.printed(part, width, ctx, function(box_w, fgcolor, bgcolor)
        local box = TextBoxWidget:new{
            text = part.uppercase and text:upper() or text,
            face = face,
            width = box_w,
            line_height = part.line_height,
            fgcolor = fgcolor,
            bgcolor = bgcolor,
            height = lines and lines * line_px or nil,
            height_adjust = true,
            height_overflow_show_ellipsis = first == nil,
        }
        if first and first > 1 then
            box:scrollLines(first - 1)
        end
        return box
    end)
end

-- The description's measure for BookStatus.split at width under ctx: a paragraph's lines counted on a one-line
-- box, so no more than a line is rendered (textboxwidget.lua:969-987), flagged as a dummy as KOReader's own are
-- (frontend/ui/widget/dictquicklookup.lua:515).
local function measure(width, ctx)
    local part = ctx.look.type.book_description
    local face, line_px = face_of(part, ctx)
    return {
        line_h = line_px,
        gap = scale(ctx.look.book_status.paragraph_gap),
        lines = function(paragraph)
            local box = TextBoxWidget:new{
                text = paragraph,
                face = face,
                width = width,
                line_height = part.line_height,
                height = line_px,
                for_measurement_only = true,
            }
            local n = box:getAllLineCount()
            box:free()
            return n
        end,
    }
end

-- The sections of kind, by kind.
local function by_kind(sections)
    local out = {}
    for _, section in ipairs(sections) do
        out[section.kind] = section
    end
    return out
end

-- Widgets stacked in a column x wide from y, each { widget, gap above }: adds each to box at x and returns the
-- column's bottom.
local function stack(box, items, x, y)
    for i, item in ipairs(items) do
        if i > 1 then
            y = y + item[2]
        end
        LibraryChrome.add(box, item[1], x, y)
        y = y + item[1]:getSize().h
    end
    return y
end

-- The subjects as chips in rows width wide from (x, y), CHIP_ROWS rows at most, the subjects past them left out.
-- Returns the chips, each { widget, rect, subject }, and the bottom of the last row.
local function chips(subjects, x, y, width, ctx)
    local tokens = ctx.look.library.header
    local gap = scale(tokens.picker_gap)
    local inside = math.max(1, width - 2 * (scale(tokens.picker_padding.x) + scale(tokens.picker_outline_width)))
    local out, row, row_x, row_h, bottom = {}, 1, x, 0, y
    for _, subject in ipairs(subjects) do
        local line = Typeset.line(ctx.look.type.shelf_chip_plain, subject, inside, ctx)
        local chip = LibraryChrome.chip({ line }, tokens.sort_fill_color, ctx)
        local size = chip:getSize()
        if row_x > x and row_x + size.w > x + width then
            row, row_x, y = row + 1, x, y + row_h + gap
            row_h = 0
        end
        if row > CHIP_ROWS then
            chip:free()
            break
        end
        out[#out + 1] = { widget = chip, subject = subject,
            rect = Geom:new{ x = row_x, y = y, w = size.w, h = size.h } }
        row_x, row_h = row_x + size.w + gap, math.max(row_h, size.h)
        bottom = y + row_h
    end
    return out, bottom
end

-- The cover's box on a page whose content is w wide: a third of it, at a book cover's 2:3.
local function cover_size(w)
    local cover_w = math.floor(w / 3)
    return cover_w, math.floor(cover_w * 3 / 2)
end

-- Page 1's top in box from top: the cover a third of w wide beside the book's lines and chips, then the progress
-- and the history, each section gap apart while it fits above bottom. Returns { drawn, chips, bar, y }, y the
-- top of the room left for the description.
local function page_one(sections, record, box, x, top, w, bottom, ctx)
    local look = ctx.look
    local types = look.type
    local gaps = { line = scale(look.sheet.line_gap), title = scale(look.featured.title_gap),
        section = scale(look.book_status.section_gap) }
    local kept = by_kind(sections)
    local out = { drawn = {}, chips = {} }

    local cover_w, cover_h = cover_size(w)
    local cover = FeaturedCover.framed(record, cover_w, cover_h, ctx, FeaturedCover.frame(look))
    LibraryChrome.add(box, cover, x, top)
    out.drawn[1] = { kind = "cover", rect = Geom:new{ x = x, y = top, w = cover_w, h = cover_h } }

    local book = kept.book
    local col_x = x + cover_w + scale(look.featured.gap)
    local col_w = math.max(1, x + w - col_x)
    local items = { { text_box(types.featured_title, book.title, col_w, ctx, TITLE_LINES), 0 } }
    if book.author then
        items[#items + 1] = { text_box(types.featured_authors, book.author, col_w, ctx, AUTHOR_LINES), gaps.title }
    end
    for _, field in ipairs({ "series", "length" }) do
        if book[field] then
            items[#items + 1] = { Typeset.line(types.series_sub, book[field], col_w, ctx), gaps.line }
        end
    end
    local col_bottom = stack(box, items, col_x, top)
    if #book.subjects > 0 then
        out.chips, col_bottom = chips(book.subjects, col_x, col_bottom + gaps.title, col_w, ctx)
        for _, chip in ipairs(out.chips) do
            LibraryChrome.add(box, chip.widget, chip.rect.x, chip.rect.y)
        end
    end
    out.drawn[2] = { kind = "book", rect = Geom:new{ x = col_x, y = top, w = col_w, h = col_bottom - top } }
    local y = math.max(top + cover:getSize().h, col_bottom)

    local function section(kind, widgets)
        local h = 0
        for i, item in ipairs(widgets) do
            h = h + item[1]:getSize().h + (i > 1 and item[2] or 0)
        end
        local at = y + gaps.section
        if at + h > bottom then
            logger.warn("KoPanda: the book status leaves out its " .. kind .. ", which doesn't fit the page")
            for _, item in ipairs(widgets) do
                item[1]:free()
            end
            return false
        end
        stack(box, widgets, x, at)
        out.drawn[#out.drawn + 1] = { kind = kind, rect = Geom:new{ x = x, y = at, w = w, h = h } }
        y = at + h
        return true
    end

    local progress = kept.progress
    if progress then
        local bar = Featured.bar(progress.shown, w, scale(look.progress.height), look.progress.outline_width, ctx)
        local widgets = { { bar, 0 }, { Typeset.line(types.featured_caption, progress.caption, w, ctx), gaps.line } }
        if progress.left then
            widgets[#widgets + 1] = { Typeset.line(types.series_sub, progress.left, w, ctx), gaps.line }
        end
        if section("progress", widgets) then
            out.bar = bar
        end
    end
    local history = kept.history
    if history then
        local widgets = {}
        if history.total then
            widgets[#widgets + 1] = { Typeset.line(types.featured_caption, history.total, w, ctx), gaps.line }
        end
        if history.dates then
            widgets[#widgets + 1] = { Typeset.line(types.series_sub, history.dates, w, ctx), gaps.line }
        end
        section("history", widgets)
    end
    out.y = y + gaps.section
    return out
end

local function same_box(a, b)
    return a.max_cover_w == b.max_cover_w and a.max_cover_h == b.max_cover_h
end

-- The description's part on a page: paragraph number part.paragraph's count lines from part.first, w wide.
local function description_part(part, ctx, w)
    return text_box(ctx.look.type.book_description, part.text, w, ctx, part.count, part.first)
end

-- Fills built at its page: the header, page 1's top or nothing on a later page, the page's share of the
-- description, and the pager with no nav bar. The description's split is kept on the window for the screen's
-- size, look and text size, so a page turn neither lays out page 1 nor measures the text again; a cover box other
-- than the one asked for marks the covers due, so a rotation asks for it again after its paint.
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local x = scale(look.shelf.list.side)
    local width = w - 2 * x
    local header_h = LibraryChrome.detail_header_height(ctx)
    local top = header_h + scale(look.shelf.books.padding_top)
    local bottom = h - LibraryTiles.pager_height(ctx) - scale(look.shelf.list.pager_gap)

    local header_box
    header_box, built.header = LibraryChrome.header(ctx, w, {
        height = header_h,
        band = look.library.header.fill_color,
        back_label = LABELS[self.opener and self.opener.screen] or LABELS.home,
        right = {},
        aside = { part = look.type.library_count, text = self.record.title },
        title = { part = look.type.shelf_detail_title, text = "Book details" },
    })
    LibraryChrome.add(frame, header_box, 0, 0)

    local key = table.concat({ w, h, tostring(ctx.text_size), tostring(look) }, " ")
    local kept = self.kept
    local top_box, first
    -- Page 1's top, laid out in a box of its own until the page is known; a failure frees it, as the frame is.
    local function lay_out_top()
        top_box = LibraryChrome.box(w, h)
        local ok, result = pcall(page_one, self.sections, self.record, top_box, x, top, width, bottom, ctx)
        if not ok then
            top_box:free()
            error(result, 0)
        end
        first = result
    end
    if built.page == 1 or not (kept and kept.key == key) then
        lay_out_top()
    end
    if not (kept and kept.key == key) then
        local description = by_kind(self.sections).description
        local ok, pages = pcall(function()
            return BookStatus.split(description and description.text, math.max(0, bottom - first.y), bottom - top,
                measure(width, ctx))
        end)
        if not ok then
            top_box:free()
            error(pages, 0)
        end
        kept = { key = key, pages = pages }
        self.kept = kept
    end
    built.pages = math.max(1, #kept.pages)
    built.page = math.max(1, math.min(built.page or 1, built.pages))
    if built.page == 1 and not top_box then
        lay_out_top()
    end

    local y = top
    built.drawn, built.chips, built.description = {}, {}, {}
    local cover_w, cover_h = cover_size(width)
    built.cover_box = { max_cover_w = cover_w, max_cover_h = cover_h }
    if self.cover_asked and not same_box(self.cover_asked, built.cover_box) then
        self.covers_due = true
    end
    if built.page == 1 then
        LibraryChrome.add(frame, top_box, 0, 0)
        built.drawn, built.chips, built.bar = first.drawn, first.chips, first.bar
        y = first.y
    elseif top_box then
        top_box:free()
    end
    local parts = kept.pages[built.page] or {}
    local gap = scale(look.book_status.paragraph_gap)
    for i, part in ipairs(parts) do
        if i > 1 then
            y = y + gap
        end
        local widget = description_part(part, ctx, width)
        local size = widget:getSize()
        LibraryChrome.add(frame, widget, x, y)
        built.description[i] = { paragraph = part.paragraph, first = part.first, count = part.count, widget = widget,
            rect = Geom:new{ x = x, y = y, w = width, h = size.h } }
        y = y + size.h
    end
    if #parts > 0 then
        local from = built.description[1].rect.y
        built.drawn[#built.drawn + 1] = { kind = "description", rect = Geom:new{ x = x, y = from, w = width,
            h = y - from } }
    end
    LibraryChrome.foot(built, frame, nil)
end

function BookStatusScreen:build(_, page)
    return LibraryChrome.build({ page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- The cover at the page's cover box, asked of CoverBrowser once per show and box after a paint, as the featured
-- cover asks for its own (FeaturedCover.after_show): one cached at the library grid's size is too small for this
-- box (bookinfomanager.lua:1013-1030). Its arrival rebuilds the page shown while the window is.
function BookStatusScreen:request_covers()
    if LibraryChrome.shown ~= self or (self.cover_asked and same_box(self.cover_asked, self.cover_box)) then
        return
    end
    self.cover_asked = self.cover_box
    local ok, err = pcall(BookCovers.request, { self.record }, self.cover_box, function()
        self:refresh()
    end, function()
        return LibraryChrome.shown == self
    end)
    if not ok then
        logger.err("KoPanda: the book status's cover request failed:", err)
    end
end

-- Read-only: nothing on the page acts on a tap but the chrome's back control and pager.
function BookStatusScreen.action_at()
    return nil
end

-- The back control: the screen the page was opened from, shown again through the plugin; with no file manager
-- instance to show it from, the window closes onto the file browser.
function BookStatusScreen:back()
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if fm and fm.kopanda then
        fm.kopanda:showOpener(self.opener)
    else
        LibraryChrome.close()
    end
end

-- opts: record (a Books record), opener (the screen back shows again: { screen = "home" }, or a chrome window's
-- { screen, view, page, from }), page and started (LibraryChrome.show's). Returns the window shown, or nil.
function BookStatusScreen.show(opts)
    return LibraryChrome.show(BookStatusScreen, opts, { record = opts.record, opener = opts.opener,
        page = opts.page })
end

function BookStatusScreen.close()
    if BookStatusScreen.shown then
        LibraryChrome.close()
    end
end

return BookStatusScreen
