-- Night mode under KOReader's software inversion (night mode's C3 to C5): only looks.lua and
-- swatch.lua read a look's palettes; the home paints the inverse of the night palette onto a
-- buffer whose inverse flag is set, as Screen:toggleNightMode leaves the screen's buffer on a
-- device that can't invert in hardware (base/ffi/framebuffer.lua:476-488), so the stored pixels,
-- which that panel shows, are the designed night colours; it rebuilds inside the paint that
-- follows a variant change; and the featured cover keeps its own colours. Every stub of
-- night_mode, color_rendering, the look, bookinfomanager and FeaturedBook.current is restored
-- in after_each.
describe("night mode", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen

    local function read(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return text
    end

    -- { r, g, b } of a #rrggbb, or of its per-channel inverse.
    local function rgb(hex)
        local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
        return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
    end

    local function inverse_rgb(hex)
        local c = rgb(hex)
        return { 255 - c[1], 255 - c[2], 255 - c[3] }
    end

    local function near(a, b, tolerance)
        return math.abs(a[1] - b[1]) <= tolerance and math.abs(a[2] - b[2]) <= tolerance
            and math.abs(a[3] - b[3]) <= tolerance
    end

    -- A w by h RGB32 buffer, its inverse flag set when night.
    local function screen_buffer(w, h, night)
        local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
        if night then
            bb:invert()
        end
        return bb
    end

    -- What the panel shows: bb's stored pixels, read through a copy with the flag cleared, as
    -- Screen:shot does in night mode (base/ffi/framebuffer.lua:566-581). The caller frees it.
    local function panel(bb)
        local view = bb:copy()
        if view:getInverse() == 1 then
            view:invert()
        end
        return view
    end

    local function pixel(view, x, y)
        local c = view:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    describe("palette reads", function()
        -- The same walk as hooks_doc_spec.lua's: every plugin file, comments included.
        it("are left to looks.lua and swatch.lua", function()
            local readers, scanned = {}, 0
            for _, file in ipairs(harness.plugin_files()) do
                local exempt = file == "looks.lua" or file == "swatch.lua" or file:match("^looks/")
                if not exempt then
                    scanned = scanned + 1
                    if read(harness.plugin_dir .. "/" .. file):find("palettes", 1, true) then
                        readers[#readers + 1] = file
                    end
                end
            end
            assert.truthy(scanned > 20, "too few files scanned: " .. scanned)
            assert.truthy(read(harness.plugin_dir .. "/swatch.lua"):find("palettes", 1, true))
            assert.same({}, readers)
        end)
    end)

    local Home, Looks, Settings
    local had_color, color_rendering, night_mode

    before_each(function()
        harness.load()
        Home = require("home")
        Looks = require("looks")
        Settings = require("settings")
        had_color = G_reader_settings:has("color_rendering")
        color_rendering = G_reader_settings:readSetting("color_rendering")
        night_mode = rawget(Screen, "night_mode")
        G_reader_settings:saveSetting("color_rendering", true)
        Screen.night_mode = false
    end)

    after_each(function()
        Screen.night_mode = night_mode
        if had_color then
            G_reader_settings:saveSetting("color_rendering", color_rendering)
        else
            G_reader_settings:delSetting("color_rendering")
        end
        Settings._reset()
        os.remove(harness.settings_file)
        os.remove(harness.settings_file .. ".old")
        harness.teardown()
    end)

    describe("the home", function()
        local bb, dirty

        -- Night mode on or off, on the screen and on bb's flag together, as toggleNightMode
        -- flips both.
        local function set_night(on)
            Screen.night_mode = on
            if bb then
                bb:setInverse(on and 1 or 0)
            end
        end

        local function paper_at_corner(home)
            home:paintTo(bb, 0, 0)
            local view = panel(bb)
            local p = pixel(view, 1, 1)
            view:free()
            return p
        end

        before_each(function()
            local size = Screen:getSize()
            bb = screen_buffer(size.w, size.h, false)
            dirty = spy.on(UIManager, "setDirty")
        end)

        after_each(function()
            dirty:revert()
            bb:free()
            bb = nil
        end)

        -- Editorial: its paper reaches the top left corner; Diner's header band covers it.
        it("built at night paints the night paper", function()
            Settings.set("look", "editorial")
            set_night(true)
            local home = Home:new{}
            assert.equals("night", home.ctx.variant)
            local p = paper_at_corner(home)
            assert.is_true(near(rgb("#15161a"), p, 1), table.concat(p, ","))
            home:free()
        end)

        it("built by day rebuilds in the first paint after night mode turns on, and back", function()
            Settings.set("look", "editorial")
            local home = Home:new{}
            local day_rows = home[1]
            assert.is_true(near(rgb("#f3f1ea"), paper_at_corner(home), 1))
            dirty:clear()

            set_night(true)
            local p = paper_at_corner(home)
            assert.is_true(near(rgb("#15161a"), p, 1), table.concat(p, ","))
            assert.equals("night", home.ctx.variant)
            assert.is_not.equals(day_rows, home[1])
            assert.spy(dirty).was_not_called()

            set_night(false)
            p = paper_at_corner(home)
            assert.is_true(near(rgb("#f3f1ea"), p, 1), table.concat(p, ","))
            assert.equals("day", home.ctx.variant)
            assert.spy(dirty).was_not_called()
            home:free()
        end)

        it("keeps its rows when the variant is unchanged between paints", function()
            local home = Home:new{}
            local rows = home[1]
            home:paintTo(bb, 0, 0)
            home:paintTo(bb, 0, 0)
            assert.equals(rows, home[1])
            home:free()
        end)

        it("on a screen without colour keeps its rows when night mode flips", function()
            G_reader_settings:saveSetting("color_rendering", false)
            local home = Home:new{}
            local rows = home[1]
            home:paintTo(bb, 0, 0)
            set_night(true)
            home:paintTo(bb, 0, 0)
            assert.equals("grey", home.ctx.variant)
            assert.equals(rows, home[1])
            home:free()
        end)

        -- Diner: its clock is on_band on the band, its quote ink in a paper tile. Editorial can't
        -- tell the two apart, as its day ink inverted lands within 8 of its night ink. The clock
        -- is a TextWidget, which KOReader draws in its colour's grey (colorblitFrom,
        -- frontend/ui/widget/textwidget.lua:369, takes getColor8A, base/ffi/blitbuffer.lua:1407),
        -- by day as at night, so its night role is looked for as that grey, and the day role as
        -- the grey the day palette would leave inverted; the quote is a TextBoxWidget, drawn in
        -- the colour itself.
        it("draws the clock and the quote in the night roles, not the day ones inverted", function()
            local function grey(hex)
                local v = Blitbuffer.colorFromString(hex):getColor8().a
                return { v, v, v }
            end
            local function inverse_grey(hex)
                local v = 255 - Blitbuffer.colorFromString(hex):getColor8().a
                return { v, v, v }
            end
            local drawn = {
                clock = { night = grey, day = inverse_grey },
                quote = { night = rgb, day = inverse_rgb },
            }
            Settings.set("look", "diner")
            set_night(true)
            local home = Home:new{}
            home:paintTo(bb, 0, 0)
            local view = panel(bb)
            local look = home.ctx.look
            for _, id in ipairs({ "clock", "quote" }) do
                local role = look.type[id].color
                local night = drawn[id].night(look.palettes.night[role])
                local day = drawn[id].day(look.palettes.day[role])
                local rect
                for _, slot in ipairs(home.slots) do
                    if slot.widget == id then
                        rect = slot.rect
                    end
                end
                assert.is_table(rect, id)
                assert.truthy(rect.h > 0, id)
                local in_night, in_day = 0, 0
                for y = rect.y, rect.y + rect.h - 1 do
                    for x = rect.x, rect.x + rect.w - 1 do
                        local p = pixel(view, x, y)
                        if near(night, p, 8) then
                            in_night = in_night + 1
                        end
                        if near(day, p, 8) then
                            in_day = in_day + 1
                        end
                    end
                end
                assert.truthy(in_night > 0, id .. " has no night " .. role)
                assert.equals(0, in_day, id .. " has the day " .. role)
            end
            view:free()
            home:free()
        end)
    end)

    describe("the featured cover", function()
        local Featured, FeaturedBook
        local current, loaded, preload

        local COVER = "#c05030"

        local function book()
            return {
                file = harness.library .. "/frankenstein.epub",
                title = "Frankenstein",
                authors = "Mary Shelley",
                percent = 0.4,
                status = "reading",
            }
        end

        -- A CoverBrowser whose cache holds a 2 by 3 cover of COVER for every file.
        local function cover_manager()
            local m = {}
            function m.getBookInfo(_, _, get_cover)
                local info = { has_cover = "Y", cover_fetched = "Y", cover_w = 1000, cover_h = 1500 }
                if get_cover then
                    local c = rgb(COVER)
                    local cover = Blitbuffer.new(2, 3, Blitbuffer.TYPE_BBRGB32)
                    cover:paintRectRGB32(0, 0, 2, 3, Blitbuffer.ColorRGB32(c[1], c[2], c[3], 255))
                    info.cover_bb = cover
                end
                return info
            end
            function m.isCachedCoverInvalid()
                return false
            end
            function m.extractInBackground()
                return true
            end
            function m.isExtractingInBackground()
                return false
            end
            return m
        end

        -- The featured widget for book in look id at night, painted at (0, 0) on a buffer of its
        -- size with the flag set. Returns the panel view and the cover box's place and size.
        local function paint_night(id)
            Screen.night_mode = true
            local ctx = {
                look = Looks.get(id), variant = Looks.variant(), text_size = "medium", now = os.time(),
                screen = Screen,
            }
            assert.equals("night", ctx.variant)
            local built = Featured.build(520, ctx)
            local box
            local function find(widget)
                if widget.name == "kopanda_featured_cover" then
                    box = widget
                end
                for _, child in ipairs(widget) do
                    find(child)
                end
            end
            find(built)
            assert.is_table(box, id .. " has no cover box")
            local paint_box = box.paintTo
            local place = {}
            box.paintTo = function(self, target, x, y)
                place.x, place.y = x, y
                return paint_box(self, target, x, y)
            end
            local size = built:getSize()
            local bb = screen_buffer(size.w, size.h, true)
            built:paintTo(bb, 0, 0)
            local view = panel(bb)
            bb:free()
            built:free()
            return view, place.x, place.y, box
        end

        before_each(function()
            Featured = require("widgets/featured")
            FeaturedBook = require("featured_book")
            current = FeaturedBook.current
            loaded, preload = package.loaded.bookinfomanager, package.preload.bookinfomanager
            FeaturedBook.current = book
        end)

        after_each(function()
            FeaturedBook.current = current
            package.loaded.bookinfomanager = loaded
            package.preload.bookinfomanager = preload
        end)

        it("keeps the cover's own pixels and frames it in the night outline", function()
            package.loaded.bookinfomanager = cover_manager()
            for _, id in ipairs({ "editorial", "diner" }) do
                local view, x, y, box = paint_night(id)
                local centre = pixel(view, x + math.floor(box.box_w / 2), y + math.floor(box.box_h / 2))
                assert.is_true(near(rgb(COVER), centre, 1), id .. " cover " .. table.concat(centre, ","))
                local edge = pixel(view, x, y + math.floor(box.box_h / 2))
                local outline = Looks.get(id).palettes.night.outline
                assert.is_true(near(rgb(outline), edge, 1), id .. " outline " .. table.concat(edge, ","))
                view:free()
            end
        end)

        it("fills the placeholder in the night cover role inside the night outline", function()
            package.loaded.bookinfomanager = nil
            package.preload.bookinfomanager = function() error("CoverBrowser is disabled") end
            for _, id in ipairs({ "editorial", "diner" }) do
                local view, x, y, box = paint_night(id)
                local night = Looks.get(id).palettes.night
                local mid = y + math.floor(box.box_h / 2)
                local fill = pixel(view, x + box.outline + 1, mid)
                assert.is_true(near(rgb(night.cover), fill, 1), id .. " fill " .. table.concat(fill, ","))
                local edge = pixel(view, x, mid)
                assert.is_true(near(rgb(night.outline), edge, 1), id .. " outline " .. table.concat(edge, ","))
                view:free()
            end
        end)
    end)
end)
