-- ShelfRows (series-and-authors C3): the series list's row, the one-series list's book row and the
-- authors list's letter group, each of a fixed height for its kind, in both looks; the one-author
-- grid's fit and the three lists' counts on the device profiles (feature "The fit"). Every case runs
-- at a device profile's size, as the screens will.
describe("shelf rows", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local Screen = require("device").screen
    local TextWidget = require("ui/widget/textwidget")
    local Books, LibraryTiles, Looks, NavBar, ShelfRows, Typeset

    setup(function()
        harness.load()
        Books = package.loaded["books"]
        LibraryTiles = package.loaded["library_tiles"]
        Looks = package.loaded["looks"]
        NavBar = package.loaded["nav_bar"]
        ShelfRows = package.loaded["shelf_rows"]
        Typeset = package.loaded["typeset"]
    end)

    local IDS = { "diner", "editorial" }

    local function scale(px)
        return Screen:scaleBySize(px)
    end

    local function ctx_for(id, variant, text_size)
        return { look = Looks.get(id), variant = variant or "day", text_size = text_size, screen = Screen }
    end

    local function book(title, fields)
        local record = { id = "file:/books/" .. title .. ".epub", path = "/books/" .. title .. ".epub", title = title,
            authors = { "N. K. Jemisin" }, series = "The Broken Earth" }
        for k, v in pairs(fields or {}) do
            record[k] = v
        end
        return record
    end

    -- A path-less record of the "shelf" source, as a source registers one.
    local function remote(title, fields)
        local record = book(title, fields)
        record.id, record.path, record.source = "shelf:" .. title, nil, "shelf"
        return record
    end

    local FIFTH = book("The Fifth Season", { series_index = 1 })
    local OBELISK = book("The Obelisk Gate", { series_index = 2 })
    local STONE = book("The Stone Sky", { series_index = 3 })

    local function entry(fields)
        local out = { name = "The Broken Earth", books = { FIFTH, OBELISK, STONE }, state = "under_way",
            complete = 1, total = 3, next = OBELISK, author = "N. K. Jemisin", others = false }
        for k, v in pairs(fields or {}) do
            out[k] = v
        end
        return out
    end

    -- No CoverBrowser rows: every cover with a file draws its plain fill. Restored in finally.
    local function covers()
        local loaded = package.loaded.bookinfomanager
        package.loaded.bookinfomanager = {
            getBookInfo = function()
                return nil
            end,
            isCachedCoverInvalid = function()
                return false
            end,
        }
        finally(function()
            package.loaded.bookinfomanager = loaded
        end)
    end

    local SENTINEL = Blitbuffer.ColorRGB32(0, 255, 0, 255)
    local GREEN = { 0, 255, 0 }
    -- Room round a painted row for what reaches past its box: the shadows and Diner's badge.
    local MARGIN = 40

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local function rgb_of(color)
        local c = color:getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local function role(ctx, name)
        return rgb_of(Looks.color(Looks.palette(ctx.look, ctx.variant)[name]))
    end

    local function paint(built)
        local size = built:getSize()
        local bb = Blitbuffer.new(size.w + 2 * MARGIN, size.h + 2 * MARGIN, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, bb:getWidth(), bb:getHeight(), SENTINEL)
        built:paintTo(bb, MARGIN, MARGIN)
        return bb, function(x, y)
            return pixel(bb, MARGIN + x, MARGIN + y)
        end
    end

    -- A line's text: a text widget's, or a tracked line's characters joined; nil for anything else.
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

    local function texts(widget)
        local out = {}
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

    -- The colour a line is set in: its own, or its first glyph's.
    local function line_color(line)
        if line.fgcolor then
            return rgb_of(line.fgcolor)
        end
        return line_color(line[1])
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

    -- A list row's width: the screen inside the list's side padding.
    local function row_width(ctx)
        return Screen:getWidth() - 2 * scale(ctx.look.shelf.list.side)
    end

    local function line_h(part, ctx)
        local line = Typeset.line(part, "Library", math.huge, { look = ctx.look, variant = ctx.variant,
            screen = ctx.screen })
        local h = line:getSize().h
        line:free()
        return h
    end

    -- The one-series and one-author header (SeriesBooksC.dc.html:19-30, AuthorBooksA.dc.html:19-28): the
    -- detail padding, the back control (its label or icon, the taller, inside its padding and outline),
    -- the back gap, the library's count over the detail title at the header's line gap, and the edge.
    local function detail_header_height(ctx)
        local look = ctx.look
        local shelf, header = look.shelf, look.library.header
        local back = shelf.back
        local back_h = math.max(scale(back.icon_size), line_h(look.type.shelf_back, ctx))
            + 2 * (scale(back.padding.y) + scale(back.outline_width))
        return scale(shelf.detail.padding.top) + back_h + scale(shelf.detail.back_gap)
            + line_h(look.type.library_count, ctx) + scale(header.line_gap) + line_h(look.type.shelf_detail_title, ctx)
            + scale(shelf.detail.padding.bottom) + scale(header.edge_width)
    end

    -- The height between a header and the pager, in which a list's rows go.
    local function room_under(header_h, padding_top, ctx)
        return Screen:getHeight() - header_h - scale(padding_top) - LibraryTiles.pager_height(ctx)
            - NavBar.height(ctx.look, Screen)
    end

    describe("a series row", function()
        it("shows the name, D15's sub-line and the chip for each state", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local width = row_width(ctx)
                    -- D15: under way with no next unread, the book count (the owner, 2026-10-17).
                    local no_next = entry()
                    no_next.next = nil
                    local cases = {
                        { entry(), "1 OF 3", "N. K. Jemisin · next: The Obelisk Gate" },
                        { entry{ next = false }, "1 OF 3", "N. K. Jemisin · 3 books" },
                        { no_next, "1 OF 3", "N. K. Jemisin · 3 books" },
                        { entry{ name = "The Murderbot Diaries", state = "finished", complete = 3, next = false,
                            author = "Martha Wells" }, "FINISHED", "Martha Wells · 3 books" },
                        { entry{ name = "Wayfarers", state = "not_started", complete = 0, next = FIFTH,
                            author = "Becky Chambers", books = { FIFTH }, total = 1 }, "NOT STARTED",
                            "Becky Chambers · 1 book" },
                        { entry{ others = true }, "1 OF 3", "N. K. Jemisin and others · next: The Obelisk Gate" },
                        { entry{ author = false, state = "finished", complete = 3, next = false }, "FINISHED",
                            "3 books" },
                    }
                    for _, case in ipairs(cases) do
                        local built = ShelfRows.series(case[1], width, ctx)
                        local label = id .. " " .. case[1].name .. " " .. case[2]
                        assert.same({ case[1].name }, texts(built.name), label)
                        assert.same({ case[3] }, texts(built.sub), label)
                        assert.same({ case[2] }, texts(built.chip), label)
                        built:free()
                    end
                end
            end)
        end)

        -- D21: up to three covers, the first in series order in front, left-most and lowest
        -- (SeriesC.dc.html:29-33); a series of one has one cover and no offset.
        it("stacks one, two or three covers with the first in front", function()
            local colours = {
                ["The Fifth Season"] = Blitbuffer.ColorRGB32(255, 0, 0, 255),
                ["The Obelisk Gate"] = Blitbuffer.ColorRGB32(0, 0, 255, 255),
                ["The Stone Sky"] = Blitbuffer.ColorRGB32(255, 0, 255, 255),
            }
            Books.add_source({ name = "shelf", cover = function(record, w, h)
                local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
                bb:paintRectRGB32(0, 0, w, h, colours[record.title])
                return bb
            end })
            finally(function()
                Books.reset()
            end)
            covers()
            local all = { remote("The Fifth Season"), remote("The Obelisk Gate"), remote("The Stone Sky") }
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local stack = ctx.look.shelf.stack
                    for n = 1, 3 do
                        local books = {}
                        for i = 1, n do
                            books[i] = all[i]
                        end
                        local built = ShelfRows.series(entry{ books = books, total = n }, row_width(ctx), ctx)
                        local label = id .. " a stack of " .. n
                        assert.equals(n, #built.covers, label)
                        local front = built.stack:place(built.covers[1])
                        for i = 2, n do
                            local other = built.stack:place(built.covers[i])
                            assert.is_true(front.x < other.x, label .. ": the first is not left-most")
                            assert.is_true(front.y > other.y, label .. ": the first is not lowest")
                            assert.equals(scale(stack.offset_x) * (i - 1), other.x - front.x, label)
                        end
                        local bb, at = paint(built)
                        local origin = built:place(built.stack)
                        local w, h = scale(stack.cover_w), scale(stack.cover_h)
                        local edge = scale(stack.outline_width)
                        -- The front cover's middle shows its own colour.
                        local fx, fy = origin.x + front.x + math.floor(w / 2), origin.y + front.y + math.floor(h / 2)
                        assert.same({ 255, 0, 0 }, at(fx, fy), label .. " front")
                        if n > 1 then
                            -- The last cover's right strip, past every cover before it, shows its colour
                            -- at its middle (the fitted image leaves paper above and below it).
                            local last = built.stack:place(built.covers[n])
                            local lx = origin.x + last.x + w - edge - 2
                            local want = n == 2 and { 0, 0, 255 } or { 255, 0, 255 }
                            assert.same(want, at(lx, origin.y + last.y + math.floor(h / 2)), label .. " back")
                        end
                        bb:free()
                        built:free()
                    end
                end
            end)
        end)

        it("sets a name and a sub-line too long for the row in one line each, cut with an ellipsis", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local long = string.rep("The Long Way to a Small Angry Planet ", 4)
                    local built = ShelfRows.series(entry{ name = long, author = long }, row_width(ctx), ctx)
                    for _, part in ipairs({ "name", "sub" }) do
                        local line = built[part]
                        assert.equals(TextWidget, getmetatable(line), id .. " " .. part)
                        assert.is_true(line:isTruncated(), id .. " " .. part)
                        assert.is_true(line.truncate_with_ellipsis, id .. " " .. part)
                        local place = built:place(line)
                        assert.is_true(place.x + line:getSize().w <= built:place(built.chip).x, id .. " " .. part)
                    end
                    built:free()
                end
            end)
        end)
    end)

    describe("a book row", function()
        local NEW = { status = "new" }
        local COMPLETE = { status = "complete", percent = 1 }
        local READING = { status = "reading", percent = 0.62 }

        it("draws D20's line and chip for each state", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local width = row_width(ctx)
                    local function row(record, progress, mark)
                        return ShelfRows.book(record, progress, mark, width, ctx)
                    end
                    local next_note = ctx.look.type.book_next_note.uppercase and "READ THIS ONE NEXT"
                        or "read this one next"

                    local built = row(FIFTH, COMPLETE, false)
                    assert.same({ "1" }, texts(built.index), id)
                    assert.same({ "The Fifth Season" }, texts(built.title), id)
                    assert.is_table(built.bar, id .. " complete bar")
                    local outline = built.bar.outline
                    assert.equals(built.bar:getSize().w - 2 * outline, built.bar[1].dimen.w, id .. " full bar")
                    assert.same({ "FINISHED" }, texts(built.chip), id)
                    assert.is_nil(built.note, id)
                    assert.is_nil(built.badge, id)
                    built:free()

                    built = row(OBELISK, READING, false)
                    assert.is_table(built.bar, id .. " reading bar")
                    local inner = built.bar:getSize().w - 2 * built.bar.outline
                    assert.equals(math.floor(inner * 62 / 100), built.bar[1].dimen.w, id .. " reading bar")
                    assert.is_nil(built.chip, id .. " reading chip")
                    assert.is_nil(built.note, id)
                    built:free()

                    built = row(OBELISK, NEW, true)
                    assert.is_nil(built.bar, id)
                    assert.same({ next_note }, texts(built.note), id)
                    assert.same({ "UP NEXT" }, texts(built.chip), id)
                    assert.is_true(built.marked, id)
                    if id == "diner" then
                        local bb, at = paint(built)
                        local edge = scale(ctx.look.shelf.row.outline_width)
                        assert.same(role(ctx, "mustard"), at(edge + 2, edge + 2), id .. " the up-next fill")
                        bb:free()
                    end
                    built:free()

                    -- A book not downloaded: the badge is its one sign, so no chip of its own
                    -- (tweaks/badge-only-not-downloaded).
                    local stone = remote("The Stone Sky", { series_index = 3 })
                    built = row(stone, NEW, false)
                    assert.is_table(built.badge, id .. " badge")
                    assert.same({ "Not on the Kindle yet" }, texts(built.note), id)
                    assert.is_nil(built.chip, id .. " not-downloaded chip")
                    assert.is_falsy(built.marked, id)
                    built:free()

                    built = row(stone, COMPLETE, false)
                    assert.is_table(built.badge, id .. " finished badge")
                    assert.same({ "FINISHED" }, texts(built.chip), id)
                    built:free()

                    -- D19: marked, its note, and the chip says Up next.
                    built = row(stone, NEW, true)
                    assert.is_table(built.badge, id .. " up-next badge")
                    assert.same({ next_note }, texts(built.note), id)
                    assert.same({ "UP NEXT" }, texts(built.chip), id)
                    assert.is_true(built.marked, id)
                    if id == "diner" then
                        local bb, at = paint(built)
                        local edge = scale(ctx.look.shelf.row.outline_width)
                        assert.same(role(ctx, "mustard"), at(edge + 2, edge + 2), id .. " the up-next fill")
                        bb:free()
                    end
                    built:free()
                end
            end)
        end)

        -- SeriesBooksC.dc.html:33-35: the row inside shelf.book.padding, the cover cover_w by cover_h with
        -- its outline outside (the owner, 2026-10-17): Diner's 68 by 100, Editorial's 64 by 96. The cover is
        -- the row's tallest item, so it fills the row inside the padding.
        it("pads the row by shelf.book.padding and draws the cover's outline outside its size", function()
            covers()
            each_profile(function(where)
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local look = ctx.look
                    local tokens, row = look.shelf.book, look.shelf.row
                    local label = id .. " at " .. where
                    local outline = scale(row.outline_width)
                    local rule, edge = scale(row.rule_width), scale(tokens.cover_outline_width)
                    local board = id == "diner" and { 68, 100 } or { 64, 96 }
                    assert.same(board, { tokens.cover_w + 2 * tokens.cover_outline_width,
                        tokens.cover_h + 2 * tokens.cover_outline_width }, label)
                    local cover_w, cover_h = scale(tokens.cover_w) + 2 * edge, scale(tokens.cover_h) + 2 * edge
                    for _, record in ipairs({ FIFTH, remote("The Stone Sky", { series_index = 3 }) }) do
                        local built = ShelfRows.book(record, { status = "new" }, false, row_width(ctx), ctx)
                        local size, place = built.cover:getSize(), built:place(built.cover)
                        assert.same({ cover_w, cover_h }, { size.w, size.h }, label .. " the cover's box")
                        assert.equals(outline + scale(tokens.padding.x) + scale(tokens.index_w) + scale(row.gap),
                            place.x, label .. " the cover's x")
                        assert.equals(outline + scale(tokens.padding.y), place.y, label .. " the cover's y")
                        assert.equals(2 * (outline + scale(tokens.padding.y)) + cover_h + rule, built:getSize().h,
                            label .. " the row's height")
                        built:free()
                    end
                    -- The stack's covers keep cover_w by cover_h as their box, the outline inside it.
                    local series = ShelfRows.series(entry(), row_width(ctx), ctx)
                    local stack = look.shelf.stack
                    assert.same({ scale(stack.cover_w), scale(stack.cover_h) },
                        { series.covers[1]:getSize().w, series.covers[1]:getSize().h }, label .. " a stack cover")
                    series:free()
                end
            end)
        end)

        it("writes a whole index without decimals and any other as written, and none as a blank column", function()
            covers()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local width = row_width(ctx)
                    local with = ShelfRows.book(book("A", { series_index = 2.0 }), NEW, false, width, ctx)
                    assert.same({ "2" }, texts(with.index), id)
                    local half = ShelfRows.book(book("B", { series_index = 1.5 }), NEW, false, width, ctx)
                    assert.same({ "1.5" }, texts(half.index), id)
                    local none = ShelfRows.book(book("C"), NEW, false, width, ctx)
                    assert.is_nil(none.index, id)
                    assert.equals(with:getSize().h, none:getSize().h, id)
                    assert.equals(with:place(with.cover).x, none:place(none.cover).x, id .. " the index column kept")
                    with:free()
                    half:free()
                    none:free()
                end
            end)
        end)

        -- Typeset's parts carry one colour each, so the up-next row sets its text in copies whose colour
        -- is shelf.next.text_color; Diner's mustard keeps dark text by night.
        it("sets Diner's up-next row in on_accent at night and leaves the look's parts as they are", function()
            covers()
            harness.at_colorsoft(function()
                local ctx = ctx_for("diner", "night")
                local look = ctx.look
                assert.equals("on_accent", look.shelf.next.text_color)
                local built = ShelfRows.book(OBELISK, NEW, true, row_width(ctx), ctx)
                local want = role(ctx, "on_accent")
                assert.same(want, line_color(built.title), "title")
                assert.same(want, line_color(built.index), "index")
                assert.same(want, line_color(built.note), "note")
                assert.equals("ink", look.type.book_row_title.color)
                built:free()
                built = ShelfRows.book(FIFTH, { status = "new" }, false, row_width(ctx), ctx)
                assert.same(role(ctx, "ink"), line_color(built.title), "an unmarked title")
                built:free()
            end)
        end)
    end)

    describe("an author group", function()
        local AUTHORS = {
            { name = "Becky Chambers", count = 4 },
            { name = "Susanna Clarke", count = 1 },
        }

        it("draws its letter and each author's name and count", function()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local built = ShelfRows.group("C", AUTHORS, false, row_width(ctx), ctx)
                    assert.same({ "C" }, texts(built.letter), id)
                    assert.equals(2, #built.rows, id)
                    assert.same({ "Becky Chambers" }, texts(built.rows[1].name), id)
                    assert.same({ "4 BOOKS ›" }, texts(built.rows[1].count), id)
                    assert.same({ "Susanna Clarke" }, texts(built.rows[2].name), id)
                    assert.same({ "1 BOOK ›" }, texts(built.rows[2].count), id)
                    assert.equals(AUTHORS[1], built.rows[1].entry, id)
                    assert.is_falsy(built.repeats, id)
                    -- Each row's band, top to bottom, inside the group.
                    assert.is_true(built.rows[1].y < built.rows[2].y, id)
                    assert.is_true(built.rows[2].y + built.rows[2].h <= built:getSize().h, id)
                    built:free()
                end
            end)
        end)

        -- D14: a group split by a page break starts the next page with its letter again.
        it("draws a repeated group with its letter", function()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local leckie = { { name = "Ann Leckie", count = 3 } }
                    local built = ShelfRows.group("L", leckie, true, row_width(ctx), ctx)
                    assert.same({ "L" }, texts(built.letter), id)
                    assert.is_true(built.repeats, id)
                    built:free()
                end
            end)
        end)
    end)

    describe("heights", function()
        it("builds every widget at ShelfRows.height for its kind, on both profiles in both looks", function()
            covers()
            each_profile(function(where)
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local width = row_width(ctx)
                    local label = id .. " at " .. where
                    local series_h = ShelfRows.height("series", width, ctx)
                    for _, e in ipairs({ entry(), entry{ books = { FIFTH } }, entry{ state = "finished" },
                            entry{ state = "not_started", author = false } }) do
                        local built = ShelfRows.series(e, width, ctx)
                        assert.same({ width, series_h }, { built:getSize().w, built:getSize().h }, label .. " series")
                        built:free()
                    end
                    local book_h = ShelfRows.height("book", width, ctx)
                    for _, args in ipairs({ { FIFTH, { status = "complete", percent = 1 }, false },
                            { OBELISK, { status = "reading", percent = 0.5 }, false },
                            { OBELISK, { status = "new" }, true },
                            { remote("The Stone Sky"), { status = "new" }, false },
                            { book("No index"), { status = "new" }, false },
                            { remote("The Stone Sky"), { status = "new" }, true } }) do
                        local built = ShelfRows.book(args[1], args[2], args[3], width, ctx)
                        assert.same({ width, book_h }, { built:getSize().w, built:getSize().h }, label .. " book")
                        built:free()
                    end
                    local author_h = ShelfRows.height("author", width, ctx)
                    local cost = ShelfRows.group_cost(width, ctx)
                    local gap = scale(ctx.look.shelf.groups.gap)
                    for n = 1, 3 do
                        local authors = {}
                        for i = 1, n do
                            authors[i] = { name = "Author " .. i, count = i }
                        end
                        local built = ShelfRows.group("A", authors, false, width, ctx)
                        assert.same({ width, n * author_h + cost - gap }, { built:getSize().w, built:getSize().h },
                            label .. " a group of " .. n)
                        -- Every row's band is its height, the last less the rule it has none of.
                        for i = 1, n - 1 do
                            assert.equals(author_h, built.rows[i].h, label .. " row " .. i)
                        end
                        assert.is_true(built.rows[n].h <= author_h and built.rows[n].h > author_h / 2,
                            label .. " the last row")
                        built:free()
                    end
                end
            end)
        end)

        -- D22: the rows' text does not follow text_size.
        it("keeps every height whatever the text size", function()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local plain = ctx_for(id)
                    local width = row_width(plain)
                    for _, size in ipairs({ "small", "large", "xlarge" }) do
                        local sized = ctx_for(id, "day", size)
                        for _, kind in ipairs({ "series", "book", "author" }) do
                            assert.equals(ShelfRows.height(kind, width, plain), ShelfRows.height(kind, width, sized),
                                id .. " " .. kind .. " " .. size)
                        end
                        assert.equals(ShelfRows.group_cost(width, plain), ShelfRows.group_cost(width, sized), id)
                    end
                end
            end)
        end)
    end)

    describe("paint", function()
        it("paints every kind in day, night and grey on both profiles, a chip's fill per look", function()
            covers()
            each_profile(function(where)
                for _, variant in ipairs({ "day", "night", "grey" }) do
                    for _, id in ipairs(IDS) do
                        local ctx = ctx_for(id, variant)
                        local width = row_width(ctx)
                        local label = ("%s %s at %s"):format(id, variant, where)
                        local widgets = {
                            series = ShelfRows.series(entry(), width, ctx),
                            book = ShelfRows.book(OBELISK, { status = "new" }, true, width, ctx),
                            remote = ShelfRows.book(remote("The Stone Sky"), { status = "new" }, false, width, ctx),
                            reading = ShelfRows.book(FIFTH, { status = "reading", percent = 0.4 }, false, width, ctx),
                            group = ShelfRows.group("C", { { name = "Becky Chambers", count = 4 },
                                { name = "Susanna Clarke", count = 3 } }, false, width, ctx),
                        }
                        for name, built in pairs(widgets) do
                            local ok, bb, at = pcall(paint, built)
                            assert.is_true(ok, label .. ", " .. name .. ": " .. tostring(bb))
                            if name == "series" then
                                -- The under-way chip's fill inside its outline: Diner mustard, Editorial none.
                                local chip = built:place(built.chip)
                                local edge = scale(ctx.look.shelf.chip.outline_width)
                                local p = at(chip.x + edge + 1, chip.y + math.floor(built.chip:getSize().h / 2))
                                if id == "diner" then
                                    assert.same(role(ctx, "mustard"), p, label .. " the chip's fill")
                                else
                                    assert.same(GREEN, p, label .. " a chip with no fill")
                                end
                            end
                            bb:free()
                            built:free()
                        end
                    end
                end
            end)
        end)
        -- Diner's chip text: ink on the paper chips, on_accent on the filled ones (SeriesC.dc.html:39, :76,
        -- :88; SeriesBooksC.dc.html:49); by night the two roles part.
        it("sets Diner's chip text by kind at night, ink on paper and on_accent on a fill", function()
            covers()
            harness.at_colorsoft(function()
                local ctx = ctx_for("diner", "night")
                local width = row_width(ctx)
                local ink, on_accent = role(ctx, "ink"), role(ctx, "on_accent")
                assert.are_not.same(ink, on_accent)
                local cases = {
                    { ShelfRows.series(entry{ state = "not_started", complete = 0 }, width, ctx), "NOT STARTED", ink },
                    { ShelfRows.book(OBELISK, { status = "new" }, true, width, ctx), "UP NEXT", ink },
                    { ShelfRows.series(entry(), width, ctx), "1 OF 3", on_accent },
                    { ShelfRows.series(entry{ state = "finished", complete = 3 }, width, ctx), "FINISHED", on_accent },
                }
                for _, case in ipairs(cases) do
                    local built, text, want = case[1], case[2], case[3]
                    assert.same({ text }, texts(built.chip), text)
                    assert.same(want, line_color(built.chip[1]), text)
                    built:free()
                end
            end)
        end)
    end)

    describe("the fit", function()
        -- The one-author grid: its header, the grid's top padding, two rows of tiles at the one-author
        -- cover height and the row gap, the pager and the nav bar, on the screen.
        it("fits the one-author header, two rows of tiles, the pager and the nav bar on both profiles", function()
            each_profile(function(where)
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local grid = ctx.look.library.grid
                    local box = LibraryTiles.geometry(Screen:getWidth(), ctx, ctx.look.shelf.author_grid.cover_h)
                    local used = detail_header_height(ctx) + scale(grid.padding_top) + 2 * box.height
                        + scale(grid.row_gap) + LibraryTiles.pager_height(ctx) + NavBar.height(ctx.look, Screen)
                    assert.is_true(used <= Screen:getHeight(),
                        ("%s at %s: %d px for a %d px screen"):format(id, where, used, Screen:getHeight()))
                end
            end)
        end)

        -- The fit measures the one-series and one-author header by the boards' sum above; the chrome
        -- draws it at that height.
        it("measures the header the chrome draws for one series or one author", function()
            local LibraryChrome = package.loaded["library_chrome"]
            each_profile(function(where)
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    assert.equals(detail_header_height(ctx), LibraryChrome.detail_header_height(ctx),
                        id .. " at " .. where)
                end
            end)
        end)

        -- The boards' counts per page at the Colorsoft: five series rows (SeriesC), three book rows
        -- (SeriesBooksC), seven author rows in five groups (AuthorsC), each group's cost counted whole,
        -- each list's page ending shelf.list.pager_gap above the pager, the last row's shadow inside it (the
        -- marked book's the deeper where a book row's is).
        it("holds the boards' rows per page at the Colorsoft, the pager gap and the last shadow kept", function()
            harness.at_colorsoft(function()
                for _, id in ipairs(IDS) do
                    local ctx = ctx_for(id)
                    local shelf = ctx.look.shelf
                    local width = row_width(ctx)
                    local list_header = LibraryTiles.header_height(ctx)
                    local function room(header_h, padding_top, shadow_y)
                        return room_under(header_h, padding_top, ctx) - scale(shelf.list.pager_gap) - scale(shadow_y)
                    end

                    local series = 5 * ShelfRows.height("series", width, ctx) + 4 * scale(shelf.list.row_gap)
                    local left = room(list_header, shelf.list.padding_top, shelf.row.shadow.y)
                    assert.is_true(series <= left, ("%s: five series rows %d px in %d"):format(id, series, left))

                    local books = 3 * ShelfRows.height("book", width, ctx) + 2 * scale(shelf.books.row_gap)
                    left = room(detail_header_height(ctx), shelf.books.padding_top,
                        math.max(shelf.row.shadow.y, shelf.next.shadow.y))
                    assert.is_true(books <= left, ("%s: three book rows %d px in %d"):format(id, books, left))

                    local authors = 7 * ShelfRows.height("author", width, ctx) + 5 * ShelfRows.group_cost(width, ctx)
                    left = room(list_header, shelf.groups.padding_top, shelf.group.shadow.y)
                    assert.is_true(authors <= left, ("%s: seven author rows %d px in %d"):format(id, authors, left))
                end
            end)
        end)
    end)
end)
