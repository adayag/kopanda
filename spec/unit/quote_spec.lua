-- The quote of the day (C6): quotes.lua as pure data held to its limits, the day's entry by
-- local calendar day, and the widget's text in curly quotes, at most four lines, with an
-- ellipsis past them, fitting the longest entry in a full-width row at large on both profiles.
describe("the quote of the day", function()
    local harness = require("plugin_harness")
    local ffi = require("ffi")
    require("ffi/posix_h")
    local Blitbuffer = require("ffi/blitbuffer")
    local Schema = require("schema")
    local Screen = require("device").screen
    local Settings = require("settings")
    local Layout = require("layout")
    local Looks = require("looks")
    local Quote = require("widgets/quote")
    local profiles = dofile(harness.root .. "/spec/emulator/profiles.lua")
    local quotes_path = harness.plugin_dir .. "/quotes.lua"
    local builtin = Quote.sources.builtin
    local real_get = Settings.get

    pcall(ffi.cdef, "void tzset(void);")

    -- The default layout, as a home with nothing stored lays it out.
    local function default_rows()
        for _, entry in ipairs(Schema.keys) do
            if entry.id == "layout.rows" then
                return entry.default
            end
        end
    end

    -- fn run with the local time zone set to tz, the previous zone restored after.
    local function in_zone(tz, fn)
        local previous = os.getenv("TZ")
        ffi.C.setenv("TZ", tz, 1)
        ffi.C.tzset()
        local ok, err = pcall(fn)
        if previous then
            ffi.C.setenv("TZ", previous, 1)
        else
            ffi.C.unsetenv("TZ")
        end
        ffi.C.tzset()
        assert(ok, err)
    end

    -- The epoch time of a local wall-clock instant.
    local function at(year, month, day, hour, min)
        return os.time{ year = year, month = month, day = day, hour = hour, min = min }
    end

    -- fn run with the device screen at w by h, so faces and lengths scale as on that screen,
    -- the screen's own size restored after.
    local function on_screen(w, h, fn)
        local get_w, get_h = rawget(Screen, "getWidth"), rawget(Screen, "getHeight")
        Screen.getWidth = function() return w end
        Screen.getHeight = function() return h end
        local ok, err = pcall(fn)
        Screen.getWidth, Screen.getHeight = get_w, get_h
        assert(ok, err)
    end

    local function ctx_for(look_id, text_size)
        return {
            look = Looks.get(look_id),
            variant = "day",
            text_size = text_size or "medium",
            now = at(2026, 10, 13, 20, 42),
            screen = Screen,
        }
    end

    -- The width of the quote's slot in the default layout on the current screen.
    local function full_row_width(ctx)
        for _, row in ipairs(Layout.arrange(default_rows(), ctx).rows) do
            for _, slot in ipairs(row.slots) do
                if slot.widget == "quote" then
                    return slot.w
                end
            end
        end
    end

    local function longest(list)
        local found = list[1]
        for _, entry in ipairs(list) do
            if #entry.text > #found.text then
                found = entry
            end
        end
        return found
    end

    before_each(function()
        os.remove(harness.settings_file)
        Settings._reset()
    end)

    after_each(function()
        Quote.sources.builtin = builtin
        Settings.get = real_get
    end)

    describe("quotes.lua", function()
        -- quotes.lua run in an environment with nothing in it: no require, no globals.
        local function load_bare()
            local chunk = assert(loadfile(quotes_path))
            setfenv(chunk, {})
            return chunk()
        end

        local function is_quote_mark(char)
            return char == "\"" or char == "'" or char == "“" or char == "”" or char == "‘" or char == "’"
        end

        it("loads by dofile with no require and holds at least 60 entries", function()
            assert.same(dofile(quotes_path), load_bare())
            assert.truthy(#load_bare() >= 60)
        end)

        it("gives each entry a text of at most 160 characters with no surrounding quote mark, an author, "
            .. "a work and a source", function()
            local util = require("util")
            for i, entry in ipairs(load_bare()) do
                local text = entry.text
                assert.is_string(text, "entry " .. i .. " has no text")
                local chars = util.splitToChars(text)
                assert.truthy(#chars > 0, "entry " .. i .. " is empty")
                assert.truthy(#chars <= 160, "entry " .. i .. " has " .. #chars .. " characters")
                assert.is_false(is_quote_mark(chars[1]), "entry " .. i .. " starts with a quote mark")
                assert.is_false(is_quote_mark(chars[#chars]), "entry " .. i .. " ends with a quote mark")
                assert.equals(text, text:match("^%s*(.-)%s*$"), "entry " .. i .. " has surrounding space")
                assert.truthy(type(entry.author) == "string" and #entry.author > 0, "entry " .. i .. " has no author")
                assert.truthy(type(entry.work) == "string" and #entry.work > 0, "entry " .. i .. " has no work")
                local source = entry.source
                assert.truthy(type(source) == "string"
                    and (source:match("^gutenberg:%d+$") or source:match("^wikisource:.+$")),
                    "entry " .. i .. " has source " .. tostring(source))
            end
        end)

        it("is the builtin source", function()
            assert.same(dofile(quotes_path), Quote.sources.builtin)
        end)
    end)

    describe("index", function()
        it("counts local calendar days since 1970-01-01, from 1", function()
            local count = #dofile(quotes_path)
            in_zone("America/Chicago", function()
                assert.equals(1, Quote.index(at(1970, 1, 1, 0, 1)))
                assert.equals(2, Quote.index(at(1970, 1, 2, 23, 59)))
                assert.equals(1, Quote.index(at(1970, 1, 1 + count, 0, 1)))
            end)
            -- East of Greenwich, local midnight is the day before in UTC.
            in_zone("Asia/Tokyo", function()
                assert.equals(2, Quote.index(at(1970, 1, 2, 0, 1)))
            end)
        end)

        it("is the same all day and the next entry after local midnight, across DST changes", function()
            local count = #dofile(quotes_path)
            local function next_of(i)
                return i % count + 1
            end
            in_zone("America/Chicago", function()
                -- 2026-03-08 is 23 hours long, 2026-11-01 25 hours.
                local days = { { 2026, 3, 7 }, { 2026, 3, 8 }, { 2026, 10, 31 }, { 2026, 11, 1 }, { 2026, 10, 13 } }
                for _, day in ipairs(days) do
                    local y, m, d = day[1], day[2], day[3]
                    local first = Quote.index(at(y, m, d, 0, 1))
                    assert.equals(first, Quote.index(at(y, m, d, 23, 59)), y .. "-" .. m .. "-" .. d)
                    assert.equals(next_of(first), Quote.index(at(y, m, d + 1, 0, 1)), y .. "-" .. m .. "-" .. d)
                end
            end)
        end)
    end)

    describe("the widget", function()
        it("reads quote.source and draws the day's builtin entry in curly quotes, with no author", function()
            local read = {}
            Settings.get = function(key)
                read[#read + 1] = key
                return real_get(key)
            end
            for _, look_id in ipairs(Looks.ids()) do
                local ctx = ctx_for(look_id)
                local entry = dofile(quotes_path)[Quote.index(ctx.now)]
                local built = Quote.build(500, ctx)
                local text = built.text_box.text
                assert.equals("“" .. entry.text .. "”", text)
                assert.is_nil(text:find(entry.author, 1, true))
                built:free()
            end
            assert.truthy(#read > 0)
            for _, key in ipairs(read) do
                if key == "quote.source" then
                    return
                end
            end
            error("the widget never read quote.source")
        end)

        it("fits the longest entry in four lines at large in a full-width row on both profiles", function()
            local entry = longest(dofile(quotes_path))
            Quote.sources.builtin = { entry }
            for name, profile in pairs(profiles) do
                on_screen(profile.width, profile.height, function()
                    for _, look_id in ipairs(Looks.ids()) do
                        local ctx = ctx_for(look_id, "large")
                        local width = full_row_width(ctx)
                        assert.truthy(width > 0)
                        local built = Quote.build(width, ctx)
                        local box = built.text_box
                        local where = name .. " " .. look_id .. ": " .. entry.text
                        assert.equals(Layout.font_size(18, "large"), box.face.orig_size, where)
                        assert.truthy(#box.vertical_string_list <= 4, where)
                        assert.is_nil(box.line_with_ellipsis, where)
                        built:free()
                    end
                end)
            end
        end)

        it("ends a longer text in an ellipsis on its fourth line", function()
            Quote.sources.builtin = {
                {
                    text = string.rep("Reading is a long and pleasant thing. ", 11):sub(1, 400),
                    author = "A",
                    work = "W",
                },
            }
            for _, look_id in ipairs(Looks.ids()) do
                local ctx = ctx_for(look_id, "large")
                local built = Quote.build(600, ctx)
                local box = built.text_box
                assert.truthy(#box.vertical_string_list > 4)
                assert.equals(4, box.lines_per_page)
                assert.equals(4, box.line_with_ellipsis)
                assert.is_true(box.vertical_string_list[4].ellipsis_added)
                assert.equals(4 * box.line_height_px, box.height)
                built:free()
            end
        end)

        it("is exactly the width it was built at, as tall as height says", function()
            for _, look_id in ipairs(Looks.ids()) do
                local ctx = ctx_for(look_id)
                for _, width in ipairs({ 300, 600 }) do
                    local built = Quote.build(width, ctx)
                    assert.equals(width, built:getSize().w)
                    assert.equals(Quote.height(width, ctx), built:getSize().h)
                    assert.truthy(built:getSize().h > built.text_box:getSize().h)
                    built:free()
                end
            end
        end)

        it("draws Editorial between hairline rules and Diner in its tile with a hard shadow", function()
            local function painted(look_id)
                local ctx = ctx_for(look_id)
                local built = Quote.build(400, ctx)
                local size = built:getSize()
                local bb = Blitbuffer.new(size.w, size.h, Blitbuffer.TYPE_BBRGB32)
                bb:fill(Blitbuffer.COLOR_WHITE)
                built:paintTo(bb, 0, 0)
                built:free()
                return bb, size, ctx.look.palettes.day
            end
            local function rgb(bb, x, y)
                local c = bb:getPixel(x, y):getColorRGB32()
                return string.format("#%02x%02x%02x", c.r, c.g, c.b)
            end

            local bb, size, palette = painted("editorial")
            assert.equals(palette.hairline, rgb(bb, 0, 0))
            assert.equals(palette.hairline, rgb(bb, size.w - 1, size.h - 1))
            bb:free()

            bb, size, palette = painted("diner")
            local shadow = Screen:scaleBySize(Looks.get("diner").shadow.tile.x)
            assert.equals(palette.outline, rgb(bb, 0, 0))
            assert.equals(palette.shadow, rgb(bb, size.w - 1, size.h - 1))
            assert.equals("#ffffff", rgb(bb, size.w - 1, 0))
            assert.equals(palette.paper, rgb(bb, size.w - shadow - 10, size.h - shadow - 10))
            bb:free()
        end)

        it("is a blank box of height 0 for an empty source", function()
            Quote.sources.builtin = {}
            local ctx = ctx_for("editorial")
            assert.is_nil(Quote.index(ctx.now))
            assert.equals(0, Quote.height(400, ctx))
            local built = Quote.build(400, ctx)
            assert.equals(400, built:getSize().w)
            assert.equals(0, built:getSize().h)
        end)
    end)
end)
