-- The end of a book in focused mode: when KoPanda's sheet takes over from KOReader's pop-up, how the book is marked,
-- the sheet's rows and what each does, and the next book of a series. The reader is a fake over KOReader's own
-- markBook; Books is stubbed, since a record's series comes from CoverBrowser, which unit specs don't run.
describe("the end of a book in focused mode", function()
    local harness = require("plugin_harness")
    local ReaderStatus = require("apps/reader/modules/readerstatus")
    local QuickStart = require("ui/quickstart")
    local UIManager = require("ui/uimanager")
    local filemanagerutil = require("apps/filemanager/filemanagerutil")
    local logger = require("logger")
    local BookStatusScreen, Books, FocusedEnd, Library, LibraryChrome, Settings, Sheet

    local FILE = "/books/one.epub"

    -- Undo steps for the running test, run last first after it.
    local undo = {}

    local function set(t, key, value)
        local old = rawget(t, key)
        undo[#undo + 1] = function()
            rawset(t, key, old)
        end
        rawset(t, key, value)
    end

    -- What ran, in order, by name; how often Books.all ran; the ui the last open was on.
    local ran, walks, opened_on
    local function note(name)
        return function()
            ran[#ran + 1] = name
        end
    end

    -- The reader on FILE, its sidecar's summary being summary.
    local function fake_ui(summary)
        local ui = {
            document = { file = FILE },
            doc_props = { display_title = "One" },
            doc_settings = {
                readSetting = function(_, key)
                    return key == "summary" and summary or nil
                end,
                flush = note("flush"),
            },
            gotopage = { onGoToBeginning = note("beginning") },
            onClose = note("close"),
        }
        function ui.showFileManager(_, file)
            ran[#ran + 1] = "file manager " .. file
        end
        ui.status = setmetatable({ ui = ui, document = ui.document }, { __index = ReaderStatus })
        return ui
    end

    local function record(id, series, fields)
        local book = { id = "file:/books/" .. id .. ".epub", path = "/books/" .. id .. ".epub", title = id,
            series = series, authors = {} }
        for key, value in pairs(fields or {}) do
            book[key] = value
        end
        return book
    end

    -- Books holding records, FILE's being the first, each record's sidecar status from statuses (default reading).
    local function library(records, statuses)
        walks = 0
        set(Books, "for_path", function(path)
            return path == FILE and records[1] or nil
        end)
        set(Books, "all", function()
            walks = walks + 1
            return records
        end)
        set(Books, "progress", function(book)
            return { status = statuses and statuses[book.title] or "reading" }
        end)
    end

    local function labels(spec)
        local list = {}
        for i, row in ipairs(spec.rows) do
            list[i] = row.label
        end
        return list
    end

    local function row_labelled(spec, label)
        for _, row in ipairs(spec.rows) do
            if row.label == label then
                return row
            end
        end
        error("no row " .. label)
    end

    local logged
    local ticks

    before_each(function()
        undo = {}
        ran = {}
        ticks = {}
        logged = {}
        harness.load()
        BookStatusScreen = package.loaded["book_status_screen"]
        Books = package.loaded["books"]
        Library = package.loaded["library"]
        LibraryChrome = package.loaded["library_chrome"]
        Settings = package.loaded["settings"]
        Sheet = package.loaded["sheet"]
        FocusedEnd = package.loaded["focused_end"]
        Settings.set("focused.on", true)
        G_reader_settings:delSetting("end_document_action")
        G_reader_settings:saveSetting("lastfile", FILE)
        set(UIManager, "nextTick", function(_, f)
            ticks[#ticks + 1] = f
        end)
        set(filemanagerutil, "openFile", function(ui, file)
            ran[#ran + 1] = "open " .. file
            opened_on = ui
        end)
        set(logger, "err", function(...)
            logged[#logged + 1] = { ... }
        end)
        library({ record("one") })
    end)

    after_each(function()
        Sheet.close()
        LibraryChrome.return_to = nil
        Library.return_to = nil
        G_reader_settings:delSetting("end_document_action")
        G_reader_settings:delSetting("lastfile")
        for i = #undo, 1, -1 do
            undo[i]()
        end
        harness.teardown()
    end)

    describe("the gate", function()
        it("takes the end with the mode on and end_document_action unset or the pop-up", function()
            for _, action in ipairs({ false, "pop-up" }) do
                if action then
                    G_reader_settings:saveSetting("end_document_action", action)
                end
                assert.is_true(FocusedEnd.take(fake_ui({ status = "reading" })))
                assert.equals("end_of_book", Sheet.shown.spec.name)
                Sheet.close()
            end
        end)

        it("leaves the end to KOReader with the mode off, marking nothing and showing nothing", function()
            Settings.set("focused.on", false)
            local summary = { status = "reading" }
            assert.is_false(FocusedEnd.take(fake_ui(summary)))
            assert.equals("reading", summary.status)
            assert.is_nil(Sheet.shown)
        end)

        it("leaves the end to KOReader for any other end_document_action", function()
            G_reader_settings:saveSetting("end_document_action", "next_file")
            local summary = { status = "reading" }
            assert.is_false(FocusedEnd.take(fake_ui(summary)))
            assert.equals("reading", summary.status)
            assert.is_nil(Sheet.shown)
        end)

        it("leaves the end of the quickstart guide to KOReader", function()
            set(QuickStart, "quickstart_filename", "/guide/quickstart.html")
            G_reader_settings:saveSetting("lastfile", "/guide/quickstart.html")
            assert.is_false(FocusedEnd.take(fake_ui({ status = "reading" })))
            assert.is_nil(Sheet.shown)
        end)

        it("shows nothing new for a second end with the sheet up, and takes it from KOReader's pop-up", function()
            local ui = fake_ui({ status = "reading" })
            assert.is_true(FocusedEnd.take(ui))
            local shown = Sheet.shown
            ran = {}
            assert.is_true(FocusedEnd.take(ui))
            assert.equals(shown, Sheet.shown)
            assert.same({}, ran)
        end)

        it("raises when the sheet isn't shown, so KOReader's pop-up runs", function()
            set(Sheet, "show", function() end)
            assert.has_error(function()
                FocusedEnd.take(fake_ui({ status = "reading" }))
            end)
        end)
    end)

    describe("marking", function()
        it("marks a reading book finished, dated today, then flushes the sidecar before the sheet", function()
            local summary = { status = "reading", modified = "2026-01-01" }
            set(Sheet, "show", function(spec)
                ran[#ran + 1] = "sheet"
                assert.equals("complete", summary.status)
                Sheet.shown = { spec = spec }
            end)
            FocusedEnd.take(fake_ui(summary))
            Sheet.shown = nil
            assert.equals("complete", summary.status)
            assert.equals(os.date("%Y-%m-%d"), summary.modified)
            assert.same({ "flush", "sheet" }, { ran[1], ran[2] })
        end)

        it("keeps the finish date of a book already complete, and still flushes", function()
            local summary = { status = "complete", modified = "2026-01-01" }
            FocusedEnd.take(fake_ui(summary))
            assert.equals("2026-01-01", summary.modified)
            assert.equals("flush", ran[1])
        end)
    end)

    describe("the sheet", function()
        it("is headed by the title and Finished, closes on a turned screen and leaves the reader beneath", function()
            local shown_opts
            local show = Sheet.show
            set(Sheet, "show", function(spec, ctx, opts)
                shown_opts = opts
                show(spec, ctx, opts)
            end)
            local ui = fake_ui({ status = "reading" })
            FocusedEnd.take(ui)
            local spec = Sheet.shown.spec
            assert.same({ heading = "One", label = "Finished" }, spec.header)
            assert.same({ "SetRotationMode", "SetDimensions" }, spec.close_on)
            shown_opts.beneath.close()
            assert.equals("flush", ran[#ran])
        end)

        it("holds Book details, Back to the start and Home with no series, walking no library", function()
            local spec = FocusedEnd.spec(fake_ui({ status = "complete" }))
            assert.same({ "Book details", "Back to the start", "Home" }, labels(spec))
            assert.equals(0, walks)
        end)

        it("shows Book details over the reader, with the reader as its opener", function()
            local book = record("one")
            library({ book })
            local shown
            set(BookStatusScreen, "show", function(opts)
                shown = opts
            end)
            row_labelled(FocusedEnd.spec(fake_ui({ status = "complete" })), "Book details").run()
            assert.equals(book, shown.record)
            assert.same({ screen = "reader" }, shown.opener)
        end)

        it("goes back to the start through the reader", function()
            row_labelled(FocusedEnd.spec(fake_ui({ status = "complete" })), "Back to the start").run()
            assert.same({ "beginning" }, ran)
        end)

        it("goes home by closing the book, then showing the file manager at it", function()
            row_labelled(FocusedEnd.spec(fake_ui({ status = "complete" })), "Home").run()
            assert.same({ "close", "file manager " .. FILE }, ran)
        end)
    end)

    describe("the next book", function()
        local ONE, TWO, THREE

        before_each(function()
            ONE = record("one", "Saga", { series_index = 1 })
            TWO = record("two", "Saga", { series_index = 2 })
            THREE = record("three", "Saga", { series_index = 3 })
        end)

        local function spec_of(records, statuses)
            library(records, statuses)
            return FocusedEnd.spec(fake_ui({ status = "complete" }))
        end

        it("opens the next unread on the tick after the tap, over the reader, read past a stale sidecar", function()
            library({ ONE, TWO, THREE })
            local ui = fake_ui({ status = "complete" })
            local spec = FocusedEnd.spec(ui)
            assert.same({ "Next: two", "Book details", "Back to the start", "Home" }, labels(spec))
            assert.is_nil(spec.rows[1].sublabel)
            spec.rows[1].run()
            assert.is_nil(ran[1])
            assert.equals(1, #ticks)
            ticks[1]()
            assert.same({ "open " .. TWO.path }, ran)
            assert.equals(ui, opened_on)
        end)

        it("skips books of other series", function()
            local spec = spec_of({ ONE, record("other", "Elsewhere", { series_index = 2 }), THREE })
            assert.equals("Next: three", spec.rows[1].label)
        end)

        it("has no Next on the last of a series", function()
            local spec = spec_of({ THREE, ONE, TWO }, { one = "complete", two = "complete" })
            assert.same({ "Book details", "Back to the start", "Home" }, labels(spec))
        end)

        it("skips an abandoned next book", function()
            local spec = spec_of({ ONE, TWO, THREE }, { two = "abandoned" })
            assert.equals("Next: three", spec.rows[1].label)
        end)

        it("has no Next when the only book left is abandoned", function()
            local spec = spec_of({ ONE, TWO }, { two = "abandoned" })
            assert.same({ "Book details", "Back to the start", "Home" }, labels(spec))
        end)

        for name, fields in pairs({ ["a cwngsync placeholder"] = { placeholder = true },
                ["a book with no file"] = { path = false } }) do
            it("takes " .. name .. " to its series window, the book closed and the library's return dropped",
                function()
                local next_book = record("two", "Saga", { series_index = 2, placeholder = fields.placeholder })
                if fields.path == false then
                    next_book.path = nil
                end
                local spec = spec_of({ ONE, next_book })
                local row = spec.rows[1]
                assert.equals("Next: two", row.label)
                assert.equals("Not downloaded", row.sublabel)
                Library.return_to = { dir = "/books", page = 3 }
                row.run()
                assert.same({ screen = "series", view = { kind = "series", name = "Saga" }, page = 1 },
                    LibraryChrome.return_to)
                assert.is_nil(Library.return_to)
                assert.same({ "close", "file manager " .. FILE }, ran)
                assert.equals(0, #ticks)
            end)
        end

        it("drops the row and logs when the lookup fails, the other rows standing", function()
            library({ ONE, TWO })
            set(Books, "all", function()
                error("kopanda-test: no library")
            end)
            local spec = FocusedEnd.spec(fake_ui({ status = "complete" }))
            assert.same({ "Book details", "Back to the start", "Home" }, labels(spec))
            assert.equals(1, #logged)
        end)
    end)
end)
