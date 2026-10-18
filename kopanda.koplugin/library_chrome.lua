-- The chrome the library's windows share (series-and-authors D1, "The chrome"): a full-screen
-- KoPanda window over the file manager (cover-grid "The window"), its show and close, its paint
-- and settled signal, the header frame, the pager and the nav bar in its band, the gesture route
-- (cover-grid "Gestures") and the events that keep it current. A window module extends
-- LibraryChrome.Window and supplies what is its own (library.lua):
--   screen, its name in the settled signal and the log; fields, the keys of its build it keeps;
--   build(view, page), a LibraryChrome.build of view at page; view(), the view it shows;
--   action_at(pos), the action a tap on its own parts runs, or nil; back(), the back control's tap;
--   hit(x, y), what lies at a point on the window of its class shown, which a hold's sheet is for;
--   on_open(view, page), run as Window:open's book open goes ahead; refresh(), its re-list;
--   request_covers(), after a page's first paint; downloaded(record), once cwngsync downloaded that
--   book over its placeholder (default: the re-list, every record's cover asked for again);
--   closing(), its part of the close. A window listing the whole library asks for its covers
--   through LibraryChrome.request_records.
-- Module state: LibraryChrome.shown, the window on screen or nil. A window's class mirrors it in a
-- slot of the same name (Library.shown) while the window shown is one of its own.
-- LibraryChrome.return_to, { screen = "series" | "authors", view, page } a book was opened from the
-- Series or Authors window (series-and-authors D7), which the next file manager's show returns to,
-- or nil, in memory only; the library records its own (Library.return_to).
local BD = require("ui/bidi")
local BookCovers = require("book_covers")
local Books = require("books")
local Device = require("device")
local FeaturedCover = require("featured_cover")
local Geom = require("ui/geometry")
local Home = require("home")
local HomeGestures = require("home_gestures")
local Icons = require("icons")
local InputContainer = require("ui/widget/container/inputcontainer")
local LibrarySheets = require("library_sheets")
local LibraryTiles = require("library_tiles")
local Looks = require("looks")
local NavBar = require("nav_bar")
local Paint = require("paint")
local PaintClock = require("paint_clock")
local Sheet = require("sheet")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local logger = require("logger")
local time = require("ui/time")
local Screen = Device.screen

local LibraryChrome = {}

LibraryChrome.shown = nil
LibraryChrome.return_to = nil

-- Whether pos lies in rect, its right and bottom edges outside, as the nav bar tests its columns.
function LibraryChrome.inside(rect, pos)
    return pos.x >= rect.x and pos.x < rect.x + rect.w and pos.y >= rect.y and pos.y < rect.y + rect.h
end

-- A filled rectangle of its dimen in color.
local Fill = Widget:extend{
    name = "kopanda_library_fill",
    color = nil,
}

function Fill:paintTo(bb, x, y)
    Paint.fill(bb, x, y, self.dimen.w, self.dimen.h, self.color)
end

-- A box w by h in fill (a colour or nil) with an outline wide in outline_color, its children
-- painted at their places.
function LibraryChrome.box(w, h, fill, outline, outline_color)
    return FeaturedCover.Box:new{
        dimen = Geom:new{ w = w, h = h },
        box_w = w,
        box_h = h,
        fill_color = fill,
        outline = outline or 0,
        outline_color = outline_color,
        places = {},
    }
end

-- Adds child to box at (x, y) from its top left; returns its index.
function LibraryChrome.add(box, child, x, y)
    box[#box + 1] = child
    box.places[#box] = { x = x, y = y }
    return #box
end

local new_box, add = LibraryChrome.box, LibraryChrome.add

-- The tools a build draws with under ctx: lengths scaled, roles as colours (nil for a role the
-- look lacks), and a part's line height, which is its face's whatever the text
-- (frontend/ui/widget/textwidget.lua:112-113).
function LibraryChrome.tools(ctx)
    local palette = Looks.palette(ctx.look, ctx.variant)
    local function scale(px)
        return Screen:scaleBySize(px)
    end
    local function color(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
    local function line_height(part)
        local line = Typeset.line(part, "Library", math.huge, ctx)
        local h = line:getSize().h
        line:free()
        return h
    end
    return scale, color, line_height
end

local tools = LibraryChrome.tools

-- The detail header's back control under ctx: its outline and its height, the taller of its icon
-- and its label inside its padding and outline (SeriesBooksC.dc.html:20-21, AuthorBooksA.dc.html:20-21).
local function back_metrics(ctx)
    local scale, _, line_height = tools(ctx)
    local back = ctx.look.shelf.back
    local outline = scale(back.outline_width)
    return outline, math.max(scale(back.icon_size), line_height(ctx.look.type.shelf_back))
        + 2 * (scale(back.padding.y) + outline)
end

-- The one-series and one-author header's height under ctx: the detail padding, the back control,
-- the back gap, the count over the detail title at the header's line gap, and the edge.
function LibraryChrome.detail_header_height(ctx)
    local scale, _, line_height = tools(ctx)
    local look = ctx.look
    local detail, header = look.shelf.detail, look.library.header
    local _, back_h = back_metrics(ctx)
    return scale(detail.padding.top) + back_h + scale(detail.back_gap) + line_height(look.type.library_count)
        + scale(header.line_gap) + line_height(look.type.shelf_detail_title) + scale(detail.padding.bottom)
        + scale(header.edge_width)
end

-- The detail header's back control to text: the back icon and text in shelf_back inside shelf.back's
-- padding and outline on its fill, a chip in Diner, a plain link in Editorial. Returns it and its label.
local function back_control(ctx, text)
    local scale, color = tools(ctx)
    local look = ctx.look
    local back, part = look.shelf.back, look.type.shelf_back
    local outline, h = back_metrics(ctx)
    local label = Typeset.line(part, text, Screen:getWidth(), ctx)
    local icon = TintedIcon:new{ file = Icons.path("back"), size = scale(back.icon_size), color = color(part.color) }
    local icon_x = outline + scale(back.padding.left)
    local label_x = icon_x + icon.size + scale(back.gap)
    local box = new_box(label_x + label:getSize().w + scale(back.padding.right) + outline, h, color(back.fill_color),
        outline, color(look.library.header.picker_outline_color))
    add(box, icon, icon_x, math.floor((h - icon.size) / 2))
    add(box, label, label_x, math.floor((h - label:getSize().h) / 2))
    return box, label
end

-- The header frame under ctx, w wide and spec.height tall (Main.dc.html:19-27, GridA.dc.html:19-27):
-- the band in spec.band's colour; the right-hand slot, spec.right's widgets laid right to left
-- from the side padding the picker gap apart; the left column, spec.aside over spec.title (each
-- { part, text }) with the back mark before the title when spec.back; all resting on the padding's
-- bottom, then the edge. With spec.back_label, the detail header (SeriesBooksC.dc.html:19-30,
-- AuthorBooksA.dc.html:19-28) in the detail padding, LibraryChrome.detail_header_height tall: the back
-- control on its own row at the top, labelled spec.back_label. Returns the header and its parts:
-- rect, aside, title, back (nil without spec.back), back_place, title_place, title_rect (the back
-- control, nil without spec.back), back_rect and back_label (the detail back control and its label,
-- nil without spec.back_label) and right (each widget's rect, in spec.right's order).
function LibraryChrome.header(ctx, w, spec)
    local scale, color, line_height = tools(ctx)
    local tokens = ctx.look.library.header
    local padding = spec.back_label and ctx.look.shelf.detail.padding or tokens.padding
    local h = spec.height
    local box = new_box(w, h, color(spec.band))
    local parts = { rect = Geom:new{ x = 0, y = 0, w = w, h = h }, right = {} }
    local side, gap = scale(padding.side), scale(tokens.picker_gap)
    local edge = scale(tokens.edge_width)
    local bottom = h - edge - scale(padding.bottom)
    if spec.back_label then
        local control
        control, parts.back_label = back_control(ctx, spec.back_label)
        local size = control:getSize()
        parts.back_rect = Geom:new{ x = side, y = scale(padding.top), w = size.w, h = size.h }
        add(box, control, side, parts.back_rect.y)
    end
    local x = w - side
    for i, widget in ipairs(spec.right) do
        local size = widget:getSize()
        parts.right[i] = Geom:new{ x = x - size.w, y = bottom - size.h, w = size.w, h = size.h }
        x = parts.right[i].x - gap
    end
    for i = #spec.right, 1, -1 do
        add(box, spec.right[i], parts.right[i].x, parts.right[i].y)
    end
    local column_w = math.max(1, x - side)
    local aside = Typeset.line(spec.aside.part, spec.aside.text, column_w, ctx)
    local title_h = line_height(spec.title.part)
    local aside_h = aside:getSize().h
    local top = bottom - (aside_h + scale(tokens.line_gap) + title_h)
    add(box, aside, side, top)
    parts.aside = aside
    local title_y = top + aside_h + scale(tokens.line_gap)
    local title_x = side
    if spec.back then
        -- Sized to the title's line, as LibraryTiles.header_height counts it.
        parts.back = TintedIcon:new{ file = Icons.path("back"), size = title_h, color = color(spec.title.part.color) }
        parts.back_place = { x = side, y = title_y }
        add(box, parts.back, side, title_y)
        title_x = side + title_h
    end
    parts.title = Typeset.line(spec.title.part, spec.title.text, math.max(1, column_w - (title_x - side)), ctx)
    parts.title_place = { x = title_x, y = title_y }
    add(box, parts.title, title_x, title_y)
    if parts.back then
        parts.title_rect = Geom:new{ x = side, y = title_y, w = title_x - side + parts.title:getSize().w, h = title_h }
    end
    local edge_color = color(tokens.edge_color)
    if edge > 0 and edge_color then
        add(box, Fill:new{ dimen = Geom:new{ w = w, h = edge }, color = edge_color }, 0, h - edge)
    end
    return box, parts
end

-- One pager button, which ("prev" or "next"): its box in the pager's fill and outline and, when
-- live, its arrow in the look's arrow colour for it, or when dead, in dead_color, or none where the
-- look has no dead colour (cover-grid D16). Returns the box and { live, arrow }.
local function button(which, live, arrow_size, ctx)
    local scale, color = tools(ctx)
    local tokens = ctx.look.library.pager
    local w, h = scale(tokens.button_w), scale(tokens.button_h)
    local outline_color = color(tokens.outline_color)
    local box = new_box(w, h, color(tokens[which .. "_fill_color"]),
        outline_color and scale(tokens.outline_width) or 0, outline_color)
    local arrow_color = color(live and tokens[which .. "_icon_color"] or tokens.dead_color)
    local parts = { live = live }
    if arrow_color then
        parts.arrow = TintedIcon:new{ file = Icons.path(which == "prev" and "back" or "forward"), size = arrow_size,
            color = arrow_color }
        add(box, parts.arrow, math.floor((w - arrow_size) / 2), math.floor((h - arrow_size) / 2))
    end
    return box, parts
end

-- The pager, centred across w with its foot bottom above y (Main.dc.html:85-88, GridA.dc.html:85-88):
-- the previous button, the page label, the next button, each centred in the pager's band. The
-- arrows are the label's line tall. Adds them to frame and returns { prev, next, label }, each
-- button with its rect.
local function pager(built, frame, w, y)
    local ctx = built.ctx
    local scale = tools(ctx)
    local look = ctx.look
    local tokens = look.library.pager
    local height = LibraryTiles.pager_height(ctx)
    local band = height - scale(tokens.bottom)
    local top = y - height
    local text = tokens.label_in_words and ("Page %d of %d"):format(built.page, built.pages)
        or ("%d / %d"):format(built.page, built.pages)
    local label = Typeset.line(look.type.pager_label, text, w, ctx)
    local label_size = label:getSize()
    local prev_box, prev = button("prev", built.page > 1, label_size.h, ctx)
    local next_box, next = button("next", built.page < built.pages, label_size.h, ctx)
    local bw, bh = prev_box:getSize().w, prev_box:getSize().h
    local gap = scale(tokens.gap)
    local x = math.floor((w - (2 * bw + 2 * gap + label_size.w)) / 2)
    local by = top + math.floor((band - bh) / 2)
    prev.rect = Geom:new{ x = x, y = by, w = bw, h = bh }
    next.rect = Geom:new{ x = x + bw + gap + label_size.w + gap, y = by, w = bw, h = bh }
    add(frame, prev_box, prev.rect.x, by)
    add(frame, label, x + bw + gap, top + math.floor((band - label_size.h) / 2))
    add(frame, next_box, next.rect.x, by)
    return { prev = prev, next = next, label = label }
end

-- The foot of built: the nav bar for where ("library": Library active) at the bottom in its band,
-- and the pager above it from built.page and built.pages, which the window sets first. Adds the
-- pager to frame (the build adds the bar last) and sets built.nav and built.pager.
function LibraryChrome.foot(built, frame, where)
    local w, h = built.dimen.w, built.dimen.h
    local ctx = built.ctx
    local nav = NavBar.new{ look = ctx.look, variant = ctx.variant, width = w, where = where, listen = false }
    nav.dimen.x, nav.dimen.y = 0, h - nav.dimen.h
    built.nav = nav
    built.pager = pager(built, frame, w, nav.dimen.y)
end

-- Fills built (the window's view and page) at the screen's size in the active look and variant:
-- dimen, ctx and frame, the paper, then fill(built, frame, w, h), which adds the window's header
-- and page and calls LibraryChrome.foot, then the nav bar. Returns built; a failure frees what was
-- built and raises.
function LibraryChrome.build(built, fill)
    local size = Screen:getSize()
    built.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    built.ctx = { look = Looks.active(), variant = Looks.variant(), screen = Screen }
    built.frame = new_box(size.w, size.h)
    local ok, err = pcall(function()
        local _, color = tools(built.ctx)
        built.frame.fill_color = color("paper")
        fill(built, built.frame, size.w, size.h)
        add(built.frame, built.nav, 0, built.nav.dimen.y)
    end)
    if not ok then
        built.frame:free()
        error(err, 0)
    end
    return built
end

-- Sets LibraryChrome[slot] ("shown") to window or nil, and the same slot of the class of the window
-- it names, so the class slot names only one of its own.
local function hold(slot, window)
    local old = LibraryChrome[slot]
    if old then
        getmetatable(old)[slot] = nil
    end
    LibraryChrome[slot] = window
    if window then
        getmetatable(window)[slot] = window
    end
end

local Window = InputContainer:extend{
    name = "kopanda_library_window",
    -- UIManager:_repaint skips paintTo beneath the topmost such widget.
    covers_fullscreen = true,
    screen = "window",
    fields = {},
    page = nil,
}
LibraryChrome.Window = Window

local FIELDS = { "page", "pages", "dimen", "ctx", "header", "pager", "nav" }

-- Puts built in place of what the window showed, and frees that.
local function apply(window, built)
    local old = window[1]
    window[1] = built.frame
    for _, list in ipairs({ FIELDS, window.fields }) do
        for _, field in ipairs(list) do
            window[field] = built[field]
        end
    end
    if old then
        old:free()
    end
end

local function close_window(window)
    if LibraryChrome.shown == window then
        hold("shown", nil)
    end
    local ok, err = pcall(UIManager.close, UIManager, window, "full")
    if not ok then
        logger.err("KoPanda: could not close the " .. window.screen .. ":", err)
    end
end

-- As the home's (home_gestures.lua): the window's own steps are touch zones on it, matched through
-- InputContainer.onGesture, so KOReader's touch lock filters them
-- (frontend/ui/widget/container/inputcontainer.lua:297-350). A zone's handler only names its step,
-- which route runs in its place in the order.
local FULL_SCREEN = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 }

local function own_zones(window)
    local zones = {}
    for _, ges in ipairs({ "tap", "hold", "swipe" }) do
        zones[#zones + 1] = {
            id = "kopanda_library_" .. ges,
            ges = ges,
            screen_zone = FULL_SCREEN,
            handler = function()
                window.own_step = ges
                return true
            end,
        }
    end
    return zones
end

function Window:init()
    self.dimen = Screen:getSize()
    self:registerTouchZones(own_zones(self))
    -- As Menu registers its page keys (frontend/ui/widget/menu.lua:984-992).
    if Device:hasKeys() then
        self.key_events.NextPage = { { Device.input.group.PgFwd } }
        self.key_events.PrevPage = { { Device.input.group.PgBack } }
    end
    apply(self, self:build(self:view(), self.page))
    self.covers_due = true
end

-- Builds view at page in place and repaints. A failure is logged and leaves the page as it was.
-- Returns whether it built.
local function rebuild(window, view, page)
    local ok, built = pcall(window.build, window, view, page)
    if not ok then
        logger.err("KoPanda: could not build the " .. window.screen .. " at", view, "page", page, ":", built)
        return false
    end
    apply(window, built)
    UIManager:setDirty(window, "ui")
    return true
end

-- Shows view at page (clamped to its pages) in place, its covers asked for after its first paint.
-- A failure is logged and leaves the page as it was.
function Window:go(view, page)
    if not rebuild(self, view, page) then
        return
    end
    self.covers_due = true
end

-- An arrival of records for window (LibraryChrome.request_records), while alive.
local function arrive(window, arrived, alive)
    if not alive() then
        return
    end
    local ok, err = pcall(function()
        local fresh, drawn = {}, false
        for _, record in ipairs(arrived) do
            fresh[record.id] = Books.get(record.id) or record
            drawn = drawn or window.drawn[record.id] or false
        end
        local records = {}
        for i, record in ipairs(window.records) do
            records[i] = fresh[record.id] or record
        end
        window.records = records
        local keys = window:page_keys(window:view(), window.page)
        if drawn or table.concat(keys, "\0") ~= table.concat(window.keys, "\0") then
            rebuild(window, window:view(), window.page)
        end
    end)
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s cover arrival failed:", err)
    end
end

-- Asks once per window, while it is the one shown, for the covers of every one of window.records at
-- the library grid's cover box, the largest these windows and the library draw (series-and-authors
-- D2, "Extraction"). An arrival re-reads each arrived record (Books.get) in window.records, then
-- rebuilds the view in place, and so repaints, only when the page shown changes: when
-- window:page_keys(view, page), the keys of its items in order under window.records now, differ from
-- window.keys, the build's, or the page draws an arrived record (a key of window.drawn). A failure is
-- logged with the page as it was.
function LibraryChrome.request_records(window)
    if window.records_asked or LibraryChrome.shown ~= window then
        return
    end
    window.records_asked = true
    local function alive()
        return LibraryChrome.shown == window
    end
    local ok, err = pcall(function()
        local box = LibraryTiles.geometry(window.dimen.w, window.ctx)
        BookCovers.request(window.records, { max_cover_w = box.cover_w, max_cover_h = box.cover_h },
            function(arrived)
                arrive(window, arrived, alive)
            end,
            alive)
    end)
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s cover request failed:", err)
    end
end

-- The page delta pages on, unless that is past the first or the last (no wrap).
function Window:turn(delta)
    local page = self.page + delta
    if page >= 1 and page <= self.pages then
        self:go(self:view(), page)
    end
end

-- The action a tap at pos runs, or nil where no part of the window acts on taps: its own parts
-- (window:action_at); the back control runs window:back(); a live pager arrow turns the page.
local function action_at(window, pos)
    local own = window:action_at(pos)
    if own then
        return own
    end
    local top, foot = window.header, window.pager
    local back = top.back_rect or top.title_rect
    if back and LibraryChrome.inside(back, pos) then
        return function()
            window:back()
        end
    end
    for delta, which in pairs({ [-1] = "prev", [1] = "next" }) do
        if foot[which].live and LibraryChrome.inside(foot[which].rect, pos) then
            return function()
                window:turn(delta)
            end
        end
    end
    return nil
end

-- Whether a tap at pos is the window's: one on a part that acts on taps runs its action, a
-- raising one logged with the page left as it was.
function Window:tap(pos)
    local action = action_at(self, pos)
    if not action then
        return false
    end
    local ok, err = pcall(action)
    if not ok then
        logger.err("KoPanda: the " .. self.screen .. "'s tap failed:", err)
    end
    return true
end

-- Opens record's file as the file browser's own tap does (cover-grid D15; filemanager.lua:160-169),
-- which asks first when the owner set "ask before opening", running the window's on_open with the
-- view and page it shows once the open goes ahead (filemanagerutil.lua:498-502). Without a file
-- manager it opens nothing.
function Window:open(record)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if not fm then
        return
    end
    local view, page = self:view(), self.page
    require("apps/filemanager/filemanagerutil").openFile(fm, record.path, function()
        self.on_open(view, page)
    end)
end

-- Signals the window's first paint on the dev loop's settled hook, once per show, as the home's
-- (home.lua:156-200); paint_ms runs from opts.started to that paint. A window whose paint failed
-- sends none.
local function settle(window, opts)
    if window.paint_failed then
        return
    end
    local ok, err = pcall(UIManager.event_hook.execute, UIManager.event_hook, "KoPandaSettled", {
        screen = window.screen,
        paint_ms = time.to_ms((window.painted_at or time.monotonic()) - opts.started),
    })
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s settled signal failed:", err)
    end
end

-- Shows a window of cls, built now as cls:new(fields). opts.started is time.monotonic() at the start
-- of the show path, which paint_ms runs from (default: now), so paint_ms includes the build. Closes
-- the home and the window shown, then shows this one and returns it. On any error it is taken off
-- the stack and nil returned, logged, the screen beneath left as it is.
function LibraryChrome.show(cls, opts, fields)
    local started = opts.started or time.monotonic()
    local window
    local ok, err = pcall(function()
        Home.close()
        LibraryChrome.close()
        window = cls:new(fields)
        hold("shown", window)
        UIManager:show(window, "full")
        window.settle_opts = { started = started }
    end)
    if ok then
        return window
    end
    logger.err("KoPanda: could not show the " .. cls.screen .. ":", err)
    if window and UIManager:isWidgetShown(window) then
        close_window(window)
    end
    hold("shown", nil)
    return nil
end

-- Closes the window shown, if any.
function LibraryChrome.close()
    if LibraryChrome.shown then
        close_window(LibraryChrome.shown)
    end
end

-- Paints the window, rebuilt first when the variant or the screen's size changed since its build
-- (night mode marks every window dirty, frontend/device/devicelistener.lua:14-27; a rotation), as
-- the editor does (editor.lua:360-369), with no repaint of its own.
local function paint(window, bb, x, y)
    local size = Screen:getSize()
    if window.ctx.variant ~= Looks.variant() or size.w ~= window.dimen.w or size.h ~= window.dimen.h then
        apply(window, window:build(window:view(), window.page))
    end
    InputContainer.paintTo(window, bb, x, y)
end

-- A widget can't be closed from inside the repaint, so a failed paint closes the window from the
-- next tick, leaving the file browser beneath. A page's covers are asked for, and a show settles,
-- from the next tick after its first paint.
function Window:paintTo(bb, x, y)
    local ok, err = pcall(paint, self, bb, x, y)
    if ok and not self.painted_at then
        self.painted_at = time.monotonic()
    end
    if not ok and not self.paint_failed then
        self.paint_failed = true
        logger.err("KoPanda: the " .. self.screen .. " failed to paint:", err)
        UIManager:nextTick(function()
            close_window(self)
        end)
    end
    if ok and self.covers_due then
        self.covers_due = nil
        UIManager:nextTick(function()
            self:request_covers()
        end)
    end
    local opts = self.settle_opts
    if opts then
        self.settle_opts = nil
        UIManager:nextTick(function()
            settle(self, opts)
        end)
    end
end

function Window:request_covers() end

function Window:closing() end

-- Re-lists the view and rebuilds the page shown, its page clamped if items went. A failure is
-- logged and leaves the page as it was.
function Window:refresh()
    if LibraryChrome.shown == self then
        rebuild(self, self:view(), self.page)
    end
end

-- After cwngsync downloaded _record's book over its placeholder (cwng-placeholders D17): the view
-- re-listed (window:refresh()), then every one of window.records' covers asked for again after the
-- paint (LibraryChrome.request_records), the once-per-window mark dropped. BookCovers asks only for
-- a file not asked in this process whose row wants a cover, so on a page of cached covers that is
-- the downloaded book alone, its cover just forgotten. The re-list stands for the one cwngsync's
-- broadcasts left due (refresh_soon), which is dropped. Nothing while the window isn't the one
-- shown.
function Window:downloaded(_record)
    if LibraryChrome.shown ~= self then
        return
    end
    self:refresh()
    self.stale = nil
    self.records_asked = nil
    self.covers_due = true
end

-- Marks the window stale and refreshes it once from the next tick, however many events marked it
-- before: one change broadcasts InvalidateMetadataCache and BookMetadataChanged, and a second
-- BookMetadataChanged when the summary changed too (filemanagerbookinfo.lua:276-280, :556-557). The
-- book-info page broadcasts from its close callback after UIManager:close
-- (frontend/ui/widget/keyvaluepage.lua:841-846), inside the input dispatch at the end of
-- handleInput (frontend/ui/uimanager.lua:1607-1620), so the tick runs at the next pass's
-- _checkTasks, before that pass's _repaint paints the close (:431-433, :1537-1564, :1663). A
-- window closed by then is not refreshed (refresh's check that it is the one shown).
local function refresh_soon(window)
    if window.stale then
        return
    end
    window.stale = true
    UIManager:nextTick(function()
        if window.stale then
            window.stale = nil
            window:refresh()
        end
    end)
end

-- Broadcast to every window when a book's metadata or status changes and when its cached
-- metadata is dropped (frontend/apps/filemanager/filemanagerbookinfo.lua:276-277, :556-557;
-- frontend/ui/uimanager.lua:1042-1061). Return nothing, so the event reaches the other windows.
function Window:onBookMetadataChanged()
    refresh_soon(self)
end

function Window:onInvalidateMetadataCache()
    refresh_soon(self)
end

-- The page keys registered at init.
function Window:onNextPage()
    self:turn(1)
    return true
end

function Window:onPrevPage()
    self:turn(-1)
    return true
end

-- KOReader may close the window itself; LibraryChrome.shown must not outlive it, nor its cover
-- check, nor a sheet shown over it, as the home closes its own (home.lua:322-339). Then the
-- window's own part (closing), and its frame freed.
function Window:onCloseWidget()
    if LibraryChrome.shown == self then
        hold("shown", nil)
    end
    self.settle_opts = nil
    local sheet_ok, sheet_err = pcall(Sheet.close)
    if not sheet_ok then
        logger.err("KoPanda: could not close the sheet over the " .. self.screen .. ":", sheet_err)
    end
    local ok, err = pcall(BookCovers.cancel)
    if not ok then
        logger.err("KoPanda: could not drop the " .. self.screen .. "'s cover check:", err)
    end
    self:closing()
    local frame = self[1]
    self[1] = nil
    if frame then
        local free_ok, free_err = pcall(frame.free, frame)
        if not free_ok then
            logger.err("KoPanda: could not free the " .. self.screen .. ":", free_err)
        end
    end
end

-- The hold step (context-menu "Holds"): what lies at pos (window.hit) handed to LibrarySheets.hold,
-- which opens its sheet over the window, paint_ms from this step's entry. A hit or dispatch that
-- raises is logged and the hold consumed, the window left as it was.
local function hold_step(window, pos)
    local started = PaintClock.now()
    local ok, err = pcall(function()
        local hit = window.hit and window.hit(pos.x, pos.y)
        LibrarySheets.hold(window, hit, started)
    end)
    if not ok then
        logger.err("KoPanda: the " .. window.screen .. "'s hold failed:", err)
    end
    return true
end

-- The window's gestures, in order, each step stopping at the first that consumes: a tap or a hold
-- in the nav bar's band, which the bar takes; a tap on a part of the window that acts on taps
-- (window:tap); a west or east swipe outside the top and bottom edge bands turns the page,
-- mirrored as Menu:onSwipe reads it (frontend/ui/widget/menu.lua:1518-1523); then the home's
-- forward step (HomeGestures.forward), so the top menu, Gestures' corner zones and its edge-band
-- swipes still work, and a hold corner bound on the file manager wins over the hold, as on the home
-- (home_gestures.lua); then a hold runs the hold step. Whatever none of them takes is consumed.
function Window:routeGesture(ges)
    self.own_step = nil
    InputContainer.onGesture(self, ges)
    local own_step = self.own_step
    self.own_step = nil
    if (own_step == "tap" or own_step == "hold") and self.nav and self.nav:handle(ges) then
        return true
    end
    if own_step == "tap" and self:tap(ges.pos) then
        return true
    end
    if own_step == "swipe" and HomeGestures.is_page_swipe(ges) then
        self:turn(BD.flipDirectionIfMirroredUILayout(ges.direction) == "west" and 1 or -1)
        return true
    end
    if HomeGestures.forward(ges) then
        return true
    end
    if own_step == "hold" then
        return hold_step(self, ges.pos)
    end
    return true
end

-- A window is not a plugin, so KOReader does not sandbox this handler: an error here would reach
-- the UI loop. A failure closes the window onto the file browser and consumes the gesture.
function Window:onGesture(ges)
    local ok, consumed = pcall(self.routeGesture, self, ges)
    if ok then
        return consumed
    end
    logger.err("KoPanda: the " .. self.screen .. " failed to handle a gesture:", consumed)
    close_window(self)
    return true
end

return LibraryChrome
