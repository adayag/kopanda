-- The featured book's cover box: the cover from CoverBrowser's cache fitted on paper, a
-- typographic placeholder when there is none, the first run's dashed frame, and the one path
-- that asks CoverBrowser to extract a cover, with its bounded check for the result.
--
-- CoverBrowser is reached through pcall(require, "bookinfomanager"): its folder joins
-- package.path only when the plugin is enabled (frontend/pluginloader.lua:283-287), so a failed
-- require means it is disabled, and the placeholder is drawn.
-- Module state: asked, the files extraction was asked for in this process; check, the scheduled
-- check or nil.
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Fonts = require("fonts")
local Geom = require("ui/geometry")
local ImageWidget = require("ui/widget/imagewidget")
local Layout = require("layout")
local Looks = require("looks")
local Math = require("optmath")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Typeset = require("typeset")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local FeaturedCover = {}

-- The placeholder title's most lines, ending in an ellipsis past them.
local TITLE_LINES = 4
-- The smallest size the placeholder title steps down to so no word of it is split.
local MIN_TITLE_SIZE = 8
-- The checks while an extraction runs, one a second, before giving up.
local MAX_CHECKS = 30

local asked = {}
local check

-- BookInfoManager, or nil when CoverBrowser is disabled.
local function manager()
    local ok, bim = pcall(require, "bookinfomanager")
    if ok and type(bim) == "table" then
        return bim
    end
    return nil
end

-- getBookInfo(file, get_cover) (bookinfomanager.lua:325-404), or nil on a failure, logged.
local function book_info(bim, file, get_cover)
    local ok, info = pcall(bim.getBookInfo, bim, file, get_cover)
    if not ok then
        logger.err("KoPanda: CoverBrowser's book info failed:", info)
        return nil
    end
    return info
end

-- Whether info's cover, cached or about to be read, suits a box of specs: there is one, the
-- book's cover is not ignored (CoverBrowser draws none for such rows, mosaicmenu.lua:508,
-- listmenu.lua:272), and it is not too small for the box (bookinfomanager.lua:1013-1030).
local function has_fitting_cover(bim, info, specs)
    return info ~= nil and info.has_cover and not info.ignore_cover
        and not bim.isCachedCoverInvalid(info, specs)
end

-- Whether info's cached cover bitmap can be drawn in a box of specs.
local function is_usable(bim, info, specs)
    return has_fitting_cover(bim, info, specs) and info.cover_bb ~= nil
end

-- The cached cover of file for a w by h box, or nil. An unusable bitmap is freed, as
-- mosaicmenu.lua:478-479 does.
local function read_cover(file, w, h)
    local bim = manager()
    if not bim or not file then
        return nil
    end
    local info = book_info(bim, file, true)
    if not info then
        return nil
    end
    local ok, usable = pcall(is_usable, bim, info, { max_cover_w = w, max_cover_h = h })
    if ok and usable then
        return info.cover_bb
    end
    if not ok then
        logger.err("KoPanda: CoverBrowser's cover check failed:", usable)
    end
    if info.cover_bb then
        info.cover_bb:free()
    end
    return nil
end

-- A filled rectangle, rounded by radius; a colour goes through the RGB32 variant, since the
-- plain one greys it (base/ffi/blitbuffer.lua:2169-2197).
local function fill(bb, x, y, w, h, color, radius)
    if Blitbuffer.isColor8(color) then
        bb:paintRoundedRect(x, y, w, h, color, radius)
    else
        bb:paintRoundedRectRGB32(x, y, w, h, color, radius)
    end
end

local function border(bb, x, y, w, h, width, color, radius)
    if Blitbuffer.isColor8(color) then
        bb:paintBorder(x, y, w, h, width, color, radius)
    else
        bb:paintBorderRGB32(x, y, w, h, width, color, radius)
    end
end

-- The cover box, box_w by box_h, with its shadow below and right of it: the shadow, the fill,
-- each child at its place (self.places[i], from the box's top left), then the outline.
local CoverBox = WidgetContainer:extend{
    name = "kopanda_featured_cover",
}

function CoverBox:paintTo(bb, x, y)
    local w, h = self.box_w, self.box_h
    if self.shadow_color then
        fill(bb, x + self.shadow_x, y + self.shadow_y, w, h, self.shadow_color, self.radius)
    end
    if self.fill_color then
        fill(bb, x, y, w, h, self.fill_color, self.fill_radius)
    end
    for i, child in ipairs(self) do
        local place = self.places[i]
        child:paintTo(bb, x + place.x, y + place.y)
    end
    if self.outline > 0 then
        border(bb, x, y, w, h, self.outline, self.outline_color, self.radius)
    end
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
        fill(bb, x + along, y, len, s, self.color, 0)
        fill(bb, x + along, y + h - s, len, s, self.color, 0)
    end
    for along = 0, h - 1, step do
        local len = math.min(self.dash, h - along)
        fill(bb, x, y + along, s, len, self.color, 0)
        fill(bb, x + w - s, y + along, s, len, self.color, 0)
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

-- The placeholder's title and authors in a box inner_w wide and inner_h high: the title at the
-- top in at most four lines, the authors on one line at the foot. Returns the widgets and their
-- places from the inner box's top left.
local function placeholder_text(book, inner_w, inner_h, ctx, background)
    local look = ctx.look
    local palette = Looks.palette(look, ctx.variant)
    local widgets, places = {}, {}
    local authors_h = 0
    if book.authors and book.authors ~= "" then
        local line = Typeset.line(look.type.cover_authors, book.authors, inner_w, ctx)
        authors_h = line:getSize().h
        widgets[#widgets + 1] = line
        places[#places + 1] = { x = 0, y = inner_h - authors_h }
    end
    local part = look.type.cover_title
    local title = book.title or ""
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

-- The framed cover box for book ({ file, title, authors }, or nil for the first run) in a w by
-- h box under ctx. The widget is the box plus the cover shadow's offset, so the shadow is never
-- cut. Reads CoverBrowser's cache; never asks for an extraction.
function FeaturedCover.build(book, w, h, ctx)
    local look = ctx.look
    local palette = Looks.palette(look, ctx.variant)
    local function color(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
    local function scale(px)
        return ctx.screen:scaleBySize(px)
    end
    local shadow = look.shadow.cover
    local shadow_x, shadow_y = scale(shadow.x), scale(shadow.y)
    local dimen = Geom:new{ w = w + shadow_x, h = h + shadow_y }

    if not book then
        local inset = scale(look.featured.cover_padding.x)
        local stroke = math.max(1, scale(look.stroke.outline))
        local text = Typeset.line(look.type.cover_empty, "No book yet", w - 2 * inset, ctx)
        local size = text:getSize()
        return DashedBox:new{
            dimen = Geom:new{ w = w, h = h },
            stroke = stroke,
            dash = scale(look.featured.dash),
            dash_gap = scale(look.featured.dash_gap),
            color = color("muted"),
            places = { { x = math.floor((w - size.w) / 2), y = math.floor((h - size.h) / 2) } },
            text,
        }
    end

    local outline_color = color("outline")
    local outline = outline_color and scale(look.stroke.outline) or 0
    local radius = scale(look.radius.cover)
    local box = CoverBox:new{
        dimen = dimen,
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

    local cover_bb = read_cover(book.file, w, h)
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
    local padding = look.featured.cover_padding
    local pad_x, pad_y = outline + scale(padding.x), outline + scale(padding.y)
    local widgets, places = placeholder_text(book, w - 2 * pad_x, h - 2 * pad_y, ctx, box.fill_color)
    for i, widget in ipairs(widgets) do
        box[i] = widget
        box.places[i] = { x = pad_x + places[i].x, y = pad_y + places[i].y }
    end
    return box
end

-- Whether to ask CoverBrowser to extract a cover for info, its getBookInfo row or nil, in a box
-- of specs ({ max_cover_w, max_cover_h }). Never without CoverBrowser. Otherwise in
-- mosaicmenu.lua:471-488's order: the never-ask rows come before the size test, since
-- isCachedCoverInvalid is true for any row without cover_w (bookinfomanager.lua:1014-1015).
function FeaturedCover.wants_extraction(info, specs)
    local bim = manager()
    if not bim then
        return false
    end
    if info == nil then
        return true
    end
    if info.unsupported or info.ignore_cover or (info.cover_fetched and not info.has_cover) then
        return false
    end
    if not info.cover_fetched then
        return true
    end
    return (info.has_cover and bim.isCachedCoverInvalid(info, specs)) and true or false
end

-- Drops the scheduled check, if any. The widget's close path calls it, so a closed home leaves
-- nothing queued.
function FeaturedCover.cancel()
    if check then
        UIManager:unschedule(check)
        check = nil
    end
end

-- After the home's first paint: asks CoverBrowser once per file per process to extract file's
-- cover for a box of specs when wants_extraction says so, then checks each second while the
-- extraction runs, at most 30 times. CoverBrowser has no completion event, and polls the same
-- way itself (covermenu.lua:164-175). A check that finds the cover's row refreshes home once and
-- stops; so does the last check, when the cover is there.
function FeaturedCover.after_show(home, file, specs)
    local bim = manager()
    if not bim or not file or asked[file] then
        return
    end
    local ok, wanted = pcall(FeaturedCover.wants_extraction, book_info(bim, file, false), specs)
    if not ok then
        logger.err("KoPanda: the cover extraction test failed:", wanted)
        return
    end
    if not wanted then
        return
    end
    asked[file] = true
    FeaturedCover.cancel()
    local started, launched = pcall(bim.extractInBackground, bim, { { filepath = file, cover_specs = specs } })
    if not started or not launched then
        logger.err("KoPanda: CoverBrowser's extraction didn't start:", launched)
        return
    end
    local runs = 0
    local this_check
    this_check = function()
        if check ~= this_check then
            return
        end
        check = nil
        local done, err = pcall(function()
            runs = runs + 1
            local Home = require("home")
            if Home.shown ~= home then
                return
            end
            -- The cover's row, read without its bitmap: once it is there, stop early, rather than
            -- wait for the extraction to end, which is noticed only when CoverBrowser reaps the
            -- process every 10 s (bookinfomanager.lua:139, :627-650).
            if has_fitting_cover(bim, book_info(bim, file, false), specs) then
                home:refresh()
                return
            end
            if runs < MAX_CHECKS and bim:isExtractingInBackground() then
                check = this_check
                UIManager:scheduleIn(1, this_check)
                return
            end
            local info = book_info(bim, file, true)
            local usable = info ~= nil and is_usable(bim, info, specs)
            if info and info.cover_bb then
                info.cover_bb:free()
            end
            if usable then
                home:refresh()
            end
        end)
        if not done then
            check = nil
            logger.err("KoPanda: the cover check failed:", err)
        end
    end
    check = this_check
    UIManager:scheduleIn(1, this_check)
end

-- Forgets the files asked for and drops the check, as in a new process. For specs.
function FeaturedCover.reset()
    FeaturedCover.cancel()
    asked = {}
end

return FeaturedCover
