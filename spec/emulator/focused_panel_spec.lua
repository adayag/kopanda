-- A KoPanda sheet over an open book: the focused-panel scenario patch opens the one book in the library and runs
-- one step per capture (spec/emulator/scenarios/2-scenario-focused-panel.lua), reporting on the "scenario" screen:
-- a probe sheet paints over the reader, closes and leaves the reader up; the focused panel fits whole on the
-- Paperwhite 7th gen with Extra large set and stays open across a tap on Text size's plus; with focused.on, a bottom
-- swipe up and a top tap in the reader each open the panel and no KOReader menu, and a hold on its header opens
-- KOReader's reader menu; with it off, the same swipe and tap open KOReader's menus and no panel. The panel's Bookmarks
-- and Contents open their lists, on the Paperwhite 7th gen at Extra large and on the Colorsoft: Remove bookmark leaves
-- one of two bookmarks; Contents has the current chapter marked and no nav bar, and a chapter tap closes the screen
-- and moves the page. The panel's Go to page and Find cells open their dialogs: on the page count plus one Go leaves
-- the dialog open and the page alone, and on page 7 it lands there; Find shows a word's hits and KOReader's message for
-- a word the book doesn't hold.
describe("a sheet over a book on the emulator", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-focused-panel.lua"

    -- Opening a book writes its .sdr sidecar beside it (document_metadata_folder defaults to
    -- "doc", frontend/docsettings.lua:102), so the book is copied out of spec/fixtures/library/.
    local function library_with_one_book()
        local dir = os.getenv("KO_HOME") .. "/focused-panel-library"
        if lfs.attributes(dir, "mode") then
            assert.equals(0, os.execute("rm -rf '" .. dir .. "'"))
        end
        assert(lfs.mkdir(dir))
        assert.equals(0, os.execute("cp '" .. root .. "/spec/fixtures/library/frankenstein.epub' '" .. dir .. "/'"))
        return dir
    end

    -- A settings file for the plugin holding values, written under KO_HOME.
    local function settings_file(name, values)
        local path = os.getenv("KO_HOME") .. "/focused-panel-" .. name .. ".lua"
        local lines = { "return {", "    [\"schema_version\"] = 1," }
        for key, value in pairs(values) do
            lines[#lines + 1] = string.format("    [%q] = %s,", key, type(value) == "string"
                and string.format("%q", value) or tostring(value))
        end
        lines[#lines + 1] = "}"
        local f = assert(io.open(path, "w"))
        f:write(table.concat(lines, "\n") .. "\n")
        f:close()
        return path
    end

    it("paints over the reader, closes on a row tap and leaves the reader up", function()
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
        assert.is_true(sidecar.sheet_painted)
        assert.is_true(sidecar.sheet_closed)
        assert.is_true(sidecar.reader_shown)
    end)

    it("fits the panel whole on the Paperwhite 7th gen with Extra large set and keeps it open across Text size's plus",
        function()
        local result = driver.capture{
            profile = "paperwhite7",
            plugin_dir = plugin,
            library_dir = library_with_one_book(),
            patches = { scenario },
            shot_screen = "scenario",
            env = { KOPANDA_FOCUSED_STEP = "panel" },
            settings_file = settings_file("fit", { look = "editorial", text_size = "extra_large" }),
        }
        local sidecar = result.sidecar
        assert.is_nil(sidecar.error)
        assert.equals(15, sidecar.areas)
        assert.is_true(sidecar.panel_top > 0, "the panel is taller than the screen")
        assert.is_true(sidecar.panel_bottom <= sidecar.screen_h)
        assert.is_true(sidecar.panel_shown)
        assert.equals(sidecar.font_size_before + 1, sidecar.font_size)
    end)

    -- The hooks step on the Colorsoft under a settings file holding values.
    local function hooks(name, values)
        return driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library_with_one_book(),
            patches = { scenario },
            shot_screen = "scenario",
            env = { KOPANDA_FOCUSED_STEP = "hooks" },
            settings_file = settings_file(name, values),
        }.sidecar
    end

    it("opens the panel for a bottom swipe up and a top tap with focused mode on, and KOReader's menu for a hold on "
        .. "its header", function()
        local sidecar = hooks("on", {})
        assert.is_nil(sidecar.error)
        assert.is_true(sidecar.swipe_panel_shown)
        assert.is_false(sidecar.swipe_config_shown)
        assert.is_true(sidecar.panel_shown)
        assert.is_false(sidecar.menu_shown)
        assert.is_true(sidecar.menu_after_hold)
        assert.is_false(sidecar.panel_after_hold)
    end)

    -- The goto step on profile under a settings file holding values.
    local function go_to(profile, name, values)
        return driver.capture{
            profile = profile,
            plugin_dir = plugin,
            library_dir = library_with_one_book(),
            patches = { scenario },
            shot_screen = "scenario",
            env = { KOPANDA_FOCUSED_STEP = "goto" },
            settings_file = settings_file(name, values),
        }.sidecar
    end

    for _, case in ipairs({
        { "the Paperwhite 7th gen at Extra large", "paperwhite7", "goto-pw7", { text_size = "extra_large" } },
        { "the Colorsoft at the default size", "colorsoft", "goto-colorsoft", {} },
    }) do
        it("opens both lists from the panel on " .. case[1] .. ": Remove bookmark leaves one, back returns to the "
            .. "book; Contents has the current chapter marked, no nav bar, a parent's toggle opens it in place, and a "
            .. "chapter tap closes the screen and moves the page", function()
            local sidecar = go_to(case[2], case[3], case[4])
            assert.is_nil(sidecar.error)
            assert.equals("bookmarks", sidecar.bookmarks_list)
            assert.equals("chapters", sidecar.list)
            assert.is_true(sidecar.rows > 0)
            assert.is_true(sidecar.has_current)
            assert.is_false(sidecar.has_nav)
            assert.is_true(sidecar.page >= 1 and sidecar.page <= sidecar.pages)
            assert.equals(2, sidecar.bookmarks_before)
            assert.equals(1, sidecar.bookmarks_after)
            assert.is_true(sidecar.sheet_closed)
            assert.equals("bookmarks", sidecar.list_after_remove)
            assert.is_true(sidecar.back_closed)
            assert.is_true(sidecar.visible_after > sidecar.visible_before)
            assert.is_true(sidecar.toggle_kept)
            assert.is_true(sidecar.goto_closed)
            assert.is_true(sidecar.page_changed)
        end)
    end

    it("goes to a page and finds a word through the panel's cells, on a real book", function()
        local sidecar = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library_with_one_book(),
            patches = { scenario },
            shot_screen = "scenario",
            env = { KOPANDA_FOCUSED_STEP = "dialogs" },
        }.sidecar
        assert.is_nil(sidecar.error)
        assert.is_not.equals(7, sidecar.page_before)
        assert.is_true(sidecar.past_shown)
        assert.equals(sidecar.page_before, sidecar.past_page)
        assert.is_false(sidecar.go_shown)
        assert.equals(7, sidecar.go_page)
        assert.equals(38, sidecar.hits)
        assert.equals("No results in the document", sidecar.no_hits_message)
    end)

    it("opens KOReader's menus for a bottom swipe up and a top tap with focused mode off, and no panel", function()
        local sidecar = hooks("off", { ["focused.on"] = false })
        assert.is_nil(sidecar.error)
        assert.is_false(sidecar.swipe_panel_shown)
        assert.is_true(sidecar.swipe_config_shown)
        assert.is_false(sidecar.panel_shown)
        assert.is_true(sidecar.menu_shown)
    end)
end)
