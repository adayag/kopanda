-- The icon files shipped under kopanda.koplugin/icons/ and icons.lua, the registry that names them.
describe("icons", function()
    local harness = require("plugin_harness")
    local lfs = require("libs/libkoreader-lfs")
    local RenderImage = require("ui/renderimage")
    local icons_dir = harness.plugin_dir .. "/icons"

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local data = f:read("*a")
        f:close()
        return data
    end

    -- Every SVG file under icons/, as a path relative to the plugin root, sorted. Other files there
    -- (a licence notice, a stray .DS_Store) are not icons.
    local function icon_files()
        local files = {}
        if lfs.attributes(icons_dir, "mode") == "directory" then
            for entry in lfs.dir(icons_dir) do
                if entry:match("^[^.].*%.svg$") then
                    files[#files + 1] = "icons/" .. entry
                end
            end
        end
        table.sort(files)
        return files
    end

    local Icons, Fonts
    setup(function()
        harness.load()
        Icons = package.loaded["icons"]
        Fonts = package.loaded["fonts"]
    end)

    it("registers every icon the canvas draws", function()
        local ids = {}
        for _, entry in ipairs(Icons.entries) do
            ids[#ids + 1] = entry.id
        end
        table.sort(ids)
        assert.same({
            "authors", "back", "bookmark", "check", "close", "folder", "history", "home", "info",
            "layout", "library", "list", "moon", "open_book", "plugin_missing", "power",
            "rotation_lock", "screenshot", "series", "settings", "sun", "sync", "terminal", "wifi",
            "wifi_off",
        }, ids)
    end)

    it("has one entry per svg file under icons/ and a file for every entry", function()
        local registered = {}
        for _, entry in ipairs(Icons.entries) do
            registered[#registered + 1] = entry.file
        end
        table.sort(registered)
        assert.same(icon_files(), registered)
    end)

    it("gives every entry a unique id, a label, a non-empty used_in and an svg file", function()
        local seen = {}
        for _, entry in ipairs(Icons.entries) do
            assert.is_string(entry.id)
            assert.truthy(entry.id:match("^[a-z][a-z_]*$"), entry.id .. " is not lower snake case")
            assert.is_nil(seen[entry.id], entry.id .. " is registered twice")
            seen[entry.id] = true
            assert.is_string(entry.label, entry.id .. " has no label")
            assert.truthy(#entry.label > 0, entry.id .. " has an empty label")
            assert.is_table(entry.used_in, entry.id .. " has no used_in")
            assert.truthy(#entry.used_in > 0, entry.id .. " has an empty used_in")
            for _, place in ipairs(entry.used_in) do
                assert.is_string(place, entry.id)
                assert.truthy(#place > 0, entry.id .. " has an empty place")
            end
            assert.equals("icons/" .. entry.id .. ".svg", entry.file)
        end
    end)

    it("resolves an id to its file through the plugin path and an unknown id to nil", function()
        for _, entry in ipairs(Icons.entries) do
            assert.equals(Fonts.path(entry.file), Icons.path(entry.id))
        end
        assert.equals(harness.plugin_dir .. "/icons/home.svg", Icons.path("home"))
        assert.is_nil(Icons.path("no_such_icon"))
        assert.is_nil(Icons.path(nil))
    end)

    it("keeps no currentColor in any icon file", function()
        for _, file in ipairs(icon_files()) do
            assert.is_nil(read(harness.plugin_dir .. "/" .. file):find("currentColor", 1, true), file)
        end
    end)

    it("renders every icon through RenderImage in opaque black ink", function()
        assert.truthy(#Icons.entries > 0)
        for _, entry in ipairs(Icons.entries) do
            local bb = RenderImage:renderSVGImageFile(Icons.path(entry.id), 48, 48)
            assert.truthy(bb, entry.id .. " did not render")
            local inked, coloured, max_alpha = 0, 0, 0
            for y = 0, bb:getHeight() - 1 do
                for x = 0, bb:getWidth() - 1 do
                    local c = bb:getPixel(x, y)
                    if c.alpha > 0 then
                        inked = inked + 1
                        if c.alpha > max_alpha then
                            max_alpha = c.alpha
                        end
                        if c.r ~= 0 or c.g ~= 0 or c.b ~= 0 then
                            coloured = coloured + 1
                        end
                    end
                end
            end
            bb:free()
            assert.truthy(inked > 0, entry.id .. " rendered no pixels")
            assert.equals(0, coloured, entry.id .. " has non-black pixels")
            assert.equals(255, max_alpha, entry.id .. " has no fully opaque pixel")
        end
    end)

    it("names an svg file in no plugin Lua file but icons.lua", function()
        local naming = {}
        for _, file in ipairs(harness.plugin_files()) do
            if file ~= "icons.lua" and read(harness.plugin_dir .. "/" .. file):find(".svg", 1, true) then
                naming[#naming + 1] = file
            end
        end
        assert.same({}, naming)
    end)
end)
