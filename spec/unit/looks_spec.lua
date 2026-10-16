-- The two looks' token tables (looks/editorial.lua, looks/diner.lua) and looks.lua, which picks
-- the active look, the palette variant (C5) and the palette to draw with, night inverted (night
-- mode's C1, C2).
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
                    "progress.fill_grey", "sheet.rule_color", "chip.fill_color", "label.size",
                    "palettes.day.on_band", "faces.strong.file", "faces.quote.file", "home.margin.side",
                    "home.free_space", "home.header.padding.top", "home.footer.line_pitch",
                    "type.date_label.face", "type.clock.color", "type.stats.line_height",
                    "palettes.day.cover", "palettes.night.on_cover", "palettes.grey.cover",
                    "type.cover_title.tracking", "type.cover_authors.color", "type.cover_empty.face",
                    "featured.cover_w", "featured.cover_h", "featured.cover_padding.x",
                    "featured.cover_padding.y", "featured.dash", "featured.dash_gap",
                    "type.featured_label.face", "type.featured_title.line_height", "type.featured_authors.color",
                    "type.featured_chapter.size", "type.featured_caption.face", "type.featured_empty_title.size",
                    "type.featured_empty_body.line_height", "type.featured_button.uppercase", "featured.gap",
                    "featured.column_padding_y", "featured.title_gap", "featured.chip_outline",
                    "featured.chip_padding.x", "featured.chip_padding.y", "featured.button_padding.x",
                    "featured.button_padding.y", "featured.button_fill_color",
                    "featured.button_outline_color", "launcher.columns", "launcher.column_gap",
                    "launcher.row_gap", "launcher.icon_size", "launcher.icon_gap", "launcher.padding.x",
                    "launcher.padding.y", "launcher.tile_height", "launcher.accent_1_color",
                    "launcher.accent_2_color", "launcher.accent_3_color", "launcher.suffix_gap",
                    "launcher.suffix_below", "type.launcher_label.face", "type.launcher_suffix.tracking",
                    "sheet.inset.side", "sheet.book_band_color", "sheet.header_padding.top",
                    "sheet.book_header_padding.bottom", "sheet.row_rule_color", "sheet.status_chip_color",
                    "sheet.chip_padding.x", "type.sheet_heading.face", "type.sheet_aside.color",
                    "type.sheet_chip.size", "editor.padding.top", "editor.header_band_color",
                    "editor.header_rule_width", "editor.body_gap", "editor.button_padding.y", "editor.card_padding.x",
                    "editor.selected_fill_color", "editor.arrow_size", "editor.disabled_color",
                    "editor.box_padding.y", "editor.row_rule_color", "editor.control_size",
                    "editor.kind_columns", "type.editor_aside.tracking", "type.editor_title.size",
                    "type.editor_button.face", "type.editor_caption.color", "type.editor_box.face",
                    "type.editor_share.color", "type.editor_label.size", "type.editor_kind.uppercase",
                    "type.editor_note.line_height", "nav.fill_color", "nav.edge_width", "nav.edge_color",
                    "nav.padding_x", "nav.padding_top", "nav.padding_bottom", "nav.icon_size", "nav.icon_gap",
                    "nav.icon_color", "nav.active_icon_color", "nav.active_rule_width", "nav.active_rule_color",
                    "nav.active_fill_color", "nav.divider_width", "nav.divider_color", "type.nav_label.face",
                    "type.nav_label.tracking", "type.nav_label_active.face", "type.nav_label_active.color" }) do
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
                        "teal", "pink", "mustard", "outline", "shadow", "on_band", "cover", "on_cover",
                        "on_accent" }) do
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

        -- on_band is exempt: it is chosen for contrast against the band, not to tell roles apart,
        -- and equals ink in grey on purpose (PWRetro.dc.html:19).
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
                        assert.is_not_false(look.palettes.day[value],
                            where .. " names a role this look lacks: " .. value)
                    elseif key == "face" then
                        assert.is_table(look.faces[value], where .. " names no face: " .. value)
                    elseif key == "fill_grey" then
                        assert.equals("hatch_135", value, where)
                    elseif key == "free_space" then
                        assert.truthy(value == "before_last_row" or value == "before_footer", where .. " = " .. value)
                    elseif key == "align" then
                        assert.truthy(value == "top" or value == "bottom", where .. " = " .. value)
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

        -- The typographic cover's fill and text (Main:33, NightA:33, PWEditorial:33; HomeRetro:28,
        -- NightC:28, PWRetro:28 under .tiller/design/2026-10-13-kopanda-screens/).
        it("give the cover and on_cover roles the boards' values", function()
            local wanted = {
                editorial = { day = { "#2b4c6f", "#f3f1ea" }, night = { "#2b4c6f", "#f3f1ea" },
                    grey = { "#4a4a4a", "#f4f4f4" } },
                diner = { day = { "#2b4c6f", "#f5f1e6" }, night = { "#2b4c6f", "#f5f1e6" },
                    grey = { "#4a4a4a", "#f4f4f4" } },
            }
            for id, variants in pairs(wanted) do
                for variant, pair in pairs(variants) do
                    local palette = looks[id].palettes[variant]
                    assert.same(pair, { palette.cover, palette.on_cover }, id .. " " .. variant)
                end
            end
        end)

        -- The text on Diner's accent fills: the boards' ink on the band (HoldBookC:31-36), the night
        -- paper (no board), ink on the grey tiles (PWRetro:19). Editorial has no accent fills.
        it("give on_accent Diner's day, night and grey values and Editorial none", function()
            local palettes = looks.diner.palettes
            assert.same({ "#2f2e2b", "#1e1c1a", "#111111" },
                { palettes.day.on_accent, palettes.night.on_accent, palettes.grey.on_accent })
            palettes = looks.editorial.palettes
            assert.same({ false, false, false },
                { palettes.day.on_accent, palettes.night.on_accent, palettes.grey.on_accent })
        end)

        it("size the cover box 2:3 and draw the placeholder's text in on_cover and its empty frame in muted", function()
            for id, size in pairs({ editorial = { 150, 225 }, diner = { 140, 210 } }) do
                local look = looks[id]
                assert.same(size, { look.featured.cover_w, look.featured.cover_h }, id)
                assert.same({ 4, 4 }, { look.featured.dash, look.featured.dash_gap }, id)
                assert.equals("on_cover", look.type.cover_title.color, id)
                assert.equals("on_cover", look.type.cover_authors.color, id)
                assert.equals("muted", look.type.cover_empty.color, id)
                assert.is_true(look.type.cover_title.uppercase, id)
                assert.is_true(look.type.cover_authors.uppercase, id)
                assert.is_true(look.type.cover_empty.uppercase, id)
            end
        end)

        -- The featured text column and first run (Main.dc.html:32-52, HomeRetro.dc.html:27-43,
        -- EmptyStates.dc.html:32-40 under .tiller/design/2026-10-13-kopanda-screens/): each part's
        -- face, size, palette role and line height, and the featured block's column entries.
        it("give the featured parts and the featured block the boards' values", function()
            local wanted = {
                editorial = {
                    featured_label = { "text", 11, "muted", 0 },
                    featured_title = { "display", 28, "ink", 0.1 },
                    featured_authors = { "text", 15, "text", 0 },
                    featured_chapter = { "text", 14, "text", 0 },
                    featured_caption = { "text", 13, "text", 0 },
                    featured_empty_title = { "display", 24, "ink", 0.15 },
                    featured_empty_body = { "text", 15, "text", 0.4 },
                    featured_button = { "strong", 11, "ink", 0 },
                },
                diner = {
                    featured_label = { "display", 11, "ink", 0 },
                    featured_title = { "display", 28, "ink", 0.05 },
                    featured_authors = { "text", 15, "muted", 0 },
                    featured_chapter = { "text", 15, "muted", 0 },
                    featured_caption = { "strong", 13, "ink", 0 },
                    featured_empty_title = { "display", 24, "ink", 0.15 },
                    featured_empty_body = { "text", 15, "muted", 0.4 },
                    featured_button = { "strong", 11, "ink", 0 },
                },
            }
            for id, parts in pairs(wanted) do
                for name, value in pairs(parts) do
                    local part = looks[id].type[name]
                    assert.is_table(part, id .. " " .. name)
                    assert.same(value, { part.face, part.size, part.color, part.line_height }, id .. " " .. name)
                end
                for _, name in ipairs({ "featured_label", "featured_button" }) do
                    assert.is_true(looks[id].type[name].uppercase, id .. " " .. name)
                end
            end
            assert.equals(looks.diner.chip.text_color, looks.diner.type.featured_label.color)
            local editorial, diner = looks.editorial.featured, looks.diner.featured
            assert.same({ 24, 0, 6, false }, { editorial.gap, editorial.column_padding_y, editorial.title_gap,
                editorial.chip_outline })
            assert.same({ 20, 6, 12, 2 }, { diner.gap, diner.column_padding_y, diner.title_gap, diner.chip_outline })
            assert.same({ x = 10, y = 3 }, diner.chip_padding)
            assert.same({ x = 14, y = 9 }, editorial.button_padding)
            assert.same({ false, "ink" }, { editorial.button_fill_color, editorial.button_outline_color })
            assert.same({ "mustard", "outline" }, { diner.button_fill_color, diner.button_outline_color })
        end)

        -- The launcher (Main.dc.html:60-62, HomeRetro.dc.html:55-64, EmptyStates.dc.html:65 under
        -- .tiller/design/2026-10-13-kopanda-screens/): its block and its two type parts. Editorial's
        -- row padding (15) and Diner's row gap (14) are tightened to fit the home above the nav bar
        -- (layout_spec.lua's default home above the bar).
        it("give the launcher block and its parts the boards' values, its height tightened", function()
            assert.same({
                columns = 2, column_gap = 32, row_gap = 0, icon_size = 22, icon_gap = 14,
                padding = { x = 0, y = 11 }, tile_height = false, accent_1_color = false,
                accent_2_color = false, accent_3_color = false, suffix_gap = 6, suffix_below = false,
            }, looks.editorial.launcher)
            assert.same({
                columns = 3, column_gap = 14, row_gap = 9, icon_size = 28, icon_gap = false,
                padding = { x = 14, y = 12 }, tile_height = 104, accent_1_color = "mustard",
                accent_2_color = "pink", accent_3_color = "teal", suffix_gap = 6, suffix_below = true,
            }, looks.diner.launcher)
            local wanted = {
                editorial = {
                    launcher_label = { "strong", 16, false, 0, 0, "ink" },
                    launcher_suffix = { "strong", 11, true, 0.1, 0, "muted" },
                },
                diner = {
                    launcher_label = { "display", 14, false, 0, 0, "ink" },
                    launcher_suffix = { "display", 11, true, 0.1, 0, "muted" },
                },
            }
            for id, parts in pairs(wanted) do
                for name, value in pairs(parts) do
                    local part = looks[id].type[name]
                    assert.is_table(part, id .. " " .. name)
                    assert.same(value, { part.face, part.size, part.uppercase, part.tracking, part.line_height,
                        part.color }, id .. " " .. name)
                end
            end
        end)

        -- The editor frame's tokens (EditLayout.dc.html:19-43 under
        -- .tiller/design/2026-10-13-kopanda-screens/); Diner has no board and takes its own vocabulary.
        it("give Editorial's editor block and parts the boards' values", function()
            local editor, parts = looks.editorial.editor, looks.editorial.type
            assert.same({ top = 40, side = 40, bottom = 28 }, editor.padding)
            assert.same({ false, false }, { editor.header_band_color, editor.header_text_color })
            assert.same({ "ink", 1, 16 }, { editor.header_rule_color, editor.header_rule_width, editor.header_gap })
            assert.equals(18, editor.body_gap)
            assert.same({ "ink", 1, false }, { editor.button_outline_color, editor.button_outline_width,
                editor.button_fill_color })
            assert.same({ "hairline", 1 }, { editor.card_outline_color, editor.card_outline_width })
            assert.same({ "ink", "hairline_light" }, { editor.selected_outline_color, editor.selected_fill_color })
            assert.same({ x = 0, y = 0, color = false }, editor.card_shadow)
            assert.equals("hairline", editor.disabled_color)
            assert.same({ "display", 34, false, 0, 0.3, "ink" }, { parts.editor_title.face, parts.editor_title.size,
                parts.editor_title.uppercase, parts.editor_title.tracking, parts.editor_title.line_height,
                parts.editor_title.color })
            assert.same({ "text", 11, true, 0.14, "muted" }, { parts.editor_aside.face, parts.editor_aside.size,
                parts.editor_aside.uppercase, parts.editor_aside.tracking, parts.editor_aside.color })
        end)

        it("give Diner's editor block its band header, outlines and mustard selection", function()
            local editor, parts = looks.diner.editor, looks.diner.type
            assert.same({ "band", "on_band" }, { editor.header_band_color, editor.header_text_color })
            assert.same({ "outline", 3 }, { editor.header_rule_color, editor.header_rule_width })
            assert.equals(18, editor.body_gap)
            assert.same({ "outline", 3, "paper" }, { editor.button_outline_color, editor.button_outline_width,
                editor.button_fill_color })
            assert.same({ "outline", 3 }, { editor.card_outline_color, editor.card_outline_width })
            assert.same({ "outline", "mustard" }, { editor.selected_outline_color, editor.selected_fill_color })
            assert.same({ "outline", 2 }, { editor.row_rule_color, editor.row_rule_width })
            assert.same({ x = 2, y = 2, color = "shadow" }, editor.card_shadow)
            assert.equals("muted", editor.disabled_color)
            assert.same({ "display", 30, "on_band" }, { parts.editor_title.face, parts.editor_title.size,
                parts.editor_title.color })
            assert.same({ "strong", 11, true, 0.1, "on_band" }, { parts.editor_aside.face, parts.editor_aside.size,
                parts.editor_aside.uppercase, parts.editor_aside.tracking, parts.editor_aside.color })
        end)

        -- The nav bar's tokens (NavBar.dc.html:68-87, NavBarC.dc.html:70-89 under
        -- .tiller/design/2026-10-13-kopanda-screens/).
        local function nav_values(look)
            local nav = look.nav
            return {
                fill_color = nav.fill_color, edge_width = nav.edge_width, edge_color = nav.edge_color,
                padding_x = nav.padding_x, padding_top = nav.padding_top, padding_bottom = nav.padding_bottom,
                icon_size = nav.icon_size, icon_gap = nav.icon_gap, icon_color = nav.icon_color,
                active_icon_color = nav.active_icon_color, active_rule_width = nav.active_rule_width,
                active_rule_color = nav.active_rule_color, active_fill_color = nav.active_fill_color,
                divider_width = nav.divider_width, divider_color = nav.divider_color,
            }
        end

        local function part_values(part)
            return { part.face, part.size, part.uppercase, part.tracking, part.line_height, part.color }
        end

        it("give Editorial's nav block and parts the boards' values", function()
            local look = looks.editorial
            assert.same({
                fill_color = "paper", edge_width = 1, edge_color = "ink",
                padding_x = 24, padding_top = 16, padding_bottom = 18,
                icon_size = 26, icon_gap = 7, icon_color = "text", active_icon_color = "ink",
                active_rule_width = 3, active_rule_color = "ink", active_fill_color = false,
                divider_width = 0, divider_color = false,
            }, nav_values(look))
            assert.same({ "strong", 11, true, 0.12, 0, "text" }, part_values(look.type.nav_label))
            assert.same({ "strong", 11, true, 0.12, 0, "ink" }, part_values(look.type.nav_label_active))
        end)

        it("give Diner's nav block and parts the boards' values", function()
            local look = looks.diner
            assert.same({
                fill_color = "band", edge_width = 4, edge_color = "ink",
                padding_x = 0, padding_top = 14, padding_bottom = 16,
                icon_size = 28, icon_gap = 6, icon_color = "ink", active_icon_color = "on_accent",
                active_rule_width = 0, active_rule_color = false, active_fill_color = "mustard",
                divider_width = 3, divider_color = "outline",
            }, nav_values(look))
            assert.same({ "strong", 12, true, 0.04, 0, "ink" }, part_values(look.type.nav_label))
            assert.same({ "display", 12, true, 0.04, 0, "on_accent" }, part_values(look.type.nav_label_active))
        end)

        -- D7: the bar always shows on the home, and NavBarC:70 draws no stripe above it; NavBar:19,
        -- :61 leave 20 px under Editorial's last row.
        it("give Diner no footer stripe and Editorial a 20 px bottom margin above the bar", function()
            assert.equals(0, looks.diner.home.footer.height)
            assert.equals(20, looks.editorial.home.margin.bottom)
        end)

        it("align both looks' header row to its bottom", function()
            assert.equals("bottom", looks.editorial.home.header.align)
            assert.equals("bottom", looks.diner.home.header.align)
        end)

        it("put the free height before Editorial's last row and before Diner's footer", function()
            assert.equals("before_last_row", looks.editorial.home.free_space)
            assert.equals("before_footer", looks.diner.home.free_space)
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
                    assert.same(looks[id].palettes, look.palettes, id)
                    assert.same(load_look(id).palettes.night, look.palettes.night, id)
                    assert.same(load_look(id), look, id)
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
    end)
end)
