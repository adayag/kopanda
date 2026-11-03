-- The book status window: a record's sections drawn in order on the chrome (library_chrome.lua), an empty one left
-- out, a failed read leaving out only its own; the description paged by BookStatus.split and turned by swipes; the
-- back control re-showing the screen it was opened from at its view and page; the page read-only; and a build that
-- raises re-showing that screen. Books.progress, Books.details and the Statistics reads are stubbed per case, under a
-- library root that exists nowhere (spec/library_fixture.lua).
describe("the book status window", function()
    local harness = require("plugin_harness")
    local fixture = require("library_fixture")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local logger = require("logger")
    local Screen = require("device").screen
    local BookStatus, BookStatusScreen, Books, FeaturedCover, Home, Library, ReadingStats, Settings, Sheet

    local LONG = {}
    for i = 1, 30 do
        LONG[i] = ("Paragraph %d of a description long enough to run over several pages of the window, "
            .. "every one of them a few lines at the window's width."):format(i)
    end
    LONG = table.concat(LONG, "\n")

    local reads

    -- Books.progress, Books.details and the Statistics reads answer data's progress, details, history and rate
    -- (each default: none), every call counted in reads; a field set to a function raises with its message.
    local function install(data)
        data = data or {}
        reads = { progress = 0, details = 0, history = 0, rate = 0 }
        local function answer(name, value)
            reads[name] = reads[name] + 1
            if type(value) == "function" then
                return value()
            end
            return value
        end
        Books.progress = function()
            return answer("progress", data.progress) or { status = "new" }
        end
        Books.details = function()
            return answer("details", data.details) or {}
        end
        ReadingStats.book_history = function()
            return answer("history", data.history)
        end
        ReadingStats.seconds_per_page = function()
            local rate = answer("rate", data.rate)
            if rate then
                return rate[1], rate[2]
            end
        end
    end

    local function raising(message)
        return function()
            error(message)
        end
    end

    local function book(fields)
        local record = fixture.book("The Time Machine")
        record.authors = { "H. G. Wells" }
        record.subjects = { "Science fiction", "Time travel" }
        for k, v in pairs(fields or {}) do
            record[k] = v
        end
        return record
    end

    local FULL = {
        progress = { status = "reading", percent = 0.62, md5 = "m" },
        details = { pages = 412, description = "A tale of the year 802,701." },
        history = { seconds = 27600, days = 12, first = os.time{ year = 2026, month = 10, day = 3, hour = 9 },
            last = os.time{ year = 2026, month = 11, day = 1, hour = 20 } },
        rate = { 30, 412 },
    }

    local function with(fields)
        local out = {}
        for k, v in pairs(FULL) do
            out[k] = v
        end
        for k, v in pairs(fields) do
            out[k] = v
        end
        return out
    end

    before_each(function()
        harness.load()
        BookStatus = package.loaded["book_status"]
        BookStatusScreen = package.loaded["book_status_screen"]
        Books = package.loaded["books"]
        FeaturedCover = package.loaded["featured_cover"]
        Home = package.loaded["home"]
        Library = package.loaded["library"]
        ReadingStats = package.loaded["reading_stats"]
        Settings = package.loaded["settings"]
        Sheet = package.loaded["sheet"]
        -- The home's own reads walk the home folder: the fixture library, not the user's.
        G_reader_settings:saveSetting("home_dir", harness.library)
    end)

    after_each(function()
        fixture.restore()
        harness.teardown()
    end)

    -- A file manager with the home up.
    local function fm_up()
        local fm = harness.show_fm()
        harness.tick(2)
        return fm
    end

    -- The window shown over the file manager, made with the home up if there is none, for record (default: book())
    -- from opener (default: the home), painted.
    local function show(record, opener, page)
        local FileManager = package.loaded["apps/filemanager/filemanager"]
        local fm = FileManager and FileManager.instance or fm_up()
        local screen = fm.kopanda:showBookStatus{ record = record or book(), opener = opener or { screen = "home" },
            page = page }
        assert.is_not_nil(screen)
        harness.tick(2)
        assert.equals(screen, harness.top())
        return screen, fm
    end

    local function kinds(screen)
        local out = {}
        for i, part in ipairs(screen.drawn) do
            out[i] = part.kind
        end
        return out
    end

    local function texts(screen)
        return table.concat(fixture.texts(screen[1]), "\n")
    end

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    local function tap_at(rect)
        send(harness.gesture("tap", fixture.centre(rect)))
        harness.tick(2)
    end

    local function swipe(direction)
        local ges = harness.gesture("swipe", math.floor(Screen:getWidth() / 2), math.floor(Screen:getHeight() / 2))
        ges.direction = direction
        send(ges)
    end

    -- Spies on logger.err; returns a function telling whether a call carried text.
    local function errors()
        local errored = spy.on(logger, "err")
        return function(text)
            for _, call in ipairs(errored.calls) do
                for _, arg in ipairs(call.vals) do
                    if tostring(arg):find(text, 1, true) then
                        return true
                    end
                end
            end
            return false
        end, function()
            logger.err:revert()
        end
    end

    describe("the page", function()
        it("shows full-screen as BookStatusScreen.shown over the file manager, the home closed", function()
            install(FULL)
            local screen, fm = show()
            assert.equals("book_status", screen.screen)
            assert.is_true(screen.covers_fullscreen)
            assert.equals(screen, BookStatusScreen.shown)
            assert.is_nil(Home.shown)
            assert.equals(fm, harness.top(2))
        end)

        it("reads the progress, the details and the Statistics once per show, not on a page turn", function()
            install(with{ details = { pages = 412, description = LONG } })
            local screen = show()
            assert.same({ progress = 1, details = 1, history = 1, rate = 1 }, reads)
            screen:turn(1)
            assert.equals(2, screen.page)
            assert.same({ progress = 1, details = 1, history = 1, rate = 1 }, reads)
        end)

        it("is headed by the back control to the screen beneath, the book's title and Book details", function()
            install(FULL)
            for screen_name, label in pairs({ home = "Home", library = "Library", series = "Series",
                    authors = "Authors", subjects = "Subjects", search = "Search" }) do
                local screen = show(nil, { screen = screen_name, view = {}, page = 1 })
                assert.equals(label:lower(), fixture.text(screen.header.back_label):lower())
                assert.equals("book details", fixture.text(screen.header.title):lower())
                assert.equals("the time machine", fixture.text(screen.header.aside):lower())
            end
        end)

        it("draws the book, its progress, its history and its description in that order, top to bottom", function()
            install(FULL)
            for _, id in ipairs({ "diner", "editorial", "frosted" }) do
                assert.is_true(Settings.set("look", id))
                local screen = show()
                assert.same({ "cover", "book", "progress", "history", "description" }, kinds(screen), id)
                local drawn = screen.drawn
                assert.equals(drawn[1].rect.y, drawn[2].rect.y, id)
                assert.is_true(drawn[2].rect.x >= drawn[1].rect.x + drawn[1].rect.w, id)
                for i = 3, #drawn do
                    local above = drawn[i - 1].kind == "book" and math.max(drawn[1].rect.y + drawn[1].rect.h,
                        drawn[2].rect.y + drawn[2].rect.h) or drawn[i - 1].rect.y + drawn[i - 1].rect.h
                    assert.is_true(drawn[i].rect.y >= above, id .. " " .. drawn[i].kind)
                end
                local text = texts(screen)
                for _, wanted in ipairs({ "The Time Machine", "H. G. Wells", "412 pages", "62% · page 255 of 412",
                        "About 1 h 20 min left", "7 h 40 min over 12 days", "Started 3 Oct · Last read 1 Nov",
                        "A tale of the year 802,701." }) do
                    assert.truthy(text:lower():find(wanted:lower(), 1, true), id .. ": " .. wanted)
                end
            end
        end)

        it("draws the cover a third of the content's width, framed as the featured cover", function()
            install(FULL)
            local framed = FeaturedCover.framed
            local asked = {}
            FeaturedCover.framed = function(record, w, h, ctx, frame)
                asked[#asked + 1] = { record = record, w = w, h = h }
                return framed(record, w, h, ctx, frame)
            end
            local record = book()
            local screen = show(record)
            FeaturedCover.framed = framed
            assert.equals(1, #asked)
            assert.equals(record, asked[1].record)
            local side = Screen:scaleBySize(screen.ctx.look.shelf.list.side)
            assert.equals(math.floor((screen.dimen.w - 2 * side) / 3), asked[1].w)
            assert.equals(math.floor(asked[1].w * 3 / 2), asked[1].h)
        end)

        it("asks CoverBrowser for the cover at its box once after the first paint, and redraws on its arrival",
            function()
                install(FULL)
                local BookCovers = package.loaded["book_covers"]
                local asked = {}
                BookCovers.request = function(records, specs, on_arrival, alive)
                    asked[#asked + 1] = { records = records, specs = specs, on_arrival = on_arrival, alive = alive }
                end
                local framed = FeaturedCover.framed
                local covers = 0
                FeaturedCover.framed = function(...)
                    covers = covers + 1
                    return framed(...)
                end
                local record = book()
                local screen = show(record)
                screen:turn(1)
                screen:turn(-1)
                assert.equals(1, #asked)
                assert.same({ record }, asked[1].records)
                local side = Screen:scaleBySize(screen.ctx.look.shelf.list.side)
                local w = math.floor((screen.dimen.w - 2 * side) / 3)
                assert.same({ max_cover_w = w, max_cover_h = math.floor(w * 3 / 2) }, asked[1].specs)
                assert.is_true(asked[1].alive())
                local before = covers
                asked[1].on_arrival({ record })
                FeaturedCover.framed = framed
                assert.equals(before + 1, covers)
                assert.equals(1, screen.page)
                BookStatusScreen.close()
                assert.is_false(asked[1].alive())
            end)

        it("asks for the cover again when a rotation changes its box, and not when a rebuild keeps it", function()
            install(FULL)
            local BookCovers = package.loaded["book_covers"]
            local asked = {}
            BookCovers.request = function(_, specs)
                asked[#asked + 1] = specs
            end
            local function box(screen)
                local w = math.floor((screen.dimen.w - 2 * Screen:scaleBySize(screen.ctx.look.shelf.list.side)) / 3)
                return { max_cover_w = w, max_cover_h = math.floor(w * 3 / 2) }
            end
            harness.at_colorsoft(function()
                local screen = show()
                assert.equals(1, #asked)
                screen:go(screen:view(), 1)
                harness.tick(2)
                assert.equals(1, #asked)
                local portrait = box(screen)
                assert.same(portrait, asked[1])
                harness.at_screen(1680, 1264, function()
                    UIManager:setDirty(screen, "ui")
                    harness.tick(2)
                    assert.equals(1680, screen.dimen.w)
                    assert.equals(2, #asked)
                    assert.same(box(screen), asked[2])
                    assert.are_not.same(portrait, asked[2])
                    screen:go(screen:view(), 1)
                    harness.tick(2)
                    assert.equals(2, #asked)
                end)
            end)
        end)

        it("draws the series, the subjects as chips and the progress bar", function()
            install(FULL)
            local screen = show(book{ series = "Wells' Romances", series_index = 2 })
            local text = texts(screen)
            assert.truthy(text:find("Wells' Romances · #2", 1, true))
            assert.equals(2, #screen.chips)
            assert.equals("science fiction", fixture.text(screen.chips[1].widget):lower())
            assert.is_not_nil(screen.bar)
        end)

        it("leaves out the progress and history of a new book, and the description of one with none", function()
            install{ details = { pages = 412 } }
            assert.same({ "cover", "book" }, kinds(show()))
        end)

        it("leaves out the history and the time left with Statistics off", function()
            install(with{ history = false, rate = false })
            local screen = show()
            assert.same({ "cover", "book", "progress", "description" }, kinds(screen))
            assert.falsy(texts(screen):find("left", 1, true))
        end)

        it("opens with the rest when a read raises, the failure logged and only its own section left out",
            function()
                local logged, revert = errors()
                install(with{ details = raising("details broke on purpose") })
                local screen = show()
                assert.same({ "cover", "book", "progress", "history" }, kinds(screen))
                assert.falsy(texts(screen):find("412 pages", 1, true))
                assert.is_true(logged("details broke on purpose"))
                BookStatusScreen.close()

                install(with{ progress = raising("progress broke on purpose") })
                screen = show()
                assert.same({ "cover", "book", "description" }, kinds(screen))
                assert.is_true(logged("progress broke on purpose"))
                BookStatusScreen.close()

                install(with{ history = raising("history broke on purpose") })
                screen = show()
                assert.same({ "cover", "book", "progress", "description" }, kinds(screen))
                assert.is_true(logged("history broke on purpose"))
                revert()
            end)

        it("asks no Statistics read for a book with no md5", function()
            install(with{ progress = { status = "reading", percent = 0.5 } })
            show()
            assert.same({ progress = 1, details = 1, history = 0, rate = 0 }, reads)
        end)

        it("keeps the description's text and the pager on the screen, with empty strings and a book of no author",
            function()
                install(with{ details = { description = "" } })
                local screen = show(book{ authors = {}, subjects = {} })
                assert.same({ "cover", "book", "progress", "history" }, kinds(screen))
                assert.same({}, screen.chips)
                assert.equals(1, screen.pages)
            end)
    end)

    describe("the description's pages", function()
        it("turns pages by west and east swipes, the description full width from the top on page 2", function()
            install(with{ details = { pages = 412, description = LONG } })
            local screen = show()
            assert.is_true(screen.pages >= 3)
            local first_top = screen.drawn[#screen.drawn].rect.y
            swipe("west")
            assert.equals(2, screen.page)
            assert.same({ "description" }, kinds(screen))
            local part = screen.drawn[1]
            assert.is_true(part.rect.y < first_top)
            assert.equals(screen.header.rect.h + Screen:scaleBySize(screen.ctx.look.shelf.books.padding_top),
                part.rect.y)
            swipe("east")
            assert.equals(1, screen.page)
            swipe("east")
            assert.equals(1, screen.page)
        end)

        it("pages as BookStatus.split pages the text, every line once and every page above the pager", function()
            install(with{ details = { pages = 412, description = LONG } })
            local split = BookStatus.split
            local paged
            BookStatus.split = function(...)
                paged = split(...)
                return paged
            end
            local screen = show()
            BookStatus.split = split
            assert.equals(#paged, screen.pages)
            local seen = {}
            for page = 1, screen.pages do
                screen:go(screen:view(), page)
                local pager_top = screen.pager.prev.rect.y
                for _, part in ipairs(screen.description) do
                    assert.is_true(part.rect.y + part.rect.h <= pager_top, "page " .. page)
                    assert.equals(part.count, part.widget[1] and part.widget[1].lines_per_page
                        or part.widget.lines_per_page)
                    for line = part.first, part.first + part.count - 1 do
                        local key = part.paragraph .. ":" .. line
                        assert.is_nil(seen[key], key .. " shown twice")
                        seen[key] = true
                    end
                end
            end
            local lines = 0
            for _, page in ipairs(paged) do
                for _, part in ipairs(page) do
                    lines = lines + part.count
                end
            end
            local n = 0
            for _ in pairs(seen) do
                n = n + 1
            end
            assert.equals(lines, n)
        end)

        it("pages a very long description, and splits it once per show", function()
            install(with{ details = { description = string.rep(LONG .. "\n", 20) } })
            local split = BookStatus.split
            local calls = 0
            BookStatus.split = function(...)
                calls = calls + 1
                return split(...)
            end
            local screen = show()
            screen:turn(1)
            screen:turn(1)
            BookStatus.split = split
            assert.is_true(screen.pages > 20)
            assert.equals(3, screen.page)
            assert.equals(1, calls)
        end)

        it("splits the description again for another screen size or text size, every page above the pager",
            function()
                install(with{ details = { pages = 412, description = LONG } })
                local split = BookStatus.split
                local calls = 0
                BookStatus.split = function(...)
                    calls = calls + 1
                    return split(...)
                end
                local function fits(screen, label)
                    for page = 1, screen.pages do
                        screen:go(screen:view(), page)
                        local pager_top = screen.pager.prev.rect.y
                        for _, part in ipairs(screen.description) do
                            assert.is_true(part.rect.y + part.rect.h <= pager_top, label .. " page " .. page)
                        end
                    end
                end
                local ok, err = pcall(harness.at_colorsoft, function()
                    local screen = show()
                    assert.equals(1, calls)
                    fits(screen, "colorsoft")
                    assert.equals(1, calls)
                    harness.at_paperwhite(function()
                        screen:refresh()
                        assert.equals(2, calls)
                        fits(screen, "paperwhite")
                        assert.equals(2, calls)
                        assert.is_true(Settings.set("text_size", "extra_large"))
                        screen:refresh()
                        assert.equals(3, calls)
                        fits(screen, "paperwhite extra large")
                    end)
                    assert.same({ progress = 1, details = 1, history = 1, rate = 1 }, reads)
                end)
                BookStatus.split = split
                assert(ok, err)
            end)

        it("is one page without a description", function()
            install(with{ details = { pages = 412 } })
            local screen = show()
            assert.equals(1, screen.pages)
            swipe("west")
            assert.equals(1, screen.page)
        end)
    end)

    describe("back", function()
        it("shows the home again from the home", function()
            install(FULL)
            local screen = show(nil, { screen = "home" })
            tap_at(screen.header.back_rect)
            assert.is_nil(BookStatusScreen.shown)
            assert.is_not_nil(Home.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("shows the library again at the folder and page it was opened from", function()
            fixture.install({ [fixture.ROOT] = { books = fixture.books(40) } })
            install(FULL)
            local screen = show(nil, { screen = "library", view = fixture.ROOT, page = 2 })
            tap_at(screen.header.back_rect)
            assert.is_nil(BookStatusScreen.shown)
            assert.is_not_nil(Library.shown)
            assert.equals(fixture.ROOT, Library.shown.dir)
            assert.equals(2, Library.shown.page)
        end)

        it("shows the Series, Authors and Subjects windows again at their view and page, and the search with its "
            .. "query and start", function()
            install(FULL)
            local cases = {
                { "series", "series_screen", { kind = "series", name = "Sherlock" } },
                { "authors", "authors_screen", { kind = "author", name = "Ann" } },
                { "subjects", "subjects_screen", { kind = "subject", name = "Gothic" } },
                { "search", "search_screen", { query = "time" } },
            }
            for _, case in ipairs(cases) do
                local module = package.loaded[case[2]]
                local real = module.show
                local asked
                module.show = function(opts)
                    asked = opts
                end
                local from = { dir = fixture.ROOT, page = 3 }
                local screen = show(nil, { screen = case[1], view = case[3], page = 4, from = from })
                tap_at(screen.header.back_rect)
                module.show = real
                assert.is_not_nil(asked, case[1])
                assert.equals(4, asked.page, case[1])
                if case[1] == "search" then
                    assert.equals("time", asked.query)
                    assert.equals(from, asked.from)
                else
                    assert.equals(case[3], asked.view, case[1])
                end
                BookStatusScreen.close()
                Home.close()
            end
        end)
    end)

    describe("read-only", function()
        it("runs nothing on a tap on the cover, a chip, the bar or the description, and opens no sheet on a hold",
            function()
                install(with{ details = { pages = 412, description = LONG } })
                local screen = show()
                assert.is_nil(screen:action_at({ x = 1, y = 1 }))
                local targets = { screen.drawn[1].rect, screen.chips[1].rect, screen.drawn[3].rect,
                    screen.drawn[#screen.drawn].rect }
                for _, rect in ipairs(targets) do
                    local x, y = fixture.centre(rect)
                    assert.is_nil(screen:action_at({ x = x, y = y }))
                    tap_at(rect)
                    assert.equals(screen, BookStatusScreen.shown)
                    assert.equals(1, screen.page)
                    send(harness.gesture("hold", x, y))
                    harness.tick(2)
                    assert.is_nil(Sheet.shown)
                    assert.equals(screen, harness.top())
                end
            end)
    end)

    describe("a build that raises", function()
        it("is logged, leaves no window up and shows the screen it was opened from again", function()
            install(FULL)
            local logged, revert = errors()
            fm_up()
            local fm = package.loaded["apps/filemanager/filemanager"].instance
            local split = BookStatus.split
            BookStatus.split = raising("split broke on purpose")
            local screen = fm.kopanda:showBookStatus{ record = book(), opener = { screen = "home" } }
            BookStatus.split = split
            revert()
            harness.tick(2)
            assert.is_nil(screen)
            assert.is_nil(BookStatusScreen.shown)
            assert.is_true(logged("split broke on purpose"))
            assert.is_not_nil(Home.shown)
            assert.equals(Home.shown, harness.top())
        end)

        it("frees the cover it drew before the failure", function()
            install(FULL)
            fm_up()
            local fm = package.loaded["apps/filemanager/filemanager"].instance
            local framed, split = FeaturedCover.framed, BookStatus.split
            local freed = 0
            FeaturedCover.framed = function(...)
                local cover = framed(...)
                local free = cover.free
                cover.free = function(widget, ...)
                    freed = freed + 1
                    return free(widget, ...)
                end
                return cover
            end
            BookStatus.split = raising("split broke on purpose")
            local screen = fm.kopanda:showBookStatus{ record = book(), opener = { screen = "home" } }
            FeaturedCover.framed, BookStatus.split = framed, split
            assert.is_nil(screen)
            assert.equals(1, freed)
        end)

        it("shows the library again when it was opened from there", function()
            fixture.install({ [fixture.ROOT] = { books = fixture.books(40) } })
            install(FULL)
            fm_up()
            local fm = package.loaded["apps/filemanager/filemanager"].instance
            local split = BookStatus.split
            BookStatus.split = raising("split broke on purpose")
            local screen = fm.kopanda:showBookStatus{ record = book(),
                opener = { screen = "library", view = fixture.ROOT, page = 2 } }
            BookStatus.split = split
            assert.is_nil(screen)
            assert.is_not_nil(Library.shown)
            assert.equals(2, Library.shown.page)
        end)
    end)

    describe("at the device sizes", function()
        it("fits page 1 above the pager on the Colorsoft and the Paperwhite at every text size", function()
            install(with{ details = { pages = 412, description = LONG } })
            for _, at in ipairs({ harness.at_colorsoft, harness.at_paperwhite }) do
                at(function()
                    for _, size in ipairs({ "small", "medium", "large", "extra_large" }) do
                        assert.is_true(Settings.set("text_size", size))
                        local screen = show()
                        local pager_top = screen.pager.prev.rect.y
                        for _, part in ipairs(screen.drawn) do
                            assert.is_true(part.rect.y + part.rect.h <= pager_top, size .. " " .. part.kind)
                        end
                    end
                end)
            end
        end)
    end)
end)
