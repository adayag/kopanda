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
            "action", "authors", "back", "bookmark", "check", "chevron_down", "chevron_up", "close",
            "download", "folder", "forward", "history", "home", "info", "layout", "library", "list", "moon",
            "open_book", "plugin_missing", "plus", "power", "quick_settings", "rotation_lock", "screenshot",
            "series", "settings", "sun", "sync", "terminal", "wifi", "wifi_off",
        }, ids)
    end)

    -- The title bar draws plus, or check in select mode (title-bar feature, D10).
    it("uses plus and check in the title bar", function()
        local places = {}
        for _, entry in ipairs(Icons.entries) do
            places[entry.id] = {}
            for _, place in ipairs(entry.used_in) do
                places[entry.id][place] = true
            end
        end
        assert.is_true(places.plus["title bar"])
        assert.is_true(places.check["title bar"])
    end)

    -- The launcher draws quick_settings as the quick-settings sheet's entry, and the sheet's Wi-Fi
    -- cell draws wifi_off when the radio is off (quick-settings feature, D9).
    it("uses quick_settings in the launcher and wifi_off in quick settings", function()
        local places = {}
        for _, entry in ipairs(Icons.entries) do
            places[entry.id] = {}
            for _, place in ipairs(entry.used_in) do
                places[entry.id][place] = true
            end
        end
        assert.is_true(places.quick_settings and places.quick_settings.launcher)
        assert.is_true(places.wifi_off["quick settings"])
    end)

    -- The library draws forward and back as the pager's arrows and back as the folder's back mark,
    -- chevron_down after each picker and download on a book not downloaded (cover-grid feature, D14).
    it("uses forward, back, chevron_down and download in the library", function()
        local places = {}
        for _, entry in ipairs(Icons.entries) do
            places[entry.id] = {}
            for _, place in ipairs(entry.used_in) do
                places[entry.id][place] = true
            end
        end
        for _, id in ipairs({ "forward", "back", "chevron_down", "download" }) do
            assert.is_true(places[id] and places[id].library, id)
        end
    end)

    -- forward is back mirrored, so the pager's two arrows match (back.svg's M15 5l-7 7 7 7); download
    -- is the boards' arrow to a line (Main.dc.html:67, GridA.dc.html:67).
    it("draws forward as back's mirror and download as the boards' arrow to a line", function()
        local function path_of(id)
            return read(Icons.path(id)):match('<path d="([^"]+)"')
        end
        assert.equals("M15 5l-7 7 7 7", path_of("back"))
        assert.equals("M9 5l7 7-7 7", path_of("forward"))
        assert.equals("M12 4v12M6 11l6 6 6-6M5 20h14", path_of("download"))
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

    -- The owner's weight, chosen from a render at launcher and nav sizes: 1.6 went faint at 40 px.
    it("strokes every icon at width 2, the check mark at 3", function()
        for _, file in ipairs(icon_files()) do
            local widths = {}
            for width in read(harness.plugin_dir .. "/" .. file):gmatch('stroke%-width="([%d.]+)"') do
                widths[#widths + 1] = width
            end
            assert.are.same({ file == "icons/check.svg" and "3" or "2" }, widths, file)
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
