-- The end of a book in focused mode: KoPanda's sheet in place of KOReader's pop-up (frontend/apps/reader/modules/
-- readerstatus.lua:57). The book is marked through ReaderStatus:markBook (:212) and its sidecar flushed as deleteFile
-- does (:198), and the next file opens as onOpenNextOrPreviousFileInFolder opens one (:184-188).
local BookStatusScreen = require("book_status_screen")
local Books = require("books")
local Focused = require("focused")
local FocusedPanel = require("focused_panel")
local Library = require("library")
local LibraryChrome = require("library_chrome")
local Sheet = require("sheet")
local ShelfOrder = require("shelf_order")
local UIManager = require("ui/uimanager")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local logger = require("logger")

local FocusedEnd = {}

local NAME = "end_of_book"

-- The reader stays under the sheet when it closes.
local NOOP = { close = function() end }

-- Whether the end goes to the sheet: the mode on, KOReader's end action left at its pop-up (readerstatus.lua:57-59),
-- and the book not the quickstart guide (:40-43).
local function wanted()
    if not Focused.on() then
        return false
    end
    local action = G_reader_settings:readSetting("end_document_action")
    if action ~= nil and action ~= "pop-up" then
        return false
    end
    local QuickStart = require("ui/quickstart")
    return G_reader_settings:readSetting("lastfile") ~= QuickStart.quickstart_filename
end

-- A book already complete keeps its finish date, which markBook would move.
local function mark(ui)
    if ui.doc_settings:readSetting("summary").status ~= "complete" then
        ui.status:markBook(true)
    end
    ui.doc_settings:flush()
end

local function close_book(ui)
    local file = ui.document.file
    ui:onClose()
    ui:showFileManager(file)
end

-- The next unread book of the series the book at file is in, and that series' name; nil outside a series or past
-- its end. The finished book reads as complete whatever its sidecar says, since the progress memo is keyed by a
-- one-second modification time.
local function next_book(file)
    local book = Books.for_path(file)
    local series = book and book.series
    if not series then
        return nil
    end
    local records = {}
    for _, record in ipairs(Books.all()) do
        if record.series == series then
            records[#records + 1] = record
        end
    end
    local entry = ShelfOrder.series(records, function(record)
        return record.id == book.id and { status = "complete" } or Books.progress(record)
    end)[1]
    return entry and entry.next, series
end

-- The Next row: a downloaded book opens on the next tick, since the open destroys the document (:184-186); any other
-- has its series window taken as the return of a closing book. A library return would win over it
-- (ScreenRoutes.return_window), so it goes.
local function next_row(ui, record, series)
    local row = { icon = "open_book", label = "Next: " .. record.title }
    if record.path and not record.placeholder then
        function row.run()
            UIManager:nextTick(function()
                filemanagerutil.openFile(ui, record.path)
            end)
        end
    else
        row.icon = "download"
        row.sublabel = "Not downloaded"
        function row.run()
            Library.return_to = nil
            LibraryChrome.return_to = { screen = "series", view = { kind = "series", name = series }, page = 1 }
            close_book(ui)
        end
    end
    return row
end

-- The sheet's spec for ui, its book marked. A failure finding the next book leaves that row out.
function FocusedEnd.spec(ui)
    local file = ui.document.file
    local rows = {}
    local ok, record, series = pcall(next_book, file)
    if not ok then
        logger.err("KoPanda: could not find the next book:", record)
    elseif record then
        rows[1] = next_row(ui, record, series)
    end
    rows[#rows + 1] = { icon = "info", label = "Book details", run = function()
        BookStatusScreen.show{ record = Books.for_path(file), opener = { screen = "reader" } }
    end }
    rows[#rows + 1] = { icon = "back", label = "Back to the start", run = function()
        ui.gotopage:onGoToBeginning()
    end }
    rows[#rows + 1] = { icon = "home", label = "Home", run = function()
        close_book(ui)
    end }
    return {
        name = NAME,
        band = "book",
        header = { heading = ui.doc_props.display_title, label = "Finished" },
        rows = rows,
        close_on = FocusedPanel.TURNED,
    }
end

-- Takes the end of ui's book from KOReader: true when the sheet is up, its book marked, or was already; false when
-- the end stays KOReader's. Raises when the sheet isn't shown, which Sheet.show logs.
function FocusedEnd.take(ui)
    if not wanted() then
        return false
    end
    if Sheet.shown and Sheet.shown.spec.name == NAME then
        return true
    end
    mark(ui)
    Sheet.show(FocusedEnd.spec(ui), FocusedPanel.ctx(ui), { beneath = NOOP })
    if not Sheet.shown then
        error("the end of book sheet was not shown")
    end
    return true
end

return FocusedEnd
