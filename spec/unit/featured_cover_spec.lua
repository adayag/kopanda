-- The featured book's cover box (C5): a cached cover fitted and centred on paper, the typographic
-- placeholder, the first run's dashed frame, the 40 % cap, and the one bounded extraction path.
-- bookinfomanager is stubbed in package.loaded and UIManager's scheduleIn and unschedule record
-- their calls; each case restores them in finally.
describe("the featured cover", function()
    require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Looks = require("looks")
    local UIManager = require("ui/uimanager")
    local FeaturedCover = require("featured_cover")
    local Home = require("home")

    local BOOK = "/books/piranesi.epub"

    -- A screen that leaves board pixels as they are, so lengths are exact.
    local flat_screen = { scaleBySize = function(_, px) return px end }

    local function ctx_for(id, variant)
        return { look = Looks.get(id), variant = variant or "day", text_size = "medium", screen = flat_screen }
    end

    local function rgb(hex)
        local c = Looks.color(hex)
        return { c:getR(), c:getG(), c:getB() }
    end

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return { c:getR(), c:getG(), c:getB() }
    end

    local SENTINEL = Blitbuffer.ColorRGB32(0, 255, 0, 255)

    -- built painted at (0, 0) on a w by h buffer of the sentinel green.
    local function paint(built, w, h)
        local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, w, h, SENTINEL)
        built:paintTo(bb, 0, 0)
        return bb
    end

    -- A solid red cover bitmap, w by h.
    local function red_bb(w, h)
        local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, w, h, Blitbuffer.ColorRGB32(255, 0, 0, 255))
        return bb
    end

    local RED = { 255, 0, 0 }

    -- The first and last x on row y (or y on column x) whose pixel is colour.
    local function extent(bb, colour, fixed, length, along_x)
        local first, last
        for i = 0, length - 1 do
            local x, y = i, fixed
            if not along_x then
                x, y = fixed, i
            end
            local p = pixel(bb, x, y)
            if p[1] == colour[1] and p[2] == colour[2] and p[3] == colour[3] then
                first = first or i
                last = i
            end
        end
        return first, last
    end

    local function count(bb, colour, x0, y0, w, h)
        local n = 0
        for y = y0, y0 + h - 1 do
            for x = x0, x0 + w - 1 do
                local p = pixel(bb, x, y)
                if p[1] == colour[1] and p[2] == colour[2] and p[3] == colour[3] then
                    n = n + 1
                end
            end
        end
        return n
    end

    -- The pixels in the region that are text in fg drawn over bg: not bg, and each channel
    -- between bg's and fg's, as a glyph's edge blends them.
    local function text_pixels(bb, fg, bg, x0, y0, w, h)
        local n = 0
        for y = y0, y0 + h - 1 do
            for x = x0, x0 + w - 1 do
                local p = pixel(bb, x, y)
                local between = p[1] ~= bg[1] or p[2] ~= bg[2] or p[3] ~= bg[3]
                for i = 1, 3 do
                    between = between and p[i] >= math.min(fg[i], bg[i]) and p[i] <= math.max(fg[i], bg[i])
                end
                if between then
                    n = n + 1
                end
            end
        end
        return n
    end

    -- A bookinfomanager stub. opts.info(file, get_cover) gives getBookInfo's result; extracting
    -- is a list of isExtractingInBackground's answers, its last repeated. isCachedCoverInvalid is
    -- the real one's rule: true for a row with no cover_w (bookinfomanager.lua:1014-1015), and
    -- true when the thumbnail is smaller than the box.
    local function manager(opts)
        local m = { extracted = {}, extracting_calls = 0 }
        function m:getBookInfo(file, get_cover)
            return opts.info and opts.info(file, get_cover)
        end
        function m:extractInBackground(files)
            m.extracted[#m.extracted + 1] = files
            return true
        end
        function m:isExtractingInBackground()
            m.extracting_calls = m.extracting_calls + 1
            local answers = opts.extracting or { false }
            return answers[math.min(m.extracting_calls, #answers)]
        end
        function m.isCachedCoverInvalid(info, specs)
            if not info.cover_w or not info.cover_h then
                return true
            end
            return info.cover_w < specs.max_cover_w and info.cover_h < specs.max_cover_h
        end
        return m
    end

    -- Installs bim as bookinfomanager (false: unrequirable) and a recording scheduler, and
    -- restores both, Home.shown and the module's state in finally. Returns the queue of
    -- scheduled { secs, fn }.
    local function stub(bim)
        local loaded, preload = package.loaded.bookinfomanager, package.preload.bookinfomanager
        local schedule_in, unschedule = UIManager.scheduleIn, UIManager.unschedule
        local shown = Home.shown
        local queue = { unscheduled = 0 }
        if bim then
            package.loaded.bookinfomanager = bim
        else
            package.loaded.bookinfomanager = nil
            package.preload.bookinfomanager = function() error("CoverBrowser is disabled") end
        end
        UIManager.scheduleIn = function(_, secs, fn)
            queue[#queue + 1] = { secs = secs, fn = fn }
        end
        UIManager.unschedule = function(_, fn)
            for i = #queue, 1, -1 do
                if queue[i].fn == fn then
                    table.remove(queue, i)
                    queue.unscheduled = queue.unscheduled + 1
                end
            end
        end
        FeaturedCover.reset()
        finally(function()
            FeaturedCover.reset()
            package.loaded.bookinfomanager = loaded
            package.preload.bookinfomanager = preload
            UIManager.scheduleIn, UIManager.unschedule = schedule_in, unschedule
            Home.shown = shown
        end)
        return queue
    end

    -- Runs the first queued task, as UIManager would when it comes due.
    local function run_next(queue)
        local task = table.remove(queue, 1)
        task.fn()
        return task
    end

    -- A home that counts its refreshes, shown.
    local function shown_home()
        local home = { refreshes = 0 }
        function home:refresh()
            self.refreshes = self.refreshes + 1
        end
        Home.shown = home
        return home
    end

    local SPECS = { max_cover_w = 150, max_cover_h = 225 }

    local function usable(bb)
        return {
            has_cover = "Y", cover_fetched = "Y", cover_w = 150, cover_h = 225,
            cover_sizetag = "300x450", cover_bb = bb,
        }
    end

    describe("box", function()
        it("is the look's scaled cover size in a full-width column", function()
            local screen = { scaleBySize = function(_, px) return 2 * px end }
            for id, size in pairs({ editorial = { 300, 450 }, diner = { 280, 420 } }) do
                local ctx = ctx_for(id)
                ctx.screen = screen
                assert.same(size, { FeaturedCover.box(1184, ctx) }, id)
            end
        end)

        it("caps the width at 40 % of a 300 px column, the height 1.5 times it", function()
            for _, id in ipairs({ "editorial", "diner" }) do
                assert.same({ 120, 180 }, { FeaturedCover.box(300, ctx_for(id)) }, id)
            end
            assert.same({ 133, 199 }, { FeaturedCover.box(333, ctx_for("diner")) })
        end)
    end)

    describe("build", function()
        it("draws a tall cover at its fitted size, centred, with paper on the long sides", function()
            stub(manager{ info = function() return usable(red_bb(300, 600)) end })
            local ctx = ctx_for("editorial")
            local built = FeaturedCover.build({ file = BOOK, title = "Piranesi" }, 150, 225, ctx)
            local bb = paint(built, 200, 260)
            -- 300x600 fitted to 150x225 is 112.5x225.
            local left, right = extent(bb, RED, 112, 150, true)
            assert.truthy(right - left + 1 >= 112 and right - left + 1 <= 113, left .. ".." .. right)
            assert.truthy(math.abs(left - (150 - (right - left + 1)) / 2) <= 1, "left at " .. left)
            assert.same({ 0, 224 }, { extent(bb, RED, 75, 260, false) })
            local paper = rgb(ctx.look.palettes.day.paper)
            assert.same(paper, pixel(bb, 2, 112))
            assert.same(paper, pixel(bb, 147, 112))
            built:free()
        end)

        it("draws a wide cover with paper above and below", function()
            stub(manager{ info = function() return usable(red_bb(600, 300)) end })
            local ctx = ctx_for("editorial")
            local built = FeaturedCover.build({ file = BOOK, title = "Piranesi" }, 150, 225, ctx)
            local bb = paint(built, 200, 260)
            -- 600x300 fitted to 150x225 is 150x75, 75 down.
            assert.same({ 75, 149 }, { extent(bb, RED, 75, 260, false) })
            assert.same({ 0, 149 }, { extent(bb, RED, 112, 200, true) })
            local paper = rgb(ctx.look.palettes.day.paper)
            assert.same(paper, pixel(bb, 75, 2))
            assert.same(paper, pixel(bb, 75, 222))
            built:free()
        end)

        it("draws the shadow at shadow.cover's offset and no outline where the variant has none", function()
            stub(manager{ info = function() return usable(red_bb(300, 450)) end })
            local ctx = ctx_for("editorial")
            local built = FeaturedCover.build({ file = BOOK, title = "Piranesi" }, 150, 225, ctx)
            assert.same({ 152, 228 }, { built:getSize().w, built:getSize().h })
            local bb = paint(built, 200, 260)
            assert.same(rgb(ctx.look.palettes.day.shadow), pixel(bb, 151, 112))
            assert.same(RED, pixel(bb, 0, 0))
            built:free()
        end)

        it("draws Diner's outline at stroke.outline round the cover, the cover inside it", function()
            stub(manager{ info = function() return usable(red_bb(300, 450)) end })
            local ctx = ctx_for("diner")
            local built = FeaturedCover.build({ file = BOOK, title = "Piranesi" }, 140, 210, ctx)
            local bb = paint(built, 200, 260)
            local outline = rgb(ctx.look.palettes.day.outline)
            assert.same(outline, pixel(bb, 0, 100))
            assert.same(outline, pixel(bb, 2, 100))
            assert.same(RED, pixel(bb, 70, 10))
            assert.same(rgb(ctx.look.palettes.day.pink), pixel(bb, 143, 213))
            built:free()
        end)

        it("frees an unusable cover bitmap and draws the placeholder", function()
            local freed = 0
            local stale = { free = function() freed = freed + 1 end }
            stub(manager{ info = function()
                return { has_cover = "Y", cover_fetched = "Y", cover_bb = stale }
            end })
            local ctx = ctx_for("editorial")
            local built = FeaturedCover.build({ file = BOOK, title = "Piranesi" }, 150, 225, ctx)
            assert.equals(1, freed)
            local bb = paint(built, 200, 260)
            assert.same(rgb(ctx.look.palettes.day.cover), pixel(bb, 75, 112))
            built:free()
        end)

        it("draws the placeholder in cover and on_cover when bookinfomanager won't load, and asks nothing", function()
            local queue = stub(false)
            for _, id in ipairs({ "editorial", "diner" }) do
                local ctx = ctx_for(id)
                local palette = ctx.look.palettes.day
                local built = FeaturedCover.build(
                    { file = BOOK, title = "Piranesi", authors = "Susanna Clarke" }, 150, 225, ctx)
                local bb = paint(built, 200, 260)
                assert.same(rgb(palette.cover), pixel(bb, 75, 112), id)
                -- The title in the top half and the authors in the foot, in on_cover.
                local on_cover, cover = rgb(palette.on_cover), rgb(palette.cover)
                assert.truthy(count(bb, on_cover, 0, 0, 150, 100) > 20, id .. " title")
                assert.truthy(text_pixels(bb, on_cover, cover, 0, 180, 150, 45) > 50, id .. " authors")
                built:free()
            end
            FeaturedCover.after_show(shown_home(), BOOK, SPECS)
            assert.equals(0, #queue)
            assert.is_false(FeaturedCover.wants_extraction(nil, SPECS))
        end)

        it("draws the first run as dashes of dash with dash_gap gaps in muted round \"No book yet\"", function()
            stub(false)
            local ctx = ctx_for("editorial")
            local built = FeaturedCover.build(nil, 150, 225, ctx)
            local bb = paint(built, 200, 260)
            local muted = rgb(ctx.look.palettes.day.muted)
            for x = 0, 3 do
                assert.same(muted, pixel(bb, x, 0), "dash at " .. x)
            end
            for x = 4, 7 do
                assert.same({ 0, 255, 0 }, pixel(bb, x, 0), "gap at " .. x)
            end
            assert.same(muted, pixel(bb, 0, 8))
            assert.same({ 0, 255, 0 }, pixel(bb, 0, 5))
            assert.truthy(text_pixels(bb, muted, { 0, 255, 0 }, 10, 90, 130, 45) > 50, "No book yet")
            built:free()
        end)

        it("never asks for extraction while building or painting", function()
            local bim = manager{ info = function() return nil end }
            stub(bim)
            shown_home()
            local built = FeaturedCover.build({ file = BOOK, title = "Piranesi" }, 150, 225, ctx_for("diner"))
            paint(built, 200, 260)
            built:free()
            assert.equals(0, #bim.extracted)
        end)
    end)

    describe("wants_extraction", function()
        it("asks for nil, an unfetched cover and a too-small one", function()
            stub(manager{})
            assert.is_true(FeaturedCover.wants_extraction(nil, SPECS))
            assert.is_true(FeaturedCover.wants_extraction({ has_meta = "Y" }, SPECS))
            assert.is_true(FeaturedCover.wants_extraction(
                { cover_fetched = "Y", has_cover = "Y", cover_w = 50, cover_h = 75, cover_sizetag = "300x450" }, SPECS))
        end)

        it("never asks for an unsupported book, an ignored cover or a book with no cover", function()
            stub(manager{})
            for name, info in pairs({
                unsupported = { unsupported = "not readable", cover_fetched = "Y" },
                unsupported_unfetched = { unsupported = "not readable" },
                ignore_cover = { ignore_cover = "Y", cover_fetched = "Y", has_cover = "Y" },
                no_cover = { cover_fetched = "Y" },
            }) do
                assert.is_nil(info.cover_w, name)
                assert.is_false(FeaturedCover.wants_extraction(info, SPECS), name)
            end
        end)

        it("doesn't ask for a cover that fits", function()
            stub(manager{})
            assert.is_false(FeaturedCover.wants_extraction(usable(nil), SPECS))
        end)
    end)

    describe("after_show", function()
        it("asks once for a file across two shows, for the box's specs", function()
            local bim = manager{ info = function() return nil end, extracting = { false } }
            local queue = stub(bim)
            local home = shown_home()
            FeaturedCover.after_show(home, BOOK, SPECS)
            assert.same({ { { filepath = BOOK, cover_specs = SPECS } } }, bim.extracted)
            run_next(queue)
            FeaturedCover.after_show(home, BOOK, SPECS)
            assert.equals(1, #bim.extracted)
            assert.equals(0, #queue)
        end)

        it("doesn't ask for a cover it has", function()
            local bim = manager{ info = function() return usable(nil) end }
            local queue = stub(bim)
            FeaturedCover.after_show(shown_home(), BOOK, SPECS)
            assert.equals(0, #bim.extracted)
            assert.equals(0, #queue)
        end)

        it("checks each second while extracting and refreshes once when the cover arrives", function()
            local arrived = false
            local bim = manager{
                info = function() return arrived and usable({ free = function() end }) or nil end,
                extracting = { true, true, true, false },
            }
            local queue = stub(bim)
            local home = shown_home()
            FeaturedCover.after_show(home, BOOK, SPECS)
            for _ = 1, 3 do
                assert.equals(1, #queue)
                assert.equals(1, run_next(queue).secs)
                assert.equals(0, home.refreshes)
            end
            arrived = true
            assert.equals(1, #queue)
            run_next(queue)
            assert.equals(1, home.refreshes)
            assert.equals(0, #queue)
            assert.equals(4, bim.extracting_calls)
        end)

        it("stops after 30 checks with no refresh when extraction never ends", function()
            local bim = manager{ info = function() return nil end, extracting = { true } }
            local queue = stub(bim)
            local home = shown_home()
            FeaturedCover.after_show(home, BOOK, SPECS)
            local checks = 0
            while #queue > 0 do
                run_next(queue)
                checks = checks + 1
                assert.truthy(checks <= 30, "more than 30 checks")
            end
            assert.equals(30, checks)
            assert.equals(0, home.refreshes)
        end)

        it("stops at the next check once the home is no longer shown, with no refresh", function()
            local arrived = false
            local bim = manager{
                info = function() return arrived and usable({ free = function() end }) or nil end,
                extracting = { true },
            }
            local queue = stub(bim)
            local home = shown_home()
            FeaturedCover.after_show(home, BOOK, SPECS)
            run_next(queue)
            Home.shown = nil
            arrived = true
            run_next(queue)
            assert.equals(0, #queue)
            assert.equals(0, home.refreshes)
        end)

        it("leaves nothing scheduled when the home closes mid-way", function()
            local bim = manager{ info = function() return nil end, extracting = { true } }
            local queue = stub(bim)
            FeaturedCover.after_show(shown_home(), BOOK, SPECS)
            run_next(queue)
            assert.equals(1, #queue)
            FeaturedCover.cancel()
            assert.equals(0, #queue)
            assert.equals(1, queue.unscheduled)
        end)

        it("schedules nothing when the extraction couldn't start", function()
            local bim = manager{ info = function() return nil end }
            bim.extractInBackground = function() return false end
            local queue = stub(bim)
            FeaturedCover.after_show(shown_home(), BOOK, SPECS)
            assert.equals(0, #queue)
        end)
    end)
end)
