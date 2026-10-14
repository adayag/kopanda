-- Closing a book in the emulator lands on the pre-built home without the file browser ever
-- being painted. The book-close scenario patch opens the one book in the library, closes it
-- from a scheduled task, and reports what it counted on the "scenario" screen.
describe("closing a book on the emulator", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-book-close.lua"

    -- Opening a book writes its .sdr sidecar beside it (document_metadata_folder defaults to
    -- "doc", frontend/docsettings.lua:102), so the book is copied out of spec/fixtures/library/.
    local function library_with_one_book()
        local dir = os.getenv("KO_HOME") .. "/book-close-library"
        if lfs.attributes(dir, "mode") then
            assert.equals(0, os.execute("rm -rf '" .. dir .. "'"))
        end
        assert(lfs.mkdir(dir))
        assert.equals(0, os.execute("cp '" .. root .. "/spec/fixtures/library/frankenstein.epub' '" .. dir .. "/'"))
        return dir
    end

    it("lands on the pre-built home with the file browser never painted", function()
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library_with_one_book(),
            patches = { scenario },
            shot_screen = "scenario",
        }
        local sidecar = result.sidecar
        assert.is_nil(sidecar.error)
        assert.equals("scenario", sidecar.screen)
        assert.equals(0, sidecar.fm_paints)
        assert.is_true(sidecar.prebuilt)
        assert.is_number(sidecar.home_ms)
        assert.truthy(sidecar.home_ms <= 100, "home_ms " .. tostring(sidecar.home_ms))
        assert.is_number(sidecar.close_to_paint_ms)
        print(string.format("book close: fm_paints=%d home_ms=%s close_to_paint_ms=%s",
            sidecar.fm_paints, tostring(sidecar.home_ms), tostring(sidecar.close_to_paint_ms)))
        assert.is_true(golden.check("home-placeholder", "colorsoft", result, { update = false }).ok)
    end)
end)
