-- LibraryTiles (cover-grid C4, C5): the grid's geometry and the two-row fit at the Colorsoft and
-- the Paperwhite, and one tile of each kind: a book's cover or placeholder, its progress strip, its
-- one-line title, the not-downloaded badge and chip, and a folder's art and counts. Every case runs
-- at a device profile's size, as the screen will.
describe("library tiles", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local Screen = require("device").screen
    local TextWidget = require("ui/widget/textwidget")
    local LibraryTiles, Looks, NavBar

    local BOOK = "/books/piranesi.epub"

    setup(function()
        harness.load()
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        NavBar = package.loaded["nav_bar"]
    end)

    local function scale(px)
        return Screen:scaleBySize(px)
    end

    local function ctx_for(id, variant, text_size)
        return { look = Looks.get(id), variant = variant or "day", text_size = text_size, screen = Screen }
    end

    local function record(fields)
        local book = { id = "file:" .. BOOK, path = BOOK, title = "Piranesi", authors = { "Susanna Clarke" } }
        for k, v in pairs(fields or {}) do
            book[k] = v
        end
        return book
    end

    -- A path-less record, as a source registers one.
    local function remote(fields)
        local book = record(fields)
        book.id, book.path, book.source = "shelf:gentleman", nil, "shelf"
        book.title = fields and fields.title or "A Gentleman in Moscow"
        return book
    end

    local READING = { status = "reading", percent = 0.62 }

    -- Installs a bookinfomanager stub whose getBookInfo gives info(file) (default: no row), and
    -- restores the real one in finally.
    local function covers(info)
        local loaded = package.loaded.bookinfomanager
        package.loaded.bookinfomanager = {
            getBookInfo = function(_, file)
                return info and info(file)
            end,
            isCachedCoverInvalid = function()
                return false
            end,
        }
        finally(function()
            package.loaded.bookinfomanager = loaded
        end)
    end

    local function red_bb(w, h)
        local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, w, h, Blitbuffer.ColorRGB32(255, 0, 0, 255))
        return bb
    end

    local RED = { 255, 0, 0 }
    local SENTINEL = Blitbuffer.ColorRGB32(0, 255, 0, 255)
    local GREEN = { 0, 255, 0 }
    -- Room round a painted tile for what reaches past its box: Diner's badge and the shadows.
    local MARGIN = 60

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local function rgb(hex)
        local c = Looks.color(hex)
        return { c:getR(), c:getG(), c:getB() }
    end

    local function role(ctx, name)
        return rgb(Looks.palette(ctx.look, ctx.variant)[name])
    end

    local function near(a, b)
        return math.abs(a[1] - b[1]) <= 2 and math.abs(a[2] - b[2]) <= 2 and math.abs(a[3] - b[3]) <= 2
    end

    -- built painted with its top left at (MARGIN, MARGIN) on a sentinel-green buffer; returns the
    -- buffer and a reader of the pixel at a point from the tile's top left.
    local function paint(built)
        local size = built:getSize()
        local bb = Blitbuffer.new(size.w + 2 * MARGIN, size.h + 2 * MARGIN, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, bb:getWidth(), bb:getHeight(), SENTINEL)
        built:paintTo(bb, MARGIN, MARGIN)
        return bb, function(x, y)
            return pixel(bb, MARGIN + x, MARGIN + y)
        end
    end

    -- Every line of text in widget, top first by tree order: a text widget's text, or a tracked
    -- line's characters joined.
    local function texts(widget)
        local out = {}
        local function line_of(node)
            if type(node.text) == "string" then
                return node.text
            end
            local chars = {}
            for _, child in ipairs(node) do
                if getmetatable(child) == TextWidget then
                    chars[#chars + 1] = child.text
                elseif getmetatable(child) ~= HorizontalSpan then
                    return nil
                end
            end
            return #chars > 0 and table.concat(chars) or nil
        end
        local function walk(node)
            local line = line_of(node)
            if line then
                out[#out + 1] = line
                return
            end
            for _, child in ipairs(node) do
                walk(child)
            end
        end
        walk(widget)
        return out
    end

    local function has_text(widget, wanted)
        for _, line in ipairs(texts(widget)) do
            if line == wanted then
                return true
            end
        end
        return false
    end

    local PROFILES = {
        { name = "the Colorsoft", run = harness.at_colorsoft },
        { name = "the Paperwhite", run = harness.at_paperwhite },
    }

    local function each_profile(fn)
        for _, profile in ipairs(PROFILES) do
            profile.run(function()
                fn(profile.name)
            end)
        end
    end

    describe("geometry", function()
        it("fits the header, two rows, the pager and the nav bar on both profiles in both looks", function()
            each_profile(function(where)
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local grid = ctx.look.library.grid
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local used = LibraryTiles.header_height(ctx) + scale(grid.padding_top) + 2 * box.height
                        + scale(grid.row_gap) + LibraryTiles.pager_height(ctx) + NavBar.height(ctx.look, Screen)
                    assert.is_true(used <= Screen:getHeight(),
                        ("%s at %s: %d px for a %d px screen"):format(id, where, used, Screen:getHeight()))
                end
            end)
        end)

        -- The one-author grid's own cover box (series-and-authors "The fit"): only the cover's height
        -- and what hangs from it change.
        it("takes an optional cover height in board pixels, as the one-author grid's", function()
            each_profile(function(where)
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local cover_h = ctx.look.shelf.author_grid.cover_h
                    local plain = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local own = LibraryTiles.geometry(Screen:getWidth(), ctx, cover_h)
                    local label = id .. " at " .. where
                    assert.equals(scale(cover_h), own.cover_h, label)
                    assert.equals(scale(ctx.look.library.grid.cover_h), plain.cover_h, label)
                    assert.same(plain.columns, own.columns, label)
                    assert.equals(plain.cover_w, own.cover_w, label)
                    assert.equals(plain.strip_y - plain.cover_h, own.strip_y - own.cover_h, label)
                    assert.equals(plain.height - plain.cover_h, own.height - own.cover_h, label)
                end
            end)
        end)

        it("splits the width inside the side padding into three columns at the look's gap", function()
            each_profile(function(where)
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local grid = ctx.look.library.grid
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local cols = box.columns
                    local label = id .. " at " .. where
                    assert.equals(3, #cols, label)
                    assert.equals(scale(grid.side), cols[1].x, label)
                    assert.equals(Screen:getWidth() - scale(grid.side), cols[3].x + cols[3].w, label)
                    for i = 2, 3 do
                        assert.equals(scale(grid.column_gap), cols[i].x - cols[i - 1].x - cols[i - 1].w, label)
                    end
                    assert.equals(cols[1].w, box.cover_w, label)
                    assert.equals(scale(grid.cover_h), box.cover_h, label)
                end
            end)
        end)

        -- D13: cover, the strip's gap, the strip, the title's gap and one title line.
        it("is a tile of the cover, the strip's slot and one title line", function()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local look = ctx.look
                    local line = require("typeset").line(look.type.tile_title, "Piranesi", Screen:getWidth(), ctx)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    assert.equals(scale(look.library.grid.cover_h) + scale(look.library.grid.strip_gap)
                        + scale(look.library.strip.height) + scale(look.library.grid.title_gap) + line:getSize().h,
                        box.height, id)
                    line:free()
                end
            end)
        end)

        -- D12: the library's text does not follow text_size.
        it("keeps the tile, the header and the pager whatever the text size", function()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local plain = ctx_for(id)
                    for _, size in ipairs({ "small", "large", "xlarge" }) do
                        local sized = ctx_for(id, "day", size)
                        assert.same(LibraryTiles.geometry(Screen:getWidth(), plain),
                            LibraryTiles.geometry(Screen:getWidth(), sized), id .. " " .. size)
                        assert.equals(LibraryTiles.header_height(plain), LibraryTiles.header_height(sized), id)
                        assert.equals(LibraryTiles.pager_height(plain), LibraryTiles.pager_height(sized), id)
                    end
                end
            end)
        end)

        it("gives the header its padding, the count over the title or the pickers, and its edge", function()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local look = ctx.look
                    local header = look.library.header
                    local Typeset = require("typeset")
                    local function line_h(part)
                        local line = Typeset.line(look.type[part], "Library", Screen:getWidth(), ctx)
                        local h = line:getSize().h
                        line:free()
                        return h
                    end
                    local text = line_h("library_count") + scale(header.line_gap) + line_h("library_title")
                    local picker = line_h("library_picker")
                        + 2 * (scale(header.picker_padding.y) + scale(header.picker_outline_width))
                    assert.equals(scale(header.padding.top) + math.max(text, picker) + scale(header.padding.bottom)
                        + scale(header.edge_width), LibraryTiles.header_height(ctx), id)
                    local pager = look.library.pager
                    assert.equals(math.max(scale(pager.button_h), line_h("pager_label")) + scale(pager.bottom),
                        LibraryTiles.pager_height(ctx), id)
                end
            end)
        end)
    end)

    describe("a tile", function()
        -- One of each kind the grid draws, by name.
        local function kinds(ctx, box)
            return {
                ["a one-word title"] = LibraryTiles.book(record(), { status = "new" }, box, ctx),
                ["a title too long for a line"] = LibraryTiles.book(record{
                    title = string.rep("The Left Hand of Darkness ", 4) }, { status = "new" }, box, ctx),
                ["a book in progress"] = LibraryTiles.book(record(), READING, box, ctx),
                ["a complete book"] = LibraryTiles.book(record(), { status = "complete", percent = 1 }, box, ctx),
                ["a path-less record"] = LibraryTiles.book(remote(), { status = "new" }, box, ctx),
                ["a folder"] = LibraryTiles.folder({ name = "Hugo winners", path = "/books/hugo" },
                    { books = 14, reading = 3 }, box, ctx),
            }
        end

        it("is the cover's width and the geometry's height whatever it holds", function()
            covers()
            each_profile(function(where)
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    for name, built in pairs(kinds(ctx, box)) do
                        local size = built:getSize()
                        assert.same({ box.cover_w, box.height }, { size.w, size.h },
                            id .. " at " .. where .. ": " .. name)
                        built:free()
                    end
                end
            end)
        end)

        it("sets its title in one line no wider than the tile, cut with an ellipsis", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local long = string.rep("The Left Hand of Darkness ", 4)
                    local built = LibraryTiles.book(record{ title = long }, { status = "new" }, box, ctx)
                    assert.is_true(built.title:getSize().w <= box.cover_w, id)
                    -- One TextWidget cut at the tile's width, with KOReader's ellipsis
                    -- (frontend/ui/widget/textwidget.lua:37, :307-310).
                    assert.equals(TextWidget, getmetatable(built.title), id)
                    assert.is_true(built.title:isTruncated(), id)
                    assert.is_true(built.title.truncate_with_ellipsis, id)
                    built:free()
                    built = LibraryTiles.book(record(), { status = "new" }, box, ctx)
                    local want = ctx.look.type.tile_title.uppercase and "PIRANESI" or "Piranesi"
                    assert.same({ want }, texts(built.title), id)
                    built:free()
                end
            end)
        end)

        it("draws the strip for a reading or on-hold book with a percent and an empty slot otherwise", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local cases = {
                        { record(), READING, true, "reading" },
                        { record(), { status = "abandoned", percent = 0.3 }, true, "on hold" },
                        { record(), { status = "reading" }, false, "reading with no percent" },
                        { record(), { status = "new", percent = 0.3 }, false, "new" },
                        { record(), { status = "complete", percent = 1 }, false, "complete" },
                        { remote(), READING, false, "path-less" },
                    }
                    local title_y
                    for _, case in ipairs(cases) do
                        local built = LibraryTiles.book(case[1], case[2], box, ctx)
                        local label = id .. " " .. case[4]
                        assert.equals(case[3], built.strip ~= nil, label)
                        local y = built:place(built.title).y
                        title_y = title_y or y
                        assert.equals(title_y, y, label .. ": the title moved")
                        local bb, at = paint(built)
                        local strip_y = box.cover_h + scale(ctx.look.library.grid.strip_gap)
                        local mid = strip_y + math.floor(scale(ctx.look.library.strip.height) / 2)
                        if not case[3] then
                            assert.same(GREEN, at(math.floor(box.cover_w / 2), mid), label .. ": the slot is painted")
                        end
                        bb:free()
                        built:free()
                    end
                end
            end)
        end)

        -- As nav_bar_spec samples the bar: Diner's strip a 2 px outline round a mustard fill on paper,
        -- the fill a 135° hatch of ink on paper in grey; Editorial's an ink fill on a hairline track.
        it("fills the strip in the look's progress colours in day, night and grey", function()
            covers()
            harness.at_colorsoft(function()
                for _, variant in ipairs({ "day", "night", "grey" }) do
                    for _, id in ipairs({ "diner", "editorial" }) do
                        local ctx = ctx_for(id, variant)
                        local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                        local built = LibraryTiles.book(record(), READING, box, ctx)
                        local bb, at = paint(built)
                        local label = id .. " " .. variant
                        local strip_y = box.cover_h + scale(ctx.look.library.grid.strip_gap)
                        local strip_h = scale(ctx.look.library.strip.height)
                        local mid = strip_y + math.floor(strip_h / 2)
                        local filled_w = math.floor(box.cover_w * 0.62)
                        if id == "diner" then
                            local edge = scale(ctx.look.library.strip.outline_width)
                            assert.is_true(near(role(ctx, "outline"), at(0, mid)), label .. " outline left")
                            assert.is_true(near(role(ctx, "outline"), at(5, strip_y)), label .. " outline top")
                            assert.is_true(near(role(ctx, "outline"), at(5, strip_y + strip_h - 1)),
                                label .. " outline bottom")
                            assert.is_true(near(role(ctx, "paper"), at(box.cover_w - edge - 2, mid)), label .. " track")
                            if variant == "grey" then
                                local ink, paper = 0, 0
                                for x = edge, filled_w - edge - 1 do
                                    local p = at(x, mid)
                                    ink = ink + (near(role(ctx, "ink"), p) and 1 or 0)
                                    paper = paper + (near(role(ctx, "paper"), p) and 1 or 0)
                                end
                                assert.is_true(ink > 0 and paper > 0, label .. " hatch: " .. ink .. " ink, "
                                    .. paper .. " paper")
                            else
                                assert.is_true(near(role(ctx, "mustard"), at(edge + 2, mid)), label .. " fill")
                            end
                        else
                            assert.is_true(near(role(ctx, "ink"), at(2, mid)), label .. " fill")
                            assert.is_true(near(role(ctx, "hairline"), at(box.cover_w - 2, mid)), label .. " track")
                            assert.same(GREEN, at(2, strip_y + strip_h), label .. " under the strip")
                        end
                        bb:free()
                        built:free()
                    end
                end
            end)
        end)

        it("draws the cached cover fitted inside the frame, a landscape one with paper above and below", function()
            covers(function()
                return { has_cover = true, cover_fetched = "Y", cover_w = 600, cover_h = 300,
                    cover_bb = red_bb(600, 300) }
            end)
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local built = LibraryTiles.book(record(), { status = "new" }, box, ctx)
                    local bb, at = paint(built)
                    local mid_x, mid_y = math.floor(box.cover_w / 2), math.floor(box.cover_h / 2)
                    assert.same(RED, at(mid_x, mid_y), id .. " the cover's middle")
                    local paper = role(ctx, "paper")
                    local edge = id == "diner" and scale(ctx.look.library.cover.outline_width) or 0
                    assert.same(paper, at(mid_x, edge + 2), id .. " above the cover")
                    assert.same(paper, at(mid_x, box.cover_h - edge - 3), id .. " below the cover")
                    if id == "diner" then
                        local outline = role(ctx, "outline")
                        assert.same(outline, at(0, mid_y), id .. " the frame's left")
                        assert.same(outline, at(box.cover_w - 1, mid_y), id .. " the frame's right")
                        assert.same(outline, at(mid_x, 0), id .. " the frame's top")
                    end
                    local shadow = ctx.look.library.cover.shadow
                    assert.same(role(ctx, shadow.color), at(box.cover_w + scale(shadow.x) - 1, mid_y), id .. " shadow")
                    bb:free()
                    built:free()
                end
            end)
        end)

        -- The hairline FeaturedCover.build frames the featured cover in (featured_cover.lua): the
        -- outline role, false by day, so the day cover runs to the box's edge.
        it("frames Editorial's cached cover in the outline role at night and in grey and in none by day", function()
            local cover_w, cover_h
            covers(function()
                return { has_cover = true, cover_fetched = "Y", cover_w = cover_w, cover_h = cover_h,
                    cover_bb = red_bb(cover_w, cover_h) }
            end)
            harness.at_colorsoft(function()
                for _, variant in ipairs({ "day", "night", "grey" }) do
                    local ctx = ctx_for("editorial", variant)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    cover_w, cover_h = box.cover_w, box.cover_h
                    local built = LibraryTiles.book(record(), { status = "new" }, box, ctx)
                    local bb, at = paint(built)
                    local want = variant == "day" and RED or role(ctx, "outline")
                    local mid_x, mid_y = math.floor(box.cover_w / 2), math.floor(box.cover_h / 2)
                    assert.is_true(near(want, at(0, mid_y)), variant .. " the cover's left edge")
                    assert.is_true(near(want, at(mid_x, 0)), variant .. " the cover's top edge")
                    assert.same(RED, at(mid_x, mid_y), variant .. " the cover's middle")
                    bb:free()
                    built:free()
                end
            end)
        end)

        -- The cover's bitmap goes with the ImageWidget holding it, so a tile frees it and its
        -- icons through its children; the icons' masks stay in TintedIcon's cache.
        it("frees its cover's bitmap and its icons' masks", function()
            local Books = package.loaded["books"]
            local ImageWidget = require("ui/widget/imagewidget")
            local TintedIcon = package.loaded["tinted_icon"]
            Books.add_source({ name = "shelf", cover = function(_, w, h)
                return red_bb(w, h)
            end })
            local image_free, icon_free = ImageWidget.free, TintedIcon.free
            local freed = { images = 0, icons = 0 }
            ImageWidget.free = function(self, ...)
                freed.images = freed.images + 1
                return image_free(self, ...)
            end
            TintedIcon.free = function(self, ...)
                freed.icons = freed.icons + 1
                return icon_free(self, ...)
            end
            finally(function()
                ImageWidget.free, TintedIcon.free = image_free, icon_free
                Books.reset()
            end)
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local built = LibraryTiles.book(remote(), { status = "new" }, box, ctx)
                    assert.is_table(built.badge, id)
                    freed.images, freed.icons = 0, 0
                    built:free()
                    assert.same({ images = 1, icons = 1 }, freed, id .. " a path-less book's tile")
                    built = LibraryTiles.folder({ name = "Hugo winners", path = "/books/hugo" },
                        { books = 14, reading = 3 }, box, ctx)
                    freed.images, freed.icons = 0, 0
                    built:free()
                    assert.same({ images = 0, icons = 1 }, freed, id .. " a folder's tile")
                end
            end)
        end)

        it("draws a book with no cover as the placeholder: the cover fill and its title in on_cover", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local built = LibraryTiles.book(record(), { status = "new" }, box, ctx)
                    assert.is_true(has_text(built.cover, "Piranesi"), id)
                    local bb, at = paint(built)
                    assert.same(role(ctx, "cover"), at(math.floor(box.cover_w / 2), box.cover_h - scale(8)), id)
                    local on_cover, fill = role(ctx, "on_cover"), role(ctx, "cover")
                    local pad = ctx.look.library.cover.padding
                    local inked = 0
                    for y = scale(pad.y), scale(pad.y) + scale(20) do
                        for x = scale(pad.x), box.cover_w - scale(pad.x) do
                            local p = at(x, y)
                            if not near(p, fill) and near(p, on_cover) then
                                inked = inked + 1
                            end
                        end
                    end
                    assert.is_true(inked > 0, id .. " no title ink at the placeholder's top")
                    bb:free()
                    built:free()
                end
            end)
        end)

        it("puts the badge and the Not downloaded chip on a path-less record's cover only", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local tokens = ctx.look.library.badge
                    local size = scale(tokens.size)
                    local downloaded = LibraryTiles.book(record(), READING, box, ctx)
                    assert.is_nil(downloaded.badge, id)
                    assert.is_nil(downloaded.chip, id)
                    assert.is_false(has_text(downloaded, "NOT DOWNLOADED"), id)
                    downloaded:free()

                    local built = LibraryTiles.book(remote(), { status = "new" }, box, ctx)
                    assert.is_table(built.badge, id)
                    assert.is_table(built.chip, id)
                    assert.is_true(has_text(built.chip, "NOT DOWNLOADED"), id)
                    local badge, chip = built:place(built.badge), built:place(built.chip)
                    local chip_size = built.chip:getSize()
                    -- The chip sits on the cover's foot, left of the badge's corner.
                    assert.is_true(chip.y + chip_size.h <= box.cover_h, id .. " chip below the cover")
                    assert.is_true(chip.y + chip_size.h >= box.cover_h - scale(40), id .. " chip off the foot")
                    assert.is_true(chip.x + chip_size.w <= badge.x or chip.y + chip_size.h <= badge.y
                        or chip.y >= badge.y + size, id .. " chip under the badge")
                    if id == "diner" then
                        -- Overhanging the cover's top right corner (Main.dc.html:66).
                        assert.is_true(badge.x + size > box.cover_w, id .. " badge not past the right edge")
                        assert.is_true(badge.y < 0, id .. " badge not above the top")
                    else
                        -- Inside the bottom right corner (GridA.dc.html:66).
                        local inset = scale(tokens.inset)
                        assert.equals(box.cover_w - inset - size, badge.x, id)
                        assert.equals(box.cover_h - inset - size, badge.y, id)
                    end
                    local bb, at = paint(built)
                    local cx, cy = badge.x + math.floor(size / 2), badge.y + math.floor(size / 2)
                    local ring = scale(tokens.outline_width)
                    assert.same(role(ctx, tokens.outline_color), at(cx, badge.y + math.floor(ring / 2)),
                        id .. " the badge's ring top")
                    assert.same(role(ctx, tokens.fill_color), at(badge.x + ring + 3, cy),
                        id .. " the badge's fill")
                    local inked = 0
                    local icon = scale(tokens.icon_size)
                    for y = cy - math.floor(icon / 2), cy + math.floor(icon / 2) do
                        for x = cx - math.floor(icon / 2), cx + math.floor(icon / 2) do
                            if near(at(x, y), role(ctx, tokens.icon_color)) then
                                inked = inked + 1
                            end
                        end
                    end
                    assert.is_true(inked > 0, id .. " the badge has no download mark")
                    -- The chip's fill (Diner pink, Editorial paper) at its middle's left padding.
                    assert.is_true(near(role(ctx, ctx.look.library.not_downloaded.fill_color),
                        at(chip.x + scale(ctx.look.library.not_downloaded.outline_width) + 1,
                            chip.y + math.floor(chip_size.h / 2))), id .. " the chip's fill")
                    bb:free()
                    built:free()
                end
            end)
        end)

        -- A tracked line too wide for its room falls back to one TextWidget, untracked and cut with
        -- KOReader's ellipsis (typeset.lua), which keeps its full text but draws "NOT DOWNLOAD…"; so
        -- the chip's line must be as wide as the label set in its type with room to spare.
        it("sets Not downloaded in full, tracked as its type says, on both profiles in both looks", function()
            covers()
            local Typeset = require("typeset")
            each_profile(function(where)
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local built = LibraryTiles.book(remote(), { status = "new" }, box, ctx)
                    local label = id .. " at " .. where
                    assert.is_true(has_text(built.chip, "NOT DOWNLOADED"), label)
                    local free = Typeset.line(ctx.look.type.not_downloaded, "Not downloaded",
                        10 * Screen:getWidth(), ctx)
                    assert.equals(free:getSize().w, built.chip[1]:getSize().w, label .. ": the label is cut")
                    free:free()
                    built:free()
                end
            end)
        end)

        -- D5, D19: "Up next" on the cover's foot where Not downloaded goes; on a path-less record it
        -- replaces that chip and the badge stays. The tile keeps its height.
        it("puts the Up next chip on the cover's foot, in place of Not downloaded, the badge kept", function()
            covers()
            each_profile(function(where)
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local label = id .. " at " .. where
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx, ctx.look.shelf.author_grid.cover_h)
                    local plain = LibraryTiles.book(record(), { status = "new" }, box, ctx)
                    local plain_h = plain:getSize().h
                    plain:free()

                    local built = LibraryTiles.book(record(), { status = "new" }, box, ctx, { label = "Up next" })
                    assert.equals(plain_h, built:getSize().h, label)
                    assert.is_table(built.chip, label)
                    assert.is_nil(built.badge, label)
                    assert.is_true(has_text(built.chip, "UP NEXT"), label)
                    local chip, chip_size = built:place(built.chip), built.chip:getSize()
                    assert.is_true(chip.x >= 0 and chip.x + chip_size.w <= box.cover_w, label .. " chip across")
                    assert.is_true(chip.y + chip_size.h <= box.cover_h, label .. " chip below the cover")
                    assert.is_true(chip.y + chip_size.h >= box.cover_h - scale(40), label .. " chip off the foot")
                    local bb, at = paint(built)
                    local tokens = ctx.look.shelf.up_next
                    assert.is_true(near(role(ctx, tokens.fill_color),
                        at(chip.x + scale(tokens.outline_width) + 1, chip.y + math.floor(chip_size.h / 2))),
                        label .. " the chip's fill")
                    bb:free()
                    built:free()

                    local remote_plain = LibraryTiles.book(remote(), { status = "new" }, box, ctx)
                    local nd_place = remote_plain:place(remote_plain.chip)
                    remote_plain:free()
                    built = LibraryTiles.book(remote(), { status = "new" }, box, ctx, { label = "Up next" })
                    assert.equals(plain_h, built:getSize().h, label .. " path-less")
                    assert.is_table(built.badge, label .. " path-less badge")
                    assert.is_true(has_text(built.chip, "UP NEXT"), label .. " path-less chip")
                    assert.is_false(has_text(built, "NOT DOWNLOADED"), label .. " path-less")
                    local up = built:place(built.chip)
                    assert.equals(nd_place.x, up.x, label .. " at Not downloaded's place")
                    local badge, size = built:place(built.badge), built.badge:getSize().w
                    local up_size = built.chip:getSize()
                    assert.is_true(up.x + up_size.w <= badge.x or up.y + up_size.h <= badge.y
                        or up.y >= badge.y + size, label .. " chip under the badge")
                    built:free()
                end
            end)
        end)

        it("shows a folder's book count, its reading count when any, and its name", function()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local function folder(counts)
                        return LibraryTiles.folder({ name = "Hugo winners", path = "/books/hugo" }, counts, box, ctx)
                    end
                    local reading_word = ctx.look.type.folder_reading.uppercase and "3 READING" or "3 reading"
                    local name = ctx.look.type.tile_title.uppercase and "HUGO WINNERS" or "Hugo winners"
                    local built = folder{ books = 14, reading = 3 }
                    assert.is_true(has_text(built, "14 books"), id)
                    assert.is_true(has_text(built, reading_word), id)
                    assert.same({ name }, texts(built.title), id)
                    assert.is_nil(built.strip, id)
                    assert.is_nil(built.badge, id)
                    built:free()
                    built = folder{ books = 1, reading = 0 }
                    assert.is_true(has_text(built, "1 book"), id)
                    for _, line in ipairs(texts(built)) do
                        assert.is_nil(line:lower():find("reading", 1, true), id .. ": " .. line)
                    end
                    built:free()
                    built = folder{ books = 0, reading = 0 }
                    assert.is_true(has_text(built, "No books"), id)
                    built:free()
                end
            end)
        end)

        it("fills a folder's cover box in the look's folder colour with its folder icon at the top", function()
            harness.at_colorsoft(function()
                for _, id in ipairs({ "diner", "editorial" }) do
                    local ctx = ctx_for(id)
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                    local tokens = ctx.look.library.folder
                    local built = LibraryTiles.folder({ name = "Hugo winners", path = "/books/hugo" },
                        { books = 14, reading = 3 }, box, ctx)
                    local bb, at = paint(built)
                    local edge = scale(tokens.outline_width)
                    assert.same(role(ctx, tokens.outline_color), at(0, math.floor(box.cover_h / 2)), id .. " edge")
                    assert.same(role(ctx, tokens.fill_color), at(box.cover_w - edge - 2, math.floor(box.cover_h / 2)),
                        id .. " fill")
                    local inked, icon = 0, scale(tokens.icon_size)
                    local x0, y0 = edge + scale(tokens.padding.x), edge + scale(tokens.padding.y)
                    for y = y0, y0 + icon - 1 do
                        for x = x0, x0 + icon - 1 do
                            if near(at(x, y), role(ctx, tokens.icon_color)) then
                                inked = inked + 1
                            end
                        end
                    end
                    assert.is_true(inked > 0, id .. " no folder icon at the top left")
                    bb:free()
                    built:free()
                end
            end)
        end)

        it("paints every kind in day, night and grey on both profiles", function()
            covers()
            each_profile(function(where)
                for _, variant in ipairs({ "day", "night", "grey" }) do
                    for _, id in ipairs({ "diner", "editorial" }) do
                        local ctx = ctx_for(id, variant)
                        local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                        for name, built in pairs(kinds(ctx, box)) do
                            local ok, bb = pcall(paint, built)
                            assert.is_true(ok, ("%s %s at %s, %s: %s"):format(id, variant, where, name, tostring(bb)))
                            bb:free()
                            built:free()
                        end
                    end
                end
            end)
        end)

        -- The region a cover arrival refreshes (library_covers.lua) is a tile's box widened by
        -- LibraryTiles.overhang: every pixel a book's tile paints lies inside it, and by day, when
        -- the shadow is drawn, a path-less tile's ink reaches its top and right edges.
        it("paints a book's tile only inside its box widened by its overhang, reaching the top and right", function()
            covers()
            each_profile(function(where)
                for _, variant in ipairs({ "day", "night", "grey" }) do
                    for _, id in ipairs({ "diner", "editorial" }) do
                        local ctx = ctx_for(id, variant)
                        local box = LibraryTiles.geometry(Screen:getWidth(), ctx)
                        local over = LibraryTiles.overhang(box, ctx)
                        local label = ("%s %s at %s"):format(id, variant, where)
                        local tiles = {
                            remote = LibraryTiles.book(remote(), { status = "new" }, box, ctx),
                            file = LibraryTiles.book(record(), READING, box, ctx),
                        }
                        for kind, built in pairs(tiles) do
                            local bb = paint(built)
                            local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
                            for y = 0, bb:getHeight() - 1 do
                                for x = 0, bb:getWidth() - 1 do
                                    local c = bb:getPixel(x, y):getColorRGB32()
                                    if c:getR() ~= 0 or c:getG() ~= 255 or c:getB() ~= 0 then
                                        min_x, max_x = math.min(min_x, x), math.max(max_x, x)
                                        min_y, max_y = math.min(min_y, y), math.max(max_y, y)
                                    end
                                end
                            end
                            bb:free()
                            built:free()
                            local what = label .. ", " .. kind
                            assert.is_true(min_x >= MARGIN, what .. " left")
                            assert.is_true(min_y >= MARGIN - over.top, what .. " top")
                            assert.is_true(max_x <= MARGIN + box.cover_w + over.right - 1, what .. " right")
                            assert.is_true(max_y <= MARGIN + box.height + over.bottom - 1, what .. " bottom")
                            if kind == "remote" and variant == "day" then
                                assert.equals(MARGIN - over.top, min_y, what .. " top reached")
                                assert.equals(MARGIN + box.cover_w + over.right - 1, max_x, what .. " right reached")
                            end
                        end
                    end
                end
            end)
        end)

        -- Diner sets text on its mustard and pink in on_accent, the dark text it keeps by night
        -- (looks/diner.lua:34, :53).
        it("keeps Diner's text on pink dark by night", function()
            harness.at_colorsoft(function()
                local ctx = ctx_for("diner", "night")
                local look = ctx.look
                for _, part in ipairs({ "folder_count", "folder_reading", "not_downloaded" }) do
                    assert.equals("on_accent", look.type[part].color, part)
                end
                assert.equals("on_accent", look.library.folder.icon_color)
            end)
        end)
    end)
end)
