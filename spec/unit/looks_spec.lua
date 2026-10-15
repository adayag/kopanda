-- The two looks' token tables (looks/editorial.lua, looks/diner.lua) and looks.lua, which picks
-- the active look and the palette variant (C5).
describe("looks", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local ids = { "editorial", "diner" }

    -- A look file run with no globals at all, as pure data must run: no require, no functions
    -- from the environment.
    local function load_look(id)
        local chunk = assert(loadfile(harness.plugin_dir .. "/looks/" .. id .. ".lua"))
        setfenv(chunk, {})
        return chunk()
    end

    -- Every key path in t that ends at a non-table value, as dotted strings, sorted.
    local function paths(t)
        local out = {}
        local function walk(node, prefix)
            for k, v in pairs(node) do
                local path = prefix .. tostring(k)
                if type(v) == "table" then
                    walk(v, path .. ".")
                else
                    out[#out + 1] = path
                end
            end
        end
        walk(t, "")
        table.sort(out)
        return out
    end

    local function keys(t)
        local out = {}
        for k in pairs(t) do
            out[#out + 1] = k
        end
        table.sort(out)
        return out
    end

    -- Calls f(path, key, value) for every non-table value outside the palettes and faces.
    local function each_style_value(look, f)
        local function walk(node, prefix)
            for k, v in pairs(node) do
                local path = prefix .. tostring(k)
                if type(v) == "table" then
                    walk(v, path .. ".")
                else
                    f(path, k, v)
                end
            end
        end
        for k, v in pairs(look) do
            if k ~= "palettes" and k ~= "faces" then
                if type(v) == "table" then
                    walk(v, k .. ".")
                else
                    f(k, k, v)
                end
            end
        end
    end

    local looks = {}
    setup(function()
        for _, id in ipairs(ids) do
            looks[id] = load_look(id)
        end
    end)

    describe("token tables", function()
        it("load as pure data with no globals", function()
            for _, id in ipairs(ids) do
                assert.is_table(looks[id], id)
                assert.is_table(looks[id].palettes, id)
                assert.is_table(looks[id].faces, id)
            end
        end)

        it("declare identical token paths in both looks", function()
            local editorial, diner = paths(looks.editorial), paths(looks.diner)
            assert.truthy(#editorial > 40, "too few tokens: " .. #editorial)
            for _, wanted in ipairs({ "faces.display.file", "faces.accent.file", "palettes.grey.paper",
                    "stroke.outline", "shadow.cover.color", "radius.cover", "tile.outline_color",
                    "progress.fill_grey", "sheet.rule_color", "chip.fill_color", "label.size" }) do
                local found = false
                for _, path in ipairs(diner) do
                    found = found or path == wanted
                end
                assert.is_true(found, wanted)
            end
            assert.same(diner, editorial)
        end)

        it("declare the same roles in the day, night and grey palettes of each look", function()
            for _, id in ipairs(ids) do
                local palettes = looks[id].palettes
                assert.same({ "day", "grey", "night" }, keys(palettes), id)
                local roles = keys(palettes.day)
                for _, role in ipairs({ "paper", "ink", "muted", "text", "hairline", "hairline_light",
                        "teal", "pink", "mustard", "outline", "shadow" }) do
                    assert.is_not_nil(palettes.day[role], id .. " has no " .. role)
                end
                assert.same(roles, keys(palettes.night), id .. " night")
                assert.same(roles, keys(palettes.grey), id .. " grey")
            end
        end)

        it("give every palette value as false or #rrggbb that colorFromString reads", function()
            for _, id in ipairs(ids) do
                for variant, palette in pairs(looks[id].palettes) do
                    for role, value in pairs(palette) do
                        local where = id .. " " .. variant .. " " .. role
                        if value ~= false then
                            assert.is_string(value, where)
                            assert.truthy(value:match("^#%x%x%x%x%x%x$"), where .. " = " .. value)
                            assert.is_not_nil(Blitbuffer.colorFromString(value), where)
                        end
                    end
                end
            end
        end)

        it("give every grey palette colour equal red, green and blue", function()
            for _, id in ipairs(ids) do
                for role, value in pairs(looks[id].palettes.grey) do
                    if value then
                        local r, g, b = value:match("^#(%x%x)(%x%x)(%x%x)$")
                        assert.is_true(r:lower() == g:lower() and g:lower() == b:lower(),
                            id .. " grey " .. role .. " = " .. value)
                    end
                end
            end
        end)

        it("keep roles that differ by day distinct in grey", function()
            for _, id in ipairs(ids) do
                local day, grey = looks[id].palettes.day, looks[id].palettes.grey
                for a, a_day in pairs(day) do
                    for b, b_day in pairs(day) do
                        if a < b and a_day and b_day and a_day ~= b_day and grey[a] and grey[b] then
                            assert.is_not.equals(grey[a], grey[b], id .. ": " .. a .. " and " .. b)
                        end
                    end
                end
            end
        end)

        it("name colours outside the palettes only by palette role", function()
            for _, id in ipairs(ids) do
                local look = looks[id]
                each_style_value(look, function(path, key, value)
                    local where = id .. " " .. path
                    assert.is_true(type(value) == "number" or type(value) == "boolean"
                        or type(value) == "string", where)
                    if type(value) ~= "string" then
                        return
                    end
                    if tostring(key):match("color$") then
                        assert.is_not_nil(look.palettes.day[value], where .. " names no palette role: " .. value)
                    elseif key == "face" then
                        assert.is_table(look.faces[value], where .. " names no face: " .. value)
                    elseif key == "fill_grey" then
                        assert.equals("hatch_135", value, where)
                    else
                        error(where .. " is a string that is neither a role, a face nor a marker: " .. value)
                    end
                end)
            end
        end)

        it("mark Diner's grey progress fill as a 135 degree hatch and Editorial's as none", function()
            assert.equals("hatch_135", looks.diner.progress.fill_grey)
            assert.is_false(looks.editorial.progress.fill_grey)
        end)

        it("give each face a file and a label, or false for a face the look has none of", function()
            for _, id in ipairs(ids) do
                for role, face in pairs(looks[id].faces) do
                    local where = id .. " " .. role
                    if face.file then
                        assert.truthy(face.file:match("^fonts/[^/]+/[^/]+%.ttf$"), where)
                        assert.is_string(face.label, where)
                    else
                        assert.is_false(face.file, where)
                        assert.is_false(face.label, where)
                    end
                end
            end
            assert.is_false(looks.editorial.faces.accent.file)
            assert.is_string(looks.diner.faces.accent.file)
        end)
    end)

    describe("Looks", function()
        local Looks, Settings

        before_each(function()
            harness.load()
            Looks = package.loaded["looks"]
            Settings = package.loaded["settings"]
        end)

        after_each(function()
            Settings._reset()
            os.remove(harness.settings_file)
            os.remove(harness.settings_file .. ".old")
            os.remove(harness.state_dir)
        end)

        it("is loaded with both look files when the plugin loads", function()
            assert.is_table(Looks)
            assert.is_table(package.loaded["looks/editorial"])
            assert.is_table(package.loaded["looks/diner"])
        end)

        it("lists the looks in the swatch's column order", function()
            assert.same({ "editorial", "diner" }, Looks.ids())
        end)

        it("returns a look's tokens by id and nil for an unknown id", function()
            assert.same(looks.editorial, Looks.get("editorial"))
            assert.same(looks.diner, Looks.get("diner"))
            assert.is_nil(Looks.get("cover_first"))
        end)

        it("is Diner with no settings file and Editorial once the look is set to it", function()
            assert.is_nil(require("libs/libkoreader-lfs").attributes(harness.settings_file, "mode"))
            assert.equals(Looks.get("diner"), Looks.active())
            assert.is_true(Settings.set("look", "editorial"))
            assert.equals(Looks.get("editorial"), Looks.active())
        end)

        describe("variant", function()
            local had, previous
            before_each(function()
                had = G_reader_settings:has("color_rendering")
                previous = G_reader_settings:readSetting("color_rendering")
            end)
            after_each(function()
                if had then
                    G_reader_settings:saveSetting("color_rendering", previous)
                else
                    G_reader_settings:delSetting("color_rendering")
                end
            end)

            it("is grey when colour rendering is off", function()
                G_reader_settings:saveSetting("color_rendering", false)
                assert.is_false(require("device").screen:isColorEnabled())
                assert.equals("grey", Looks.variant())
            end)

            it("is day when colour rendering is on", function()
                G_reader_settings:saveSetting("color_rendering", true)
                assert.is_true(require("device").screen:isColorEnabled())
                assert.equals("day", Looks.variant())
            end)
        end)

        describe("color", function()
            it("reads a token's hex as a KOReader colour", function()
                local color = Looks.color("#6fb3ab")
                assert.is_not_nil(color)
                assert.equals(0x6f, color:getR())
                assert.equals(0xb3, color:getG())
                assert.equals(0xab, color:getB())
            end)

            it("returns nil without raising for a value that is not a colour", function()
                for _, bad in ipairs({ "#6fb3a", "#zzzzzz", "", 12 }) do
                    local ok, color = pcall(Looks.color, bad)
                    assert.is_true(ok, tostring(bad) .. ": " .. tostring(color))
                    assert.is_nil(color, tostring(bad))
                end
                local ok, color = pcall(Looks.color, nil)
                assert.is_true(ok, tostring(color))
                assert.is_nil(color)
            end)
        end)
    end)
end)
