-- The featured book's cover box: the cover from CoverBrowser's cache fitted on paper, a
-- typographic placeholder when there is none, and the first run's dashed frame. The cover read,
-- the extraction ask and its bounded check are book_covers.lua's; this module's functions for
-- them delegate there.
local BookCovers = require("book_covers")
local CenterContainer = require("ui/widget/container/centercontainer")
local Fonts = require("fonts")
local Geom = require("ui/geometry")
local ImageWidget = require("ui/widget/imagewidget")
local Layout = require("layout")
local Looks = require("looks")
local Math = require("optmath")
local Paint = require("paint")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Typeset = require("typeset")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local FeaturedCover = {}

-- The placeholder title's most lines, ending in an ellipsis past them.
local TITLE_LINES = 4
-- The smallest size the placeholder title steps down to so no word of it is split.
local MIN_TITLE_SIZE = 8

-- The cover box, box_w by box_h, with its shadow below and right of it: the shadow, the fill,
-- each child at its place (self.places[i], from the box's top left), then the outline (Paint.backing
-- and Paint.outline read the fields). FeaturedCover.Box, so the library's tiles draw their boxes so.
local CoverBox = WidgetContainer:extend{
    name = "kopanda_featured_cover",
}
FeaturedCover.Box = CoverBox

function CoverBox:paintTo(bb, x, y)
    local w, h = self.box_w, self.box_h
    Paint.backing(bb, x, y, w, h, self)
    for i, child in ipairs(self) do
        local place = self.places[i]
        child:paintTo(bb, x + place.x, y + place.y)
    end
    Paint.outline(bb, x, y, w, h, self)
end

-- The first run's frame: dash-long strokes with dash_gap between them along each edge of the
-- box, then the child at its place. KOReader has no dashed border.
local DashedBox = WidgetContainer:extend{
    name = "kopanda_featured_cover_empty",
}

function DashedBox:paintTo(bb, x, y)
    local w, h, s = self.dimen.w, self.dimen.h, self.stroke
    local step = self.dash + self.dash_gap
    for along = 0, w - 1, step do
        local len = math.min(self.dash, w - along)
        Paint.fill(bb, x + along, y, len, s, self.color, 0)
        Paint.fill(bb, x + along, y + h - s, len, s, self.color, 0)
    end
    for along = 0, h - 1, step do
        local len = math.min(self.dash, h - along)
        Paint.fill(bb, x, y + along, s, len, self.color, 0)
        Paint.fill(bb, x + w - s, y + along, s, len, self.color, 0)
    end
    self[1]:paintTo(bb, x + self.places[1].x, y + self.places[1].y)
end

-- The cover box's w and h in device pixels for a column width wide: the look's size, scaled,
-- with the width at most 40 % of the column and the height then 1.5 times the width.
function FeaturedCover.box(width, ctx)
    local featured = ctx.look.featured
    local w = ctx.screen:scaleBySize(featured.cover_w)
    local h = ctx.screen:scaleBySize(featured.cover_h)
    local cap = math.floor(0.4 * width)
    if w > cap then
        w = cap
        h = math.floor(1.5 * w)
    end
    return w, h
end

-- Whether box split a word on a line it shows. TextBoxWidget sets has_split_inside_word for a
-- split on any line, shown or past its lines_per_page (frontend/ui/widget/textboxwidget.lua:421-424,
-- :478-480); with xtext each line keeps its own no_allowed_break_met (:420-421), so the shown lines
-- are read. Without xtext only the box's flag is there.
local function split_shown(box)
    if not box.has_split_inside_word then
        return false
    end
    if not box.use_xtext then
        return true
    end
    for i = 1, math.min(box.lines_per_page, #box.vertical_string_list) do
        if box.vertical_string_list[i].no_allowed_break_met then
            return true
        end
    end
    return false
end

-- The placeholder's title and authors in a box inner_w wide and inner_h high: the title in
-- frame.title at the top in at most four lines, the authors, joined, in frame.authors on one line
-- at the foot, or none without that part. Returns the widgets and their places from the inner
-- box's top left.
local function placeholder_text(record, inner_w, inner_h, ctx, background, frame)
    local look = ctx.look
    local palette = Looks.palette(look, ctx.variant)
    local widgets, places = {}, {}
    local authors_h = 0
    local authors = record.authors and table.concat(record.authors, ", ") or ""
    if frame.authors and authors ~= "" then
        local line = Typeset.line(frame.authors, authors, inner_w, ctx)
        authors_h = line:getSize().h
        widgets[#widgets + 1] = line
        places[#places + 1] = { x = 0, y = inner_h - authors_h }
    end
    local part = frame.title
    local title = record.title or ""
    if part.uppercase then
        title = title:upper()
    end
    -- TextBoxWidget breaks a word wider than its box mid-word, so the box is built again one size
    -- smaller, to MIN_TITLE_SIZE at least, while it splits one, as CoverBrowser's fake cover does
    -- (plugins/coverbrowser.koplugin/mosaicmenu.lua:211-214).
    local file = look.faces[part.face].file
    local size = Layout.font_size(part.size, ctx.text_size)
    local room = inner_h - authors_h
    local box
    while true do
        local face = Fonts.face(file, size)
        if not face then
            error("the cover title's font didn't load")
        end
        -- TextBoxWidget's line is (1 + line_height) em, rounded (frontend/ui/widget/textboxwidget.lua:151).
        local line_px = Math.round((1 + part.line_height) * face.size)
        local lines = math.max(1, math.min(TITLE_LINES, math.floor(room / line_px)))
        box = TextBoxWidget:new{
            text = title,
            face = face,
            width = inner_w,
            line_height = part.line_height,
            fgcolor = Looks.color(palette[part.color]),
            bgcolor = background,
            height = lines * line_px,
            height_adjust = true,
            height_overflow_show_ellipsis = true,
        }
        if size <= MIN_TITLE_SIZE or not split_shown(box) then
            break
        end
        box:free()
        size = size - 1
    end
    widgets[#widgets + 1] = box
    places[#places + 1] = { x = 0, y = 0 }
    return widgets, places
end

-- The framed cover box for record ({ path, title, authors list }) in a w by h box under ctx, in
-- frame's tokens (board pixels and palette roles): { outline_color, outline_width, radius,
-- shadow = { x, y, color }, padding = { x, y }, title, authors }, title and authors type parts,
-- authors nil for none. The outline is drawn only where the variant has outline_color. The widget
-- is the box plus the shadow's offset, so the shadow is never cut. Reads the cover cache through
-- BookCovers.read, the bitmap freed with the widget; never asks for an extraction.
function FeaturedCover.framed(record, w, h, ctx, frame)
    local palette = Looks.palette(ctx.look, ctx.variant)
    local function color(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
    local function scale(px)
        return ctx.screen:scaleBySize(px)
    end
    local shadow = frame.shadow
    local shadow_x, shadow_y = scale(shadow.x), scale(shadow.y)
    local outline_color = color(frame.outline_color)
    local outline = outline_color and scale(frame.outline_width) or 0
    local radius = scale(frame.radius)
    local box = CoverBox:new{
        dimen = Geom:new{ w = w + shadow_x, h = h + shadow_y },
        box_w = w,
        box_h = h,
        shadow_color = color(shadow.color),
        shadow_x = shadow_x,
        shadow_y = shadow_y,
        outline = outline,
        outline_color = outline_color,
        radius = radius,
        places = {},
    }
    local inner_w, inner_h = w - 2 * outline, h - 2 * outline

    local cover_bb = BookCovers.read(record, w, h)
    if cover_bb then
        -- Square: FrameContainer rounds its background and border, not its content
        -- (frontend/ui/widget/container/framecontainer.lua:124-139), and neither does this box.
        box.fill_color = color("paper")
        box.fill_radius = 0
        box[1] = CenterContainer:new{
            dimen = Geom:new{ w = inner_w, h = inner_h },
            ImageWidget:new{ image = cover_bb, width = inner_w, height = inner_h, scale_factor = 0 },
        }
        box.places[1] = { x = outline, y = outline }
        return box
    end

    box.fill_color = color("cover")
    box.fill_radius = radius
    local pad_x, pad_y = outline + scale(frame.padding.x), outline + scale(frame.padding.y)
    local widgets, places = placeholder_text(record, w - 2 * pad_x, h - 2 * pad_y, ctx, box.fill_color, frame)
    for i, widget in ipairs(widgets) do
        box[i] = widget
        box.places[i] = { x = pad_x + places[i].x, y = pad_y + places[i].y }
    end
    return box
end

-- The framed cover box for book ({ file, title, authors }, or nil for the first run) in a w by
-- h box under ctx: FeaturedCover.framed in the look's cover stroke, radius and shadow and the
-- featured placeholder's padding and parts, or the first run's dashed frame.
function FeaturedCover.build(book, w, h, ctx)
    local look = ctx.look
    if not book then
        local palette = Looks.palette(look, ctx.variant)
        local function scale(px)
            return ctx.screen:scaleBySize(px)
        end
        local inset = scale(look.featured.cover_padding.x)
        local stroke = math.max(1, scale(look.stroke.outline))
        local text = Typeset.line(look.type.cover_empty, "No book yet", w - 2 * inset, ctx)
        local size = text:getSize()
        return DashedBox:new{
            dimen = Geom:new{ w = w, h = h },
            stroke = stroke,
            dash = scale(look.featured.dash),
            dash_gap = scale(look.featured.dash_gap),
            color = Looks.color(palette.muted),
            places = { { x = math.floor((w - size.w) / 2), y = math.floor((h - size.h) / 2) } },
            text,
        }
    end
    local authors = {}
    if book.authors and book.authors ~= "" then
        authors[1] = book.authors
    end
    return FeaturedCover.framed({ path = book.file, title = book.title, authors = authors }, w, h, ctx, {
        outline_color = "outline",
        outline_width = look.stroke.outline,
        radius = look.radius.cover,
        shadow = look.shadow.cover,
        padding = look.featured.cover_padding,
        title = look.type.cover_title,
        authors = look.type.cover_authors,
    })
end

-- Whether to ask CoverBrowser to extract a cover for info, its getBookInfo row or nil, in a box
-- of specs ({ max_cover_w, max_cover_h }): BookCovers.wants.
FeaturedCover.wants_extraction = BookCovers.wants

-- Drops the scheduled check, if any. The widget's close path calls it, so a closed home leaves
-- nothing queued.
function FeaturedCover.cancel()
    BookCovers.cancel()
end

-- After the home's first paint: asks CoverBrowser for file's cover in a box of specs through
-- BookCovers.request, which refreshes home once the cover arrives while home is still shown.
function FeaturedCover.after_show(home, file, specs)
    if not file then
        return
    end
    BookCovers.request({ { path = file } }, specs, function()
        home:refresh()
    end, function()
        return require("home").shown == home
    end)
end

-- Forgets the files asked for and drops the check, as in a new process. For specs.
function FeaturedCover.reset()
    BookCovers.reset()
end

return FeaturedCover
