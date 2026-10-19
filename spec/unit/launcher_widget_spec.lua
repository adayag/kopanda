-- The launcher widget (C4): its grid per look at both profiles' full-width columns, its tiles and
-- rows, its states, its taps through the real home and its stale check. LauncherEntries.resolve
-- and run are stubbed per case and restored by the harness's reload.
describe("the launcher widget", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local TextWidget = require("ui/widget/textwidget")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local logger = require("logger")
    local util = require("util")
    local Launcher, LauncherEntries, Settings, Looks, Icons, Widgets, Home

    -- The default six's views, by target, as resolve gives them with Wi-Fi on.
    local VIEWS = {
        library = { label = "Library", icon = "library", state = "ready" },
        series = { label = "Series", icon = "series", state = "ready" },
        authors = { label = "Authors", icon = "authors", state = "ready" },
        history = { label = "History", icon = "history", state = "ready" },
        wifi = { label = "Wi-Fi", icon = "wifi", state = "ready" },
        settings = { label = "Settings", icon = "settings", state = "ready" },
    }
    local LABELS = { "Library", "Series", "Authors", "History", "Wi-Fi", "Settings" }

    local resolved, ran

    -- resolve stubbed: an entry's view is views[target or label], else VIEWS[target].
    local function stub_resolve(views)
        LauncherEntries.resolve = function(entry)
            resolved = resolved + 1
            local key = entry.target or entry.label
            local view = (views and views[key]) or VIEWS[key]
            return util.tableDeepCopy(view)
        end
    end

    local function default_entries()
        for _, e in ipairs(require("schema").keys) do
            if e.id == "launcher.entries" then
                return util.tableDeepCopy(e.default)
            end
        end
    end

    local function set_entries(entries)
        assert.is_true(Settings.set("launcher.entries", entries))
    end

    before_each(function()
        harness.load()
        Launcher = package.loaded["widgets/launcher"]
        LauncherEntries = package.loaded["launcher_entries"]
        Settings = package.loaded["settings"]
        Looks = package.loaded["looks"]
        Icons = package.loaded["icons"]
        Widgets = package.loaded["widgets"]
        Home = package.loaded["home"]
        resolved, ran = 0, {}
        stub_resolve()
        LauncherEntries.run = function(entry, ctx)
            ran[#ran + 1] = { entry = entry, ctx = ctx }
        end
    end)

    after_each(function()
        harness.teardown()
    end)

    local function ctx_for(id, variant)
        return {
            look = Looks.get(id),
            variant = variant or "day",
            text_size = "medium",
            now = 1000000,
            screen = Screen,
        }
    end

    local function scale(px)
        return Screen:scaleBySize(px)
    end

    -- The full-width column of each profile's screen width in look id.
    local function widths(id)
        local side = 2 * scale(Looks.get(id).home.margin.side)
        return { 1264 - side, 1236 - side }
    end

    -- Every widget in the tree under widget for which pick is true.
    local function find(widget, pick, found)
        found = found or {}
        if type(widget) ~= "table" then
            return found
        end
        if pick(widget) then
            found[#found + 1] = widget
        end
        for _, child in ipairs(widget) do
            find(child, pick, found)
        end
        return found
    end

    local function entries_of(built)
        return find(built, function(w)
            return w.name == "kopanda_launcher_entry"
        end)
    end

    local function icons_of(widget)
        return find(widget, function(w)
            return w.name == "kopanda_tinted_icon"
        end)
    end

    -- The lines drawn under widget, in order: each { text, glyphs, widget }, a tracked line's
    -- glyphs joined and a cut line's ellipsis included.
    local function lines(widget)
        local out = {}
        local function walk(w)
            if getmetatable(w) == TextWidget then
                local fitted, ellipsis = w:getFittedText()
                out[#out + 1] = { text = fitted .. (ellipsis and "…" or ""), glyphs = { w }, widget = w }
                return
            end
            local glyphs = {}
            local tracked = #w > 0
            for _, child in ipairs(w) do
                if getmetatable(child) == TextWidget then
                    if #util.splitToChars(child.text) ~= 1 then
                        tracked = false
                    end
                    glyphs[#glyphs + 1] = child
                elseif not child.width or child[1] then
                    tracked = false
                end
            end
            if tracked and #glyphs > 0 then
                local text = ""
                for _, g in ipairs(glyphs) do
                    text = text .. g.text
                end
                out[#out + 1] = { text = text, glyphs = glyphs, widget = w }
                return
            end
            for _, child in ipairs(w) do
                walk(child)
            end
        end
        walk(widget)
        return out
    end

    local function texts(widget)
        local out = {}
        for i, line in ipairs(lines(widget)) do
            out[i] = line.text
        end
        return out
    end

    local function line_of(widget, text)
        for _, line in ipairs(lines(widget)) do
            if line.text == text then
                return line
            end
        end
    end

    local function same_color(a, b)
        a, b = a:getColorRGB32(), b:getColorRGB32()
        return a.r == b.r and a.g == b.g and a.b == b.b
    end

    local function role(ctx, name)
        return Looks.color(ctx.look.palettes[ctx.variant][name])
    end

    -- Asserts every glyph of line is drawn in the palette role name.
    local function assert_line_color(line, ctx, name, where)
        assert.is_table(line, where)
        for _, glyph in ipairs(line.glyphs) do
            assert.is_true(same_color(role(ctx, name), glyph.fgcolor), where .. " not in " .. name)
        end
    end

    -- The place of child inside entry, as entry paints it.
    local function place_in(entry, child)
        for i, c in ipairs(entry) do
            if c == child then
                return entry.places[i]
            end
        end
    end

    it("is registered as launcher, with a tap, a hold and a stale check", function()
        local module = Widgets.get("launcher")
        assert.equals(Launcher, module)
        assert.equals("launcher", module.id)
        assert.equals("launcher", module.settings_prefix)
        assert.is_function(module.tap)
        assert.is_function(module.hold)
        assert.is_function(module.stale)
    end)

    describe("geometry", function()
        it("is exactly the column wide and height(width) high in each look at both profiles' widths", function()
            for _, id in ipairs({ "editorial", "diner", "toybox" }) do
                for _, width in ipairs(widths(id)) do
                    local ctx = ctx_for(id)
                    local h = Launcher.height(width, ctx)
                    local built = Launcher.build(width, ctx)
                    assert.same({ width, h }, { built:getSize().w, built:getSize().h }, id .. " " .. width)
                    assert.is_true(h > 0, id)
                    -- A build with no height before it is the same size.
                    local again = Launcher.build(width, ctx_for(id))
                    assert.same({ width, h }, { again:getSize().w, again:getSize().h }, id .. " " .. width)
                    built:free()
                    again:free()
                end
            end
        end)

        it("resolves each entry once per build", function()
            local ctx = ctx_for("diner")
            Launcher.height(1184, ctx)
            Launcher.build(1184, ctx):free()
            assert.equals(6, resolved)
        end)

        it("lays six entries out 2×3 in Editorial and 3×2 in Diner, columns and gaps filling the width", function()
            for id, grid in pairs({ editorial = { 2, 3 }, diner = { 3, 2 } }) do
                for _, width in ipairs(widths(id)) do
                    local ctx = ctx_for(id)
                    local look = ctx.look
                    local built = Launcher.build(width, ctx)
                    local rects = built.rects
                    local columns, rows = grid[1], grid[2]
                    local where = id .. " " .. width
                    assert.equals(6, #rects, where)
                    local shadow_x, shadow_y = 0, 0
                    if look.tile.box and look.shadow.tile.color then
                        shadow_x, shadow_y = scale(look.shadow.tile.x), scale(look.shadow.tile.y)
                    end
                    for i, rect in ipairs(rects) do
                        local col, row = (i - 1) % columns + 1, math.floor((i - 1) / columns) + 1
                        assert.equals(rects[col].x, rect.x, where .. " entry " .. i .. " x")
                        assert.equals(rects[(row - 1) * columns + 1].y, rect.y, where .. " entry " .. i .. " y")
                    end
                    assert.equals(0, rects[1].x, where)
                    assert.equals(0, rects[1].y, where)
                    -- Each column's tile, its shadow inside the column, then the gap.
                    local x = 0
                    for col = 1, columns do
                        assert.equals(x, rects[col].x, where .. " column " .. col)
                        x = x + rects[col].w + shadow_x
                        if col < columns then
                            x = x + scale(look.launcher.column_gap)
                        end
                    end
                    assert.equals(width, x, where .. ": the columns and gaps fill the width")
                    for row = 2, rows do
                        local above, here = rects[(row - 2) * columns + 1], rects[(row - 1) * columns + 1]
                        assert.equals(above.y + above.h + scale(look.launcher.row_gap), here.y, where)
                    end
                    local last = rects[6]
                    assert.equals(last.y + last.h + shadow_y, built:getSize().h, where)
                    built:free()
                end
            end
        end)

        it("lays four entries out in two rows in either look", function()
            local entries = default_entries()
            set_entries({ entries[1], entries[2], entries[3], entries[4] })
            for _, id in ipairs({ "editorial", "diner" }) do
                local built = Launcher.build(widths(id)[1], ctx_for(id))
                local ys = {}
                for _, rect in ipairs(built.rects) do
                    ys[rect.y] = true
                end
                assert.equals(4, #built.rects, id)
                assert.equals(2, util.tableSize(ys), id)
                assert.same({ "Library", "Series", "Authors", "History" }, texts(built), id)
                built:free()
            end
        end)

        it("is 0 high with no entries", function()
            set_entries({})
            for _, id in ipairs({ "editorial", "diner" }) do
                local ctx = ctx_for(id)
                assert.equals(0, Launcher.height(1184, ctx), id)
                local built = Launcher.build(1184, ctx)
                assert.same({ 1184, 0 }, { built:getSize().w, built:getSize().h }, id)
                built:free()
            end
        end)

        it("adds the tile shadow's y to Diner's height so the last row's shadow isn't cut", function()
            local ctx = ctx_for("diner")
            local look = ctx.look
            local built = Launcher.build(1184, ctx)
            assert.equals(2 * scale(look.launcher.tile_height) + scale(look.launcher.row_gap)
                + scale(look.shadow.tile.y), built:getSize().h)
            built:free()
        end)

        it("makes an Editorial entry its padding, its icon or label line, and its rule high", function()
            local ctx = ctx_for("editorial")
            local look = ctx.look
            local built = Launcher.build(1184, ctx)
            local label = line_of(built, "Library").widget
            local content = math.max(scale(look.launcher.icon_size), label:getSize().h)
            assert.equals(2 * scale(look.launcher.padding.y) + content + scale(look.stroke.hairline), built.rects[1].h)
            built:free()
        end)
    end)

    describe("drawing", function()
        it("draws the labels in order in each look", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                local built = Launcher.build(1184, ctx_for(id))
                assert.same(LABELS, texts(built), id)
                built:free()
            end
        end)

        it("draws each entry's icon from its view in ink, at the look's icon size", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                local ctx = ctx_for(id)
                local built = Launcher.build(1184, ctx)
                local entries = entries_of(built)
                assert.equals(6, #entries, id)
                local targets = { "library", "series", "authors", "history", "wifi", "settings" }
                for i, entry in ipairs(entries) do
                    local icons = icons_of(entry)
                    assert.equals(1, #icons, id .. " " .. i)
                    assert.equals(Icons.path(VIEWS[targets[i]].icon), icons[1].file, id .. " " .. i)
                    assert.is_true(same_color(role(ctx, "ink"), icons[1].color), id .. " " .. i)
                    assert.equals(scale(ctx.look.launcher.icon_size), icons[1].size, id .. " " .. i)
                end
                for _, label in ipairs(LABELS) do
                    assert_line_color(line_of(built, label), ctx, "ink", id .. " " .. label)
                end
                built:free()
            end
        end)

        it("fills Diner's tiles mustard, pink, teal, then paper, outlined with the hard shadow, by day and in grey",
            function()
                for _, variant in ipairs({ "day", "grey" }) do
                    local ctx = ctx_for("diner", variant)
                    local look = ctx.look
                    local built = Launcher.build(1184, ctx)
                    local fills = { "mustard", "pink", "teal", "paper", "paper", "paper" }
                    for i, entry in ipairs(entries_of(built)) do
                        local where = variant .. " tile " .. i
                        assert.is_true(same_color(role(ctx, fills[i]), entry.fill_color), where)
                        assert.is_true(same_color(role(ctx, "outline"), entry.outline_color), where)
                        assert.equals(scale(look.stroke.outline), entry.outline, where)
                        assert.is_true(same_color(role(ctx, "shadow"), entry.shadow_color), where)
                        assert.same({ scale(look.shadow.tile.x), scale(look.shadow.tile.y) },
                            { entry.shadow_x, entry.shadow_y }, where)
                        assert.is_falsy(entry.rule_color, where)
                        assert.same({ built.rects[i].w, built.rects[i].h },
                            { entry:getSize().w, entry:getSize().h }, where)
                    end
                    built:free()
                end
            end)

        -- toybox.md: paper blocks rounded 18 on a 6 px ink edge straight below, each with a 42 px
        -- badge in sun, coral, mint, coral, mint, sun, ringed 2.5 px in ink, the icon at its centre
        -- and the label beside it, both centred down the block.
        it("draws Toybox's tiles as rounded paper blocks on their edge, each a ringed badge round its icon",
                function()
            for _, variant in ipairs({ "day", "grey" }) do
                local ctx = ctx_for("toybox", variant)
                local look = ctx.look
                local built = Launcher.build(1184, ctx)
                local fills = { "sun", "coral", "mint", "coral", "mint", "sun" }
                local size, ring = scale(42), scale(2.5)
                local outline = scale(look.stroke.outline)
                for i, entry in ipairs(entries_of(built)) do
                    local where = variant .. " tile " .. i
                    assert.is_true(same_color(role(ctx, "paper"), entry.fill_color), where)
                    assert.equals(scale(18), entry.radius, where)
                    assert.equals(outline, entry.outline, where)
                    assert.same({ 0, scale(6) }, { entry.shadow_x, entry.shadow_y }, where)
                    assert.is_true(same_color(role(ctx, "shadow"), entry.shadow_color), where)
                    local badges = find(entry, function(w)
                        return w.name == "kopanda_launcher_badge"
                    end)
                    assert.equals(1, #badges, where)
                    local badge = badges[1]
                    assert.same({ size, size }, { badge:getSize().w, badge:getSize().h }, where)
                    assert.is_true(same_color(role(ctx, fills[i]), badge.fill_color), where .. " fill")
                    assert.is_true(same_color(role(ctx, "outline"), badge.ring_color), where .. " ring")
                    assert.equals(ring, badge.ring, where)
                    local icon = icons_of(badge)[1]
                    assert.equals(scale(22), icon.size, where)
                    local inset = math.floor((size - icon.size) / 2)
                    assert.same({ x = inset, y = inset }, badge.icon_place, where)
                    -- The badge and the label each centred down the block, the label beside the badge.
                    local at = place_in(entry, badge)
                    local inner_h = entry:getSize().h - 2 * outline
                    assert.same({ x = outline + scale(11), y = outline + math.floor((inner_h - size) / 2) }, at, where)
                    local label = line_of(entry, LABELS[i]).widget
                    local label_at = place_in(entry, label)
                    assert.equals(at.x + size + scale(10), label_at.x, where)
                    assert.equals(outline + math.floor((inner_h - label:getSize().h) / 2), label_at.y, where)
                end
                built:free()
            end
        end)

        -- The tile's radius and the badge's circle reach the paint: the block's corner and the
        -- badge's corner stay as they were, the badge's edge is the ring and inside it the fill.
        it("paints Toybox's block with round corners and its badge as a ringed disc", function()
            local Blitbuffer = require("ffi/blitbuffer")
            local ctx = ctx_for("toybox")
            local built = Launcher.build(1184, ctx)
            local entry = entries_of(built)[2]
            local size = entry:getSize()
            local sentinel = Blitbuffer.colorFromString("#00ff00")
            local bb = Blitbuffer.new(size.w, size.h + scale(6), Blitbuffer.TYPE_BBRGB32)
            bb:paintRectRGB32(0, 0, bb:getWidth(), bb:getHeight(), sentinel)
            entry:paintTo(bb, 0, 0)
            assert.is_true(same_color(sentinel, bb:getPixel(0, 0)), "the block's top-left corner")
            assert.is_true(same_color(sentinel, bb:getPixel(size.w - 1, size.h + scale(6) - 1)),
                "the edge's bottom-right corner")
            assert.is_true(same_color(role(ctx, "shadow"), bb:getPixel(math.floor(size.w / 2), size.h + scale(6) - 1)),
                "the edge below the block")
            local badge = find(entry, function(w)
                return w.name == "kopanda_launcher_badge"
            end)[1]
            local at, d = place_in(entry, badge), badge:getSize().w
            local r = math.floor(d / 2)
            local cx = at.x + r
            assert.is_true(same_color(role(ctx, "paper"), bb:getPixel(at.x, at.y)), "the badge's corner is the block")
            assert.is_true(same_color(role(ctx, "outline"), bb:getPixel(cx, at.y + 1)), "the ring at the badge's top")
            assert.is_true(same_color(role(ctx, "coral"), bb:getPixel(cx, at.y + badge.ring + 1)),
                "the fill inside the ring")
            -- The icon over the disc: some of its rectangle is the ink the disc would hide.
            local icon = icons_of(badge)[1]
            local inked = false
            for y = at.y + badge.icon_place.y, at.y + badge.icon_place.y + icon.size - 1 do
                for x = at.x + badge.icon_place.x, at.x + badge.icon_place.x + icon.size - 1 do
                    inked = inked or same_color(role(ctx, "ink"), bb:getPixel(x, y))
                end
            end
            assert.is_true(inked, "the icon's ink over the disc")
            bb:free()
            built:free()
        end)

        it("rules each Editorial entry in hairline_light at the hairline's width, with no fill or outline", function()
            for _, variant in ipairs({ "day", "grey" }) do
                local ctx = ctx_for("editorial", variant)
                local built = Launcher.build(1184, ctx)
                local entries = entries_of(built)
                assert.equals(6, #entries)
                for i, entry in ipairs(entries) do
                    local where = variant .. " row " .. i
                    assert.is_true(same_color(role(ctx, "hairline_light"), entry.rule_color), where)
                    assert.equals(scale(ctx.look.stroke.hairline), entry.rule, where)
                    assert.is_falsy(entry.fill_color, where)
                    assert.is_falsy(entry.shadow_color, where)
                    assert.equals(0, entry.outline, where)
                end
                built:free()
            end
        end)

        it("paints inside its own rectangle", function()
            local Blitbuffer = require("ffi/blitbuffer")
            for _, id in ipairs({ "editorial", "diner", "toybox" }) do
                local built = Launcher.build(560, ctx_for(id))
                local size = built:getSize()
                local margin = 10
                local sentinel = Blitbuffer.colorFromString("#00ff00")
                local bb = Blitbuffer.new(size.w + 2 * margin, size.h + 2 * margin, Blitbuffer.TYPE_BBRGB32)
                bb:paintRectRGB32(0, 0, bb:getWidth(), bb:getHeight(), sentinel)
                built:paintTo(bb, margin, margin)
                local spilled = 0
                for y = 0, bb:getHeight() - 1 do
                    for x = 0, bb:getWidth() - 1 do
                        local inside = x >= margin and x < margin + size.w and y >= margin and y < margin + size.h
                        if not inside and not same_color(bb:getPixel(x, y), sentinel) then
                            spilled = spilled + 1
                        end
                    end
                end
                assert.equals(0, spilled, id)
                assert.same({ x = margin, y = margin }, built.painted_at, id)
                bb:free()
                built:free()
            end
        end)
    end)

    describe("states", function()
        local OFF = { label = "Wi-Fi", icon = "wifi_off", state = "off", suffix = "off" }
        local MISSING = {
            label = "Terminal", icon = "plugin_missing", state = "unavailable", suffix = "plugin missing",
        }

        it("draws Wi-Fi off with the wifi_off icon in ink and OFF in muted", function()
            stub_resolve({ wifi = OFF })
            for _, id in ipairs({ "editorial", "diner" }) do
                local ctx = ctx_for(id)
                local built = Launcher.build(1184, ctx)
                local entry = entries_of(built)[5]
                local icons = icons_of(entry)
                assert.equals(Icons.path("wifi_off"), icons[1].file, id)
                assert.is_true(same_color(role(ctx, "ink"), icons[1].color), id)
                assert.same({ "Wi-Fi", "OFF" }, texts(entry), id)
                assert_line_color(line_of(entry, "Wi-Fi"), ctx, "ink", id .. " label")
                assert_line_color(line_of(entry, "OFF"), ctx, "muted", id .. " suffix")
                built:free()
            end
        end)

        it("draws an unavailable entry with the plugin_missing icon, its label and PLUGIN MISSING in muted", function()
            stub_resolve({ settings = MISSING })
            for _, variant in ipairs({ "day", "grey" }) do
                for _, id in ipairs({ "editorial", "diner" }) do
                    local ctx = ctx_for(id, variant)
                    local built = Launcher.build(1184, ctx)
                    local entry = entries_of(built)[6]
                    local where = id .. " " .. variant
                    local icons = icons_of(entry)
                    assert.equals(Icons.path("plugin_missing"), icons[1].file, where)
                    assert.is_true(same_color(role(ctx, "muted"), icons[1].color), where)
                    assert.same({ "Terminal", "PLUGIN MISSING" }, texts(entry), where)
                    assert_line_color(line_of(entry, "Terminal"), ctx, "muted", where .. " label")
                    assert_line_color(line_of(entry, "PLUGIN MISSING"), ctx, "muted", where .. " suffix")
                    if id == "diner" then
                        -- The tile keeps its fill, outline and shadow.
                        assert.is_true(same_color(role(ctx, "paper"), entry.fill_color), where)
                        assert.is_true(same_color(role(ctx, "outline"), entry.outline_color), where)
                        assert.is_true(same_color(role(ctx, "shadow"), entry.shadow_color), where)
                    end
                    built:free()
                end
            end
        end)

        it("puts the suffix on the label's line in Editorial and on the line below in Diner", function()
            stub_resolve({ settings = MISSING })
            for _, id in ipairs({ "editorial", "diner" }) do
                local built = Launcher.build(1184, ctx_for(id))
                local entry = entries_of(built)[6]
                local label, suffix = line_of(entry, "Terminal").widget, line_of(entry, "PLUGIN MISSING").widget
                local at, below = place_in(entry, label), place_in(entry, suffix)
                assert.is_table(at, id)
                assert.is_table(below, id)
                if id == "editorial" then
                    local gap = scale(ctx_for(id).look.launcher.suffix_gap)
                    assert.equals(at.x + label:getSize().w + gap, below.x, id)
                    -- On one baseline.
                    local Typeset = package.loaded["typeset"]
                    assert.equals(at.y + Typeset.baseline(label), below.y + Typeset.baseline(suffix), id)
                else
                    assert.equals(at.x, below.x, id)
                    assert.equals(at.y + label:getSize().h, below.y, id)
                end
                built:free()
            end
        end)

        it("cuts a 60-character label with an ellipsis inside its column, Diner at 560 px too", function()
            local long = string.rep("MW", 30)
            assert.equals(60, #long)
            stub_resolve({ Long = { label = long, icon = "folder", state = "unavailable", suffix = "folder missing" },
                Short = { label = long, icon = "folder", state = "ready" } })
            set_entries({
                { kind = "directory", path = "/mnt/us/a", label = "Long" },
                { kind = "directory", path = "/mnt/us/b", label = "Short" },
            })
            for _, case in ipairs({ { "editorial", 1184 }, { "diner", 1184 }, { "diner", 560 } }) do
                local id, width = case[1], case[2]
                local ctx = ctx_for(id)
                local built = Launcher.build(width, ctx)
                assert.equals(width, built:getSize().w, id)
                for i, entry in ipairs(entries_of(built)) do
                    local where = id .. " " .. width .. " entry " .. i
                    local label = lines(entry)[1]
                    assert.equals("…", label.text:sub(-#"…"), where .. ": " .. label.text)
                    for _, line in ipairs(lines(entry)) do
                        local p = place_in(entry, line.widget)
                        assert.is_true(p.x >= 0 and p.x + line.widget:getSize().w <= entry:getSize().w,
                            where .. " " .. line.text)
                    end
                    local icon = icons_of(entry)[1]
                    assert.equals(scale(ctx.look.launcher.icon_size), icon:getSize().w, where)
                end
                built:free()
            end
        end)

        it("draws no icon for an id the registry lacks, logged once per build", function()
            stub_resolve({ series = { label = "Series", icon = "kopanda_no_such_icon", state = "ready" } })
            local warned = spy.on(logger, "warn")
            finally(function()
                logger.warn:revert()
            end)
            local ctx = ctx_for("diner")
            Launcher.height(1184, ctx)
            local built = Launcher.build(1184, ctx)
            local entries = entries_of(built)
            assert.equals(0, #icons_of(entries[2]))
            assert.equals(1, #icons_of(entries[1]))
            assert.same(LABELS, texts(built))
            local count = 0
            for _, call in ipairs(warned.calls) do
                for _, arg in ipairs(call.vals) do
                    if tostring(arg):find("kopanda_no_such_icon", 1, true) then
                        count = count + 1
                    end
                end
            end
            assert.equals(1, count)
            built:free()
        end)
    end)

    describe("tap", function()
        it("finds the entry under the tap from where the grid was last painted", function()
            local Blitbuffer = require("ffi/blitbuffer")
            local ctx = ctx_for("diner")
            local built = Launcher.build(560, ctx)
            local bb = Blitbuffer.new(700, 400, Blitbuffer.TYPE_BBRGB32)
            built:paintTo(bb, 37, 61)
            local entries = default_entries()
            for i, rect in ipairs(built.rects) do
                local ges = harness.gesture("tap", 37 + rect.x + 1, 61 + rect.y + rect.h - 1)
                assert.is_true(Launcher.tap(ctx, ges, built), "entry " .. i)
                assert.same(entries[i], ran[#ran].entry, "entry " .. i)
                ges = harness.gesture("tap", 37 + rect.x + rect.w - 1, 61 + rect.y + rect.h - 1)
                assert.is_true(Launcher.tap(ctx, ges, built), "far corner of entry " .. i)
                assert.same(entries[i], ran[#ran].entry, "far corner of entry " .. i)
            end
            assert.equals(12, #ran)
            -- The grid's own coordinates, unpainted there, are above and left of it.
            assert.is_false(Launcher.tap(ctx, harness.gesture("tap", 5, 5), built))
            assert.equals(12, #ran)
            -- Just past each tile's right and bottom edges (Geom:contains counts the edge itself)
            -- lies the gap or the Diner shadow band: a point there outside every entry runs nothing.
            local function in_any(x, y)
                for _, rect in ipairs(built.rects) do
                    if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                        return true
                    end
                end
                return false
            end
            local gaps = 0
            for _, rect in ipairs(built.rects) do
                for _, p in ipairs({
                    { rect.x + rect.w + 1, rect.y + 1 },
                    { rect.x + 1, rect.y + rect.h + 1 },
                }) do
                    if not in_any(p[1], p[2]) then
                        gaps = gaps + 1
                        local ges = harness.gesture("tap", 37 + p[1], 61 + p[2])
                        assert.is_false(Launcher.tap(ctx, ges, built), "gap at " .. p[1] .. "," .. p[2])
                    end
                end
            end
            assert.is_true(gaps >= 6)
            assert.equals(12, #ran)
            bb:free()
            built:free()
        end)

        it("returns false, running nothing, for a grid never painted", function()
            local ctx = ctx_for("editorial")
            local built = Launcher.build(560, ctx)
            assert.is_false(Launcher.tap(ctx, harness.gesture("tap", 5, 5), built))
            assert.same({}, ran)
            built:free()
        end)
    end)

    describe("taps through the real home", function()
        local function show_home()
            local fm = harness.show_fm()
            harness.tick(2)
            assert.equals(Home.shown, harness.top())
            return fm, Home.shown
        end

        local function launcher_slot(home)
            for _, slot in ipairs(home.slots) do
                if slot.widget == "launcher" then
                    return slot
                end
            end
        end

        local function tap_at(x, y)
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", x, y)))
        end

        -- The launcher in a row of its own under the header and the quote, clear of KOReader's top
        -- menu zones: Diner's header, tightened to fit the home above the nav bar, no longer holds
        -- it below DTAP_ZONE_MENU_EXT on the unit screen.
        local ROWS = {
            { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
            { { widget = "quote", share = 1 } },
            { { widget = "launcher", share = 1 } },
        }

        -- Whether (x, y) lies in the top menu zones the home leaves to the file manager's menu
        -- (home.lua in_menu_zone; defaults.lua:59-60).
        local function in_menu_zone(x, y)
            local size = Screen:getSize()
            for _, name in ipairs({ "DTAP_ZONE_MENU", "DTAP_ZONE_MENU_EXT" }) do
                local z = G_defaults:readSetting(name)
                if x >= z.x * size.w and x <= (z.x + z.w) * size.w and y >= z.y * size.h
                        and y <= (z.y + z.h) * size.h then
                    return true
                end
            end
            return false
        end

        for _, look in ipairs({ "editorial", "diner" }) do
            it("runs the entry under a tap at each entry's centre, with the home's ctx, in " .. look, function()
                assert.is_true(Settings.set("look", look))
                assert.is_true(Settings.set("layout.rows", ROWS))
                local _, home = show_home()
                local built = launcher_slot(home).built
                assert.is_table(built.painted_at)
                for _, rect in ipairs(built.rects) do
                    local x = built.painted_at.x + rect.x + math.floor(rect.w / 2)
                    local y = built.painted_at.y + rect.y + math.floor(rect.h / 2)
                    assert.is_false(in_menu_zone(x, y))
                    tap_at(x, y)
                end
                assert.equals(6, #ran)
                local entries = default_entries()
                for i, call in ipairs(ran) do
                    assert.same(entries[i], call.entry, "entry " .. i)
                    assert.equals(home.ctx, call.ctx)
                end
                assert.equals(home, Home.shown)
            end)
        end

        for _, look in ipairs({ "editorial", "diner" }) do
            it("returns false on a tap in a column gap, so the home closes onto the file browser, in " .. look,
                    function()
                assert.is_true(Settings.set("look", look))
                assert.is_true(Settings.set("layout.rows", ROWS))
                local fm, home = show_home()
                local built = launcher_slot(home).built
                local a, b = built.rects[1], built.rects[2]
                local gap_x = built.painted_at.x + math.floor((a.x + a.w + b.x) / 2) + 1
                assert.is_true(gap_x > built.painted_at.x + a.x + a.w and gap_x < built.painted_at.x + b.x, look)
                tap_at(gap_x, built.painted_at.y + a.y + math.floor(a.h / 2))
                assert.same({}, ran)
                assert.is_nil(Home.shown)
                assert.equals(fm, harness.top())
            end)
        end

        it("closes the home onto the file browser when the entry's run raises", function()
            LauncherEntries.run = function()
                error("kopanda-test: run failed")
            end
            local errored = spy.on(logger, "err")
            finally(function()
                logger.err:revert()
            end)
            assert.is_true(Settings.set("layout.rows", ROWS))
            local fm, home = show_home()
            local built = launcher_slot(home).built
            local rect = built.rects[1]
            tap_at(built.painted_at.x + rect.x + math.floor(rect.w / 2),
                built.painted_at.y + rect.y + math.floor(rect.h / 2))
            assert.is_nil(Home.shown)
            assert.equals(fm, harness.top())
            local logged = false
            for _, call in ipairs(errored.calls) do
                for _, arg in ipairs(call.vals) do
                    logged = logged or tostring(arg):find("kopanda-test: run failed", 1, true) ~= nil
                end
            end
            assert.is_true(logged)
        end)
    end)

    describe("hold", function()
        local Editor, InfoMessage

        before_each(function()
            Editor = package.loaded["editor"]
            InfoMessage = require("ui/widget/infomessage")
        end)

        local function show_home()
            assert.is_true(Settings.set("layout.rows", {
                { { widget = "date", share = 1 }, { widget = "clock", share = 1 } },
                { { widget = "launcher", share = 1 } },
            }))
            harness.show_fm()
            harness.tick(2)
            assert.equals(Home.shown, harness.top())
            return Home.shown
        end

        it("opens launcher management's top level and returns nil", function()
            local home = show_home()
            local ges = harness.gesture("hold", 10, 10)
            assert.is_nil(Launcher.hold(home.ctx, ges, nil))
            local editor = Editor.shown
            assert.is_not_nil(editor)
            assert.equals("launcher", editor.spec.screen)
            assert.equals("Launcher", editor.spec.title)
            assert.equals(editor, harness.top())
        end)

        it("is what a hold on the launcher's slot runs through the home, opening no settings", function()
            local home = show_home()
            local slot
            for _, s in ipairs(home.slots) do
                if s.widget == "launcher" then
                    slot = s
                end
            end
            local rect = slot.rect
            UIManager:sendEvent(Event:new("Gesture", harness.gesture("hold",
                rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))))
            local editor = Editor.shown
            assert.is_not_nil(editor)
            assert.equals("launcher", editor.spec.screen)
            assert.equals(editor, harness.top())
            assert.equals(home, harness.top(2))
            for _, widget in ipairs(harness.stack()) do
                assert.is_not.equals(InfoMessage, getmetatable(widget))
            end
            assert.same({}, ran)
        end)
    end)

    describe("stale", function()
        local function set_wifi(on)
            G_reader_settings:saveSetting("emulator_fake_wifi_connected", on)
        end

        it("is false while the drawn Wi-Fi state holds and true once it flips", function()
            local OFF = { label = "Wi-Fi", icon = "wifi_off", state = "off", suffix = "off" }
            stub_resolve({ wifi = OFF })
            set_wifi(false)
            local ctx = ctx_for("diner")
            local off = Launcher.build(1184, ctx)
            assert.is_false(Launcher.stale(off, ctx))
            set_wifi(true)
            assert.is_true(Launcher.stale(off, ctx))
            stub_resolve()
            local on = Launcher.build(1184, ctx)
            assert.is_false(Launcher.stale(on, ctx))
            set_wifi(false)
            assert.is_true(Launcher.stale(on, ctx))
            off:free()
            on:free()
        end)

        it("is false for a launcher with no Wi-Fi entry, or with Wi-Fi unavailable, either way", function()
            local entries = default_entries()
            set_entries({ entries[1], entries[2] })
            local ctx = ctx_for("editorial")
            local without = Launcher.build(1184, ctx)
            set_entries(entries)
            stub_resolve({ wifi = { label = "Wi-Fi", icon = "plugin_missing", state = "unavailable",
                suffix = "not available" } })
            local unavailable = Launcher.build(1184, ctx)
            for _, on in ipairs({ false, true }) do
                set_wifi(on)
                assert.is_false(Launcher.stale(without, ctx))
                assert.is_false(Launcher.stale(unavailable, ctx))
            end
            set_wifi(false)
            without:free()
            unavailable:free()
        end)
    end)
end)
