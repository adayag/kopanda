-- The sleep screen: the cover and card drawn into one screen-sized bitmap, and the Screensaver.setup wrapper that hands
-- it to KOReader, or leaves KOReader's own screen on anything unexpected.
describe("SleepScreen", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local SleepScreen, Featured, Forecast, Looks, Paint, ReadingStats, Streak, Wallpaper
    local W, H = 600, 800

    -- The unit screen is grey, so these draw for a colour screen of the same scale.
    local function ctx(look_id, variant, grey_screen)
        return { look = Looks.get(look_id or "diner"), variant = variant or "day", text_size = "medium", now = 0,
            screen = grey_screen and Screen or {
                bb = { getType = function() return Blitbuffer.TYPE_BBRGB32 end },
                night_mode = variant == "night",
                scaleBySize = function(_, px) return Screen:scaleBySize(px) end,
            } }
    end

    -- A flat cover the card's paper can't be mistaken for.
    local function cover()
        local bb = Blitbuffer.new(300, 400, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, 300, 400, Blitbuffer.colorFromString("#102030"))
        return bb
    end

    local BOOK = { title = "Frankenstein", chapter = "Letter 4", percent = 0.42, status = "reading",
        seconds_left = 3600 }

    -- The bitmap's pixel as #rrggbb.
    local function hex(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return string.format("#%02x%02x%02x", c:getR(), c:getG(), c:getB())
    end

    -- A point just inside the card's bottom edge on a bitmap h tall (H by default), clear of its text and outline.
    local function in_card(look, h)
        local scale = Paint.scaler(ctx())
        return math.floor(W / 2), (h or H) - scale(look.sleep.margin) - scale(look.sleep.outline_width) - 2
    end

    -- The first row above the card's bottom edge that isn't paper, up its left padding band, clear of its text.
    local function card_top(bb, look, h)
        local scale = Paint.scaler(ctx())
        local x = scale(look.sleep.margin) + math.floor(scale(look.sleep.padding.x) / 2)
        local _, y = in_card(look, h)
        while hex(bb, x, y) == look.palettes.day.paper do
            y = y - 1
        end
        return y
    end

    setup(function()
        harness.load()
        SleepScreen, Featured = require("kopanda_sleep_screen"), require("widgets/featured")
        Looks, Paint, Wallpaper = require("looks"), require("paint"), require("wallpaper")
        Forecast, Streak = require("widgets/forecast"), require("widgets/streak")
        ReadingStats = require("reading_stats")
    end)

    describe("clean_chapter", function()
        it("strips Chapter, its word and a separator from the front", function()
            for _, title in ipairs({ "Chapter 5: The Storm", "CHAPTER V. The Storm", "Chapter One - The Storm",
                "Chapter 12 \u{2014} The Storm", "Chapter 12 \u{2013} The Storm", "Chapter 12\u{2014}The Storm",
                "Chapter Twenty-One: The Storm" }) do
                assert.equals("The Storm", SleepScreen.clean_chapter(title), title)
            end
            assert.equals("序章", SleepScreen.clean_chapter("Chapter 5: 序章"))
        end)

        it("leaves a title with no separator or nothing after it", function()
            for _, title in ipairs({ "Chapter 5", "Chapter of Accidents", "Letter 4", "Chapter 5 The Storm",
                "Chapter 5:", "Chapter 5: ", "Chapter Twenty-One", "Chapter 1.5 Notes", "Chapter 5: \u{2014}",
                "Chapter 5: \u{2013}", "Chapter 5 - -" }) do
                assert.equals(title, SleepScreen.clean_chapter(title), title)
            end
        end)
    end)

    describe("byline", function()
        it("joins the authors and the series with its number", function()
            assert.equals("Mary Shelley · Barsoom #2",
                SleepScreen.byline({ authors = "Mary Shelley", series = "Barsoom", series_index = 2 }))
        end)

        it("shows a part number as it is", function()
            assert.equals("Barsoom #2.5", SleepScreen.byline({ series = "Barsoom", series_index = 2.5 }))
        end)

        it("shows either alone", function()
            assert.equals("Barsoom", SleepScreen.byline({ series = "Barsoom" }))
            assert.equals("Mary Shelley", SleepScreen.byline({ authors = "Mary Shelley" }))
        end)

        it("is nil with neither", function()
            assert.is_nil(SleepScreen.byline({}))
        end)
    end)

    describe("chapter_line", function()
        it("joins the clean title and the time left in the chapter", function()
            assert.equals("The Storm · 12 min left in chapter",
                SleepScreen.chapter_line({ chapter = "Chapter 5: The Storm", chapter_seconds = 720 }))
        end)

        it("shows either alone", function()
            assert.equals("The Storm", SleepScreen.chapter_line({ chapter = "Chapter 5: The Storm" }))
            assert.equals("12 min left in chapter", SleepScreen.chapter_line({ chapter_seconds = 720 }))
        end)

        it("says a minute for under one", function()
            assert.equals("1 min left in chapter", SleepScreen.chapter_line({ chapter_seconds = 20 }))
        end)

        it("is nil with neither", function()
            assert.is_nil(SleepScreen.chapter_line({}))
        end)
    end)

    describe("today", function()
        it("words pages and time", function()
            assert.equals("Today 35 pages · 40 min", SleepScreen.today(2400, 35))
            assert.equals("Today 1 page · 1 min", SleepScreen.today(60, 1))
        end)

        it("says a minute for under one", function()
            assert.equals("Today 1 page · 1 min", SleepScreen.today(20, 1))
        end)

        it("is nil at zero pages", function()
            assert.is_nil(SleepScreen.today(600, 0))
        end)
    end)

    describe("battery", function()
        local TOTALS = { discharging = { percentage = 10, time = 3600 * 10 * 1000000 } }

        it("words the percent and the time left", function()
            assert.equals("62% · about 2 days left", SleepScreen.battery(62, false, TOTALS))
        end)

        it("is the percent alone charging or with no time", function()
            assert.equals("62%", SleepScreen.battery(62, true, TOTALS))
            assert.equals("62%", SleepScreen.battery(62, false, {}))
            assert.equals("62%", SleepScreen.battery(62, false, nil))
        end)

        it("is nil with no percent", function()
            assert.is_nil(SleepScreen.battery(nil, false, TOTALS))
        end)
    end)

    describe("image", function()
        it("is the screen's size, with the cover above the card", function()
            local bb = SleepScreen.image(BOOK, cover(), W, H, ctx())
            assert.equals(W, bb:getWidth())
            assert.equals(H, bb:getHeight())
            assert.equals("#102030", hex(bb, 10, 10))
            bb:free()
        end)

        it("paints the card in the look's paper", function()
            local look = Looks.get("diner")
            local x, y = in_card(look)
            local bb = SleepScreen.image(BOOK, cover(), W, H, ctx("diner"))
            assert.equals(look.palettes.day.paper, hex(bb, x, y))
            bb:free()
        end)

        it("shows the night palette as designed, the cover unchanged, at night", function()
            local look = Looks.get("diner")
            local x, y = in_card(look)
            local bb = SleepScreen.image(BOOK, cover(), W, H, ctx("diner", "night"))
            assert.equals(look.palettes.night.paper, hex(bb, x, y))
            assert.equals("#102030", hex(bb, 10, 10))
            bb:free()
        end)

        it("is in the screen's own type", function()
            local bb = SleepScreen.image(BOOK, cover(), W, H, ctx("diner", "grey", true))
            assert.equals(Screen.bb:getType(), bb:getType())
            bb:free()
        end)

        it("paints the grey card for the panel's inversion at night, the cover unchanged", function()
            local look = Looks.get("diner")
            local x, y = in_card(look)
            local day = SleepScreen.image(BOOK, cover(), W, H, ctx("diner", "grey", true))
            local night_mode = Screen.night_mode
            Screen.night_mode = true
            local ok, night = pcall(SleepScreen.image, BOOK, cover(), W, H, ctx("diner", "grey", true))
            Screen.night_mode = night_mode
            assert(ok, night)
            local paper = look.palettes.grey.paper
            local v = 255 - tonumber(paper:sub(2, 3), 16)
            assert.equals(paper, hex(day, x, y))
            assert.equals(string.format("#%02x%02x%02x", v, v, v), hex(night, x, y))
            assert.equals(hex(day, 10, 10), hex(night, 10, 10))
            day:free()
            night:free()
        end)

        it("paints a card in every look", function()
            for _, id in ipairs(Looks.ids()) do
                for _, variant in ipairs({ "day", "night" }) do
                    local look = Looks.get(id)
                    local x, y = in_card(look)
                    local bb = SleepScreen.image(BOOK, cover(), W, H, ctx(id, variant))
                    assert.equals(look.palettes[variant].paper, hex(bb, x, y))
                    bb:free()
                end
            end
        end)

        describe("the tiles", function()
            local NOW = os.time{ year = 2026, month = 10, day = 13, hour = 12 }
            local real_insights

            local function insights(state)
                local days = {}
                for i = 1, ReadingStats.INSIGHT_DAYS do
                    days[i] = 600
                end
                return { state = state, days = days, hours = {} }
            end

            local function reading(state)
                ReadingStats.insights = function()
                    return insights(state)
                end
            end

            local function tile_ctx(look_id, variant)
                local c = ctx(look_id, variant)
                c.now, c.forecast_book = NOW, { title = "F", seconds_left = 7200, percent = 0.42 }
                return c
            end

            -- Wraps build so each widget's width and frees are recorded; returns the built widgets and the revert.
            local function counted(widget_module)
                local built, build = {}, widget_module.build
                widget_module.build = function(width, ...)
                    local widget = build(width, ...)
                    local entry = { widget = widget, width = width, freed = 0 }
                    built[#built + 1] = entry
                    local free = widget.free
                    widget.free = function(self)
                        entry.freed = entry.freed + 1
                        return free(self)
                    end
                    return widget
                end
                return built, function()
                    widget_module.build = build
                end
            end

            -- A row's height on the card: the card with the tiles less the card without them, on a tall bitmap.
            local function card_heights(look)
                local tall = 3000
                reading("ok")
                local with = SleepScreen.image(BOOK, cover(), W, tall, tile_ctx())
                reading("empty")
                local without = SleepScreen.image(BOOK, cover(), W, tall, tile_ctx())
                local _, bottom = in_card(look, tall)
                local a, b = bottom - card_top(with, look, tall), bottom - card_top(without, look, tall)
                with:free()
                without:free()
                return a, b
            end

            before_each(function()
                real_insights = ReadingStats.insights
            end)

            after_each(function()
                ReadingStats.insights = real_insights
            end)

            it("draws both at half the inner width, one height, and frees them", function()
                reading("ok")
                local c = tile_ctx()
                local scale = Paint.scaler(c)
                local tokens = c.look.sleep
                local inner_w = W - 2 * scale(tokens.margin) - 2 * scale(tokens.padding.x)
                local streak, revert_streak = counted(Streak)
                local forecast, revert_forecast = counted(Forecast)
                local bb = SleepScreen.image(BOOK, cover(), W, H, c)
                revert_streak()
                revert_forecast()
                bb:free()
                assert.equals(math.floor((inner_w - scale(tokens.tile_gap)) / 2), streak[1].width)
                assert.equals(streak[1].width, forecast[1].width)
                assert.equals(streak[1].widget.dimen.h, forecast[1].widget.dimen.h)
                assert.equals(1, streak[1].freed)
                assert.equals(1, forecast[1].freed)
            end)

            it("leaves them out unless the reading history is ok", function()
                for _, state in ipairs({ "off", "empty" }) do
                    reading(state)
                    local streak, revert = counted(Streak)
                    local bb = SleepScreen.image(BOOK, cover(), W, H, tile_ctx())
                    revert()
                    bb:free()
                    assert.equals(0, #streak, state)
                end
            end)

            it("makes the card taller", function()
                local with, without = card_heights(Looks.get("diner"))
                assert.is_true(with > without)
            end)

            it("keeps them on a card of half the screen, and drops them on one just over it", function()
                local look = Looks.get("diner")
                local with, without = card_heights(look)
                local scale = Paint.scaler(ctx())
                -- From the row inside the bottom outline to the last row under the top one, in_card's 2 px inset,
                -- and the margin under the card.
                local half = 2 * (with + 2 * scale(look.sleep.outline_width) + 1 + scale(look.sleep.margin))

                local function shown(h)
                    reading("ok")
                    local streak, revert = counted(Streak)
                    local bb = SleepScreen.image(BOOK, cover(), W, h, tile_ctx())
                    revert()
                    local height = select(2, in_card(look, h)) - card_top(bb, look, h)
                    bb:free()
                    return height, streak
                end

                assert.is_true(without < with)
                local tall, kept = shown(half)
                assert.equals(with, tall)
                assert.equals(1, kept[1].freed)
                local short, dropped = shown(half - 1)
                assert.equals(without, short)
                assert.equals(1, dropped[1].freed)
            end)

            it("frees the streak when the forecast raises", function()
                reading("ok")
                local streak, revert = counted(Streak)
                local forecast = stub(Forecast, "build", function() error("no forecast") end)
                local ok, err = pcall(SleepScreen.image, BOOK, cover(), W, H, tile_ctx())
                forecast:revert()
                revert()
                assert.is_false(ok)
                assert.truthy(tostring(err):find("no forecast", 1, true))
                assert.equals(1, streak[1].freed)
            end)

            it("paints the grey card with them", function()
                reading("ok")
                local look = Looks.get("diner")
                local x, y = in_card(look)
                local c = ctx("diner", "grey", true)
                c.now, c.forecast_book = NOW, { title = "F", seconds_left = 7200, percent = 0.42 }
                local bb = SleepScreen.image(BOOK, cover(), W, H, c)
                assert.equals(look.palettes.grey.paper, hex(bb, x, y))
                bb:free()
            end)

            it("paints the card's paper by day and at night in every look with them", function()
                reading("ok")
                for _, id in ipairs(Looks.ids()) do
                    for _, variant in ipairs({ "day", "night" }) do
                        local look = Looks.get(id)
                        local x, y = in_card(look)
                        local bb = SleepScreen.image(BOOK, cover(), W, H, tile_ctx(id, variant))
                        assert.equals(look.palettes[variant].paper, hex(bb, x, y), id .. " " .. variant)
                        bb:free()
                    end
                end
            end)
        end)

        describe("the lines", function()
            local function height(book)
                local look = Looks.get("diner")
                local bb = SleepScreen.image(book, cover(), W, H, ctx())
                local h = H - card_top(bb, look)
                bb:free()
                return h
            end

            it("adds a line for each of the byline, today and the battery", function()
                local bare = height(BOOK)
                local function with(fields)
                    local book = {}
                    for k, v in pairs(BOOK) do
                        book[k] = v
                    end
                    for k, v in pairs(fields) do
                        book[k] = v
                    end
                    return height(book)
                end
                assert.is_true(with({ authors = "Mary Shelley" }) > bare)
                assert.is_true(with({ today = "Today 1 page · 1 min" }) > bare)
                assert.is_true(with({ battery = "62%" }) > bare)
                assert.equals(with({ today = "Today 1 page · 1 min" }),
                    with({ today = "Today 1 page · 1 min", battery = "62%" }))
            end)
        end)

        describe("foot", function()
            local WIDE, TODAY, BATTERY = 500, "Today 1 page · 1 min", "62%"

            it("sets today at the left and the battery at the right of the width", function()
                local foot = SleepScreen.foot({ today = TODAY, battery = BATTERY }, WIDE, ctx())
                assert.equals(TODAY, foot[1].text)
                assert.equals(BATTERY, foot[#foot].text)
                assert.equals(WIDE, foot:getSize().w)
                foot:free()
            end)

            it("keeps the battery at the right alone", function()
                local foot = SleepScreen.foot({ battery = BATTERY }, WIDE, ctx())
                assert.equals(BATTERY, foot[#foot].text)
                assert.equals(WIDE, foot:getSize().w)
                foot:free()
            end)

            it("sets today alone", function()
                local foot = SleepScreen.foot({ today = TODAY }, WIDE, ctx())
                assert.equals(TODAY, foot[1].text)
                foot:free()
            end)

            it("drops a today the battery leaves no room for, rather than cut it", function()
                local foot = SleepScreen.foot({ today = TODAY, battery = BATTERY }, 80, ctx())
                assert.equals(2, #foot)
                assert.equals(BATTERY, foot[#foot].text)
                foot:free()
            end)

            it("is nil with neither", function()
                assert.is_nil(SleepScreen.foot({}, WIDE, ctx()))
            end)
        end)

        it("drops the chapter's line with no chapter", function()
            local look = Looks.get("diner")
            local full = SleepScreen.image(BOOK, cover(), W, H, ctx())
            local bare = SleepScreen.image({ title = "Frankenstein", percent = 0, status = "reading" },
                cover(), W, H, ctx())
            assert.is_true(card_top(bare, look) > card_top(full, look))
            full:free()
            bare:free()
        end)

        -- A bitmap's free lives on its metatype, out of a stub's reach, so the bitmap here is a table around one.
        it("frees its bitmap and raises when the card can't be drawn", function()
            local freed = 0
            local fill_box = Wallpaper.fill_box
            local filled = stub(Wallpaper, "fill_box", function(...)
                local bb = fill_box(...)
                return { free = function() freed = freed + 1; bb:free() end }
            end)
            local title = stub(Featured, "text_box", function() error("no title") end)
            local ok, err = pcall(SleepScreen.image, BOOK, cover(), W, H, ctx())
            filled:revert()
            title:revert()
            assert.is_false(ok)
            assert.truthy(tostring(err):find("no title", 1, true))
            assert.equals(1, freed)
        end)
    end)

    describe("setup", function()
        local Screensaver = require("ui/screensaver")
        local fm, Settings, logger
        local book = harness.library .. "/frankenstein.epub"
        local saved_type

        before_each(function()
            harness.load()
            SleepScreen = require("kopanda_sleep_screen")
            Settings, logger = require("settings"), require("logger")
            fm = harness.show_fm()
            saved_type = G_reader_settings:readSetting("screensaver_type")
            G_reader_settings:saveSetting("screensaver_type", "disable")
            G_reader_settings:saveSetting("lastfile", book)
        end)

        after_each(function()
            Screensaver:cleanup()
            G_reader_settings:saveSetting("screensaver_type", saved_type)
            G_reader_settings:delSetting("lastfile")
            fm:onClose()
        end)

        local function kept_koreaders()
            assert.is_nil(Screensaver.image)
            assert.equals("disable", Screensaver.screensaver_type)
        end

        it("hands KOReader a screen-sized cover for the last book", function()
            Screensaver:setup()
            assert.equals("cover", Screensaver.screensaver_type)
            assert.is_nil(Screensaver.image_file)
            assert.equals(math.min(Screen:getWidth(), Screen:getHeight()), Screensaver.image:getWidth())
            assert.equals(math.max(Screen:getWidth(), Screen:getHeight()), Screensaver.image:getHeight())
        end)

        -- Sets KOReader's cover mode with a first cover whose free counts, since a bitmap's is out of a stub's reach.
        local function koreaders_cover()
            local image = { freed = 0 }
            function image.free()
                image.freed = image.freed + 1
            end
            local calls = 0
            local stubbed = stub(fm.bookinfo, "getCoverImage", function()
                calls = calls + 1
                return calls == 1 and image or cover()
            end)
            G_reader_settings:saveSetting("screensaver_type", "cover")
            return image, stubbed
        end

        it("frees the image KOReader's own cover mode made and replaces it", function()
            local image, stubbed = koreaders_cover()
            Screensaver:setup()
            stubbed:revert()
            assert.equals(1, image.freed)
            assert.is_not.equals(image, Screensaver.image)
            assert.equals(math.min(Screen:getWidth(), Screen:getHeight()), Screensaver.image:getWidth())
        end)

        it("keeps the image KOReader's own cover mode made when the draw fails", function()
            local image, stubbed = koreaders_cover()
            local draw = stub(SleepScreen, "image", function(_, bitmap)
                bitmap:free()
                error("no")
            end)
            Screensaver:setup()
            draw:revert()
            stubbed:revert()
            assert.equals(0, image.freed)
            assert.equals(image, Screensaver.image)
        end)

        it("replaces the file KOReader's own art mode chose", function()
            G_reader_settings:saveSetting("screensaver_type", "random_image")
            Screensaver:setup()
            assert.is_nil(Screensaver.image_file)
            assert.equals("cover", Screensaver.screensaver_type)
        end)

        it("takes the image background, as KOReader's own cover mode does", function()
            local img = G_reader_settings:readSetting("screensaver_img_background")
            local msg = G_reader_settings:readSetting("screensaver_msg_background")
            G_reader_settings:saveSetting("screensaver_img_background", "black")
            G_reader_settings:saveSetting("screensaver_msg_background", "none")
            Screensaver:setup()
            G_reader_settings:saveSetting("screensaver_img_background", img)
            G_reader_settings:saveSetting("screensaver_msg_background", msg)
            assert.equals("black", Screensaver.screensaver_background)
        end)

        it("leaves KOReader's screen with sleep.on off", function()
            Settings.set("sleep.on", false)
            Screensaver:setup()
            kept_koreaders()
        end)

        it("leaves KOReader's screen for poweroff and reboot", function()
            Screensaver:setup("poweroff", "Powered off")
            kept_koreaders()
        end)

        it("leaves KOReader's screen with no last book", function()
            G_reader_settings:delSetting("lastfile")
            Screensaver:setup()
            kept_koreaders()
        end)

        it("leaves KOReader's screen when the last book has gone", function()
            G_reader_settings:saveSetting("lastfile", harness.library .. "/gone.epub")
            local err = spy.on(logger, "err")
            Screensaver:setup()
            assert.spy(err).was_not_called()
            err:revert()
            kept_koreaders()
        end)

        it("leaves KOReader's screen for an excluded book", function()
            local stubbed = stub(Screensaver, "isExcluded", function() return true end)
            Screensaver:setup()
            stubbed:revert()
            kept_koreaders()
        end)

        it("leaves KOReader's screen for a book with no cover", function()
            local stubbed = stub(fm.bookinfo, "getCoverImage", function() return nil end)
            local err = spy.on(logger, "err")
            Screensaver:setup()
            stubbed:revert()
            assert.spy(err).was_not_called()
            err:revert()
            kept_koreaders()
        end)

        it("logs a failed draw and leaves KOReader's screen", function()
            local image, err = stub(SleepScreen, "image", function() error("no") end), spy.on(logger, "err")
            Screensaver:setup()
            image:revert()
            assert.spy(err).was_called()
            err:revert()
            kept_koreaders()
        end)

        -- Sleeps with frankenstein open, after prepare(reader); check(reader, book) gets the book the card draws.
        local function sleep_in_book(prepare, check)
            fm:onClose()
            local reader = harness.open_reader("frankenstein.epub")
            local got
            local image = stub(SleepScreen, "image", function(b, bitmap)
                got = b
                bitmap:free()
                error("stop")
            end)
            prepare(reader)
            Screensaver:setup()
            image:revert()
            local ok, err = pcall(check, reader, got)
            reader:onClose()
            fm = harness.show_fm()
            if not ok then
                error(err, 0)
            end
        end

        it("reads the open book's title, page and chapter live", function()
            sleep_in_book(function(reader)
                reader:handleEvent(require("ui/event"):new("GotoPage", 10))
            end, function(reader, got)
                assert.equals(10 / reader.document:getPageCount(), got.percent)
                assert.equals(reader.toc:getTocTitleByPage(10), got.chapter)
                assert.equals(reader.doc_props.display_title, got.title)
            end)
        end)

        it("keeps the saved percent when the open book counts no pages", function()
            local pages
            sleep_in_book(function(reader)
                pages = stub(reader.document, "getPageCount", function() return 0 end)
            end, function(_, got)
                pages:revert()
                assert.equals(require("featured_book").for_file(book).percent, got.percent)
            end)
        end)

        it("works out the time left in the chapter from the reader's pace", function()
            local counted_screen_pages
            sleep_in_book(function(reader)
                reader.statistics = { avg_time = 30, settings = { is_enabled = true } }
                reader:handleEvent(require("ui/event"):new("GotoPage", 10))
                stub(reader.toc, "getTocTitleByPage", function() return "Letter 4" end)
                stub(reader.toc, "getChapterPagesLeft", function(_, _, screen_pages)
                    counted_screen_pages = screen_pages
                    return 4
                end)
            end, function(reader, got)
                reader.toc.getTocTitleByPage:revert()
                reader.toc.getChapterPagesLeft:revert()
                assert.equals(120, got.chapter_seconds)
                assert.is_true(counted_screen_pages)
            end)
        end)

        it("has no chapter time on a page with no chapter title", function()
            sleep_in_book(function(reader)
                reader.statistics = { avg_time = 30, settings = { is_enabled = true } }
                stub(reader.toc, "getTocTitleByPage", function() return "" end)
                stub(reader.toc, "getChapterPagesLeft", function() return 4 end)
            end, function(reader, got)
                reader.toc.getTocTitleByPage:revert()
                reader.toc.getChapterPagesLeft:revert()
                assert.is_nil(got.chapter)
                assert.is_nil(got.chapter_seconds)
            end)
        end)

        it("counts the book's pages left in its last chapter", function()
            sleep_in_book(function(reader)
                reader.statistics = { avg_time = 30, settings = { is_enabled = true } }
                stub(reader.toc, "getTocTitleByPage", function() return "Letter 4" end)
                stub(reader.toc, "getChapterPagesLeft", function() return nil end)
                stub(reader.document, "getTotalPagesLeft", function() return 3 end)
            end, function(reader, got)
                reader.toc.getTocTitleByPage:revert()
                reader.toc.getChapterPagesLeft:revert()
                reader.document.getTotalPagesLeft:revert()
                assert.equals(90, got.chapter_seconds)
            end)
        end)

        it("has no chapter time without a usable pace, or on the chapter's last page", function()
            local nan = 0 / 0
            for _, statistics in ipairs({
                { avg_time = nan, settings = { is_enabled = true } },
                { settings = { is_enabled = true } },
                { avg_time = 0, settings = { is_enabled = true } },
                { avg_time = -1, settings = { is_enabled = true } },
                { avg_time = math.huge, settings = { is_enabled = true } },
                { avg_time = 30, settings = { is_enabled = false } },
            }) do
                sleep_in_book(function(reader)
                    reader.statistics = statistics
                end, function(_, got)
                    assert.is_nil(got.chapter_seconds)
                end)
            end
            sleep_in_book(function(reader)
                reader.statistics = { avg_time = 30, settings = { is_enabled = true } }
                stub(reader.toc, "getChapterPagesLeft", function() return 0 end)
            end, function(reader, got)
                reader.toc.getChapterPagesLeft:revert()
                assert.is_nil(got.chapter_seconds)
            end)
        end)

        it("has no chapter time from the home", function()
            local got
            local image = stub(SleepScreen, "image", function(b, bitmap)
                got = b
                bitmap:free()
            end)
            Screensaver:setup()
            image:revert()
            assert.is_nil(got.chapter_seconds)
        end)

        describe("today and the battery", function()
            local QuickSettings, ReadingStats_, DeviceStats, real_insights, real_battery, real_totals

            -- The book the draw is handed from the home, with the home's ui holding statistics.
            local function drawn(statistics)
                local held = fm.statistics
                fm.statistics = statistics
                local got
                local image = stub(SleepScreen, "image", function(b, bitmap)
                    got = b
                    bitmap:free()
                end)
                Screensaver:setup()
                image:revert()
                fm.statistics = held
                return got
            end

            local function today_reads(seconds, pages, unflushed_seconds, unflushed_pages)
                return { getTodayBookStats = function() return seconds, pages end,
                    mem_read_time = unflushed_seconds, mem_read_pages = unflushed_pages }
            end

            before_each(function()
                QuickSettings, ReadingStats_ = require("quick_settings"), require("reading_stats")
                DeviceStats = require("device_stats")
                real_insights, real_battery = ReadingStats_.insights, QuickSettings.battery
                real_totals = DeviceStats.battery_totals
                ReadingStats_.insights = function() return { state = "empty" } end
            end)

            after_each(function()
                ReadingStats_.insights, QuickSettings.battery = real_insights, real_battery
                DeviceStats.battery_totals = real_totals
            end)

            it("words today's reading from Statistics", function()
                ReadingStats_.insights = function() return { state = "ok", days = { 1 }, hours = {} } end
                assert.equals("Today 35 pages · 40 min", drawn(today_reads(2400, 35)).today)
            end)

            it("counts the session Statistics hasn't flushed", function()
                ReadingStats_.insights = function() return { state = "ok", days = { 1 }, hours = {} } end
                assert.equals("Today 40 pages · 50 min", drawn(today_reads(2400, 35, 600, 5)).today)
            end)

            it("shows a first session of the day, with nothing flushed yet", function()
                ReadingStats_.insights = function() return { state = "ok", days = { 1 }, hours = {} } end
                assert.equals("Today 5 pages · 10 min", drawn(today_reads(0, 0, 600, 5)).today)
                assert.is_nil(drawn(today_reads(0, 0, 0, 0)).today)
            end)

            it("doesn't ask Statistics while the reading history has nothing", function()
                local asked = false
                local got = drawn({ getTodayBookStats = function() asked = true end })
                assert.is_false(asked)
                assert.is_nil(got.today)
            end)

            it("reads no today without Statistics, or when it raises", function()
                ReadingStats_.insights = function() return { state = "ok", days = { 1 }, hours = {} } end
                local err = spy.on(logger, "err")
                assert.is_nil(drawn(nil).today)
                assert.spy(err).was_not_called()
                local got = drawn({ getTodayBookStats = function() error("no database") end })
                assert.spy(err).was_called()
                err:revert()
                assert.is_nil(got.today)
            end)

            it("words the battery from its reads", function()
                QuickSettings.battery = function() return 74 end
                DeviceStats.battery_totals = function()
                    return { discharging = { percentage = 37, time = 3600 * 240 * 1000000 } }
                end
                local power = require("device"):getPowerDevice()
                local charging = stub(power, "isCharging", function() return false end)
                assert.equals("74% · about 20 days left", drawn().battery)
                charging:revert()
                charging = stub(power, "isCharging", function() return true end)
                assert.equals("74%", drawn().battery)
                charging:revert()
            end)

            it("takes a failed charging read as charging", function()
                QuickSettings.battery = function() return 74 end
                local charging = stub(require("device"):getPowerDevice(), "isCharging", function() error("no") end)
                assert.equals("74%", drawn().battery)
                charging:revert()
            end)

            it("draws with no battery when a battery read raises", function()
                QuickSettings.battery = function() return 74 end
                local charging = stub(require("device"):getPowerDevice(), "isCharging", function() return false end)
                local left = stub(DeviceStats, "time_left", function() error("no") end)
                local err = spy.on(logger, "err")
                local got = drawn()
                left:revert()
                charging:revert()
                assert.spy(err).was_called()
                err:revert()
                assert.is_table(got)
                assert.is_nil(got.battery)
            end)

            it("reads no battery with no percent", function()
                QuickSettings.battery = function() return nil end
                assert.is_nil(drawn().battery)
            end)
        end)

        it("draws the open book over lastfile", function()
            sleep_in_book(function()
                G_reader_settings:saveSetting("lastfile", harness.library .. "/the-time-machine.epub")
            end, function(reader, got)
                assert.equals(reader.document.file, got.file)
            end)
        end)
    end)
end)
