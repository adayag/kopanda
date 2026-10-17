-- KoTitleBar (the title bar's C3): its height per look whatever the text size, what it reads from
-- a real file chooser (the title, the count, the sort and status labels), its rebuilds at paint,
-- its paint in each look and variant, its taps and holds, and the interface KOReader's file
-- manager and chooser call. Nothing here puts the bar into the file manager; each case builds one
-- against a file manager shown on a scratch copy of the fixture library.
describe("the title bar", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local BookList = require("ui/widget/booklist")
    local DataStorage = require("datastorage")
    local DocSettings = require("docsettings")
    local Event = require("ui/event")
    local FileChooser = require("ui/widget/filechooser")
    local Screen = require("device").screen
    local TitleBar = require("ui/widget/titlebar")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local KoTitleBar, Icons, Looks, Settings, Typeset

    local scratch = DataStorage:getDataDir() .. "/title_bar_spec"
    local lib = scratch .. "/library"
    local link = scratch .. "/library_link"
    local long_name = string.rep("A very long folder name ", 8)
    local books = { "a-christmas-carol.epub", "frankenstein.epub", "the-time-machine.epub" }

    local function copy(from, to)
        local src = assert(io.open(from, "rb"))
        local data = src:read("*a")
        src:close()
        local dst = assert(io.open(to, "wb"))
        dst:write(data)
        dst:close()
    end

    -- The scratch library: the fixture's three books, a subfolder of one book, an empty folder
    -- and a folder with a long name; and a symlink to the library beside it.
    setup(function()
        os.execute("rm -rf '" .. scratch .. "'")
        assert(lfs.mkdir(scratch))
        assert(lfs.mkdir(lib))
        for _, book in ipairs(books) do
            copy(harness.library .. "/" .. book, lib .. "/" .. book)
        end
        assert(lfs.mkdir(lib .. "/Shelf"))
        copy(harness.library .. "/frankenstein.epub", lib .. "/Shelf/one.epub")
        assert(lfs.mkdir(lib .. "/Empty"))
        assert(lfs.mkdir(lib .. "/" .. long_name))
        assert(os.execute("ln -s '" .. lib .. "' '" .. link .. "'") == 0)
    end)

    teardown(function()
        os.execute("rm -rf '" .. scratch .. "'")
    end)

    -- What spy replaced, put back after each case, latest first.
    local restores = {}

    before_each(function()
        harness.load()
        KoTitleBar = package.loaded["title_bar"]
        Icons = package.loaded["icons"]
        Looks = package.loaded["looks"]
        Settings = package.loaded["settings"]
        Typeset = package.loaded["typeset"]
        G_reader_settings:saveSetting("home_dir", lib)
    end)

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        FileChooser.show_filter.status = nil
        G_reader_settings:delSetting("home_dir")
        G_reader_settings:delSetting("collate")
        harness.teardown()
    end)

    local function scale(px)
        return Screen:scaleBySize(px)
    end

    -- Replaces t[name] with a recorder of each call's arguments, raising raises when given; the
    -- original comes back after the case.
    local function spy(t, name, raises)
        local calls, original = {}, rawget(t, name)
        restores[#restores + 1] = function()
            t[name] = original
        end
        t[name] = function(...)
            calls[#calls + 1] = { ... }
            if raises then
                error(raises)
            end
        end
        return calls
    end

    -- A bar in look id for fm, with KOReader's attributes and spies for every callback; calls
    -- counts each callback's runs, and a callback named in raising raises.
    local function bar_for(id, fm, raising)
        raising = raising or {}
        local calls = { sort = 0, status = 0, plus = 0, hold = 0 }
        local function callback(name)
            return function()
                calls[name] = calls[name] + 1
                if raising[name] then
                    error("boom from " .. name)
                end
            end
        end
        local bar = KoTitleBar:new{
            fm = fm,
            look = Looks.get(id),
            show_parent = fm and fm.show_parent,
            title = "KOReader",
            subtitle = "Home",
            left_icon = "home",
            left_icon_tap_callback = function() error("the left icon's tap is ignored") end,
            right_icon = "plus",
            right_icon_tap_callback = callback("plus"),
            right_icon_hold_callback = false,
            left_icon_hold_callback = callback("hold"),
            on_sort = callback("sort"),
            on_status = callback("status"),
        }
        return bar, calls
    end

    -- The text a Typeset line shows: a TextWidget's, or its glyphs' in order.
    local function text_of(line)
        if line.text then
            return line.text
        end
        local out = {}
        for _, widget in ipairs(line) do
            if widget.text then
                out[#out + 1] = widget.text
            end
        end
        return table.concat(out)
    end

    -- A white RGB32 buffer of the bar's size with the bar painted at its (0, 0).
    local function paint(bar)
        local size = bar:getSize()
        local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
        bb:fill(Blitbuffer.COLOR_WHITE)
        bar:paintTo(bb, 0, 0)
        return bb
    end

    local function logged_with(calls, needle)
        local n = 0
        for _, call in ipairs(calls) do
            local parts = {}
            for i = 1, select("#", unpack(call)) do
                parts[#parts + 1] = tostring(call[i])
            end
            if table.concat(parts, " "):find(needle, 1, true) then
                n = n + 1
            end
        end
        return n
    end

    it("is a subclass of KOReader's TitleBar", function()
        assert.equals(TitleBar, getmetatable(KoTitleBar))
    end)

    describe("height", function()
        -- The feature's formula: edge, top padding, the taller of the count-over-title column and
        -- the picker row, bottom padding, each length scaled and each line set with no text size.
        local function formula(look)
            local tokens, parts = look.title_bar, look.type
            local ctx = { look = look, variant = "day" }
            local function line_h(part, sample)
                local line = Typeset.line(part, sample, Screen:getWidth(), ctx)
                local h = line:getSize().h
                line:free()
                return h
            end
            local column = line_h(parts.title_bar_count, "0 books") + scale(tokens.line_gap)
                + line_h(parts.title_bar_title, "Library")
            local row = math.max(line_h(parts.title_bar_sort, "Name"), line_h(parts.title_bar_status, "Name"))
                + 2 * (scale(tokens.picker_padding.y) + scale(tokens.picker_outline_width))
            return scale(tokens.edge_width) + scale(tokens.padding.top) + math.max(column, row)
                + scale(tokens.padding.bottom)
        end

        local function check(where)
            local fm = harness.show_fm(lib)
            for _, id in ipairs(Looks.ids()) do
                local look = Looks.get(id)
                local wanted = formula(look)
                assert.equals(wanted, KoTitleBar.height(look, Screen), id .. " " .. where)
                local bar = bar_for(id, fm)
                assert.same({ wanted, wanted, wanted, Screen:getWidth() },
                    { bar:getHeight(), bar.dimen.h, bar:getSize().h, bar:getSize().w }, id .. " " .. where)
                bar:free()
            end
        end

        it("is the formula from each look's tokens at the unit screen and at the Colorsoft", function()
            check("unit")
            harness.at_colorsoft(function()
                check("Colorsoft")
                assert.is_true(KoTitleBar.height(Looks.get("diner"), Screen) > scale(100))
            end)
        end)

        it("doesn't follow the stored text size", function()
            for _, size in ipairs({ "small", "medium", "large" }) do
                assert.is_true(Settings.set("text_size", size))
                check(size)
                harness.at_colorsoft(function()
                    check(size .. " at the Colorsoft")
                end)
            end
        end)
    end)

    describe("title", function()
        it("is Library at the home folder, stored plain, with a slash and through a symlink", function()
            local fm = harness.show_fm(lib)
            for _, home in ipairs({ lib, lib .. "/", link }) do
                G_reader_settings:saveSetting("home_dir", home)
                local bar = bar_for("editorial", fm)
                assert.equals("Library", bar:state().title, home)
                bar:free()
            end
        end)

        it("is the folder's own name elsewhere and / at the root", function()
            local fm = harness.show_fm(lib)
            local bar = bar_for("diner", fm)
            fm.file_chooser:changeToPath(lib .. "/Shelf")
            assert.equals("Shelf", bar:state().title)
            -- The root's listing isn't needed for its title, and listing the host's / can stall.
            fm.file_chooser.path = "/"
            assert.equals("/", bar:state().title)
            bar:free()
        end)

        it("is cut to the width the pickers leave, which keep theirs", function()
            harness.at_colorsoft(function()
                local fm = harness.show_fm(lib)
                fm.file_chooser:changeToPath(lib .. "/" .. long_name)
                for _, id in ipairs(Looks.ids()) do
                    local bar = bar_for(id, fm)
                    local bb = paint(bar)
                    local boxes, gap = bar.boxes, scale(Looks.get(id).title_bar.picker_gap)
                    assert.is_true(boxes.title.x + boxes.title.w <= boxes.sort.x - gap, id)
                    local sort = Typeset.line(Looks.get(id).type.title_bar_sort, "Name \u{25BE}", Screen:getWidth(),
                        { look = Looks.get(id), variant = "day" })
                    assert.is_true(boxes.sort.w >= sort:getSize().w, id)
                    sort:free()
                    bar:free()
                    bb:free()
                end
            end)
        end)

        it("is empty with no file chooser, and so is the count", function()
            local bar = bar_for("diner", {})
            local state = bar:state()
            assert.equals("", state.title)
            assert.is_nil(state.count)
            bar:free()
        end)
    end)

    describe("count", function()
        local function built_count(id, fm)
            local bar = bar_for(id, fm)
            local bb = paint(bar)
            local count, text = bar:state().count, text_of(bar.built.lines.count)
            bar:free()
            bb:free()
            return count, text
        end

        it("is the folder's books, its folders and the go-up entry left out, worded by look", function()
            local fm = harness.show_fm(lib)
            fm.file_chooser:changeToPath(lib)
            local go_up = false
            for _, item in ipairs(fm.file_chooser.item_table) do
                go_up = go_up or item.is_go_up == true
            end
            assert.is_true(go_up, "the listing has no go-up entry")
            assert.same({ 3, "3 BOOKS" }, { built_count("editorial", fm) })
            assert.same({ 3, "3 books on the shelf" }, { built_count("diner", fm) })
            fm.file_chooser:changeToPath(lib .. "/Shelf")
            assert.same({ 1, "1 BOOK" }, { built_count("editorial", fm) })
            assert.same({ 1, "1 book on the shelf" }, { built_count("diner", fm) })
            fm.file_chooser:changeToPath(lib .. "/Empty")
            assert.same({ 0, "NO BOOKS" }, { built_count("editorial", fm) })
            assert.same({ 0, "No books on the shelf" }, { built_count("diner", fm) })
        end)

        it("counts what the status filter leaves", function()
            -- The chooser lists real paths, and the earlier cases left each book's info cached
            -- under its real path as never opened.
            local real_lib = require("ffi/util").realpath(lib)
            local function reset()
                for _, name in ipairs(books) do
                    BookList.resetBookInfoCache(real_lib .. "/" .. name)
                end
            end
            local book = real_lib .. "/frankenstein.epub"
            local doc = DocSettings:open(book)
            doc:saveSetting("summary", { status = "complete" })
            doc:flush()
            restores[#restores + 1] = function()
                os.execute("rm -rf '" .. real_lib .. "/frankenstein.sdr'")
                reset()
            end
            reset()
            local fm = harness.show_fm(lib)
            FileChooser.show_filter.status = { complete = true }
            fm.file_chooser:refreshPath()
            local bar = bar_for("editorial", fm)
            assert.equals(1, bar:state().count)
            bar:free()
        end)
    end)

    describe("labels", function()
        local short = {
            strcoll = "Name", natural = "Name", access = "Recent", date = "Modified", size = "Size",
            type = "Type", percent_unopened_first = "Progress", percent_unopened_last = "Progress",
            percent_natural = "Progress", title = "Title", authors = "Author", series = "Series",
            keywords = "Keywords", rating = "Rating",
        }

        it("give each of KOReader's sorts its short label and any other its own text", function()
            local fm = harness.show_fm(lib)
            local bar = bar_for("editorial", fm)
            local seen = 0
            for id in pairs(BookList.collates) do
                seen = seen + 1
                G_reader_settings:saveSetting("collate", id)
                assert.equals(short[id], bar:state().sort, id)
            end
            assert.equals(14, seen)
            BookList.collates.kopanda_stub = { text = "stub order" }
            restores[#restores + 1] = function()
                BookList.collates.kopanda_stub = nil
            end
            G_reader_settings:saveSetting("collate", "kopanda_stub")
            assert.equals("stub order", bar:state().sort)
            bar:free()
        end)

        it("give the status filter as All, one status, or the first in KOReader's order and +n", function()
            local fm = harness.show_fm(lib)
            local bar = bar_for("diner", fm)
            for _, case in ipairs({
                { nil, "All" },
                { { reading = true }, "Reading" },
                { { abandoned = true }, "On hold" },
                { { reading = true, abandoned = true }, "Reading +1" },
                { { complete = true, new = true, abandoned = true }, "New +2" },
            }) do
                FileChooser.show_filter.status = case[1]
                assert.equals(case[2], bar:state().status, case[2])
            end
            bar:free()
        end)

        it("set the pickers in uppercase with the down mark", function()
            local fm = harness.show_fm(lib)
            G_reader_settings:saveSetting("collate", "access")
            FileChooser.show_filter.status = { reading = true }
            for _, id in ipairs(Looks.ids()) do
                local bar = bar_for(id, fm)
                local bb = paint(bar)
                assert.equals("RECENT \u{25BE}", text_of(bar.built.lines.sort), id)
                assert.equals("READING \u{25BE}", text_of(bar.built.lines.status), id)
                bar:free()
                bb:free()
            end
        end)
    end)

    describe("at paint", function()
        it("rebuilds only when what it reads has changed", function()
            local fm = harness.show_fm(lib)
            local bar = bar_for("diner", fm)
            local builds = 0
            local build = bar.build
            bar.build = function(...)
                builds = builds + 1
                return build(...)
            end
            local bb = paint(bar)
            assert.equals(1, builds)
            bar:paintTo(bb, 0, 0)
            assert.equals(1, builds)
            G_reader_settings:saveSetting("collate", "access")
            bar:paintTo(bb, 0, 0)
            assert.equals(2, builds)
            assert.equals("Recent", bar.built.state.sort)
            bar:paintTo(bb, 0, 0)
            assert.equals(2, builds)
            fm.file_chooser:changeToPath(lib .. "/Shelf")
            bar:paintTo(bb, 0, 0)
            assert.equals(3, builds)
            bar:free()
            bb:free()
        end)

        it("paints only its fill and edge, logged once, when its first read raises", function()
            harness.at_colorsoft(function()
                local logged = spy(logger, "err")
                local fm = harness.show_fm(lib)
                local current = Looks.variant
                spy(Looks, "variant")
                -- The variant as set, night, and a variant read that raises, which paints by day.
                local modes = {
                    { "as set", current, current() },
                    { "night", function() return "night" end, "night" },
                    { "raising", function() error("boom in variant") end, "day" },
                }
                local n = 0
                for _, mode in ipairs(modes) do
                    Looks.variant = mode[2]
                    for _, look_id in ipairs(Looks.ids()) do
                        n = n + 1
                        local id = look_id .. " " .. mode[1]
                        local bar = bar_for(look_id, fm)
                        bar.state = function()
                            error("boom in state")
                        end
                        local bb = paint(bar)
                        bar:paintTo(bb, 0, 0)
                        assert.equals(n, logged_with(logged, "boom in state"), id)
                        local look = Looks.get(look_id)
                        local palette = Looks.palette(look, mode[3])
                        local fill = Looks.color(palette[look.title_bar.fill_color]):getColorRGB32()
                        local edge_color = Looks.color(palette[look.title_bar.edge_color]):getColorRGB32()
                        local size = bar:getSize()
                        local edge = scale(look.title_bar.edge_width)
                        local strays = 0
                        for y = 0, size.h - edge - 1, 3 do
                            for x = 0, size.w - 1, 3 do
                                local c = bb:getPixel(x, y):getColorRGB32()
                                if c:getR() ~= fill:getR() or c:getG() ~= fill:getG() or c:getB() ~= fill:getB() then
                                    strays = strays + 1
                                end
                            end
                        end
                        assert.equals(0, strays, id .. ": pixels above the edge that aren't the fill")
                        local c = bb:getPixel(math.floor(size.w / 2), size.h - 1):getColorRGB32()
                        assert.same({ edge_color:getR(), edge_color:getG(), edge_color:getB() },
                            { c:getR(), c:getG(), c:getB() }, id .. " edge")
                        bar:free()
                        bb:free()
                    end
                end
            end)
        end)

        it("rebuilds when the variant changes", function()
            local fm = harness.show_fm(lib)
            local variant = "day"
            spy(Looks, "variant")
            Looks.variant = function()
                return variant
            end
            local bar = bar_for("diner", fm)
            local builds = 0
            local build = bar.build
            bar.build = function(...)
                builds = builds + 1
                return build(...)
            end
            local bb = paint(bar)
            assert.equals(1, builds)
            variant = "night"
            bar:paintTo(bb, 0, 0)
            assert.equals(2, builds)
            assert.equals("night", bar.built.state.variant)
            local look = Looks.get("diner")
            local fill = Looks.color(Looks.palette(look, "night")[look.title_bar.fill_color]):getColorRGB32()
            local c = bb:getPixel(0, bar:getSize().h - scale(look.title_bar.edge_width) - 1):getColorRGB32()
            assert.same({ fill:getR(), fill:getG(), fill:getB() }, { c:getR(), c:getG(), c:getB() })
            bar:free()
            bb:free()
        end)

        it("logs a raising paint once and raises nothing", function()
            local logged = spy(logger, "err")
            local fm = harness.show_fm(lib)
            local bar = bar_for("editorial", fm)
            bar.build = function()
                error("boom in build")
            end
            local bb = paint(bar)
            bar:paintTo(bb, 0, 0)
            assert.equals(1, logged_with(logged, "boom in build"))
            bar:free()
            bb:free()
        end)
    end)

    describe("paint", function()
        local function rgb(hex)
            local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
            return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
        end

        -- The bar in look id painted in variant at the Colorsoft, and a check that (x, y) holds role.
        local function painted(id, variant, fn)
            harness.at_colorsoft(function()
                local fm = harness.show_fm(lib)
                spy(Looks, "variant")
                Looks.variant = function()
                    return variant
                end
                local bar = bar_for(id, fm)
                local bb = paint(bar)
                local palette = Looks.palette(Looks.get(id), variant)
                local function holds(role, x, y, what)
                    local c = bb:getPixel(x, y):getColorRGB32()
                    local got, want = { c:getR(), c:getG(), c:getB() }, rgb(palette[role])
                    local near = math.abs(got[1] - want[1]) <= 2 and math.abs(got[2] - want[2]) <= 2
                        and math.abs(got[3] - want[3]) <= 2
                    assert.is_true(near, ("%s %s %s: %s at %d,%d is %d,%d,%d"):format(
                        id, variant, what, role, x, y, got[1], got[2], got[3]))
                end
                -- How many pixels of the box at (x, y), w by h, hold role's colour as KOReader blits
                -- text in it: its grey (base/ffi/blitbuffer.lua:1405-1407).
                local function count(role, x, y, w, h)
                    local grey = Looks.color(palette[role]):getColor8().a
                    local want, n = { grey, grey, grey }, 0
                    for py = y, y + h - 1 do
                        for px = x, x + w - 1 do
                            local c = bb:getPixel(px, py):getColorRGB32()
                            if math.abs(c:getR() - want[1]) <= 2 and math.abs(c:getG() - want[2]) <= 2
                                and math.abs(c:getB() - want[3]) <= 2 then
                                n = n + 1
                            end
                        end
                    end
                    return n
                end
                fn(bar, holds, count)
                bar:free()
                bb:free()
            end)
        end

        it("draws Editorial's 1 px ink edge under paper and no chip boxes", function()
            for _, variant in ipairs({ "day", "night", "grey" }) do
                painted("editorial", variant, function(bar, holds)
                    local size, edge = bar:getSize(), scale(1)
                    for _, x in ipairs({ 0, math.floor(size.w / 2), size.w - 1 }) do
                        holds("ink", x, size.h - 1, "edge bottom")
                        holds("ink", x, size.h - edge, "edge top")
                        holds("paper", x, size.h - edge - 1, "above the edge")
                        holds("paper", x, 1, "the top")
                    end
                    for _, name in ipairs({ "sort", "status" }) do
                        local box = bar.boxes[name]
                        for d = 1, 3 do
                            for x = box.x - d, box.x + box.w - 1 + d do
                                holds("paper", x, box.y - d, name .. " above")
                                holds("paper", x, box.y + box.h - 1 + d, name .. " below")
                            end
                            for y = box.y, box.y + box.h - 1 do
                                holds("paper", box.x - d, y, name .. " left")
                                holds("paper", box.x + box.w - 1 + d, y, name .. " right")
                            end
                        end
                    end
                end)
            end
        end)

        it("draws Diner's mustard band over a 4 px ink edge and the chips on paper and pink, outlined", function()
            for _, variant in ipairs({ "day", "night", "grey" }) do
                painted("diner", variant, function(bar, holds, count)
                    local size, edge, outline, pad_x, pad_y = bar:getSize(), scale(4), scale(2), scale(10), scale(4)
                    for _, x in ipairs({ 0, math.floor(size.w / 2), size.w - 1 }) do
                        holds("ink", x, size.h - 1, "edge bottom")
                        holds("ink", x, size.h - edge, "edge top")
                        holds("mustard", x, size.h - edge - 1, "above the edge")
                        holds("mustard", x, 1, "the top")
                    end
                    for name, fill in pairs({ sort = "paper", status = "pink" }) do
                        local box = bar.boxes[name]
                        local right, bottom = box.x + box.w - 1, box.y + box.h - 1
                        holds("mustard", box.x - 1, box.y, name .. " left of its outline")
                        for _, point in ipairs({ { box.x, box.y }, { box.x + outline - 1, box.y + outline - 1 },
                                { right, bottom }, { right - outline + 1, bottom - outline + 1 },
                                { box.x, bottom }, { right, box.y } }) do
                            holds("outline", point[1], point[2], name .. " outline")
                        end
                        holds(fill, box.x + outline, box.y + outline, name .. " fill, top left")
                        holds(fill, right - outline, bottom - outline, name .. " fill, bottom right")
                        -- The label, over the fill inside the outline and the padding, in its part's colour.
                        local role = Looks.get("diner").type["title_bar_" .. name].color
                        local inked = count(role, box.x + outline + pad_x, box.y + outline + pad_y,
                            box.w - 2 * (outline + pad_x), box.h - 2 * (outline + pad_y))
                        assert.is_true(inked >= 20, ("diner %s %s label: %d pixels of %s"):format(
                            variant, name, inked, role))
                    end
                end)
            end
        end)
    end)

    describe("geometry", function()
        it("sets the column and the right group on the content's bottom, the group at the side padding", function()
            harness.at_colorsoft(function()
                local fm = harness.show_fm(lib)
                for _, id in ipairs(Looks.ids()) do
                    local t = Looks.get(id).title_bar
                    local bar = bar_for(id, fm)
                    local bb = paint(bar)
                    local b, size = bar.boxes, bar:getSize()
                    local side, gap = scale(t.padding.side), scale(t.picker_gap)
                    local bottom = size.h - scale(t.edge_width) - scale(t.padding.bottom)
                    assert.equals(bottom, b.title.y + b.title.h, id .. " title bottom")
                    assert.equals(b.title.y, b.count.y + b.count.h + scale(t.line_gap), id .. " count over title")
                    assert.is_true(b.count.y >= scale(t.padding.top), id .. " count under the top padding")
                    assert.same({ side, side }, { b.count.x, b.title.x }, id .. " column at the side padding")
                    assert.same({ bottom, bottom }, { b.sort.y + b.sort.h, b.status.y + b.status.h },
                        id .. " pickers' bottom")
                    assert.equals(b.sort.x + b.sort.w + gap, b.status.x, id .. " sort to status")
                    assert.equals(b.status.x + b.status.w + gap, b.icon.x, id .. " status to icon")
                    assert.same({ scale(t.icon_size), scale(t.icon_size) }, { b.icon.w, b.icon.h }, id .. " icon size")
                    assert.is_true(math.abs((2 * b.icon.y + b.icon.h) - (2 * b.sort.y + b.sort.h)) <= 1,
                        id .. " icon centred on the picker row")
                    assert.equals(size.w - side, b.icon.x + b.icon.w, id .. " icon at the side padding")
                    bar:free()
                    bb:free()
                end
            end)
        end)
    end)

    describe("a tap", function()
        local function centre(bar, area)
            local a = bar.areas[area]
            return bar.dimen.x + a.x + math.floor(a.w / 2), bar.dimen.y + math.floor(bar.dimen.h / 2)
        end

        local function box_centre(bar, name)
            local box = bar.boxes[name]
            return bar.dimen.x + box.x + math.floor(box.w / 2), bar.dimen.y + box.y + math.floor(box.h / 2)
        end

        it("on the sort, status or plus runs its callback once and is consumed", function()
            local fm = harness.show_fm(lib)
            for _, id in ipairs(Looks.ids()) do
                local bar, calls = bar_for(id, fm)
                local bb = paint(bar)
                for area, name in pairs({ sort = "sort", status = "status", plus = "plus" }) do
                    local before = calls[name]
                    assert.is_true(bar:handle(harness.gesture("tap", centre(bar, area))), id .. " " .. area)
                    assert.equals(before + 1, calls[name], id .. " " .. area)
                end
                assert.same({ sort = 1, status = 1, plus = 1, hold = 0 }, calls, id)
                bar:free()
                bb:free()
            end
        end)

        it("on the title or the count is not consumed and runs nothing", function()
            local fm = harness.show_fm(lib)
            for _, id in ipairs(Looks.ids()) do
                local bar, calls = bar_for(id, fm)
                local bb = paint(bar)
                assert.is_false(bar:handle(harness.gesture("tap", box_centre(bar, "title"))), id)
                assert.is_false(bar:handle(harness.gesture("tap", box_centre(bar, "count"))), id)
                assert.same({ sort = 0, status = 0, plus = 0, hold = 0 }, calls, id)
                bar:free()
                bb:free()
            end
        end)

        it("meets the next area half a picker gap left of each picker and the plus", function()
            harness.at_colorsoft(function()
                local fm = harness.show_fm(lib)
                for _, id in ipairs(Looks.ids()) do
                    local bar, calls = bar_for(id, fm)
                    local bb = paint(bar)
                    local b = bar.boxes
                    local half = math.floor(scale(Looks.get(id).title_bar.picker_gap) / 2)
                    local y = bar.dimen.y + math.floor(bar.dimen.h / 2)
                    assert.is_true(half > 0, id)
                    local function tap(x)
                        return bar:handle(harness.gesture("tap", bar.dimen.x + x, y))
                    end
                    assert.is_false(tap(b.sort.x - half - 1), id .. " left of the sort's area")
                    assert.same({ sort = 0, status = 0, plus = 0, hold = 0 }, calls, id)
                    for _, case in ipairs({
                        { b.sort.x - half, "sort" },
                        { b.status.x - half - 1, "sort" },
                        { b.status.x - half, "status" },
                        { b.icon.x - half - 1, "status" },
                        { b.icon.x - half, "plus" },
                    }) do
                        local before = calls[case[2]]
                        assert.is_true(tap(case[1]), id .. " " .. case[2] .. " at " .. case[1])
                        assert.equals(before + 1, calls[case[2]], id .. " " .. case[2] .. " at " .. case[1])
                    end
                    assert.same({ sort = 2, status = 2, plus = 1, hold = 0 }, calls, id)
                    bar:free()
                    bb:free()
                end
            end)
        end)

        it("reaches handle through the listener, at the bar's painted place", function()
            local fm = harness.show_fm(lib)
            local bar, calls = bar_for("diner", fm)
            local size = bar:getSize()
            local bb = Blitbuffer.new(size.w, size.h + 300, Blitbuffer.TYPE_BBRGB32)
            bar:paintTo(bb, 0, 0)
            local x, y = centre(bar, "sort")
            assert.is_true(bar:handleEvent(Event:new("Gesture", harness.gesture("tap", x, y))))
            assert.equals(1, calls.sort)
            bar:paintTo(bb, 0, 300)
            assert.equals(300, bar.dimen.y)
            assert.is_true(bar:handleEvent(Event:new("Gesture", harness.gesture("tap", x, y + 300))))
            assert.equals(2, calls.sort)
            assert.is_falsy((bar:handleEvent(Event:new("Gesture", harness.gesture("tap", x, y)))))
            assert.equals(2, calls.sort)
            bar:free()
            bb:free()
        end)

        it("whose callback raises is logged and not consumed", function()
            local logged = spy(logger, "err")
            local fm = harness.show_fm(lib)
            local bar, calls = bar_for("editorial", fm, { sort = true })
            local bb = paint(bar)
            assert.is_false(bar:handle(harness.gesture("tap", centre(bar, "sort"))))
            assert.equals(1, calls.sort)
            assert.equals(1, logged_with(logged, "boom from sort"))
            bar:free()
            bb:free()
        end)

        describe("hold", function()
            it("on the title or the count runs the hold callback once, consumed with its release", function()
                local fm = harness.show_fm(lib)
                for _, id in ipairs(Looks.ids()) do
                    local bar, calls = bar_for(id, fm)
                    local bb = paint(bar)
                    for i, name in ipairs({ "title", "count" }) do
                        local x, y = box_centre(bar, name)
                        assert.is_true(bar:handle(harness.gesture("hold", x, y)), id .. " " .. name)
                        assert.equals(i, calls.hold, id .. " " .. name)
                        assert.is_true(bar:handle(harness.gesture("hold_release", x, y)), id .. " " .. name)
                        assert.is_false(bar:handle(harness.gesture("hold_release", x, y)), id .. " " .. name)
                    end
                    bar:free()
                    bb:free()
                end
            end)

            it("on a picker or the plus is not taken, nor is its release", function()
                local fm = harness.show_fm(lib)
                local bar, calls = bar_for("diner", fm)
                local bb = paint(bar)
                for _, area in ipairs({ "sort", "status", "plus" }) do
                    local x, y = centre(bar, area)
                    assert.is_false(bar:handle(harness.gesture("hold", x, y)), area)
                    assert.is_false(bar:handle(harness.gesture("hold_release", x, y)), area)
                end
                assert.same({ sort = 0, status = 0, plus = 0, hold = 0 }, calls)
                bar:free()
                bb:free()
            end)

            it("forgets a taken hold whose release went elsewhere, so a later hold's release passes on", function()
                -- On the device the folder menu the hold opens is on top and takes its release
                -- (frontend/ui/uimanager.lua:988), so the bar never sees it.
                local fm = harness.show_fm(lib)
                local bar, calls = bar_for("diner", fm)
                local bb = paint(bar)
                assert.is_true(bar:handle(harness.gesture("hold", box_centre(bar, "title"))))
                local x, y = box_centre(bar, "sort")
                assert.is_false(bar:handle(harness.gesture("hold", x, y)))
                assert.is_false(bar:handle(harness.gesture("hold_release", x, y)))
                assert.same({ sort = 0, status = 0, plus = 0, hold = 1 }, calls)
                bar:free()
                bb:free()
            end)

            it("whose callback raises is logged and not consumed", function()
                local logged = spy(logger, "err")
                local fm = harness.show_fm(lib)
                local bar, calls = bar_for("editorial", fm, { hold = true })
                local bb = paint(bar)
                local x, y = box_centre(bar, "title")
                assert.is_false(bar:handle(harness.gesture("hold", x, y)))
                assert.equals(1, calls.hold)
                assert.equals(1, logged_with(logged, "boom from hold"))
                assert.is_false(bar:handle(harness.gesture("hold_release", x, y)))
                bar:free()
                bb:free()
            end)
        end)
    end)

    describe("interface", function()
        it("switches the right icon to check and back to plus", function()
            local fm = harness.show_fm(lib)
            local bar = bar_for("diner", fm)
            local bb = paint(bar)
            assert.equals(Icons.path("plus"), bar.built.icon.file)
            for _, case in ipairs({ { "check", "check" }, { "plus", "plus" }, { "home", "plus" } }) do
                bar:setRightIcon(case[1])
                bar:paintTo(bb, 0, 0)
                assert.equals(Icons.path(case[2]), bar.built.icon.file, case[1])
            end
            bar:free()
            bb:free()
        end)

        it("keeps no title or subtitle text and marks itself dirty unless told not to", function()
            local fm = harness.show_fm(lib)
            local bar = bar_for("editorial", fm)
            local bb = paint(bar)
            local dirty = spy(UIManager, "setDirty")
            bar:setTitle("Something else")
            bar:setSubTitle("~/Books")
            local mark = { UIManager, fm.show_parent, "ui", bar.dimen }
            assert.same({ mark, mark }, dirty)
            bar:setTitle("Again", true)
            bar:setSubTitle("Again", true)
            assert.equals(2, #dirty)
            bar:paintTo(bb, 0, 0)
            assert.equals("Library", text_of(bar.built.lines.title))
            bar:setLeftIcon("home")
            assert.equals(2, #dirty)
            bar:free()
            bb:free()
        end)

        it("generates empty layouts for key navigation", function()
            local bar = bar_for("diner", harness.show_fm(lib))
            assert.same({}, bar:generateHorizontalLayout())
            assert.same({}, bar:generateVerticalLayout())
            bar:free()
        end)

        it("keeps the left button's dimen, in place, at the title column's box on screen", function()
            local fm = harness.show_fm(lib)
            for _, id in ipairs(Looks.ids()) do
                local bar = bar_for(id, fm)
                assert.is_false(bar.has_left_icon)
                assert.is_true(bar.has_right_icon)
                local dimen = bar.left_button.image.dimen
                local size = bar:getSize()
                local bb = Blitbuffer.new(size.w + 40, size.h + 120, Blitbuffer.TYPE_BBRGB32)
                bar:paintTo(bb, 40, 120)
                local boxes = bar.boxes
                assert.equals(dimen, bar.left_button.image.dimen, id)
                assert.same({ 40 + boxes.title.x, 120, math.max(boxes.count.w, boxes.title.w),
                    boxes.title.y + boxes.title.h }, { dimen.x, dimen.y, dimen.w, dimen.h }, id)
                assert.equals(boxes.count.x, boxes.title.x, id)
                assert.is_true(boxes.title.y + boxes.title.h <= size.h, id)
                bar:free()
                bb:free()
            end
        end)
    end)
end)
