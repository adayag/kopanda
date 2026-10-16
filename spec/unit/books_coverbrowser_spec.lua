-- The records against the real CoverBrowser (book-model C7, the record parts): its
-- bookinfomanager loaded through PluginLoader as on a device, its real database under the
-- scratch KO_HOME, and the three fixture EPUBs as the library root. Before extraction each record
-- is its file name with its cover missing; after extractBookInfo each has the manifest's title
-- and author with its cover cached; setBookInfoProperties' authors, series and fractional index
-- reach the record; deleteBookInfo makes its cover missing again. This is the check that the
-- stubs the other book specs use answer as CoverBrowser does.
-- luacheck: read globals disable_plugins load_plugin

-- bookinfomanager requires KOReader's sqlite binding, which ffi.cdef()s its constants when it
-- loads (common/lua-ljsqlite3/init.lua:109), so a Busted process can load it once at most
-- (spec/emulator/driver.lua:90-92). Busted insulates each spec file and drops what it required;
-- expose keeps the binding loaded for the files after this one, which bin/check runs in sorted
-- order (--sort-files), spec/unit/reading_stats_spec.lua among them.
expose("KOReader's sqlite binding, loaded once for the process", function()
    require("lua-ljsqlite3/init")
end)

describe("Books against the real CoverBrowser", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")

    local manifest = dofile(harness.library .. "/manifest.lua")
    local Books, bim

    local function remove_tree(path)
        if lfs.attributes(path, "mode") == "directory" then
            for entry in lfs.dir(path) do
                if entry ~= "." and entry ~= ".." then
                    remove_tree(path .. "/" .. entry)
                end
            end
        end
        os.remove(path)
    end

    local function fixture(file)
        return harness.library .. "/" .. file
    end

    before_each(function()
        harness.load()
        Books = package.loaded["books"]
        Books.reset()
        package.loaded["bookinfomanager"] = nil
        package.preload["bookinfomanager"] = nil
        -- PluginLoader:_load reads enabled_plugins, which harness.load() has just reset
        -- (frontend/pluginloader.lua:168, :264); CoverBrowser's main.lua requires
        -- bookinfomanager at its top (plugins/coverbrowser.koplugin/main.lua:6).
        load_plugin("coverbrowser.koplugin")
        bim = assert(package.loaded["bookinfomanager"], "CoverBrowser did not load bookinfomanager")
        G_reader_settings:saveSetting("document_metadata_folder", "dir")
        G_reader_settings:saveSetting("home_dir", harness.library)
        remove_tree(DataStorage:getDocSettingsDir())
        for _, entry in ipairs(manifest) do
            bim:deleteBookInfo(fixture(entry.file))
        end
    end)

    after_each(function()
        for _, entry in ipairs(manifest) do
            bim:deleteBookInfo(fixture(entry.file))
        end
        package.loaded["bookinfomanager"] = nil
        G_reader_settings:delSetting("document_metadata_folder")
        G_reader_settings:delSetting("home_dir")
        Books.reset()
        harness.teardown()
    end)

    it("reads each fixture by its file name with its cover missing before extraction", function()
        local all = Books.all()
        assert.equals(#manifest, #all)
        for i, entry in ipairs(manifest) do
            assert.same({
                id = "file:" .. ffiutil.realpath(fixture(entry.file)),
                source = "file",
                path = fixture(entry.file),
                title = entry.file:gsub("%.epub$", ""),
                authors = {},
                cover = "missing",
            }, all[i])
        end
    end)

    it("reads the manifest's titles and authors, cover cached, after extraction", function()
        for _, entry in ipairs(manifest) do
            bim:extractBookInfo(fixture(entry.file), { max_cover_w = 150, max_cover_h = 225 })
        end
        local all = Books.all()
        assert.equals(#manifest, #all)
        for i, entry in ipairs(manifest) do
            local record = all[i]
            assert.equals(fixture(entry.file), record.path)
            assert.equals(entry.title, record.title)
            assert.same({ entry.author }, record.authors)
            assert.equals("cached", record.cover)
            assert.same(record, Books.for_path(fixture(entry.file)))
            assert.same(record, Books.get(record.id))
        end
    end)

    it("follows setBookInfoProperties' authors, series and fractional index, then deleteBookInfo", function()
        local path = fixture("frankenstein.epub")
        bim:extractBookInfo(path, { max_cover_w = 150, max_cover_h = 225 })
        bim:setBookInfoProperties(path, {
            authors = "Mary Shelley\nPercy Shelley",
            series = "Gothic",
            series_index = 1.5,
        })
        local record = Books.for_path(path)
        assert.equals("Frankenstein", record.title)
        assert.same({ "Mary Shelley", "Percy Shelley" }, record.authors)
        assert.equals("Gothic", record.series)
        assert.equals(1.5, record.series_index)
        assert.equals("cached", record.cover)
        bim:deleteBookInfo(path)
        record = Books.for_path(path)
        assert.equals("missing", record.cover)
        assert.equals("frankenstein", record.title)
        assert.is_nil(record.series)
    end)
end)
