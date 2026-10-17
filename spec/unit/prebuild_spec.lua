-- Closing a book builds no home: it records the book's chapter for the featured book (C3) and
-- marks the close, and the file manager's Show that follows builds the home and puts it up at
-- once, after the reader saved its sidecar and Statistics flushed its session. A close with the
-- reader tearing down (reload, switch) marks nothing.
describe("closing a book shows the home at the file manager's Show", function()
    local harness = require("plugin_harness")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
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

    it("builds no home on CloseDocument and marks the close", function()
        local reader = harness.open_reader()
        harness.tick(2)
        local builds = spy_builds()
        reader:onClose()
        assert.spy(builds).was_not_called()
        assert.is_true(Home.just_closed)
        assert.is_nil(Home.shown)
    end)

    it("puts a home on top synchronously from the file manager's Show after the close", function()
        local reader = harness.open_reader()
        harness.tick(2)
        reader:onClose()
        local builds = spy_builds()
        local fm = harness.show_fm()
        local home = harness.top()
        assert.equals("kopanda_home", home.name)
        assert.equals(fm, harness.top(2))
        assert.equals(home, Home.shown)
        assert.spy(builds).was_called(1)
        assert.is_false(Home.just_closed)
        harness.tick(2)
        assert.equals(home, harness.top())
        assert.equals(home, Home.shown)
        assert.spy(builds).was_called(1)
    end)

    it("reads the reading stats once across a close and the Show after it", function()
        local Settings = package.loaded["settings"]
        local ReadingStats = package.loaded["reading_stats"]
        assert.is_true(Settings.set("layout.rows", { { { widget = "stats", share = 1 } } }))
        local reader = harness.open_reader()
        harness.tick(2)
        local reads = spy.on(ReadingStats, "read")
        local ok, err = pcall(function()
            reader:onClose()
            harness.show_fm()
            harness.tick(2)
        end)
        reads:revert()
        assert(ok, err)
        assert.equals("kopanda_home", harness.top().name)
        assert.spy(reads).was_called(1)
    end)

    -- reloadDocument and switchDocument set tearing_down before onClose
    -- (frontend/apps/reader/readerui.lua:952, :973), as onShowingReader and onSetupShowReader do
    -- (:600, :609), and close with onClose(false).
    it("marks nothing on a close with the reader tearing down, so a later Show defers", function()
        local reader = harness.open_reader()
        harness.tick(2)
        local builds = spy_builds()
        reader.tearing_down = true
        reader:onClose(false)
        assert.is_false(Home.just_closed)
        assert.spy(builds).was_not_called()
        local fm = harness.show_fm()
        assert.equals(fm, harness.top())
        harness.tick(1)
        assert.equals("kopanda_home", harness.top().name)
    end)

    it("clears the mark when a new reader starts (switch, reload)", function()
        Home.just_closed = true
        harness.open_reader()
        assert.is_false(Home.just_closed)
    end)

    it("builds nothing on a second CloseDocument while the close is marked", function()
        local reader = harness.open_reader()
        harness.tick(2)
        local builds = spy_builds()
        -- KoPanda's handler returns nothing, so CloseDocument goes on to later modules.
        local consumed = reader.kopanda:handleEvent(Event:new("CloseDocument"))
        assert.is_falsy(consumed)
        assert.is_true(Home.just_closed)
        reader:onClose()
        assert.is_true(Home.just_closed)
        assert.spy(builds).was_not_called()
    end)

    -- The reader's sidecar is saved after CloseDocument, by UIManager:close's FlushSettings
    -- (frontend/apps/reader/readerui.lua:887, :893; frontend/ui/uimanager.lua:298), so a home
    -- built at CloseDocument would show the percent of the last save before it.
    it("shows the featured percent the reader saved on its close", function()
        local Settings = package.loaded["settings"]
        local FeaturedBook = package.loaded["featured_book"]
        local DocSettings = require("docsettings")
        local book = harness.library .. "/frankenstein.epub"
        assert.is_true(Settings.set("layout.rows", { { { widget = "featured", share = 1 } } }))
        assert.is_true(Settings.set("featured.pinned", book))
        local reader = harness.open_reader()
        harness.tick(2)
        local before = DocSettings:open(book):readSetting("percent_finished")
        reader:handleEvent(Event:new("GotoPercent", 50))
        local current = FeaturedBook.current
        local shown = {}
        FeaturedBook.current = function(...)
            local featured = current(...)
            shown[#shown + 1] = featured
            return featured
        end
        local ok, err = pcall(function()
            reader:onClose()
            harness.show_fm()
        end)
        FeaturedBook.current = current
        assert(ok, err)
        local saved = DocSettings:open(book):readSetting("percent_finished")
        assert.is_number(saved)
        assert.is_not.equals(before, saved)
        assert.equals("kopanda_home", harness.top().name)
        assert.equals(1, #shown)
        assert.equals(book, shown[1].file)
        assert.equals(saved, shown[1].percent)
    end)

    -- The settled signal lands a tick after the paint, behind tasks already due then, such as
    -- coverbrowser's background extraction (covermenu.lua:119), queued before the show. With the
    -- close run from a task, as the end-of-book action runs it (readerstatus.lua:144-148), that
    -- task runs after the paint and before the signal. paint_ms stops at the paint, and cpu_ms,
    -- on the CPU clock, with it.
    it("times the home shown after a close to its paint, not to the settled signal", function()
        local InputContainer = require("ui/widget/container/inputcontainer")
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
        local inherited_paint = InputContainer.paintTo
        local ok, err = pcall(harness.with_cpu_clock, 20, function(cpu)
            local reader = harness.open_reader()
            harness.tick(2)
            InputContainer.paintTo = function(self, ...)
                if self.name == "kopanda_home" then
                    clock = clock + time.ms(5)
                    cpu.now = cpu.now + 0.003
                end
                return inherited_paint(self, ...)
            end
            UIManager:nextTick(function()
                reader:onClose()
                UIManager:nextTick(function()
                    clock = clock + time.ms(300)
                    cpu.now = cpu.now + 0.3
                end)
                harness.show_fm()
            end)
            harness.tick(4)
        end)
        InputContainer.paintTo = inherited_paint
        UIManager.event_hook:unregister("KoPandaSettled", listener)
        time.monotonic = monotonic
        assert(ok, err)
        assert.equals(1, #signals)
        assert.equals(5, signals[1].paint_ms)
        assert.equals(3, signals[1].cpu_ms)
        assert.equals(305, signals[1].settle_ms)
    end)

    describe("recording the chapter", function()
        local logger = require("logger")
        local State, order, real_set, real_set_many
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
            real_set, real_set_many = State.set, State.set_many
            State.set = function(key, value)
                order[#order + 1] = "set " .. key
                return real_set(key, value)
            end
            State.set_many = function(values)
                local keys = {}
                for key in pairs(values) do
                    keys[#keys + 1] = key
                end
                table.sort(keys)
                order[#order + 1] = "set " .. table.concat(keys, " ")
                return real_set_many(values)
            end
        end)

        after_each(function()
            State.set, State.set_many = real_set, real_set_many
        end)

        -- One flush for both keys, and none when the book closes again on the same chapter:
        -- each flush is an fsync on the way from the book to the home.
        it("writes the file and the TOC title in one write and marks the close, and writes none again unchanged",
        function()
            local util = require("util")
            local write = util.writeToFile
            local writes = 0
            util.writeToFile = function(...)
                writes = writes + 1
                return write(...)
            end
            finally(function()
                util.writeToFile = write
            end)
            reader_kopanda("Letter IV"):onCloseDocument()
            assert.equals(1, writes)
            assert.same({ "set featured_chapter featured_chapter_file" }, order)
            assert.equals(file, State.get("featured_chapter_file"))
            assert.equals("Letter IV", State.get("featured_chapter"))
            assert.is_true(Home.just_closed)
            writes, order = 0, {}
            Home.just_closed = false
            reader_kopanda("Letter IV"):onCloseDocument()
            assert.equals(0, writes)
            assert.same({}, order)
            assert.equals("Letter IV", State.get("featured_chapter"))
            assert.is_true(Home.just_closed)
        end)

        it("records the chapter but marks no close with the reader tearing down", function()
            local kopanda = reader_kopanda("Letter IV")
            kopanda.ui.tearing_down = true
            kopanda:onCloseDocument()
            assert.same({ "set featured_chapter featured_chapter_file" }, order)
            assert.equals("Letter IV", State.get("featured_chapter"))
            assert.is_false(Home.just_closed)
        end)

        it("records a TOC with no title for the page as an empty chapter", function()
            reader_kopanda(nil):onCloseDocument()
            assert.equals(file, State.get("featured_chapter_file"))
            assert.equals("", State.get("featured_chapter"))
        end)

        it("still records with the close already marked", function()
            local kopanda = reader_kopanda("Letter IV")
            Home.just_closed = true
            kopanda:onCloseDocument()
            assert.same({ "set featured_chapter featured_chapter_file" }, order)
            assert.is_true(Home.just_closed)
        end)

        -- C3: a raising lookup on a re-close leaves no chapter, not the one recorded before.
        it("clears the chapter of a re-closed book whose TOC raises, logs it and marks the close", function()
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
            assert.is_true(Home.just_closed)
        end)

        it("clears the chapter when the write fails, logs it and marks the close", function()
            reader_kopanda("Letter IV"):onCloseDocument()
            order = {}
            local errored = spy.on(logger, "err")
            local logged_set_many = State.set_many
            State.set_many = function()
                order[#order + 1] = "set_many"
                return false
            end
            reader_kopanda("Letter V"):onCloseDocument()
            State.set_many = logged_set_many
            logger.err:revert()
            assert.equals("", State.get("featured_chapter"))
            assert.spy(errored).was_called()
            assert.is_true(Home.just_closed)
        end)

        -- B-e2tfz0: a failed write leaves the state's in-memory copy ahead of the disk (write
        -- saves each key before its flush), so the retry can't compare against that copy. The
        -- failure here is a write that can't open the file: util.writeToFile, which
        -- LuaSettings:flush calls (frontend/luasettings.lua:270-275), writes nothing, and State's
        -- read-back catches it. (A full disk would truncate the file instead; see B-e2tfz0.)
        -- The failed close's clearing write leaves "" in that copy, so a retry at a page with no
        -- TOC title is the one the old skip missed; a titled chapter is the other case.
        for _, failed in ipairs({ "", "Letter V" }) do
            local at = failed == "" and "a page with no TOC title" or failed
            it("writes again on the next close at " .. at .. " after a failed write there", function()
                local util = require("util")
                local write = util.writeToFile
                reader_kopanda("Letter IV"):onCloseDocument()
                order = {}
                local errored = spy.on(logger, "err")
                util.writeToFile = function()
                    return nil, "no space left on device"
                end
                finally(function()
                    util.writeToFile = write
                    logger.err:revert()
                end)
                reader_kopanda(failed):onCloseDocument()
                util.writeToFile = write
                assert.same({ "set featured_chapter featured_chapter_file", "set featured_chapter" }, order)
                -- Both writes failed, the clearing one too, so the file still holds the chapter
                -- of the last successful write.
                assert.equals("Letter IV", dofile(harness.state_file).featured_chapter)
                assert.spy(errored).was_called()
                order = {}
                reader_kopanda(failed):onCloseDocument()
                assert.same({ "set featured_chapter featured_chapter_file" }, order)
                assert.equals(file, dofile(harness.state_file).featured_chapter_file)
                assert.equals(failed, dofile(harness.state_file).featured_chapter)
                order = {}
                reader_kopanda(failed):onCloseDocument()
                assert.same({}, order)
            end)
        end

        -- B-25sffy: another key's failed write leaves the disk behind State's in-memory copy too.
        -- util.writeToFile opens the file "wb" before writing (frontend/util.lua:1130), so a full
        -- disk truncates it: the chapter is gone from the file but still in that copy. The next
        -- close at the same chapter must write it again.
        it("writes again on the next close at the same chapter after another key's failed write", function()
            local util = require("util")
            local write = util.writeToFile
            reader_kopanda("Letter IV"):onCloseDocument()
            assert.equals("Letter IV", dofile(harness.state_file).featured_chapter)
            local errored = spy.on(logger, "err")
            util.writeToFile = function(_, filepath)
                local truncated = assert(io.open(filepath, "wb"))
                truncated:close()
                return nil, "no space left on device"
            end
            finally(function()
                util.writeToFile = write
                logger.err:revert()
            end)
            assert.is_false(State.set("x", 1))
            util.writeToFile = write
            assert.is_nil(dofile(harness.state_file))
            -- the in-memory copy still holds the chapter: it has run ahead of the disk
            assert.equals("Letter IV", State.get("featured_chapter"))
            assert.spy(errored).was_called()
            local writes = 0
            util.writeToFile = function(...)
                writes = writes + 1
                return write(...)
            end
            order = {}
            reader_kopanda("Letter IV"):onCloseDocument()
            assert.same({ "set featured_chapter featured_chapter_file" }, order)
            assert.equals(1, writes)
            assert.equals(file, dofile(harness.state_file).featured_chapter_file)
            assert.equals("Letter IV", dofile(harness.state_file).featured_chapter)
            order = {}
            reader_kopanda("Letter IV"):onCloseDocument()
            assert.same({}, order)
        end)

        it("writes nothing with no document, and still marks the close", function()
            local kopanda = reader_kopanda("Letter IV")
            kopanda.ui.document = nil
            kopanda:onCloseDocument()
            assert.same({}, order)
            assert.is_nil(State.get("featured_chapter_file"))
            assert.is_true(Home.just_closed)
        end)

        it("records a real reader's book on its close", function()
            local reader = harness.open_reader()
            harness.tick(2)
            reader:onClose()
            assert.equals(harness.library .. "/frankenstein.epub", State.get("featured_chapter_file"))
            assert.is_string(State.get("featured_chapter"))
            assert.is_true(Home.just_closed)
        end)
    end)
end)
