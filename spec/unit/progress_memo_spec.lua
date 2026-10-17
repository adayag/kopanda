-- The library-wide progress memo (TW-3tfybs): a book's sidecar is opened once while its file's
-- path, mtime and size hold, across library builds, and a folder tile counts its books from the
-- folder's scan without a CoverBrowser row per book. Run on a scratch library under the data
-- directory with KOReader's home folder pointed at it and sidecars in the "dir" location, through
-- the real Books and LibraryView, DocSettings.openSettingsFile and CoverBrowser's getBookInfo
-- counted.
describe("the progress memo", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local DocSettings = require("docsettings")
    local ReadHistory = require("readhistory")
    local lfs = require("libs/libkoreader-lfs")
    local util = require("util")
    local Books, LibraryOrder, LibraryView

    local lib = DataStorage:getDataDir() .. "/progress-memo"
    local saved_open, saved_hist, loaded_bim
    local opened, rows

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    -- n files book-01.epub … in dir, each with a sidecar holding lua when lua is given.
    local function books(dir, n, lua)
        lfs.mkdir(dir)
        local paths = {}
        for i = 1, n do
            local path = ("%s/book-%02d.epub"):format(dir, i)
            write(path, "not really a book")
            if lua then
                local sdr = DocSettings:getSidecarDir(path, "dir")
                util.makePath(sdr)
                write(sdr .. "/" .. DocSettings.getSidecarFilename(path), "return " .. lua)
            end
            paths[i] = path
        end
        return paths
    end

    local function remove_tree(path)
        if lfs.symlinkattributes(path, "mode") == "directory" then
            for entry in lfs.dir(path) do
                if entry ~= "." and entry ~= ".." then
                    remove_tree(path .. "/" .. entry)
                end
            end
        end
        os.remove(path)
    end

    -- The library at lib's page 1 built as a show builds it, its frame freed.
    local function build()
        LibraryView.build(lib, 1).frame:free()
    end

    -- How many getBookInfo calls were for a file under dir.
    local function rows_under(dir)
        local n = 0
        for _, file in ipairs(rows) do
            if file:sub(1, #dir + 1) == dir .. "/" then
                n = n + 1
            end
        end
        return n
    end

    before_each(function()
        harness.load()
        Books = package.loaded["books"]
        LibraryOrder = package.loaded["library_order"]
        LibraryView = package.loaded["library_view"]
        Books.reset()
        G_reader_settings:saveSetting("document_metadata_folder", "dir")
        remove_tree(lib)
        remove_tree(DataStorage:getDocSettingsDir())
        assert(lfs.mkdir(lib))
        G_reader_settings:saveSetting("home_dir", lib)
        saved_hist = ReadHistory.hist
        ReadHistory.hist = {}
        opened, rows = {}, {}
        saved_open = DocSettings.openSettingsFile
        DocSettings.openSettingsFile = function(file)
            opened[#opened + 1] = file
            return saved_open(file)
        end
        loaded_bim = package.loaded["bookinfomanager"]
        package.loaded["bookinfomanager"] = {
            getBookInfo = function(_, file)
                rows[#rows + 1] = file
                return { title = file:match("([^/]+)%.epub$"), authors = "An Author" }
            end,
        }
    end)

    after_each(function()
        DocSettings.openSettingsFile = saved_open
        package.loaded["bookinfomanager"] = loaded_bim
        ReadHistory.hist = saved_hist
        G_reader_settings:delSetting("document_metadata_folder")
        G_reader_settings:delSetting("home_dir")
        Books.reset()
        remove_tree(lib)
        remove_tree(DataStorage:getDocSettingsDir())
        harness.teardown()
    end)

    it("opens two folder tiles' sidecars on the first build, none on the next, one re-dated again", function()
        books(lib, 2)
        local one = books(lib .. "/one", 10, '{ percent_finished = 0.5, summary = { status = "reading" } }')
        books(lib .. "/two", 10, '{ percent_finished = 1, summary = { status = "complete" } }')
        build()
        assert.equals(20, #opened)
        assert.equals(0, rows_under(lib .. "/one") + rows_under(lib .. "/two"))
        opened = {}
        build()
        assert.equals(0, #opened)
        local side = DocSettings:findSidecarFile(one[3])
        local mtime = lfs.attributes(side, "modification")
        assert.is_true(lfs.touch(side, mtime + 10, mtime + 10))
        build()
        assert.same({ side }, opened)
        assert.equals(0, rows_under(lib .. "/one") + rows_under(lib .. "/two"))
    end)

    it("opens a Reading library's sidecars on the first build and none on the next", function()
        books(lib, 10, '{ percent_finished = 0.25, summary = { status = "reading" } }')
        assert.is_true(LibraryOrder.choose(lib, "title", "reading"))
        build()
        assert.equals(10, #opened)
        opened = {}
        build()
        assert.equals(0, #opened)
    end)
end)
