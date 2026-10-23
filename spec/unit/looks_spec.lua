-- The looks: the base look (looks/base.lua), every token path with its default; each look's file (looks/<id>.lua, one
-- per id Looks.ids() lists), which declares only what differs from it; and looks.lua, which lays each file over the
-- base, picks the active look, the palette variant and the palette to draw with, night inverted. The tests are rules
-- every look keeps, run over every id; none pins a look's own values.
describe("looks", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local lfs = require("libs/libkoreader-lfs")
    -- Every look id, from looks.lua once the plugin has loaded (setup).
    local ids
    -- Each look's tokens as Looks.get gives them, the base with its file laid over (setup).
    local looks = {}

    -- The home widgets' shapes a look chooses, each token under home with its values: the weather line's order, the
    -- date's line count, the stats joined or spread, the streak word-first or count-first, the featured label, and
    -- the featured authors and chapter and the caption's parts, joined on one line each or split.
    local HOME_CHOICES = {
        weather_order = { "degrees_first", "condition_first" },
        date_lines = { 1, 2 },
        stats_line = { "joined", "spread" },
        stats_streak = { "count_first", "word_first" },
        featured_label = { "now_reading", "continue_reading" },
        featured_details = { "joined", "split" },
    }

    -- A look file run with no globals at all, as pure data must run: no require, no functions
    -- from the environment.
    local function load_look(id)
        local chunk = assert(loadfile(harness.plugin_dir .. "/looks/" .. id .. ".lua"))
        setfenv(chunk, {})
        return chunk()
    end

    -- A table of tokens, not a list: inherit replaces a list whole, so a list is one token.
    local function is_branch(v)
        return type(v) == "table" and v[1] == nil
    end

    -- The paths a look file sets that the base doesn't declare, as dotted strings, sorted: a key
    -- the base lacks, or a table where the base has a value or a value where it has a table.
    local function unknown_paths(own, base)
        local out = {}
        local function walk(mine, theirs, prefix)
            for k, v in pairs(mine) do
                local path = prefix .. tostring(k)
                local declared = theirs[k]
                if declared == nil or (type(v) == "table") ~= (type(declared) == "table") then
                    out[#out + 1] = path
                elseif is_branch(v) then
                    walk(v, declared, path .. ".")
                end
            end
        end
        walk(own, base, "")
        table.sort(out)
        return out
    end

    -- Every key path in t that ends at a non-table value or a list, as dotted strings, sorted.
    local function paths(t)
        local out = {}
        local function walk(node, prefix)
            for k, v in pairs(node) do
                local path = prefix .. tostring(k)
                if is_branch(v) then
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

    setup(function()
        harness.load()
        ids = package.loaded["looks"].ids()
        for _, id in ipairs(ids) do
            looks[id] = package.loaded["looks"].get(id)
        end
        harness.teardown()
    end)

    describe("token tables", function()
        it("load as pure data with no globals", function()
            local base = load_look("base")
            assert.is_table(base.palettes)
            assert.is_table(base.faces)
            for _, id in ipairs(ids) do
                assert.is_table(load_look(id), id)
            end
        end)

        it("give every look every token path the base declares", function()
            local base = paths(load_look("base"))
            assert.truthy(#base > 40, "too few tokens: " .. #base)
            for _, id in ipairs(ids) do
                assert.same(base, paths(looks[id]), id)
            end
            assert.same({ "dash", "plate.radius" }, paths({ dash = { 6, 4 }, plate = { radius = 0 } }))
        end)

        it("set in a look file only token paths the base declares", function()
            local base = load_look("base")
            for _, id in ipairs(ids) do
                assert.same({}, unknown_paths(load_look(id), base), id)
            end
            assert.same({ "plate.glow", "stroke" },
                unknown_paths({ plate = { glow = 1, radius = 0 }, stroke = 2 }, base))
            assert.same({}, unknown_paths({ dash = { 1, 2, 3, 4 } }, { dash = { 1 } }))
        end)

        it("give every look one of each home choice's values", function()
            for _, id in ipairs(ids) do
                for key, values in pairs(HOME_CHOICES) do
                    local value = looks[id].home[key]
                    local known = false
                    for _, allowed in ipairs(values) do
                        known = known or value == allowed
                    end
                    assert.is_true(known, id .. " home." .. key .. " = " .. tostring(value))
                end
            end
        end)

        it("declare the same roles in the day, night and grey palettes of each look", function()
            for _, id in ipairs(ids) do
                local palettes = looks[id].palettes
                assert.same({ "day", "grey", "night" }, keys(palettes), id)
                local roles = keys(palettes.day)
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

        -- on_band is exempt: it is chosen for contrast against the band, not to tell roles apart, and equals ink in
        -- grey on purpose.
        it("keep roles that differ by day distinct in grey", function()
            for _, id in ipairs(ids) do
                local day, grey = looks[id].palettes.day, looks[id].palettes.grey
                for a, a_day in pairs(day) do
                    for b, b_day in pairs(day) do
                        if a < b and a ~= "on_band" and b ~= "on_band"
                                and a_day and b_day and a_day ~= b_day and grey[a] and grey[b] then
                            assert.is_not.equals(grey[a], grey[b], id .. ": " .. a .. " and " .. b)
                        end
                    end
                end
            end
        end)

        -- Colours live in the palettes alone: every other token names one by role, or is false.
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
                    assert.is_nil(value:match("^#%x+$"), where .. " is a colour outside the palettes: " .. value)
                    if tostring(key):match("color$") then
                        assert.is_not_nil(look.palettes.day[value], where .. " names no palette role: " .. value)
                        -- A role false by day but drawn at night or in grey, as Editorial's outline, is
                        -- one the look has.
                        local drawn = false
                        for _, palette in pairs(look.palettes) do
                            drawn = drawn or palette[value] ~= false
                        end
                        assert.is_true(drawn, where .. " names a role this look lacks: " .. value)
                    elseif key == "face" then
                        assert.is_table(look.faces[value], where .. " names no face: " .. value)
                    elseif key == "fill_grey" then
                        assert.equals("hatch_135", value, where)
                    elseif key == "free_space" then
                        assert.truthy(value == "before_last_row" or value == "before_footer", where .. " = " .. value)
                    elseif key == "align" then
                        assert.truthy(value == "top" or value == "bottom", where .. " = " .. value)
                    elseif path == "home." .. tostring(key) and HOME_CHOICES[key] then
                        return -- one of its values, checked by the home choices' own test
                    elseif path == "icons.set" then
                        return -- a vendored set, checked by the icon set's own test
                    else
                        error(where .. " is a string that is neither a role, a face nor a marker: " .. value)
                    end
                end)
            end
        end)

        it("give every type entry a face with a file, a size, case, tracking, line height and a colour role", function()
            local fields = { "color", "face", "line_height", "size", "tracking", "uppercase" }
            for _, id in ipairs(ids) do
                local look = looks[id]
                assert.truthy(next(look.type), id .. " has no type entries")
                for part, entry in pairs(look.type) do
                    local where = id .. " type." .. part
                    assert.same(fields, keys(entry), where)
                    assert.is_table(look.faces[entry.face], where .. " names no face: " .. tostring(entry.face))
                    assert.is_string(look.faces[entry.face].file, where .. " names a face this look lacks")
                    assert.is_string(look.palettes.day[entry.color],
                        where .. " names no palette role this look has: " .. tostring(entry.color))
                    assert.is_number(entry.size, where)
                    assert.is_boolean(entry.uppercase, where)
                    assert.is_number(entry.tracking, where)
                    assert.is_number(entry.line_height, where)
                end
            end
        end)

        it("give every look the insight parts and tokens, Diner's chart and today in its accents", function()
            for _, id in ipairs(ids) do
                local look = looks[id]
                for _, part in ipairs({ "insight_label", "insight_caption", "insight_value", "insight_note" }) do
                    assert.is_table(look.type[part], id .. " " .. part)
                end
                local i = look.insights
                for _, size in ipairs({ "padding", "chart_height", "chart_line_width", "today_ring", "reading_column",
                    "streak_scale", "dot", "dot_gap" }) do
                    assert.is_number(i[size], id .. " " .. size)
                end
                for _, role in ipairs({ "bar_fill_color", "chart_area_color", "chart_line_color", "today_ring_color",
                    "dot_fill_color", "dot_empty_color" }) do
                    assert.is_string(look.palettes.day[i[role]], id .. " " .. role .. " names no palette role")
                end
                for _, gone in ipairs({ "cell_max", "calendar_cell", "level_1_color", "read_fill_color" }) do
                    assert.is_nil(i[gone], id .. " " .. gone)
                end
            end
            local diner = looks.diner
            assert.same({ "teal", "mustard" }, { diner.insights.chart_area_color, diner.insights.today_ring_color })
        end)

        -- The two pickers' lines differ in colour alone, so the header's height measures either
        -- (LibraryTiles.header_height measures library_picker).
        it("set the status picker's label as the sort picker's in its own colour", function()
            for _, id in ipairs(ids) do
                local sort, status = looks[id].type.library_picker, looks[id].type.library_picker_status
                assert.same({ sort.face, sort.size, sort.uppercase, sort.tracking, sort.line_height },
                    { status.face, status.size, status.uppercase, status.tracking, status.line_height }, id)
            end
        end)

        it("give a launcher badge room for its icon and an outline", function()
            for _, id in ipairs(ids) do
                local launcher = looks[id].launcher
                if launcher.badge.size > 0 then
                    assert.is_true(launcher.badge.size >= launcher.icon_size, id .. ": the icon overruns its badge")
                    assert.is_true(launcher.badge.outline_width > 0, id)
                end
            end
        end)

        -- nav_bar.lua:173-177 draws the pill's shadow inside its bottom margin.
        it("give a floating nav margins with room for its shadow", function()
            for _, id in ipairs(ids) do
                local nav = looks[id].nav
                if nav.float then
                    assert.is_true(nav.margin.side > 0 and nav.margin.bottom > 0, id .. " margin")
                    assert.is_true(nav.margin.bottom >= nav.shadow.y, id .. ": the shadow runs off the screen")
                end
            end
        end)

        -- A plate's lightening is lightenRect's opacity.
        it("lighten plates by false or a number above 0 and up to 1", function()
            for _, id in ipairs(ids) do
                for variant, by in pairs(looks[id].plate.lighten) do
                    assert.is_true(by == false or (type(by) == "number" and by > 0 and by <= 1),
                        id .. " plate.lighten." .. variant .. " = " .. tostring(by))
                end
            end
        end)

        it("offset a misregistration that has a colour", function()
            for _, id in ipairs(ids) do
                local m = looks[id].misregister
                if m.color then
                    assert.is_true(m.x > 0 or m.y > 0, id .. ": a misregistration with no offset")
                end
            end
        end)

        -- A shadow is a fill, or with an outline width an outline of that width at the offset.
        it("give every shadow an outline width of false or a positive number", function()
            for _, id in ipairs(ids) do
                local look = looks[id]
                local shadows = { cover = look.shadow.cover, tile = look.shadow.tile, sheet = look.shadow.sheet,
                    library_cover = look.library.cover.shadow }
                for name, shadow in pairs(shadows) do
                    local width = shadow.outline_width
                    assert.is_true(width == false or (type(width) == "number" and width > 0),
                        id .. " " .. name .. " outline_width = " .. tostring(width))
                end
            end
        end)

        it("give every radius as a number of 0 or more", function()
            for _, id in ipairs(ids) do
                local look = looks[id]
                local radii = { cover = look.radius.cover, box = look.radius.box, progress = look.progress.radius,
                    chip = look.chip.radius, sheet = look.sheet.radius, nav = look.nav.radius,
                    title_bar_picker = look.title_bar.picker_radius,
                    library_picker = look.library.header.picker_radius, library_cover = look.library.cover.radius }
                for name, radius in pairs(radii) do
                    assert.is_true(type(radius) == "number" and radius >= 0, id .. " " .. name .. " radius")
                end
            end
        end)

        it("give each face a shipped file and a label, or false for a face the look has none of", function()
            for _, id in ipairs(ids) do
                for role, face in pairs(looks[id].faces) do
                    local where = id .. " " .. role
                    if face.file then
                        assert.truthy(face.file:match("^fonts/[^/]+/[^/]+%.ttf$"), where)
                        assert.equals("file", lfs.attributes(harness.plugin_dir .. "/" .. face.file, "mode"),
                            where .. ": " .. face.file)
                        assert.is_string(face.label, where)
                    else
                        assert.is_false(face.file, where)
                        assert.is_false(face.label, where)
                    end
                end
            end
        end)

        -- The icon set a look draws with: a vendored set's id, its folder shipped, or false for the
        -- registry's default.
        it("draw a vendored icon set, or false for the default", function()
            harness.load()
            local sets = package.loaded["icons"].sets
            harness.teardown()
            for _, id in ipairs(ids) do
                local set = looks[id].icons.set
                if set ~= false then
                    assert.is_table(sets[set], id .. " icons.set names no vendored set: " .. tostring(set))
                    assert.equals("directory", lfs.attributes(harness.plugin_dir .. "/" .. sets[set].dir, "mode"),
                        id .. " " .. set)
                end
            end
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

        it("is loaded with the base and every look file when the plugin loads", function()
            assert.is_table(Looks)
            assert.is_table(package.loaded["looks/base"])
            for _, id in ipairs(Looks.ids()) do
                assert.is_table(package.loaded["looks/" .. id], id)
                assert.is_table(Looks.get(id), id)
            end
        end)

        -- Looks.get lays each look file over the base, once, when looks.lua loads.
        describe("inheriting", function()
            local names, saved

            before_each(function()
                names, saved = { "looks", "looks/base" }, {}
                for _, id in ipairs(Looks.ids()) do
                    names[#names + 1] = "looks/" .. id
                end
                for _, name in ipairs(names) do
                    saved[name] = package.loaded[name]
                end
            end)

            after_each(function()
                for _, name in ipairs(names) do
                    package.loaded[name] = saved[name]
                end
            end)

            -- looks.lua loaded afresh over base and the look files given, every other look file empty.
            local function reload(base, files)
                package.loaded["looks/base"] = base
                for _, id in ipairs(Looks.ids()) do
                    package.loaded["looks/" .. id] = files[id] or {}
                end
                package.loaded["looks"] = nil
                return require("looks")
            end

            it("lets a look file's false override the base's value and keeps what the file leaves out", function()
                local Fresh = reload({ plate = { fill_color = "paper", radius = 4 }, icons = { set = "lucide" } },
                    { frosted = { plate = { fill_color = false } } })
                assert.same({ plate = { fill_color = false, radius = 4 }, icons = { set = "lucide" } },
                    Fresh.get("frosted"))
                assert.same({ plate = { fill_color = "paper", radius = 4 }, icons = { set = "lucide" } },
                    Fresh.get("diner"))
            end)

            it("replaces a list whole", function()
                local Fresh = reload({ dash = { 6, 4, 2 } }, { riso = { dash = { 3 } } })
                assert.same({ 3 }, Fresh.get("riso").dash)
            end)

            it("lays a look file over the base at every depth", function()
                local Fresh = reload({ a = { b = { c = 1, d = 2 } } }, { riso = { a = { b = { c = 9 } } } })
                assert.same({ a = { b = { c = 9, d = 2 } } }, Fresh.get("riso"))
            end)

            it("leaves the look's own file as it was", function()
                local Fresh = reload({ plate = { radius = 4 }, dash = { 6 } },
                    { riso = { plate = { radius = 7 }, dash = { 3 } } })
                local riso = Fresh.get("riso")
                riso.plate.radius = 9
                riso.dash[1] = 5
                assert.same({ plate = { radius = 7 }, dash = { 3 } }, package.loaded["looks/riso"])
            end)

            it("gives each look its own tables, the same ones each time, and leaves the base as it was", function()
                local base = { plate = { radius = 4 } }
                local Fresh = reload(base, {})
                Fresh.get("diner").plate.radius = 9
                assert.equals(9, Fresh.get("diner").plate.radius)
                assert.equals(4, Fresh.get("editorial").plate.radius)
                assert.equals(4, base.plate.radius)
            end)
        end)

        it("lists the looks in the swatch's order, Editorial, Diner, Riso, Toybox then Frosted first", function()
            local listed = Looks.ids()
            assert.same({ "editorial", "diner", "riso", "toybox", "frosted" },
                { listed[1], listed[2], listed[3], listed[4], listed[5] })
        end)

        it("lists a fresh copy each time", function()
            local listed = Looks.ids()
            local count = #listed
            listed[1] = "changed"
            listed[count + 1] = "added"
            assert.equals("editorial", Looks.ids()[1])
            assert.equals(count, #Looks.ids())
        end)

        -- Adding a look is one id in looks.lua, one token file and one choice of the look setting.
        it("lists one id per look file but the base and per choice of the look setting", function()
            local listed = Looks.ids()
            table.sort(listed)
            local files = {}
            for name in require("libs/libkoreader-lfs").dir(harness.plugin_dir .. "/looks") do
                local id = name:match("^(.+)%.lua$")
                if id and id ~= "base" then
                    files[#files + 1] = id
                end
            end
            table.sort(files)
            assert.same(files, listed)
            local choices
            for _, key in ipairs(require("schema").keys) do
                if key.id == "look" then
                    choices = {}
                    for _, choice in ipairs(key.choices) do
                        choices[#choices + 1] = choice.value
                    end
                end
            end
            table.sort(choices)
            assert.same(choices, listed)
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
            local had, previous, is_color_screen, night_mode
            before_each(function()
                had = G_reader_settings:has("color_rendering")
                previous = G_reader_settings:readSetting("color_rendering")
                is_color_screen = require("device").screen.isColorScreen
                night_mode = rawget(require("device").screen, "night_mode")
                require("device").screen.night_mode = false
            end)
            after_each(function()
                require("device").screen.isColorScreen = is_color_screen
                require("device").screen.night_mode = night_mode
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

            it("follows the panel when colour rendering was never set", function()
                G_reader_settings:delSetting("color_rendering")
                local screen = require("device").screen
                screen.isColorScreen = function() return true end
                assert.equals("day", Looks.variant())
                screen.isColorScreen = function() return false end
                assert.equals("grey", Looks.variant())
            end)

            it("is night when night mode is on and colour rendering is on", function()
                G_reader_settings:saveSetting("color_rendering", true)
                require("device").screen.night_mode = true
                assert.equals("night", Looks.variant())
            end)

            it("stays grey with night mode on when colour rendering is off", function()
                G_reader_settings:saveSetting("color_rendering", false)
                require("device").screen.night_mode = true
                assert.equals("grey", Looks.variant())
            end)

            it("stays grey with night mode on a panel without colour", function()
                G_reader_settings:delSetting("color_rendering")
                local screen = require("device").screen
                screen.isColorScreen = function() return false end
                screen.night_mode = true
                assert.equals("grey", Looks.variant())
            end)
        end)

        describe("palette", function()
            -- The per-channel inverse of a #rrggbb, lower case.
            local function inverse(hex)
                local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
                return string.format("#%02x%02x%02x", 255 - tonumber(r, 16), 255 - tonumber(g, 16),
                    255 - tonumber(b, 16))
            end

            it("is the look's own day and grey palette", function()
                for _, id in ipairs(ids) do
                    local look = Looks.get(id)
                    assert.equals(look.palettes.day, Looks.palette(look, "day"), id)
                    assert.equals(look.palettes.grey, Looks.palette(look, "grey"), id)
                end
            end)

            it("inverts each night colour per channel and keeps false roles false", function()
                for _, id in ipairs(ids) do
                    local look = Looks.get(id)
                    local night = Looks.palette(look, "night")
                    assert.is_not.equals(look.palettes.night, night, id)
                    assert.same(keys(look.palettes.night), keys(night), id)
                    for role, designed in pairs(look.palettes.night) do
                        local where = id .. " night " .. role
                        if designed == false then
                            assert.is_false(night[role], where)
                        else
                            assert.truthy(night[role]:match("^#%x%x%x%x%x%x$"), where)
                            assert.equals(designed:lower(), inverse(night[role]), where)
                        end
                    end
                end
                assert.equals("#eae9e5", Looks.palette(Looks.get("editorial"), "night").paper)
                assert.equals("#d0949a", Looks.palette(Looks.get("diner"), "night").teal)
            end)

            it("builds the night palette once per look", function()
                for _, id in ipairs(ids) do
                    local look = Looks.get(id)
                    assert.equals(Looks.palette(look, "night"), Looks.palette(look, "night"), id)
                end
            end)

            it("passes a night value that is not #rrggbb through unchanged", function()
                local look = { palettes = { night = { short = "#abc", gone = false, ink = "#102030" } } }
                local night = Looks.palette(look, "night")
                assert.same({ short = "#abc", gone = false, ink = "#efdfcf" }, night)
                assert.is_nil(Looks.color(night.short))
            end)

            it("leaves each look's palettes and its file as they were", function()
                for _, id in ipairs(ids) do
                    local look = Looks.get(id)
                    Looks.palette(look, "night")
                    Looks.palette(look, "day")
                    Looks.palette(look, "grey")
                    assert.same({ "day", "grey", "night" }, keys(look.palettes), id)
                    assert.same(looks[id], look, id)
                end
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

        describe("colorer", function()
            it("draws a role in ctx's palette, night inverted, and a role the look lacks as nil", function()
                local look = Looks.get("diner")
                local day = Looks.colorer({ look = look, variant = "day" })
                local night = Looks.colorer({ look = look, variant = "night" })
                local day_ink = Looks.color(look.palettes.day.ink)
                assert.equals(day_ink:getR(), day("ink"):getR())
                assert.equals(day_ink:getB(), day("ink"):getB())
                local night_ink = Looks.color(Looks.palette(look, "night").ink)
                assert.equals(night_ink:getR(), night("ink"):getR())
                assert.is_nil(day(nil))
                assert.is_nil(day(false))
                assert.is_nil(day("no_such_role"))
            end)
        end)
    end)
end)
