-- main.lua requires every KoPanda module at load time: KOReader puts the plugin root on package.path only while it
-- dofile()s main.lua (frontend/pluginloader.lua:242, :269-270). The unit harness keeps the root on package.path
-- throughout, so a module main.lua forgets still loads under every other spec; this one reads main.lua's text for a
-- top-level require of each module, and loads the plugin once to see every module required by loading main.lua alone.
describe("kopanda.koplugin/main.lua", function()
    local harness = require("plugin_harness")

    -- The names main.lua passes to require("..."), with line comments stripped so a
    -- commented-out require does not count.
    local function required_names()
        local names = {}
        for line in io.lines(harness.plugin_dir .. "/main.lua") do
            local code = line:gsub("%-%-.*$", "")
            for name in code:gmatch('require%("([^"]+)"%)') do
                names[name] = true
            end
        end
        return names
    end

    it("requires every KoPanda module", function()
        local modules = harness.module_names()
        assert.is_true(#modules > 0, "module_names() listed no modules")
        local required = required_names()
        local missing = {}
        for _, name in ipairs(modules) do
            if not required[name] then
                missing[#missing + 1] = name
            end
        end
        assert.are.same({}, missing, "main.lua does not require: " .. table.concat(missing, ", "))
    end)

    -- require caches by name across every plugin, and one that loads first keeps the name
    -- (frontend/pluginloader.lua:289, plugins load sorted by path). cwngsync.koplugin's main.lua requires its own
    -- "sleep_screen", which has no install.
    it("starts beside another plugin's sleep_screen module", function()
        local Screensaver = require("ui/screensaver")
        local FileManager = require("apps/filemanager/filemanager")
        package.preload["sleep_screen"] = function()
            return {}
        end
        local ok, err = pcall(function()
            harness.load()
            local fm = harness.show_fm()
            fm:onClose()
            assert.is_not.equals(harness.screensaver_setup, Screensaver.setup)
            assert.is_not.equals(harness.fm_setup_layout, FileManager.setupLayout)
        end)
        package.preload["sleep_screen"] = nil
        package.loaded["sleep_screen"] = nil
        assert(ok, err)
    end)

    it("still installs the file browser's bar when the sleep screen can't install", function()
        local FileManager = require("apps/filemanager/filemanager")
        harness.load()
        require("kopanda_sleep_screen").install = function()
            error("no sleep screen")
        end
        local fm = harness.show_fm()
        fm:onClose()
        assert.is_not.equals(harness.fm_setup_layout, FileManager.setupLayout)
    end)

    it("loads every KoPanda module when the plugin loads", function()
        local modules = harness.module_names()
        assert.is_true(#modules > 0, "module_names() listed no modules")
        -- A stale cache entry from an earlier require would hide a module main.lua no longer
        -- loads, so each starts as a sentinel that harness.load() must unload and main.lua
        -- must replace.
        local stale = {}
        for _, name in ipairs(modules) do
            package.loaded[name] = stale
        end
        harness.load()
        local missing = {}
        for _, name in ipairs(modules) do
            if package.loaded[name] == nil or package.loaded[name] == stale then
                missing[#missing + 1] = name
            end
        end
        assert.are.same({}, missing, "not loaded: " .. table.concat(missing, ", "))
    end)
end)
