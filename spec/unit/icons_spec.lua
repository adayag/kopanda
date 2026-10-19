-- The icon files shipped under kopanda.koplugin/icons/ and icons.lua, the registry that names them:
-- the default Lucide files at the top of icons/, and one vendored set per new look under
-- icons/<set id>/, recorded in icons/SOURCES.md.
describe("icons", function()
    local harness = require("plugin_harness")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local sha256 = require("ffi/sha2").sha256
    local RenderImage = require("ui/renderimage")
    local icons_dir = harness.plugin_dir .. "/icons"
    local SETS = { "mingcute-line", "phosphor-bold", "phosphor-fill" }

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

    -- Every entry in icons/<set>/ but . and .., sorted.
    local function set_entries(set)
        local entries = {}
        for entry in lfs.dir(icons_dir .. "/" .. set) do
            if entry ~= "." and entry ~= ".." then
                entries[#entries + 1] = entry
            end
        end
        table.sort(entries)
        return entries
    end

    -- Renders the file at 48 px and asserts it inked some pixels, all black, one fully opaque.
    local function assert_black_ink(path, what)
        local bb = RenderImage:renderSVGImageFile(path, 48, 48)
        assert.truthy(bb, what .. " did not render")
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
        assert.truthy(inked > 0, what .. " rendered no pixels")
        assert.equals(0, coloured, what .. " has non-black pixels")
        assert.equals(255, max_alpha, what .. " has no fully opaque pixel")
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
            "download", "eye_off", "filter", "folder", "folder_open", "forward", "history", "home",
            "home_plus", "info", "layout", "library", "list", "moon", "open_book", "plugin_missing", "plus",
            "power", "quick_settings", "refresh", "rotation_lock", "screenshot", "series", "settings", "sort",
            "sun", "sync", "terminal", "trash", "wifi", "wifi_off",
        }, ids)
    end)

    -- The library's three hold sheets draw seven new icons and library: the book sheet's Add to the home and Delete,
    -- the folder sheet's Open, Set as library root and Hide, and the library sheet's Sort, Show and Refresh and
    -- Hidden folders (eye_off).
    it("uses the context menu's icons in the book, library folder and library sheets", function()
        local places = {}
        for _, entry in ipairs(Icons.entries) do
            places[entry.id] = {}
            for _, place in ipairs(entry.used_in) do
                places[entry.id][place] = true
            end
        end
        local expected = {
            ["book sheet"] = { "home_plus", "trash" },
            ["library folder sheet"] = { "folder_open", "eye_off", "library" },
            ["library sheet"] = { "sort", "filter", "refresh", "eye_off" },
        }
        for place, ids in pairs(expected) do
            for _, id in ipairs(ids) do
                assert.is_true(places[id] and places[id][place], id .. " in " .. place)
            end
        end
    end)

    -- The title bar draws plus, or check in select mode.
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

    -- The launcher draws quick_settings as the quick-settings sheet's entry, and the sheet's Wi-Fi cell draws wifi_off
    -- when the radio is off.
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

    -- The library draws forward and back as the pager's arrows and back as the folder's back mark, chevron_down after
    -- each picker and download on a book not downloaded.
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

    -- The series and authors screens draw back as their back control and the pager's arrow, forward as the pager's
    -- other arrow and download on a path-less book.
    it("uses back, forward and download in the series and authors screens", function()
        local places = {}
        for _, entry in ipairs(Icons.entries) do
            places[entry.id] = {}
            for _, place in ipairs(entry.used_in) do
                places[entry.id][place] = true
            end
        end
        for _, id in ipairs({ "back", "forward", "download" }) do
            assert.is_true(places[id] and places[id].series, id .. " in series")
            assert.is_true(places[id] and places[id].authors, id .. " in authors")
        end
    end)

    -- forward is back mirrored, so the pager's two arrows match (back.svg's M15 5l-7 7 7 7); download is an arrow to
    -- a line.
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
            assert.equals(Fonts.path(entry.file), Icons.path(entry.id, false))
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

    -- The stroke weight, chosen at launcher and nav sizes: 1.6 went faint at 40 px.
    -- The Lucide files at the top of icons/ only: a vendored set keeps its pack's own drawing.
    it("strokes every Lucide icon at width 2, the check mark at 3", function()
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
            assert_black_ink(Icons.path(entry.id, false), entry.id)
        end
    end)

    -- Riso draws Phosphor Fill, Frosted Phosphor Bold and Toybox MingCute Line (new-looks design,
    -- Icons row), each under icons/<set id>/.
    it("registers the three vendored sets with a label, a licence and their folder", function()
        local ids = {}
        for id, set in pairs(Icons.sets) do
            ids[#ids + 1] = id
            assert.is_string(set.label, id)
            assert.truthy(#set.label > 0, id)
            assert.equals("icons/" .. id, set.dir)
        end
        table.sort(ids)
        assert.same(SETS, ids)
        assert.equals("MIT", Icons.sets["phosphor-fill"].licence)
        assert.equals("MIT", Icons.sets["phosphor-bold"].licence)
        assert.equals("Apache-2.0", Icons.sets["mingcute-line"].licence)
    end)

    it("vendors one file per registry id in every set, beside the pack's licence", function()
        local expected = { "LICENSE.txt" }
        for _, entry in ipairs(Icons.entries) do
            expected[#expected + 1] = entry.id .. ".svg"
        end
        table.sort(expected)
        for _, set in ipairs(SETS) do
            assert.same(expected, set_entries(set), set)
        end
        local mit = read(icons_dir .. "/phosphor-fill/LICENSE.txt")
        assert.truthy(mit:find("MIT License", 1, true))
        assert.equals(mit, read(icons_dir .. "/phosphor-bold/LICENSE.txt"))
        local apache = read(icons_dir .. "/mingcute-line/LICENSE.txt")
        assert.truthy(apache:find("Apache License", 1, true))
        assert.truthy(apache:find("END OF TERMS AND CONDITIONS", 1, true))
    end)

    it("keeps no currentColor and no style in any set file", function()
        for _, set in ipairs(SETS) do
            for _, entry in ipairs(Icons.entries) do
                local data = read(icons_dir .. "/" .. set .. "/" .. entry.id .. ".svg")
                assert.is_nil(data:find("currentColor", 1, true), set .. "/" .. entry.id)
                assert.is_nil(data:find("<style", 1, true), set .. "/" .. entry.id)
            end
        end
    end)

    it("renders every set file through RenderImage in opaque black ink", function()
        for _, set in ipairs(SETS) do
            for _, entry in ipairs(Icons.entries) do
                assert_black_ink(Icons.path(entry.id, set), set .. "/" .. entry.id)
            end
        end
    end)

    -- SOURCES.md has a section per set, "## <set id>", whose table rows are
    -- "| <registry id> | `<pack file>` | <sha256> |".
    it("records every set file in SOURCES.md with its pack file and the hash of the file as shipped", function()
        local rows, set = {}, nil
        for line in read(icons_dir .. "/SOURCES.md"):gmatch("[^\n]+") do
            local heading = line:match("^## (%S+)$")
            if heading then
                set = heading
                rows[set] = {}
            else
                local id, file, hash = line:match("^| ([%w_]+) | `([^`]+)` | (%x+) |$")
                if set and id then
                    assert.is_nil(rows[set][id], set .. "/" .. id .. " recorded twice")
                    rows[set][id] = { file = file, hash = hash }
                end
            end
        end
        for _, s in ipairs(SETS) do
            assert.is_table(rows[s], s .. " has no section")
            local recorded = 0
            for _ in pairs(rows[s]) do
                recorded = recorded + 1
            end
            assert.equals(#Icons.entries, recorded, s)
            for _, entry in ipairs(Icons.entries) do
                local row = rows[s][entry.id]
                assert.is_table(row, s .. "/" .. entry.id .. " not recorded")
                assert.truthy(row.file:match("%.svg$"), s .. "/" .. entry.id)
                assert.equals(sha256(read(icons_dir .. "/" .. s .. "/" .. entry.id .. ".svg")), row.hash,
                    s .. "/" .. entry.id .. " hash")
            end
        end
    end)

    describe("path", function()
        local Looks

        before_each(function()
            Looks = package.loaded["looks"]
        end)

        after_each(function()
            package.loaded["looks"] = Looks
            Icons.sets.stub = nil
        end)

        it("resolves an id to the Lucide file when false names no set", function()
            assert.equals(harness.plugin_dir .. "/icons/home.svg", Icons.path("home", false))
        end)

        it("resolves an id to a named set's file", function()
            assert.equals(harness.plugin_dir .. "/icons/phosphor-fill/home.svg", Icons.path("home", "phosphor-fill"))
            assert.equals(harness.plugin_dir .. "/icons/mingcute-line/wifi_off.svg",
                Icons.path("wifi_off", "mingcute-line"))
            assert.is_nil(Icons.path("no_such_icon", "phosphor-bold"))
        end)

        -- A stub set whose folder, a scratch one under KO_HOME, holds only home.svg; its dir climbs
        -- from the plugin folder to the root and down to it.
        it("falls back to the Lucide file for an id the set lacks", function()
            local dir = harness.state_dir .. "/stub_icons"
            lfs.mkdir(harness.state_dir)
            lfs.mkdir(dir)
            local f = assert(io.open(dir .. "/home.svg", "wb"))
            f:write(read(icons_dir .. "/phosphor-fill/home.svg"))
            f:close()
            local _, depth = harness.plugin_dir:gsub("/[^/]+", "")
            Icons.sets.stub = { label = "Stub", licence = "MIT", dir = ("../"):rep(depth) .. dir:sub(2) }
            local home = Icons.path("home", "stub")
            os.remove(dir .. "/home.svg")
            lfs.rmdir(dir)
            assert.truthy(home and home:find("/stub_icons/home.svg", 1, true), home)
            assert.equals(harness.plugin_dir .. "/icons/wifi.svg", Icons.path("wifi", "stub"))
        end)

        -- A look with a bad token still draws icons: the Lucide files, the bad set logged once.
        it("an unknown set gives Lucide and logs once", function()
            local warn = spy.on(logger, "warn")
            local home = Icons.path("home", "no-such-set")
            local wifi = Icons.path("wifi", "no-such-set")
            local look = { icons = { set = "no-such-set" } }
            package.loaded["looks"] = { active = function() return look end }
            local folder = Icons.path("folder")
            warn:revert()
            assert.equals(harness.plugin_dir .. "/icons/home.svg", home)
            assert.equals(harness.plugin_dir .. "/icons/wifi.svg", wifi)
            assert.equals(harness.plugin_dir .. "/icons/folder.svg", folder)
            assert.spy(warn).was.called(1)
            assert.is_nil(Icons.path("no_such_icon", "no-such-set"))
        end)

        it("resolves through the active look's icon set when no set is asked for", function()
            local look
            package.loaded["looks"] = { active = function() return look end }
            look = { icons = { set = "phosphor-fill" } }
            assert.equals(harness.plugin_dir .. "/icons/phosphor-fill/home.svg", Icons.path("home"))
            assert.equals(harness.plugin_dir .. "/icons/home.svg", Icons.path("home", false))
            look = { icons = { set = false } }
            assert.equals(harness.plugin_dir .. "/icons/home.svg", Icons.path("home"))
            look = {}
            assert.equals(harness.plugin_dir .. "/icons/home.svg", Icons.path("home"))
        end)
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
