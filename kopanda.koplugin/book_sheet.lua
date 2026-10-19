-- A book's sheet: a header of its small cover, title, author and meta line, then Open, Book
-- details, Read status and More by this author. The featured book's (BookSheet.open), opened by a
-- hold on it (widgets/featured.lua), adds Feature a different book and This widget's settings; a
-- library record's (BookSheet.open_record), opened by a hold on a book in the library or on a shelf
-- screen (library_sheets.lua), runs the window's own open and re-list (context-menu D13) and adds
-- Add to the home and Delete, and Download under Open for cwngsync's placeholder, which asks
-- cwngsync to fetch the book without opening it (cwng-placeholders D2). Read status opens a
-- sub-sheet of KOReader's own three status buttons, which write the sidecar themselves; Feature a
-- different book opens the picker and Add to the home pins the book, both writing featured.pinned;
-- Delete is KOReader's own delete confirm. Nothing else here writes.
local BookCovers = require("book_covers")
local BookList = require("ui/widget/booklist")
local Books = require("books")
local DocSettings = require("docsettings")
local Featured = require("widgets/featured")
local FeaturedBook = require("featured_book")
local FeaturedCover = require("featured_cover")
local Guards = require("guards")
local Home = require("home")
local Math = require("optmath")
local PaintClock = require("paint_clock")
local Settings = require("settings")
local SettingsMenu = require("settings_menu")
local Sheet = require("sheet")
local ffiutil = require("ffi/util")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

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

-- Adds to parts when file was last opened, if known. A history that can't be read is logged and
-- adds nothing.
local function add_opened(parts, file, now)
    local ok, when = pcall(opened, file, now)
    if not ok then
        logger.err("KoPanda: could not read when the book was last opened:", when)
    elseif when then
        parts[#parts + 1] = when
    end
end

-- The meta line: the percent the home shows, the recorded chapter and when it was last opened,
-- each left out when unknown.
local function meta(book, now)
    local parts = { Featured.shown_percent(book) .. "%" }
    if book.chapter and book.chapter ~= "" then
        parts[#parts + 1] = book.chapter
    end
    add_opened(parts, book.file, now)
    return table.concat(parts, JOIN)
end

-- A record's meta line (HoldBookC.dc.html:40): the percent when Books.progress has one or the
-- book is finished, as the tiles read it (library_tiles.lua), then when it was last opened; each
-- left out when unknown, nil when both are, so the header has no meta line. No chapter: a record
-- has none. "Not downloaded" for a book not downloaded: a record with no path (D2), or cwngsync's
-- placeholder (cwng-placeholders D6).
local function record_meta(record, now)
    if not record.path or record.placeholder == true then
        return "Not downloaded"
    end
    local parts = {}
    local progress = Books.progress(record)
    if progress.status == "complete" or type(progress.percent) == "number" then
        parts[1] = Featured.shown_percent(progress) .. "%"
    end
    add_opened(parts, record.path, now)
    return #parts > 0 and table.concat(parts, JOIN) or nil
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
-- status itself, then runs refresh (the home's refresh, or the window's re-list).
local function open_status(ctx, file, title, refresh, opts)
    local doc = DocSettings:hasSidecarFile(file) and BookList.getDocSettings(file) or file
    local buttons = filemanagerutil.genStatusButtonsRow(doc, function()
        refresh()
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
        header = { heading = "Read status", aside = title },
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

-- The named author's own books (series-and-authors D6), or the Authors list for nil. The show
-- closes the screen the sheet was over.
local function show_authors(name)
    local fm = file_manager()
    if fm then
        fm.kopanda:showAuthors{ view = name and { kind = "author", name = name } or nil }
    end
end

-- The rows every book's sheet starts with, each with its board icon (HoldBookC.dc.html:43-63):
-- Open, Book details, Read status and More by this author, for the book at file titled title
-- under ctx. on holds the caller's callbacks: open(), Open's; refresh(), run after the status
-- sub-sheet writes; author(), read on the tap, the name More by this author shows (nil for the
-- Authors list). beneath is the screen the sub-sheet is shown over (nil for the home). With no file
-- (a book not downloaded, D2), Open, Book details and Read status are greyed with no run, so a tap
-- closes the sheet and runs nothing (D14), and Read status has no detail.
local function book_rows(file, title, on, ctx, beneath)
    local rows = {
        { icon = "open_book", label = "Open" },
        { icon = "info", label = "Book details" },
        { icon = "bookmark", label = "Read status" },
        {
            icon = "authors",
            label = "More by this author",
            detail = "›",
            run = function()
                show_authors(on.author())
            end,
        },
    }
    if not file then
        for i = 1, 3 do
            rows[i].muted = true
        end
        return rows
    end
    rows[1].run = on.open
    rows[2].run = function()
        show_details(file)
    end
    -- KOReader's label: New with no sidecar (frontend/ui/widget/booklist.lua:366-389).
    rows[3].detail = BookList.getBookStatusString(BookList.getBookStatus(file), false, true) .. " ›"
    rows[3].chip = "status"
    rows[3].run = function()
        open_status(ctx, file, title, on.refresh, { started = PaintClock.now(), beneath = beneath })
    end
    return rows
end

-- Add to the home (context-menu D8): pins the book at file by its realpath, as the picker pins
-- one, history holding realpaths (readhistory.lua:26). The window stays shown and the home, closed
-- while a library window is up, builds afresh on its next show, so nothing is refreshed. When
-- featured.pinned already names the book, by realpath, and is a file, as the picker reads the pin,
-- the row reads On the home, ticked, so a tap runs nothing. A refused write is logged and changes
-- nothing. Greyed with no file (D2). Its run, as the delete's and the download's below, goes through
-- Guards.guarded, so a row's failure leaves the window it was shown over as it was rather than
-- closing it, as the sheet's own failure would (context-menu "Failure behaviour").
local function home_row(file)
    local row = { icon = "home_plus", label = "Add to the home" }
    if not file then
        row.muted = true
        return row
    end
    local real = ffiutil.realpath(file) or file
    local pinned = Settings.get("featured.pinned")
    if pinned and lfs.attributes(pinned, "mode") == "file" and (ffiutil.realpath(pinned) or pinned) == real then
        row.label = "On the home"
        row.tick = true
        return row
    end
    row.run = Guards.guarded("the pin to the home", function()
        local ok, err = Settings.set("featured.pinned", real)
        if not ok then
            logger.err("KoPanda: could not change the featured book:", err)
        end
    end)
    return row
end

-- Delete… (context-menu D7): KOReader's own delete confirm for the book at file, called on the
-- file manager's instance as the file browser's Delete calls it
-- (frontend/apps/filemanager/filemanager.lua:228-233, :1121-1153), with its wording, its archive
-- check and its notices. Its post-delete callback, run only once the delete succeeded (:1141-1142),
-- re-lists window. Without a file manager, logged and nothing shown. Greyed with no file (D2), and
-- for cwngsync's placeholder, which its next sync would put back (cwng-placeholders D5).
local function delete_row(file, placeholder, window)
    local row = { icon = "trash", label = "Delete…" }
    if not file or placeholder then
        row.muted = true
        return row
    end
    row.run = Guards.guarded("the delete", function()
        local fm = file_manager()
        if not fm then
            logger.warn("KoPanda: no file manager to delete the book from")
            return
        end
        fm:showDeleteFileDialog(file, function()
            window:refresh()
        end)
    end)
    return row
end

-- cwngsync's plugin instance on the file manager (cwng-placeholders D13), or nil.
local function cwngsync()
    local fm = file_manager()
    return fm and fm.cwngsync
end

local function can_download(plugin)
    return plugin ~= nil and type(plugin.openLibraryPlaceholder) == "function"
end

-- cwngsync's call once the book has arrived at file, in place of its open (cwng-placeholders D17):
-- the book's cover forgotten, so it is asked for afresh, then window's re-list with that request
-- (window:downloaded), which does nothing once another window is shown. Never opens the book. A
-- failure is logged.
local function arrived(file, record, window)
    local ok, err = pcall(function()
        BookCovers.forget({ file })
        window:downloaded(record)
    end)
    if not ok then
        logger.err("KoPanda: the downloaded book's re-list failed:", err)
    end
end

-- Download (cwng-placeholders D16, D17, D18), for cwngsync's placeholder: hands cwngsync record's
-- path and arrived in place of the open (cwng_library_runtime.lua:999-1030), which waits for
-- Wi-Fi, downloads and calls arrived; a false return (the file was replaced, or its record went)
-- re-lists window. Greyed with no run when cwngsync has no openLibraryPlaceholder. cwngsync is read
-- again on the tap, since it can go between the build and the tap: then the tap is logged and
-- does nothing.
local function download_row(record, window)
    local row = { icon = "download", label = "Download" }
    if not can_download(cwngsync()) then
        row.muted = true
        return row
    end
    row.run = Guards.guarded("the download", function()
        local plugin = cwngsync()
        if not can_download(plugin) then
            logger.warn("KoPanda: cwngsync went before the download; nothing to download the book with")
            return
        end
        local taken = plugin:openLibraryPlaceholder(record.path, function(file)
            arrived(file, record, window)
        end)
        if not taken then
            window:refresh()
        end
    end)
    return row
end

-- The sheet's cover size under ctx, the tokens' cover_w by cover_h.
local function cover_size(ctx)
    local tokens = ctx.look.sheet
    return ctx.screen:scaleBySize(tokens.cover_w), ctx.screen:scaleBySize(tokens.cover_h)
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
    -- os.time() rather than ctx.now, the home's build time, so an old home shows the true age.
    local now = os.time()
    local rows = book_rows(book.file, book.title, {
        open = function()
            Featured.tap(ctx, nil, built)
        end,
        refresh = function()
            ctx.home:refresh()
        end,
        -- From the book's record read on the tap; the Authors list for a book with no author.
        author = function()
            local record = Books.for_path(book.file)
            return record and record.authors[1]
        end,
    }, ctx, nil)
    rows[#rows + 1] = {
        icon = "list",
        label = "Feature a different book",
        run = function()
            open_picker(ctx, { started = PaintClock.now() })
        end,
    }
    rows[#rows + 1] = {
        icon = "settings",
        label = "This widget's settings",
        run = function()
            SettingsMenu.open("featured")
        end,
    }
    local header = { title = book.title, author = book.authors, meta = meta(book, now) }
    -- The cover last, so nothing raising after it leaves it unfreed: from here the sheet frees it.
    local w, h = cover_size(ctx)
    header.cover = FeaturedCover.build(book, w, h, ctx)
    Sheet.show({ name = "book", band = "book", header = header, rows = rows }, ctx, opts)
end

-- Shows the sheet of record (a Books record, books.lua) held on window (the library or a shelf
-- screen) under ctx, the window's, with opts passed on to Sheet.show (its beneath the window).
-- Open runs window:open(record), the open its tap on the book runs; a status write re-lists the
-- window (window:refresh()); More by this author shows the record's first author; then Add to the
-- home and Delete; for cwngsync's placeholder, Download under Open. A record whose file has gone
-- since the window was built re-lists the window instead and shows no sheet. The cover is the
-- featured cover's frame round the record's cached cover (FeaturedCover.framed), never asking for
-- an extraction.
function BookSheet.open_record(record, window, ctx, opts)
    local file = record.path
    if file and lfs.attributes(file, "mode") ~= "file" then
        window:refresh()
        return
    end
    local rows = book_rows(file, record.title, {
        open = function()
            window:open(record)
        end,
        refresh = function()
            window:refresh()
        end,
        author = function()
            return record.authors[1]
        end,
    }, ctx, opts and opts.beneath)
    if record.placeholder == true then
        table.insert(rows, 2, download_row(record, window))
    end
    rows[#rows + 1] = home_row(file)
    rows[#rows + 1] = delete_row(file, record.placeholder == true, window)
    local header = {
        title = record.title,
        author = #record.authors > 0 and table.concat(record.authors, ", ") or nil,
        meta = record_meta(record, os.time()),
    }
    -- The cover last, as BookSheet.open's.
    local w, h = cover_size(ctx)
    header.cover = FeaturedCover.framed(record, w, h, ctx, FeaturedCover.frame(ctx.look))
    Sheet.show({ name = "book", band = "book", header = header, rows = rows }, ctx, opts)
end

return BookSheet
