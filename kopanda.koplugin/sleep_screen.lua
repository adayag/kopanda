-- The sleep screen: the book's cover filling the screen with one card of its reading state, the streak and forecast
-- tiles above the book's lines, one bitmap handed to KOReader as a cover, so Screensaver:show keeps rotation, flashing,
-- the lock and closing. Wraps Screensaver.setup (frontend/ui/screensaver.lua:346), which runs before :show on every
-- sleep; the rest is cited where it's read.
local Device = require("device")
local DeviceStats = require("device_stats")
local Featured = require("widgets/featured")
local FeaturedBook = require("featured_book")
local Forecast = require("widgets/forecast")
local Helpers = require("helpers")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Looks = require("looks")
local Paint = require("paint")
local QuickSettings = require("quick_settings")
local ReadingStats = require("reading_stats")
local Screensaver = require("ui/screensaver")
local Settings = require("settings")
local Streak = require("widgets/streak")
local Typeset = require("typeset")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Wallpaper = require("wallpaper")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Screen = Device.screen

local SleepScreen = {}

local JOIN = " · "
local TITLE_LINES = 2
local MINUTE = 60
local CHAPTER_WORD = "chapter "
-- After "Chapter <word>": a hyphen or a full stop only with a space after it, so "Twenty-One" and "1.5" stay words.
local SEPARATORS = { ":%s*", "%.%s+", "%-%s+", "\u{2014}%s*", "\u{2013}%s*" }
-- A character other than punctuation, a space or a dash: the bytes of U+2013 and U+2014 are excluded one by one.
local WORDY = "[^%p%s\226\128\147\148]"

local installed = false

-- title without a leading "Chapter <word><separator>", or title as it is when nothing would follow that.
function SleepScreen.clean_chapter(title)
    if title:sub(1, #CHAPTER_WORD):lower() == CHAPTER_WORD then
        local rest = title:sub(#CHAPTER_WORD + 1)
        for _, separator in ipairs(SEPARATORS) do
            local clean = rest:match("^[%w%-]+%s*" .. separator .. "(%S.*)$")
            if clean and clean:find(WORDY) then
                return clean
            end
        end
    end
    return title
end

-- book's authors and series, its number after a "#", or nil with neither.
function SleepScreen.byline(book)
    local series = book.series
    if series and book.series_index then
        series = series .. " #" .. book.series_index
    end
    if book.authors and series then
        return book.authors .. JOIN .. series
    end
    return book.authors or series
end

-- book's clean chapter title and the time left in it, either alone, or nil with neither.
function SleepScreen.chapter_line(book)
    local title = book.chapter and SleepScreen.clean_chapter(book.chapter)
    local left = book.chapter_seconds and Helpers.duration(math.max(MINUTE, book.chapter_seconds)) .. " left in chapter"
    if title and left then
        return title .. JOIN .. left
    end
    return title or left or nil
end

-- Today's reading in words, or nil with no pages read.
function SleepScreen.today(seconds, pages)
    if pages == 0 then
        return nil
    end
    return "Today " .. pages .. (pages == 1 and " page" or " pages") .. JOIN
        .. Helpers.duration(math.max(MINUTE, seconds))
end

-- The battery at percent, with the time totals (DeviceStats.battery_totals') work out unless charging; nil with no
-- percent.
function SleepScreen.battery(percent, charging, totals)
    if not percent then
        return nil
    end
    local left = not charging and DeviceStats.time_left(percent, totals)
    if left then
        return percent .. "%" .. JOIN .. DeviceStats.left_text(left)
    end
    return percent .. "%"
end

-- The card's foot, inner_w wide: book.today at the left and book.battery at the right, the battery measured first and
-- today dropped rather than cut in the room left; nil with neither.
function SleepScreen.foot(book, inner_w, ctx)
    local part = ctx.look.type.featured_caption
    local battery = book.battery and Typeset.line(part, book.battery, inner_w, ctx)
    local battery_w = battery and battery:getSize().w or 0
    local today
    if book.today then
        local gap = battery and Paint.scaler(ctx)(ctx.look.sleep.tile_gap) or 0
        today = Typeset.line(part, book.today, math.max(1, inner_w - battery_w - gap), ctx)
        if not Typeset.whole(today) then
            today:free()
            today = nil
        end
    end
    if not (today or battery) then
        return nil
    end
    local foot = HorizontalGroup:new{ align = "top" }
    foot[1] = today
    foot[#foot + 1] = HorizontalSpan:new{ width = inner_w - battery_w - (today and today:getSize().w or 0) }
    foot[#foot + 1] = battery
    return foot
end

-- Fills group, a left-aligned VerticalGroup, with the card's lines for book, each dropping alone with nothing to show.
local function fill_lines(group, book, inner_w, ctx)
    local look, scale = ctx.look, Paint.scaler(ctx)
    local gap = VerticalSpan:new{ width = scale(look.sleep.gap) }
    local function add(widget)
        group[#group + 1] = gap
        group[#group + 1] = widget
    end
    group[1] = Featured.text_box("featured_title", book.title, inner_w, TITLE_LINES, ctx)
    local byline = SleepScreen.byline(book)
    if byline then
        add(Typeset.line(look.type.featured_authors, byline, inner_w, ctx))
    end
    local chapter = SleepScreen.chapter_line(book)
    if chapter then
        add(Typeset.line(look.type.featured_chapter, chapter, inner_w, ctx))
    end
    add(Featured.bar(Featured.shown_percent(book), inner_w, scale(look.progress.height),
        look.progress.outline_width, ctx))
    add(Typeset.line(look.type.featured_caption, table.concat(Featured.caption(book), JOIN), inner_w, ctx))
    local foot = SleepScreen.foot(book, inner_w, ctx)
    if foot then
        add(foot)
    end
end

-- Fills tiles, a HorizontalGroup, with the streak and forecast at half of inner_w and one height, when there is a
-- reading history to show.
local function fill_tiles(tiles, inner_w, ctx)
    if ReadingStats.insights(ctx.now).state ~= "ok" then
        return
    end
    local gap = Paint.scaler(ctx)(ctx.look.sleep.tile_gap)
    local tile_w = math.floor((inner_w - gap) / 2)
    tiles[1] = Streak.build(tile_w, ctx)
    tiles[2] = HorizontalSpan:new{ width = gap }
    tiles[3] = Forecast.build(tile_w, ctx)
    local h = math.max(tiles[1]:getSize().h, tiles[3]:getSize().h)
    tiles[1].dimen.h, tiles[3].dimen.h = h, h
end

-- Fills text and tiles for book and paints the card along the bottom of a w by h bitmap; tiles that would take the
-- card's top past the middle of h stay out, so the cover keeps half the screen.
local function draw_card(bb, book, w, h, ctx, text, tiles)
    local tokens, scale, color = ctx.look.sleep, Paint.scaler(ctx), Looks.colorer(ctx)
    local margin = scale(tokens.margin)
    local pad_x, pad_y = scale(tokens.padding.x), scale(tokens.padding.y)
    local card_w = w - 2 * margin
    local inner_w = card_w - 2 * pad_x
    fill_lines(text, book, inner_w, ctx)
    fill_tiles(tiles, inner_w, ctx)
    local text_h = text:getSize().h
    local card_h = text_h + 2 * pad_y
    local tiles_h = 0
    if #tiles > 0 then
        local with_tiles = tiles:getSize().h + scale(tokens.gap)
        if 2 * (card_h + with_tiles + margin) <= h then
            tiles_h = with_tiles
            card_h = card_h + with_tiles
        end
    end
    local x, y, radius = margin, h - margin - card_h, scale(tokens.radius)
    Paint.fill(bb, x, y, card_w, card_h, color(tokens.fill_color), radius)
    local outline = color(tokens.outline_color)
    if outline then
        Paint.border(bb, x, y, card_w, card_h, scale(tokens.outline_width), outline, radius)
    end
    if tiles_h > 0 then
        tiles:paintTo(bb, x + pad_x, y + pad_y)
    end
    text:paintTo(bb, x + pad_x, y + pad_y + tiles_h)
end

-- Paints book's card, in ctx's look, freeing every widget it built whether or not it draws.
local function paint_card(bb, book, w, h, ctx)
    local text = VerticalGroup:new{ align = "left" }
    local tiles = HorizontalGroup:new{ align = "top" }
    local ok, err = pcall(draw_card, bb, book, w, h, ctx, text, tiles)
    text:free()
    tiles:free()
    if not ok then
        error(err, 0)
    end
end

-- The sleep screen for book (FeaturedBook.for_file's, with chapter_seconds, today and battery, each may be nil), a new
-- w by h bitmap; consumes cover.
function SleepScreen.image(book, cover, w, h, ctx)
    local bb = Wallpaper.fill_box(cover, w, h, ctx.screen.bb:getType())
    local ok, err = pcall(function()
        -- KOReader's ImageWidget inverts a bitmap at night so it shows as drawn (frontend/ui/widget/imagewidget.lua:77,
        -- :591-593), while KoPanda paints for the panel's inversion: two inversions around the card leave the cover.
        local night = ctx.screen.night_mode
        if night then
            bb:invertRect(0, 0, w, h)
        end
        paint_card(bb, book, w, h, ctx)
        if night then
            bb:invertRect(0, 0, w, h)
        end
    end)
    if not ok then
        bb:free()
        error(err, 0)
    end
    return bb
end

-- The seconds left in the open book's chapter, or in the book in its last one, in screen pages as the footer counts
-- them (frontend/apps/reader/modules/readerfooter.lua:345), at Statistics' pace, as getTimeForPages takes it
-- (plugins/statistics.koplugin/main.lua:3026, where it can be nil or nan); nil with no pace or no pages left.
local function chapter_seconds(ui, page)
    local statistics = ui.statistics
    local pace = statistics and statistics.settings.is_enabled and statistics.avg_time
    if not (pace and pace > 0 and pace < math.huge) then
        return nil
    end
    local left = ui.toc:getChapterPagesLeft(page, true) or ui.document:getTotalPagesLeft(page)
    return left > 0 and left * pace or nil
end

-- The open book's own title, percent, chapter and, with a chapter title to set it beside, the time left in it, since a
-- first-opened book has no record and its sidecar can lag it (frontend/apps/reader/readerui.lua:495, :1007,
-- frontend/apps/reader/modules/readertoc.lua:446); nil outside a book.
local function live(ui)
    if not ui.document then
        return nil
    end
    local page, pages = ui:getCurrentPage(), ui.document:getPageCount()
    local chapter = ui.toc:getTocTitleByPage(page)
    return {
        title = ui.doc_props.display_title,
        percent = pages > 0 and page / pages or nil,
        chapter = chapter,
        chapter_seconds = chapter ~= "" and chapter_seconds(ui, page) or nil,
    }
end

-- Today's reading in words, from what Statistics has flushed (plugins/statistics.koplugin/main.lua:1452), which is
-- asked only with a reading history to find, and the session it hasn't (:69-70, :2606-2617), since the card draws
-- before the flush. A failed read is logged and reads as nil.
local function read_today(ui, now)
    local statistics = ui.statistics
    if not statistics or ReadingStats.insights(now).state ~= "ok" then
        return nil
    end
    local ok, today = pcall(function()
        local seconds, pages = statistics:getTodayBookStats()
        return SleepScreen.today(seconds + (statistics.mem_read_time or 0), pages + (statistics.mem_read_pages or 0))
    end)
    if not ok then
        logger.err("KoPanda: could not read today's reading:", today)
        return nil
    end
    return today
end

-- The battery in words, a failed charging read taken as charging, so it shows the percent alone. Any other failed read
-- is logged and reads as nil.
local function read_battery()
    local read, battery = pcall(function()
        local ok, charging = pcall(function()
            return Device:getPowerDevice():isCharging()
        end)
        return SleepScreen.battery(QuickSettings.battery(), not ok or charging, DeviceStats.battery_totals())
    end)
    if not read then
        logger.err("KoPanda: could not read the battery:", battery)
        return nil
    end
    return battery
end

-- The bitmap for the open or last book, or nil to leave KOReader's screen. Raises what a read or the draw raises.
-- A book is excluded as KOReader's menu asks it (frontend/ui/screensaver.lua:200).
local function build(ui)
    if not (ui and Settings.get("sleep.on")) or Screensaver.isExcluded(ui) then
        return nil
    end
    local file = ui.document and ui.document.file or G_reader_settings:readSetting("lastfile")
    if not (file and lfs.attributes(file, "mode") == "file") then
        return nil
    end
    local open = live(ui)
    local book = FeaturedBook.for_file(file, open)
    -- As Screensaver:setup reads a cover (frontend/ui/screensaver.lua:410).
    local cover = book and ui.bookinfo:getCoverImage(ui.document, file)
    if not cover then
        return nil
    end
    local now = os.time()
    book.chapter_seconds = open and open.chapter_seconds
    book.today, book.battery = read_today(ui, now), read_battery()
    -- Portrait, since Screensaver:show rotates after setup (frontend/ui/screensaver.lua:469-481).
    local w, h = Screen:getWidth(), Screen:getHeight()
    return SleepScreen.image(book, cover, math.min(w, h), math.max(w, h), {
        look = Looks.active(),
        variant = Looks.variant(),
        text_size = Settings.get("text_size"),
        now = now,
        screen = Screen,
        forecast_book = book,
    })
end

-- Wraps Screensaver.setup, once per process. KOReader's setup runs first, so its result stands on anything but a
-- finished image; poweroff and reboot pass an event and keep their own screens (frontend/ui/uimanager.lua:84, :109).
function SleepScreen.install()
    if installed then
        return
    end
    installed = true
    local original = Screensaver.setup
    Screensaver.setup = function(self, event, event_message)
        original(self, event, event_message)
        if event then
            return
        end
        local ok, image = pcall(build, self.ui)
        if not ok then
            logger.err("KoPanda: could not draw the sleep screen:", image)
        elseif image then
            if self.image then
                self.image:free()
            end
            self.image, self.image_file, self.screensaver_type = image, nil, "cover"
            -- As setup picks it for an image mode (frontend/ui/screensaver.lua:443-447), for :show's flash (:488-492).
            self.screensaver_background = G_reader_settings:readSetting("screensaver_img_background")
        end
    end
end

return SleepScreen
