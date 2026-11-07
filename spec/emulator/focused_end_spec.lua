-- The end of a book in focused mode on the emulator: the end-of-book scenario patch turns past the last page of the
-- one book in the library, and reports on the "scenario" screen that KoPanda's sheet came up in place of KOReader's
-- pop-up with the book marked finished, that a second turn shows no second sheet, that Book details shows over the
-- reader and its back control lands on the book, and that Back to the start goes to the first page.
describe("the end of a book on the emulator", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")

    -- Opening a book writes its .sdr sidecar beside it (document_metadata_folder defaults to
    -- "doc", frontend/docsettings.lua:102), so the book is copied out of spec/fixtures/library/.
    local function library_with_one_book()
        local dir = os.getenv("KO_HOME") .. "/end-of-book-library"
        if lfs.attributes(dir, "mode") then
            assert.equals(0, os.execute("rm -rf '" .. dir .. "'"))
        end
        assert(lfs.mkdir(dir))
        assert.equals(0, os.execute("cp '" .. root .. "/spec/fixtures/library/frankenstein.epub' '" .. dir .. "/'"))
        return dir
    end

    local function focused_settings()
        local path = os.getenv("KO_HOME") .. "/end-of-book-settings.lua"
        local f = assert(io.open(path, "w"))
        f:write('return {\n    ["schema_version"] = 1,\n    ["focused.on"] = true,\n}\n')
        f:close()
        return path
    end

    it("shows the sheet at the end, the book marked, and acts from it over the reader", function()
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = root .. "/kopanda.koplugin",
            library_dir = library_with_one_book(),
            patches = { root .. "/spec/emulator/scenarios/2-scenario-end-of-book.lua" },
            shot_screen = "scenario",
            settings_file = focused_settings(),
        }
        local sidecar = result.sidecar
        assert.is_nil(sidecar.error)
        assert.equals("Finished", sidecar.header_label)
        assert.equals("Book details|Back to the start|Home", sidecar.rows)
        assert.equals("complete", sidecar.status)
        assert.is_false(sidecar.popup_shown)
        assert.is_true(sidecar.sheet_kept)
        assert.is_true(sidecar.details_closed)
        assert.equals("complete", sidecar.status_again)
        assert.is_true(sidecar.reader_shown)
        assert.is_true(sidecar.sheet_closed)
        assert.equals(1, sidecar.page)
    end)
end)
