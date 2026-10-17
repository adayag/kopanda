-- KoPanda's title bar for KOReader's file manager, drawn from the look as the library boards draw
-- their header: a count over the folder's title on the left, the sort and status pickers and the
-- plus (or check) icon on the right. It is a TitleBar, so the file manager and its chooser call it
-- as they call KOReader's (frontend/ui/widget/titlebar.lua:395-494), and it reads what it shows
-- from the file chooser each time it paints.
--
-- The down mark after each picker's label is the text " ▾" (U+25BE). Open fact F1, settled at the
-- Colorsoft: "▾" set by Typeset.line in Editorial's strong part and in Diner's display part paints
-- a down-pointing triangle 12 px wide in both looks. It differs from U+E000 (which KOReader's
-- fallback fonts turn out to cover with a glyph of their own) and from the missing-glyph box an
-- unassigned code point paints (U+0378, a 14 px outlined box), so it renders (outcome a) and no
-- icon is needed.
local BookList = require("ui/widget/booklist")
local FileChooser = require("ui/widget/filechooser")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Icons = require("icons")
local InputContainer = require("ui/widget/container/inputcontainer")
local Looks = require("looks")
local OverlapGroup = require("ui/widget/overlapgroup")
local Paint = require("paint")
local Screen = require("device").screen
local TintedIcon = require("tinted_icon")
local TitleBar = require("ui/widget/titlebar")
local Typeset = require("typeset")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local logger = require("logger")
local util = require("util")

local KoTitleBar = TitleBar:extend{
    name = "kopanda_title_bar",
    fm = nil,
    look = nil,
    on_sort = nil,
    on_status = nil,
}

-- The sort picker's label by KOReader's collate id (frontend/ui/widget/booklist.lua:20-270); an
-- id not here (a user patch's collate) shows its own text.
KoTitleBar.SORT_LABELS = {
    strcoll = "Name",
    natural = "Name",
    access = "Recent",
    date = "Modified",
    size = "Size",
    type = "Type",
    percent_unopened_first = "Progress",
    percent_unopened_last = "Progress",
    percent_natural = "Progress",
    title = "Title",
    authors = "Author",
    series = "Series",
    keywords = "Keywords",
    rating = "Rating",
}

-- The book statuses in the order KOReader's filter lists them
-- (frontend/apps/filemanager/filemanagermenu.lua:875).
local STATUSES = { "new", "reading", "abandoned", "complete" }

local DOWN_MARK = " \u{25BE}"

-- The height of part's line under look with no text size (D8): a line's height is its face's or
-- its forced height, whatever the text (typeset.lua:31-45). The variant only colours it.
local function line_height(look, part, sample, screen)
    local line = Typeset.line(part, sample, screen:getWidth(), { look = look, variant = "day" })
    local h = line:getSize().h
    line:free()
    return h
end

-- The bar's lengths in device pixels on screen, and its line heights.
local function metrics(look, screen)
    local tokens, parts = look.title_bar, look.type
    local m = {
        edge = screen:scaleBySize(tokens.edge_width),
        top = screen:scaleBySize(tokens.padding.top),
        side = screen:scaleBySize(tokens.padding.side),
        bottom = screen:scaleBySize(tokens.padding.bottom),
        line_gap = screen:scaleBySize(tokens.line_gap),
        picker_gap = screen:scaleBySize(tokens.picker_gap),
        outline = screen:scaleBySize(tokens.picker_outline_width),
        pad_x = screen:scaleBySize(tokens.picker_padding.x),
        pad_y = screen:scaleBySize(tokens.picker_padding.y),
        icon = screen:scaleBySize(tokens.icon_size),
        count_h = line_height(look, parts.title_bar_count, "0 books", screen),
        title_h = line_height(look, parts.title_bar_title, "Library", screen),
        picker_h = math.max(line_height(look, parts.title_bar_sort, "Name", screen),
            line_height(look, parts.title_bar_status, "Name", screen)),
    }
    m.row = m.picker_h + 2 * (m.pad_y + m.outline)
    m.content = math.max(m.count_h + m.line_gap + m.title_h, m.row)
    m.height = m.edge + m.top + m.content + m.bottom
    return m
end

-- The bar's height in look on screen, in device pixels: the edge, the top padding, the taller of
-- the count-over-title column and the picker row, and the bottom padding. Raises when a face
-- won't load.
function KoTitleBar.height(look, screen)
    return metrics(look, screen).height
end

-- Replaces TitleBar:init (titlebar.lua:86-393) whole: no title, subtitle or buttons of KOReader's,
-- one listener for the bar's taps and holds, and OverlapGroup's init so its size and dimen agree
-- (frontend/ui/widget/overlapgroup.lua:42-56): getSize, OverlapGroup's (:22-39), is then the
-- bar's width by its height.
function KoTitleBar:init()
    if not self.width then
        self.width = Screen:getWidth()
    end
    self.metrics = metrics(self.look, Screen)
    self.titlebar_height = self.metrics.height
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.titlebar_height }
    self.has_left_icon = false
    self.has_right_icon = true
    self.right_icon = self.right_icon == "check" and "check" or "plus"
    self.left_button = { image = { dimen = Geom:new{} } }
    self.logged = {}
    self.hold_taken = false
    -- The ranges are functions, read at match time (frontend/ui/gesturerange.lua:25-39): the
    -- dimen OverlapGroup.init makes below, and whose x and y paintTo sets, is the one matched.
    local function range()
        return self.dimen
    end
    local listener = InputContainer:new{
        ges_events = {
            KoTitleBarGesture = {
                GestureRange:new{ ges = "tap", range = range },
                GestureRange:new{ ges = "hold", range = range },
                GestureRange:new{ ges = "hold_release", range = range },
            },
        },
    }
    listener.onKoTitleBarGesture = function(_, _, ges)
        local ok, taken = pcall(self.handle, self, ges)
        if not ok then
            logger.err("KoPanda: the title bar's gesture failed:", taken)
            return false
        end
        return taken
    end
    self[1] = listener
    OverlapGroup.init(self)
end

-- Logs err under what, once per bar.
function KoTitleBar:logOnce(what, err)
    if not self.logged[what] then
        self.logged[what] = true
        logger.err("KoPanda: the title bar's " .. what .. " failed:", err)
    end
end

-- path, or its real path when it has one.
local function real(path)
    return ffiUtil.realpath(path) or path
end

-- The title: Library at the home folder, as KOReader tells it (filemanagerutil.lua:33), the
-- folder's last component elsewhere (filechooser.lua:327-329), "/" at the root.
local function title_of(path)
    local home = real(filemanagerutil.getHomeFolder())
    local here = real(path)
    if here == home or here == home .. "/" then
        return "Library"
    end
    if path == "/" then
        return "/"
    end
    local _, name = util.splitFilePathName(path)
    return name
end

-- The status filter's label: All, one status's, or the first in KOReader's order and +n.
local function status_of(filter)
    local set = {}
    for _, status in ipairs(STATUSES) do
        if filter and filter[status] then
            set[#set + 1] = status
        end
    end
    if #set == 0 then
        return BookList.getBookStatusString("all")
    end
    local label = BookList.getBookStatusString(set[1])
    if #set > 1 then
        label = label .. " +" .. (#set - 1)
    end
    return label
end

-- What the bar shows, read from the file manager's chooser and the screen: the variant, the
-- title, the count of files listed (nil with no chooser), the sort and status labels and the
-- right icon.
function KoTitleBar:state()
    local chooser = self.fm and self.fm.file_chooser
    local state = {
        variant = Looks.variant(),
        title = "",
        status = status_of(FileChooser.show_filter.status),
        icon = self.right_icon,
    }
    local collate, id = (chooser or FileChooser):getCollate()
    state.sort = KoTitleBar.SORT_LABELS[id] or collate.text
    if chooser then
        state.title = title_of(chooser.path)
        local count = 0
        for _, item in ipairs(chooser.item_table or {}) do
            if item.is_file then
                count = count + 1
            end
        end
        state.count = count
    end
    return state
end

local function same_state(a, b)
    if not (a and b) then
        return false
    end
    for _, key in ipairs({ "variant", "title", "count", "sort", "status", "icon" }) do
        if a[key] ~= b[key] then
            return false
        end
    end
    return true
end

-- The count's words: "3 books", "1 book", "No books", and "on the shelf" after them in a look
-- that says so.
local function count_text(count, on_shelf)
    local text
    if count == 0 then
        text = "No books"
    elseif count == 1 then
        text = "1 book"
    else
        text = count .. " books"
    end
    if on_shelf then
        text = text .. " on the shelf"
    end
    return text
end

local function free_build(built)
    if not built then
        return
    end
    for _, line in pairs(built.lines) do
        line:free()
    end
    built.icon:free()
end

-- Sets state's lines into lines and returns their boxes and the icon's, in bar-relative pixels.
-- The right group ends at the side padding with its bottom on the content's bottom: the sort
-- picker, the status picker, then the icon centred on the pickers' row; the count and title take
-- the width left of it, the title's bottom on the content's bottom.
local function lay_out(bar, state, lines)
    local look, m, width = bar.look, bar.metrics, bar.width
    local parts = look.type
    local ctx = { look = look, variant = state.variant }
    lines.sort = Typeset.line(parts.title_bar_sort, state.sort .. DOWN_MARK, width, ctx)
    lines.status = Typeset.line(parts.title_bar_status, state.status .. DOWN_MARK, width, ctx)
    local content_bottom = m.height - m.edge - m.bottom
    local row_top = content_bottom - m.row
    local inset = m.outline + m.pad_x
    local boxes = {}
    boxes.icon = { x = width - m.side - m.icon, y = row_top + math.floor((m.row - m.icon) / 2), w = m.icon, h = m.icon }
    local status_w = lines.status:getSize().w + 2 * inset
    boxes.status = { x = boxes.icon.x - m.picker_gap - status_w, y = row_top, w = status_w, h = m.row }
    local sort_w = lines.sort:getSize().w + 2 * inset
    boxes.sort = { x = boxes.status.x - m.picker_gap - sort_w, y = row_top, w = sort_w, h = m.row }
    local column_w = math.max(0, boxes.sort.x - m.picker_gap - m.side)
    local count = state.count and count_text(state.count, look.title_bar.count_on_shelf) or ""
    lines.title = Typeset.line(parts.title_bar_title, state.title, column_w, ctx)
    lines.count = Typeset.line(parts.title_bar_count, count, column_w, ctx)
    local title_y = content_bottom - m.title_h
    boxes.title = { x = m.side, y = title_y, w = lines.title:getSize().w, h = m.title_h }
    boxes.count = { x = m.side, y = title_y - m.line_gap - m.count_h, w = lines.count:getSize().w, h = m.count_h }
    return boxes
end

-- Builds the lines, the icon and the boxes for state, and the tap areas. A line that raises frees
-- the lines set before it and raises on, leaving the last build as it was.
function KoTitleBar:build(state)
    local lines = {}
    local ok, boxes = pcall(lay_out, self, state, lines)
    if not ok then
        for _, line in pairs(lines) do
            line:free()
        end
        error(boxes, 0)
    end
    local palette = Looks.palette(self.look, state.variant)
    local icon = TintedIcon:new{
        file = Icons.path(state.icon),
        size = self.metrics.icon,
        color = Looks.color(palette[self.look.title_bar.icon_color]),
    }
    -- Each area runs the bar's full height and meets the next half a gap from each picker.
    local half = math.floor(self.metrics.picker_gap / 2)
    local sort_left, status_left, plus_left = boxes.sort.x - half, boxes.status.x - half, boxes.icon.x - half
    self.areas = {
        title = { x = 0, w = sort_left },
        sort = { x = sort_left, w = status_left - sort_left },
        status = { x = status_left, w = plus_left - status_left },
        plus = { x = plus_left, w = self.width - plus_left },
    }
    free_build(self.built)
    self.built = { state = state, lines = lines, icon = icon }
    self.boxes = boxes
end

-- The fill above the edge and the edge across the bottom, in variant.
local function paint_ground(bar, bb, x, y, variant)
    local tokens, m = bar.look.title_bar, bar.metrics
    local palette = Looks.palette(bar.look, variant)
    local w, h = bar.width, m.height
    Paint.fill(bb, x, y, w, h - m.edge, Looks.color(palette[tokens.fill_color]))
    if m.edge > 0 then
        Paint.fill(bb, x, y + h - m.edge, w, m.edge, Looks.color(palette[tokens.edge_color]))
    end
end

-- The built bar: its ground, the count and title, each picker's fill and outline under its label,
-- and the icon.
function KoTitleBar:paintBuilt(bb, x, y)
    local built, boxes, m = self.built, self.boxes, self.metrics
    local tokens = self.look.title_bar
    local palette = Looks.palette(self.look, built.state.variant)
    paint_ground(self, bb, x, y, built.state.variant)
    for _, name in ipairs({ "count", "title" }) do
        built.lines[name]:paintTo(bb, x + boxes[name].x, y + boxes[name].y)
    end
    for name, fill in pairs({ sort = tokens.sort_fill_color, status = tokens.status_fill_color }) do
        local box = boxes[name]
        if fill then
            Paint.fill(bb, x + box.x, y + box.y, box.w, box.h, Looks.color(palette[fill]))
        end
        if m.outline > 0 then
            Paint.border(bb, x + box.x, y + box.y, box.w, box.h, m.outline,
                Looks.color(palette[tokens.picker_outline_color]))
        end
        built.lines[name]:paintTo(bb, x + box.x + m.outline + m.pad_x, y + box.y + m.outline + m.pad_y)
    end
    built.icon:paintTo(bb, x + boxes.icon.x, y + boxes.icon.y)
end

-- Places the bar as TitleBar:paintTo does (titlebar.lua:395-402), reads its state and rebuilds
-- when it changed, then paints. A read that raises keeps the last build, or, before any, paints
-- the fill and edge alone; a build or paint that raises is logged and leaves the rest unpainted.
function KoTitleBar:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    local read, state = pcall(self.state, self)
    if not read then
        self:logOnce("state read", state)
        state = nil
    end
    local painted, err = pcall(function()
        if state and not same_state(state, self.built and self.built.state) then
            self:build(state)
        end
        if self.built then
            self:paintBuilt(bb, x, y)
        else
            local ok, variant = pcall(Looks.variant)
            paint_ground(self, bb, x, y, ok and variant or "day")
        end
    end)
    if not painted then
        self:logOnce("paint", err)
    end
    if self.boxes then
        -- The title column's box on screen, in place, for the folder menu's anchor
        -- (frontend/apps/filemanager/filemanager.lua:1430-1437).
        local dimen, boxes = self.left_button.image.dimen, self.boxes
        dimen.x = x + boxes.title.x
        dimen.y = y
        dimen.w = math.max(boxes.count.w, boxes.title.w)
        dimen.h = boxes.title.y + boxes.title.h
    end
end

local function inside(rect, pos)
    return pos.x >= rect.x and pos.x < rect.x + rect.w and pos.y >= rect.y and pos.y < rect.y + rect.h
end

-- The area under pos: "title", "sort", "status" or "plus", or nil off the bar or before a build.
function KoTitleBar:areaAt(pos)
    if not (self.areas and inside(self.dimen, pos)) then
        return nil
    end
    local px = pos.x - self.dimen.x
    for _, name in ipairs({ "title", "sort", "status", "plus" }) do
        local area = self.areas[name]
        if px >= area.x and px < area.x + area.w then
            return name
        end
    end
    return nil
end

local function dispatch(bar, ges)
    local area = bar:areaAt(ges.pos)
    if ges.ges == "tap" then
        if area == "sort" then
            bar.on_sort()
        elseif area == "status" then
            bar.on_status()
        elseif area == "plus" then
            bar.right_icon_tap_callback()
        else
            return false
        end
        return true
    elseif ges.ges == "hold" then
        -- A new hold forgets one whose release went elsewhere, as IconButton does (iconbutton.lua:146-150).
        bar.hold_taken = false
        if area ~= "title" then
            return false
        end
        bar.left_icon_hold_callback()
        bar.hold_taken = true
        return true
    elseif ges.ges == "hold_release" then
        -- The release of a hold the bar took is taken too, as IconButton pairs them
        -- (frontend/ui/widget/iconbutton.lua:146-170), so it reaches no MovableContainer.
        if bar.hold_taken then
            bar.hold_taken = false
            return true
        end
        return false
    end
    return false
end

-- Whether the bar consumes ges: a tap on a picker or the plus runs its callback; a hold on the
-- title column runs the folder menu's callback, and its release is taken with it. A tap on the
-- title, a hold elsewhere and anything off the bar pass on. A callback that raises is logged and
-- the gesture passes on.
function KoTitleBar:handle(ges)
    local ok, taken = pcall(dispatch, self, ges)
    if not ok then
        logger.err("KoPanda: the title bar's " .. tostring(ges.ges) .. " failed:", taken)
        return false
    end
    return taken
end

function KoTitleBar:getHeight()
    return self.titlebar_height
end

-- The bar keeps no title or subtitle: it reads its own at paint. Marked dirty as KOReader's are
-- (titlebar.lua:443-468), so the next paint reads the change.
function KoTitleBar:setTitle(_, no_refresh)
    if not no_refresh then
        UIManager:setDirty(self.show_parent, "ui", self.dimen)
    end
end

function KoTitleBar:setSubTitle(_, no_refresh)
    if not no_refresh then
        UIManager:setDirty(self.show_parent, "ui", self.dimen)
    end
end

-- KOReader's Home button is dropped, so there is no left icon to set.
function KoTitleBar:setLeftIcon() end

-- check in select mode, plus otherwise.
function KoTitleBar:setRightIcon(icon)
    self.right_icon = icon == "check" and "check" or "plus"
    UIManager:setDirty(self.show_parent, "ui", self.dimen)
end

-- No buttons for key navigation: it stays the chooser's.
function KoTitleBar:generateHorizontalLayout()
    return {}
end

function KoTitleBar:generateVerticalLayout()
    return {}
end

function KoTitleBar:free()
    free_build(self.built)
    self.built = nil
    OverlapGroup.free(self)
end

return KoTitleBar
