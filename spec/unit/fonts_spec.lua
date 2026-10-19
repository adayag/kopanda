-- The font files shipped under kopanda.koplugin/fonts/ and fonts.lua, which loads them by path.
describe("fonts", function()
    local harness = require("plugin_harness")
    local lfs = require("libs/libkoreader-lfs")
    local sha256 = require("ffi/sha2").sha256
    local Font = require("ui/font")
    local fonts_dir = harness.plugin_dir .. "/fonts"

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local data = f:read("*a")
        f:close()
        return data
    end

    local function be16(data, offset)
        local a, b = data:byte(offset, offset + 1)
        return a * 256 + b
    end

    -- Every .ttf under fonts/, as a path relative to the plugin root, sorted.
    local function ttf_files()
        local files = {}
        local function walk(dir, rel)
            for entry in lfs.dir(dir) do
                if entry ~= "." and entry ~= ".." then
                    local path = dir .. "/" .. entry
                    if lfs.attributes(path, "mode") == "directory" then
                        walk(path, rel .. "/" .. entry)
                    elseif entry:match("%.ttf$") then
                        files[#files + 1] = rel .. "/" .. entry
                    end
                end
            end
        end
        if lfs.attributes(fonts_dir, "mode") == "directory" then
            walk(fonts_dir, "fonts")
        end
        table.sort(files)
        return files
    end

    -- The table tags of a TrueType file: numTables at offset 4, then 16-byte records from
    -- offset 12, each starting with its 4-byte tag.
    local function table_tags(data)
        local tags = {}
        for i = 0, be16(data, 5) - 1 do
            local at = 13 + 16 * i
            tags[#tags + 1] = data:sub(at, at + 3)
        end
        return tags
    end

    -- The path from the current directory to an absolute path, as ./ followed by ../ steps.
    local function relative_from_cwd(path)
        local function parts(p)
            local list = {}
            for part in p:gmatch("[^/]+") do
                list[#list + 1] = part
            end
            return list
        end
        local from, to = parts(lfs.currentdir()), parts(path)
        local common = 0
        while common < #from and common < #to and from[common + 1] == to[common + 1] do
            common = common + 1
        end
        local steps = { "." }
        for _ = common + 1, #from do
            steps[#steps + 1] = ".."
        end
        for i = common + 1, #to do
            steps[#steps + 1] = to[i]
        end
        return table.concat(steps, "/")
    end

    -- The faces the looks' tables name.
    local look_faces = {
        "fonts/bricolage-grotesque/BricolageGrotesque-Bold.ttf",
        "fonts/bricolage-grotesque/BricolageGrotesque-ExtraBold.ttf",
        "fonts/bricolage-grotesque/BricolageGrotesque-Medium.ttf",
        "fonts/caveat/Caveat-Regular.ttf",
        "fonts/ibm-plex-sans/IBMPlexSans-Medium.ttf",
        "fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf",
        "fonts/newsreader/Newsreader16pt-Medium.ttf",
        "fonts/newsreader/Newsreader16pt-MediumItalic.ttf",
    }

    -- The faces for the looks in docs/plans/2026-10-19-new-looks-design.md, which no look names
    -- yet, each with the family and style its name table gives FreeType.
    local new_look_faces = {
        { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf",
          family = "Atkinson Hyperlegible", style = "Bold" },
        { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Italic.ttf",
          family = "Atkinson Hyperlegible", style = "Italic" },
        { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Regular.ttf",
          family = "Atkinson Hyperlegible", style = "Regular" },
        { file = "fonts/baloo-2/Baloo2-ExtraBold.ttf", family = "Baloo 2", style = "ExtraBold" },
        { file = "fonts/big-shoulders-display/BigShouldersDisplay-Black.ttf",
          family = "Big Shoulders Display", style = "Black" },
        { file = "fonts/nunito/Nunito-Bold.ttf", family = "Nunito", style = "Bold" },
        { file = "fonts/nunito/Nunito-ExtraBold.ttf", family = "Nunito", style = "ExtraBold" },
        { file = "fonts/nunito/Nunito-SemiBoldItalic.ttf", family = "Nunito", style = "SemiBold Italic" },
        { file = "fonts/work-sans/WorkSans-Bold.ttf", family = "Work Sans", style = "Bold" },
        { file = "fonts/work-sans/WorkSans-Medium.ttf", family = "Work Sans", style = "Medium" },
    }

    local Fonts
    setup(function()
        harness.load()
        Fonts = package.loaded["fonts"]
    end)

    it("ships the eight faces the looks use and the ten for the new looks", function()
        local expected = {}
        for _, file in ipairs(look_faces) do
            expected[#expected + 1] = file
        end
        for _, face in ipairs(new_look_faces) do
            expected[#expected + 1] = face.file
        end
        table.sort(expected)
        assert.same(expected, ttf_files())
    end)

    it("keeps every face in a family folder beside its OFL.txt", function()
        for _, file in ipairs(ttf_files()) do
            local family = file:match("^fonts/([^/]+)/[^/]+%.ttf$")
            assert.is_string(family, file .. " is not in a family folder")
            local ofl = fonts_dir .. "/" .. family .. "/OFL.txt"
            assert.equals("file", lfs.attributes(ofl, "mode"), family .. " has no OFL.txt")
            assert.truthy(read(ofl):find("SIL Open Font License", 1, true), family .. "/OFL.txt is not the OFL")
        end
    end)

    it("lists every face in SOURCES.md with its SHA-256", function()
        local sources = read(fonts_dir .. "/SOURCES.md")
        for _, file in ipairs(ttf_files()) do
            local rel = file:gsub("^fonts/", "")
            local line
            for l in sources:gmatch("[^\n]+") do
                if l:find("`" .. rel .. "`", 1, true) then
                    line = l
                end
            end
            assert.is_string(line, rel .. " is not in SOURCES.md")
            -- The row's one 64-digit hex run; the commit is 40 digits.
            local recorded = line:match("%f[%x]" .. string.rep("%x", 64) .. "%f[^%x]")
            assert.equals(sha256(read(harness.plugin_dir .. "/" .. file)), recorded, rel .. " hash")
        end
    end)

    it("ships no variable font", function()
        for _, file in ipairs(ttf_files()) do
            local tags = table_tags(read(harness.plugin_dir .. "/" .. file))
            assert.truthy(#tags > 0, file .. " has no tables")
            -- Every TrueType file has head and cmap: finding them proves the directory was read.
            local seen = {}
            for _, tag in ipairs(tags) do
                seen[tag] = true
            end
            assert.is_true(seen["head"], file .. " has no head table")
            assert.is_true(seen["cmap"], file .. " has no cmap table")
            for _, tag in ipairs(tags) do
                assert.is_not.equals("fvar", tag, file .. " has an fvar table")
            end
        end
    end)

    it("loads every face through Font:getFace by absolute and by ./-relative path", function()
        for _, file in ipairs(ttf_files()) do
            local absolute = harness.plugin_dir .. "/" .. file
            local relative = relative_from_cwd(absolute)
            assert.truthy(relative:find("^%./"), relative)
            assert.truthy(relative:find("/%.%./"), relative .. " has no ../ step")
            assert.truthy(Font:getFace(absolute, 20), absolute)
            assert.truthy(Font:getFace(relative, 20), relative)
        end
    end)

    it("resolves paths from the plugin directory the loader gave the plugin", function()
        local plugin = require("pluginloader").enabled_plugins[1]
        assert.equals(plugin.path .. "/fonts/x.ttf", Fonts.path("fonts/x.ttf"))
        assert.equals(harness.plugin_dir .. "/fonts/x.ttf", Fonts.path("fonts/x.ttf"))
    end)

    it("prefixes ./ to a relative plugin directory and leaves an absolute one alone", function()
        assert.equals("./plugins/kopanda.koplugin/fonts/x.ttf", Fonts._join("plugins/kopanda.koplugin", "fonts/x.ttf"))
        assert.equals("./plugins/kopanda.koplugin/fonts/x.ttf",
            Fonts._join("./plugins/kopanda.koplugin", "fonts/x.ttf"))
        assert.equals("/mnt/us/koreader/plugins/kopanda.koplugin/fonts/x.ttf",
            Fonts._join("/mnt/us/koreader/plugins/kopanda.koplugin", "fonts/x.ttf"))
    end)

    -- Stable KOReader (v2026.07.x, frontend/ui/font.lua:306) joins every face name onto
    -- FontList.fontdir, even a path; the pinned build takes a / or ./ name as a path
    -- (font.lua:307-312, since c4f1127). The name Fonts.face hands getFace must resolve both ways.
    it("hands getFace a name that resolves to the file with and without the fonts folder prepended", function()
        local FontList = require("fontlist")
        local ffiUtil = require("ffi/util")
        for _, file in ipairs(ttf_files()) do
            local name = Fonts.face_name(file)
            assert.is_nil(name:find("^/"), name)
            assert.is_nil(name:find("^%./"), name)
            local expected = ffiUtil.realpath(harness.plugin_dir .. "/" .. file)
            assert.equals(expected, ffiUtil.realpath(FontList.fontdir .. "/" .. name), file)
            assert.truthy(Font:getFace(name, 20), name)
        end
    end)

    it("falls back to the plain plugin path for a file that doesn't exist", function()
        assert.equals(Fonts.path("fonts/nope/missing.ttf"), Fonts.face_name("fonts/nope/missing.ttf"))
    end)

    it("returns a face for a shipped file", function()
        local face = Fonts.face("fonts/caveat/Caveat-Regular.ttf", 20)
        assert.truthy(face)
        assert.truthy(face.ftsize)
    end)

    it("ships and loads every face a look names", function()
        local named = 0
        for _, id in ipairs({ "editorial", "diner" }) do
            for role, face in pairs(package.loaded["looks"].get(id).faces) do
                if face.file then
                    named = named + 1
                    local where = id .. " " .. role .. ": " .. face.file
                    assert.equals("file", lfs.attributes(harness.plugin_dir .. "/" .. face.file, "mode"), where)
                    assert.truthy(Fonts.face(face.file, 20), where)
                end
            end
        end
        assert.equals(9, named)
    end)

    it("names in the looks' tables exactly the eight look faces", function()
        local seen, files = {}, {}
        for _, id in ipairs({ "editorial", "diner" }) do
            for _, face in pairs(package.loaded["looks"].get(id).faces) do
                if face.file and not seen[face.file] then
                    seen[face.file] = true
                    files[#files + 1] = face.file
                end
            end
        end
        table.sort(files)
        assert.same(look_faces, files)
    end)

    -- FTSize:hasGlyph and :renderGlyph read the face getFace opened (ffi/freetype.lua:74-96), and
    -- its family and style are FreeType's reading of that file, so a wrong or fallback file fails.
    it("renders a glyph from each face for the new looks through Fonts.face", function()
        local ffi = require("ffi")
        for _, expected in ipairs(new_look_faces) do
            local face = Fonts.face(expected.file, 20)
            assert.truthy(face, expected.file)
            local ft_face = face.ftsize.face
            assert.equals(expected.family, ffi.string(ft_face.family_name), expected.file)
            assert.equals(expected.style, ffi.string(ft_face.style_name), expected.file)
            assert.is_true(face.ftsize:hasGlyph(0x48), expected.file .. " has no H")
            local glyph = face.ftsize:renderGlyph(0x48)
            assert.truthy(glyph.bb:getWidth() > 0 and glyph.bb:getHeight() > 0, expected.file .. " drew no H")
            assert.truthy(glyph.ax > 0, expected.file .. " H has no advance")
        end
    end)

    -- The look faces have no U+2011 (non-breaking hyphen), so KOReader would draw it from a
    -- fallback face; plugin strings write a plain hyphen instead.
    it("finds no U+2011 in any plugin source, raw or escaped", function()
        local files = harness.plugin_files()
        assert.truthy(#files > 0)
        for _, file in ipairs(files) do
            local source = read(harness.plugin_dir .. "/" .. file)
            assert.is_nil(source:find("\226\128\145", 1, true), file .. " has a raw U+2011")
            local lower = source:lower()
            assert.is_nil(lower:find("\\u{0*2011}"), file .. " has a \\u{} escaped U+2011")
            assert.is_nil(lower:find("\\226\\128\\145", 1, true), file .. " has a decimal escaped U+2011")
            assert.is_nil(lower:find("\\xe2\\x80\\x91", 1, true), file .. " has a hex escaped U+2011")
        end
    end)

    it("returns nil for a missing file without raising", function()
        local ok, face = pcall(Fonts.face, "fonts/nope/missing.ttf", 20)
        assert.is_true(ok, tostring(face))
        assert.is_nil(face)
    end)

    it("returns nil for a non-string path without raising", function()
        local ok, face = pcall(Fonts.face, nil, 20)
        assert.is_true(ok, tostring(face))
        assert.is_nil(face)
    end)
end)
