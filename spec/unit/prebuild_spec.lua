-- Closing a book builds the home before the file browser comes back, and the file manager's
-- show puts that pre-built home up at once. Before it builds, the close records the book's
-- chapter for the featured book (C3).
describe("the KoPanda home pre-built on book close", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local Home, Plugin, new_spy

    -- The home's constructor: Home:new{} resolves Widget:new through Home's metatable, so the
    -- spy sits on Home itself and sees every build.
    local function spy_builds()
        new_spy = spy.on(Home, "new")
        return new_spy
    end

    before_each(function()
        Plugin = harness.load()
        Home = require("home")
    end)

    after_each(function()
        if new_spy then
            new_spy:revert()
            new_spy = nil
        end
        harness.teardown()
    end)

    it("builds a home on CloseDocument and keeps it pending, not shown", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        assert.is_not_nil(Home.pending)
        assert.equals("kopanda_home", Home.pending.name)
        assert.is_false(UIManager:isWidgetShown(Home.pending))
        assert.is_nil(Home.shown)
    end)

    it("puts the pending home on top synchronously from the file manager's show", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        local pending = Home.pending
        local builds = spy_builds()
        local fm = harness.show_fm()
        assert.equals(pending, harness.top())
        assert.equals(fm, harness.top(2))
        assert.equals(pending, Home.shown)
        assert.is_nil(Home.pending)
        harness.tick(2)
        assert.equals(pending, harness.top())
        assert.equals(pending, Home.shown)
        assert.spy(builds).was_not_called()
    end)

    it("signals a pre-built home's paint as prebuilt", function()
        local signals = {}
        local listener = function(args)
            signals[#signals + 1] = args
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        harness.show_fm()
        harness.tick(4)
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        assert.equals(1, #signals)
        assert.equals("home", signals[1].screen)
        assert.is_true(signals[1].prebuilt)
        assert.is_number(signals[1].paint_ms)
    end)

    -- The settled signal lands a tick after the paint, behind tasks already due then, such as
    -- coverbrowser's background extraction (covermenu.lua:119), queued before the show. With the
    -- close run from a task, as the end-of-book action runs it (readerstatus.lua:144-148), that
    -- task runs after the paint and before the signal. paint_ms stops at the paint, and cpu_ms,
    -- on the CPU clock, with it.
    it("times a pre-built home to its paint, not to the settled signal", function()
        local time = require("ui/time")
        local monotonic = time.monotonic
        local clock = monotonic()
        time.monotonic = function()
            return clock
        end
        local signals = {}
        local listener = function(args)
            signals[#signals + 1] = args
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
        local ok, err = pcall(harness.with_cpu_clock, 20, function(cpu)
            local reader = harness.open_reader()
            harness.tick(2)
            UIManager:nextTick(function()
                reader:onClose()
                local frame = Home.pending[1]
                local frame_paint = frame.paintTo
                frame.paintTo = function(...)
                    clock = clock + time.ms(5)
                    cpu.now = cpu.now + 0.003
                    return frame_paint(...)
                end
                UIManager:nextTick(function()
                    clock = clock + time.ms(300)
                    cpu.now = cpu.now + 0.3
                end)
                harness.show_fm()
            end)
            harness.tick(4)
        end)
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        time.monotonic = monotonic
        assert(ok, err)
        assert.equals(1, #signals)
        assert.equals(5, signals[1].paint_ms)
        assert.equals(3, signals[1].cpu_ms)
        assert.equals(305, signals[1].settle_ms)
    end)

    it("times a pending home that the deferred show finds", function()
        local signals = {}
        local listener = function(args)
            signals[#signals + 1] = args
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
        harness.show_fm()
        Home.prebuild()
        local pending = Home.pending
        harness.tick(4)
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        assert.equals(pending, harness.top())
        assert.equals(1, #signals)
        assert.is_true(signals[1].prebuilt)
        assert.is_number(signals[1].paint_ms)
    end)

    it("drops a pending home of another size and shows a fresh one", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        local pending = Home.pending
        local size = Screen:getSize()
        pending.dimen = Geom:new{ x = 0, y = 0, w = size.h, h = size.w }
        local freed = spy.on(pending, "free")
        harness.show_fm()
        harness.tick(2)
        local home = harness.top()
        assert.equals("kopanda_home", home.name)
        assert.is_not.equals(pending, home)
        assert.equals(home, Home.shown)
        assert.same(size, home.dimen)
        assert.is_false(UIManager:isWidgetShown(pending))
        assert.is_nil(Home.pending)
        assert.spy(freed).was_called()
    end)

    it("drops the pending home when a new reader starts (switch, reload)", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        local pending = Home.pending
        assert.is_not_nil(pending)
        local freed = spy.on(pending, "free")
        harness.open_reader("the-time-machine.epub")
        assert.is_nil(Home.pending)
        assert.spy(freed).was_called()
    end)

    describe("recording the chapter", function()
        local logger = require("logger")
        local State, order, real_set, real_prebuild
        local file = "/mnt/us/books/frankenstein.epub"

        -- A reader's KoPanda over a stub ui reading book (default: file) whose TOC answers with
        -- toc_title (a function to call, or a string to return).
        local function reader_kopanda(toc_title, book)
            return Plugin:new{
                ui = {
                    document = { file = book or file },
                    toc = {
                        getTocTitleOfCurrentPage = function()
                            if type(toc_title) == "function" then
                                return toc_title()
                            end
                            return toc_title
                        end,
                    },
                    menu = { registerToMainMenu = function() end },
                },
            }
        end

        before_each(function()
            State = package.loaded["state"]
            order = {}
            real_set, real_prebuild = State.set, Home.prebuild
            State.set = function(key, value)
                order[#order + 1] = "set " .. key
                return real_set(key, value)
            end
            Home.prebuild = function()
                order[#order + 1] = "prebuild"
            end
        end)

        after_each(function()
            State.set, Home.prebuild = real_set, real_prebuild
        end)

        it("writes the file and the TOC title to the state before it pre-builds", function()
            reader_kopanda("Letter IV"):onCloseDocument()
            assert.same({ "set featured_chapter_file", "set featured_chapter", "prebuild" }, order)
            assert.equals(file, State.get("featured_chapter_file"))
            assert.equals("Letter IV", State.get("featured_chapter"))
        end)

        it("records a TOC with no title for the page as an empty chapter", function()
            reader_kopanda(nil):onCloseDocument()
            assert.equals(file, State.get("featured_chapter_file"))
            assert.equals("", State.get("featured_chapter"))
        end)

        it("still records with a home already pending, which it doesn't rebuild", function()
            local kopanda = reader_kopanda("Letter IV")
            Home.pending = {}
            kopanda:onCloseDocument()
            Home.pending = nil
            assert.same({ "set featured_chapter_file", "set featured_chapter" }, order)
        end)

        -- C3: a raising lookup on a re-close leaves no chapter, not the one recorded before.
        it("clears the chapter of a re-closed book whose TOC raises, logs it and pre-builds", function()
            local FeaturedBook = package.loaded["featured_book"]
            local saved_history = package.loaded["readhistory"]
            local real = harness.library .. "/frankenstein.epub"
            package.loaded["readhistory"] = { hist = { { file = real, select_enabled = true } } }
            reader_kopanda("Letter IV", real):onCloseDocument()
            assert.equals("Letter IV", State.get("featured_chapter"))
            order = {}
            local errored = spy.on(logger, "err")
            reader_kopanda(function()
                error("toc broke on purpose")
            end, real):onCloseDocument()
            logger.err:revert()
            local featured = FeaturedBook.current()
            package.loaded["readhistory"] = saved_history
            assert.equals(real, State.get("featured_chapter_file"))
            assert.equals("", State.get("featured_chapter"))
            assert.equals(real, featured.file)
            assert.is_nil(featured.chapter)
            assert.spy(errored).was_called()
            assert.equals("prebuild", order[#order])
        end)

        it("clears the chapter when the file's write fails, logs it and pre-builds", function()
            reader_kopanda("Letter IV"):onCloseDocument()
            order = {}
            local errored = spy.on(logger, "err")
            local logged_set = State.set
            State.set = function(key, value)
                if key == "featured_chapter_file" then
                    order[#order + 1] = "set " .. key
                    return false
                end
                return logged_set(key, value)
            end
            reader_kopanda("Letter V"):onCloseDocument()
            State.set = logged_set
            logger.err:revert()
            assert.equals("", State.get("featured_chapter"))
            assert.spy(errored).was_called()
            assert.equals("prebuild", order[#order])
        end)

        it("writes nothing with no document, and still pre-builds", function()
            local kopanda = reader_kopanda("Letter IV")
            kopanda.ui.document = nil
            kopanda:onCloseDocument()
            assert.same({ "prebuild" }, order)
            assert.is_nil(State.get("featured_chapter_file"))
        end)

        it("records a real reader's book on its close", function()
            Home.prebuild = real_prebuild
            local reader = harness.open_reader()
            harness.tick(2)
            reader:onClose()
            assert.equals(harness.library .. "/frankenstein.epub", State.get("featured_chapter_file"))
            assert.is_string(State.get("featured_chapter"))
            assert.is_not_nil(Home.pending)
        end)
    end)

    it("builds nothing more on a second CloseDocument while a home is pending", function()
        local reader = harness.open_reader()
        harness.tick(2)
        local builds = spy_builds()
        -- KoPanda's handler returns nothing, so CloseDocument goes on to later modules.
        local consumed = reader.kopanda:handleEvent(Event:new("CloseDocument"))
        assert.is_falsy(consumed)
        local pending = Home.pending
        assert.is_not_nil(pending)
        reader:onClose()
        assert.equals(pending, Home.pending)
        assert.spy(builds).was_called(1)
    end)
end)
