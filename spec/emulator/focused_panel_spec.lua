-- A KoPanda sheet over an open book: the focused-panel scenario patch opens the one book in the library and runs
-- one step per capture (spec/emulator/scenarios/2-scenario-focused-panel.lua), reporting on the "scenario" screen:
-- a probe sheet paints over the reader, closes and leaves the reader up; the focused panel fits whole on the
-- Paperwhite 7th gen with Extra large set and stays open across a tap on Text size's plus; with focused.on, a bottom
-- swipe up and a top tap in the reader each open the panel and no KOReader menu, and a hold on its header opens
-- KOReader's reader menu; with it off, the same swipe and tap open KOReader's menus and no panel. The panel's Go to
-- opens the Go to screen on Chapters with the current chapter marked and no nav bar, on the Paperwhite 7th gen at
-- Extra large and on the Colorsoft; Remove bookmark there leaves one of two bookmarks, and a chapter tap closes the
-- screen and moves the page.
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
        assert.equals(12, sidecar.areas)
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
        it("opens the Go to screen from the panel on " .. case[1] .. ": Chapters with the current chapter marked, no "
            .. "nav bar; Remove bookmark leaves one, a parent's toggle opens it in place, and a chapter tap closes "
            .. "the screen and moves the page", function()
            local sidecar = go_to(case[2], case[3], case[4])
            assert.is_nil(sidecar.error)
            assert.equals("chapters", sidecar.tab)
            assert.is_true(sidecar.rows > 0)
            assert.is_true(sidecar.has_current)
            assert.is_false(sidecar.has_nav)
            assert.is_true(sidecar.page >= 1 and sidecar.page <= sidecar.pages)
            assert.equals(2, sidecar.bookmarks_before)
            assert.equals(1, sidecar.bookmarks_after)
            assert.is_true(sidecar.sheet_closed)
            assert.equals("bookmarks", sidecar.tab_after_remove)
            assert.is_true(sidecar.visible_after > sidecar.visible_before)
            assert.is_true(sidecar.toggle_kept)
            assert.is_true(sidecar.goto_closed)
            assert.is_true(sidecar.page_changed)
        end)
    end

    it("opens KOReader's menus for a bottom swipe up and a top tap with focused mode off, and no panel", function()
        local sidecar = hooks("off", { ["focused.on"] = false })
        assert.is_nil(sidecar.error)
        assert.is_false(sidecar.swipe_panel_shown)
        assert.is_true(sidecar.swipe_config_shown)
        assert.is_false(sidecar.panel_shown)
        assert.is_true(sidecar.menu_shown)
    end)
end)
