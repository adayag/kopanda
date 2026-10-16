-- The featured book's sheet, opened by a hold on it (widgets/featured.lua): a header of its small
-- cover, title, author and meta line, then Open, Book details, Read status, More by this author,
-- Feature a different book and This widget's settings. Read status opens a sub-sheet of
-- KOReader's own three status buttons, which write the sidecar themselves; Feature a different
-- book opens the picker, which writes featured.pinned. Nothing else here writes.
local BookList = require("ui/widget/booklist")
local DocSettings = require("docsettings")
local Featured = require("widgets/featured")
local FeaturedBook = require("featured_book")
local FeaturedCover = require("featured_cover")
local Home = require("home")
local LauncherEntries = require("launcher_entries")
local Math = require("optmath")
local Settings = require("settings")
local SettingsMenu = require("settings_menu")
local Sheet = require("sheet")
local ffiutil = require("ffi/util")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local time = require("ui/time")

local BookSheet = {}

-- The statuses in the order genStatusButtonsRow builds its buttons
-- (frontend/apps/filemanager/filemanagerutil.lua:141-145).
local STATUSES = { "reading", "abandoned", "complete" }
-- How many history books the picker offers.
local RECENT = 6
local JOIN = " · "
local DAY = 24 * 60 * 60

local function file_manager()
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    return FileManager and FileManager.instance
end

-- Noon on the local calendar day of t, so a difference of two is a whole number of days across
-- a DST change.
local function noon_of(t)
    local date = os.date("*t", t)
    return os.time{ year = date.year, month = date.month, day = date.day, hour = 12 }
end

-- When file was last opened, by its history entry's time (frontend/readhistory.lua:25-35), in
-- local calendar days before now: "opened today", "opened yesterday" or "opened N days ago"; a
-- time in the future reads as today. nil with no entry. History holds realpaths
-- (readhistory.lua:26). Required at call time, so the history read is the one KOReader holds now.
local function opened(file, now)
    local real = ffiutil.realpath(file) or file
    for _, entry in ipairs(require("readhistory").hist) do
        if entry.file == real and type(entry.time) == "number" then
            local days = math.max(0, Math.round((noon_of(now) - noon_of(entry.time)) / DAY))
            if days == 0 then
                return "opened today"
            elseif days == 1 then
                return "opened yesterday"
            end
            return "opened " .. days .. " days ago"
        end
    end
end

-- The meta line: the percent the home shows, the recorded chapter and when it was last opened,
-- each left out when unknown. A history that can't be read is logged and leaves out the last.
local function meta(book, now)
    local parts = { Featured.shown_percent(book) .. "%" }
    if book.chapter and book.chapter ~= "" then
        parts[#parts + 1] = book.chapter
    end
    local ok, when = pcall(opened, book.file, now)
    if not ok then
        logger.err("KoPanda: could not read when the book was last opened:", when)
    elseif when then
        parts[#parts + 1] = when
    end
    return table.concat(parts, JOIN)
end

-- KOReader's page of the book's details, over the home (filemanagerbookinfo.lua:71-87).
local function show_details(file)
    local fm = file_manager()
    if not fm then
        logger.warn("KoPanda: no file manager to show the book's details from")
        return
    end
    fm.bookinfo:show(file)
end

-- The read status sub-sheet: KOReader's own status buttons for the book, with the sidecar when
-- the book has one on disk, so its other summary fields survive the write, else with the path.
-- The file dialog asks BookList.hasBookBeenOpened (filemanager.lua:255-270), which a stale
-- cache can answer false while a sidecar exists, and a bare path's write starts from an empty
-- summary (filemanagerutil.lua:124-127), wiping the note and rating; so the disk is asked here,
-- through DocSettings:hasSidecarFile (frontend/docsettings.lua:151-153). Each button writes the
-- status itself, then refreshes the home through the callback given.
local function open_status(ctx, book, opts)
    local file = book.file
    local doc = DocSettings:hasSidecarFile(file) and BookList.getDocSettings(file) or file
    local buttons = filemanagerutil.genStatusButtonsRow(doc, function()
        ctx.home:refresh()
    end)
    local rows = {}
    for i, status in ipairs(STATUSES) do
        rows[i] = {
            label = BookList.getBookStatusString(status, false, true),
            -- The current status's button is the disabled one (filemanagerutil.lua:132).
            tick = buttons[i].enabled == false,
            run = buttons[i].callback,
        }
    end
    Sheet.show({
        name = "status",
        band = "book",
        header = { heading = "Read status", aside = book.title },
        rows = rows,
    }, ctx, opts)
end

-- Stores value as featured.pinned, then refreshes the home and runs the featured slot's
-- after_show, which the home runs only after a show, so a newly featured book's cover is asked
-- for. A refused write is logged and changes nothing.
local function pin(ctx, value)
    local ok, err = Settings.set("featured.pinned", value)
    if not ok then
        logger.err("KoPanda: could not change the featured book:", err)
        return
    end
    local home = ctx.home
    home:refresh()
    -- The refresh rebuilt the slots, or closed the home when it failed.
    if Home.shown ~= home then
        return
    end
    for _, slot in ipairs(home.slots) do
        if slot.widget == "featured" and slot.module and slot.module.after_show then
            local shown, show_err = pcall(slot.module.after_show, home.ctx, slot.built)
            if not shown then
                logger.err("KoPanda: the featured book failed after the pick:", show_err)
            end
        end
    end
end

local function book_row(entry, tick, ctx)
    return {
        label = entry.title,
        detail = entry.authors,
        tick = tick,
        run = function()
            pin(ctx, entry.file)
        end,
    }
end

-- The picker: The last one opened, then the history's six most recent books, then the pinned
-- book when it is older than those, so the current choice is always listed unless reading it
-- raises, which is logged and leaves its row out. The tick follows featured.pinned, compared by
-- realpath; a pin to a file that has gone reads as no pin, as FeaturedBook reads it.
local function open_picker(ctx, opts)
    local pinned = Settings.get("featured.pinned")
    local pinned_real = pinned and (ffiutil.realpath(pinned) or pinned)
    local pin_is_file = pinned and lfs.attributes(pinned, "mode") == "file" or false
    local rows = {
        {
            label = "The last one opened",
            tick = not pin_is_file,
            run = function()
                pin(ctx, false)
            end,
        },
    }
    local ticked = false
    for _, entry in ipairs(FeaturedBook.recent(RECENT)) do
        local tick = pin_is_file and entry.file == pinned_real
        ticked = ticked or tick
        rows[#rows + 1] = book_row(entry, tick, ctx)
    end
    if pin_is_file and not ticked then
        local described, entry = pcall(FeaturedBook.describe, pinned)
        if described then
            rows[#rows + 1] = book_row(entry, true, ctx)
        else
            logger.err("KoPanda: could not read the pinned book", pinned, ":", entry)
        end
    end
    Sheet.show({
        name = "picker",
        band = "book",
        header = { heading = "Feature a book" },
        rows = rows,
    }, ctx, opts)
end

-- Shows the sheet of built's book (the featured widget's built widget) under ctx, the home's,
-- with opts passed on to Sheet.show. A book whose file has gone since the build refreshes the
-- home instead, as a tap does, so the next book is featured.
function BookSheet.open(ctx, built, opts)
    local book = built.book
    if lfs.attributes(book.file, "mode") ~= "file" then
        ctx.home:refresh()
        return
    end
    local tokens = ctx.look.sheet
    -- os.time() rather than ctx.now, the home's build time, so an old home shows the true age.
    local now = os.time()
    local rows = {
        {
            icon = "open_book",
            label = "Open",
            run = function()
                Featured.tap(ctx, nil, built)
            end,
        },
        {
            icon = "info",
            label = "Book details",
            run = function()
                show_details(book.file)
            end,
        },
        {
            icon = "bookmark",
            label = "Read status",
            -- KOReader's label: New with no sidecar (frontend/ui/widget/booklist.lua:366-389).
            detail = BookList.getBookStatusString(BookList.getBookStatus(book.file), false, true) .. " ›",
            chip = "status",
            run = function()
                open_status(ctx, book, { started = time.monotonic() })
            end,
        },
        {
            icon = "authors",
            label = "More by this author",
            detail = "›",
            run = function()
                LauncherEntries.run({ kind = "kopanda", target = "authors" }, ctx)
            end,
        },
        {
            icon = "list",
            label = "Feature a different book",
            run = function()
                open_picker(ctx, { started = time.monotonic() })
            end,
        },
        {
            icon = "settings",
            label = "This widget's settings",
            run = function()
                SettingsMenu.open("featured")
            end,
        },
    }
    local header = { title = book.title, author = book.authors, meta = meta(book, now) }
    -- The cover last, so nothing raising after it leaves it unfreed: from here the sheet frees it.
    header.cover = FeaturedCover.build(book, ctx.screen:scaleBySize(tokens.cover_w),
        ctx.screen:scaleBySize(tokens.cover_h), ctx)
    Sheet.show({ name = "book", band = "book", header = header, rows = rows }, ctx, opts)
end

return BookSheet
