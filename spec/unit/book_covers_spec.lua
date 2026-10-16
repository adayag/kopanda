-- The cover reads and the batched extraction (book-model C6): a usable cached bitmap returned and an
-- unusable one freed; one extractInBackground per request for every wanted file with the specs
-- given, never for a file already asked, a path-less record or a cover that fits; a check once a
-- second while extraction runs, at most 30, each calling on_arrival once with exactly the records
-- that arrived; the last check's cover read; alive(), cancel, a replacing request and a failed
-- fork. bookinfomanager is stubbed in package.loaded, since this file sorts before
-- books_coverbrowser_spec.lua, which loads the real one; UIManager's scheduleIn and unschedule
-- record their calls; each case restores them in finally.
describe("BookCovers", function()
    require("plugin_harness")
    local UIManager = require("ui/uimanager")
    local BookCovers = require("book_covers")
    local logger = require("logger")

    local SPECS = { max_cover_w = 150, max_cover_h = 225 }
    local A, B, C = "/books/a.epub", "/books/b.epub", "/books/c.epub"

    -- A row with a cover that fits SPECS, with bitmap bb.
    local function usable(bb)
        return {
            has_cover = "Y", cover_fetched = "Y", cover_w = 150, cover_h = 225,
            cover_sizetag = "300x450", cover_bb = bb,
        }
    end

    -- A bitmap stub that counts its frees in counter[1].
    local function bitmap(counter)
        return { free = function() counter[1] = counter[1] + 1 end }
    end

    -- A bookinfomanager stub. opts.info(file, get_cover) gives getBookInfo's result; extracting
    -- is a list of isExtractingInBackground's answers, its last repeated. isCachedCoverInvalid is
    -- the real one's rule (bookinfomanager.lua:1013-1030): true for a row with no cover_w, and true
    -- when the thumbnail is smaller than the box both ways.
    local function manager(opts)
        local m = { extracted = {}, extracting_calls = 0, reads = {} }
        function m:getBookInfo(file, get_cover)
            m.reads[#m.reads + 1] = { file = file, get_cover = get_cover }
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

    -- Installs bim as bookinfomanager (false: unrequirable), a recording scheduler and a recording
    -- logger.err, and restores them and the module's state in finally. Returns the queue of
    -- scheduled { secs, fn } and the logged calls.
    local function stub(bim)
        local loaded, preload = package.loaded.bookinfomanager, package.preload.bookinfomanager
        local schedule_in, unschedule = UIManager.scheduleIn, UIManager.unschedule
        local err = logger.err
        local queue = { unscheduled = 0 }
        local logged = {}
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
        logger.err = function(...)
            logged[#logged + 1] = table.concat((function(...)
                local parts = {}
                for i = 1, select("#", ...) do
                    parts[i] = tostring((select(i, ...)))
                end
                return parts
            end)(...), " ")
        end
        BookCovers.reset()
        finally(function()
            BookCovers.reset()
            package.loaded.bookinfomanager = loaded
            package.preload.bookinfomanager = preload
            UIManager.scheduleIn, UIManager.unschedule = schedule_in, unschedule
            logger.err = err
        end)
        return queue, logged
    end

    local function was_logged(logged, text)
        for _, line in ipairs(logged) do
            if line:find(text, 1, true) then
                return true
            end
        end
        return false
    end

    -- Runs the first queued task, as UIManager would when it comes due.
    local function run_next(queue)
        local task = table.remove(queue, 1)
        task.fn()
        return task
    end

    -- An on_arrival that records each call's records' paths, with the check it came in, in calls.
    local function recorder()
        local calls = {}
        local check = 0
        local function on_arrival(records)
            local paths = {}
            for i, record in ipairs(records) do
                paths[i] = record.path
            end
            calls[#calls + 1] = { check = check, paths = paths }
        end
        local function next_check()
            check = check + 1
        end
        return calls, on_arrival, next_check
    end

    local function always()
        return true
    end

    local function files(...)
        local list = {}
        for i, path in ipairs({ ... }) do
            list[i] = { filepath = path, cover_specs = SPECS }
        end
        return list
    end

    describe("read", function()
        it("gives a usable cached bitmap, read with its cover, and asks nothing", function()
            local bb = bitmap({ 0 })
            local bim = manager{ info = function(_, get_cover) return usable(get_cover and bb or nil) end }
            stub(bim)
            assert.equals(bb, BookCovers.read({ path = A }, 150, 225))
            assert.same({ { file = A, get_cover = true } }, bim.reads)
            assert.equals(0, #bim.extracted)
        end)

        it("frees a bitmap too small for the box and gives nil", function()
            local freed = { 0 }
            local bim = manager{ info = function()
                return { has_cover = "Y", cover_fetched = "Y", cover_w = 50, cover_h = 75, cover_bb = bitmap(freed) }
            end }
            stub(bim)
            assert.is_nil(BookCovers.read({ path = A }, 150, 225))
            assert.equals(1, freed[1])
        end)

        it("frees an ignored cover's bitmap and gives nil", function()
            local freed = { 0 }
            local bim = manager{ info = function()
                local info = usable(bitmap(freed))
                info.ignore_cover = "Y"
                return info
            end }
            stub(bim)
            assert.is_nil(BookCovers.read({ path = A }, 150, 225))
            assert.equals(1, freed[1])
        end)

        it("gives nil for a row with a cover but no bitmap, or no row", function()
            local rows = { [A] = usable(nil) }
            stub(manager{ info = function(file) return rows[file] end })
            assert.is_nil(BookCovers.read({ path = A }, 150, 225))
            assert.is_nil(BookCovers.read({ path = B }, 150, 225))
        end)

        it("gives nil without CoverBrowser", function()
            stub(false)
            assert.is_nil(BookCovers.read({ path = A }, 150, 225))
        end)

        it("gives nil, logged, when the row can't be read", function()
            local bim = manager{}
            bim.getBookInfo = function() error("row broke on purpose") end
            local _, logged = stub(bim)
            assert.is_nil(BookCovers.read({ path = A }, 150, 225))
            assert.is_true(was_logged(logged, "row broke on purpose"))
        end)
    end)

    describe("wants", function()
        it("never asks without CoverBrowser", function()
            stub(false)
            assert.is_false(BookCovers.wants(nil, SPECS))
        end)

        it("asks for no row and not for a cover that fits", function()
            stub(manager{})
            assert.is_true(BookCovers.wants(nil, SPECS))
            assert.is_false(BookCovers.wants(usable(nil), SPECS))
        end)
    end)

    describe("request", function()
        it("asks once for the batch's wanted files with the specs, in order, and never again", function()
            local rows = { [A] = usable(nil) }
            local bim = manager{ info = function(file) return rows[file] end, extracting = { true } }
            local queue = stub(bim)
            local records = { { path = A }, { id = "remote:x", source = "remote" }, { path = B }, { path = C } }
            BookCovers.request(records, SPECS, function() end, always)
            assert.same({ files(B, C) }, bim.extracted)
            assert.equals(1, #queue)
            assert.equals(1, queue[1].secs)
            for _, read in ipairs(bim.reads) do
                assert.is_false(read.get_cover)
            end
            BookCovers.request({ { path = B }, { path = C } }, SPECS, function() end, always)
            assert.equals(1, #bim.extracted)
            assert.equals(1, #queue)
            assert.equals(0, queue.unscheduled)
        end)

        it("schedules nothing when no file is wanted", function()
            local bim = manager{ info = function() return usable(nil) end }
            local queue = stub(bim)
            BookCovers.request({ { path = A }, { id = "remote:x" } }, SPECS, function() end, always)
            assert.equals(0, #bim.extracted)
            assert.equals(0, #queue)
        end)

        it("asks nothing and schedules nothing without CoverBrowser", function()
            local queue = stub(false)
            BookCovers.request({ { path = A } }, SPECS, function() end, always)
            assert.equals(0, #queue)
        end)

        it("skips a file whose test raises, logged, and asks for the others", function()
            local bim = manager{ info = function(file)
                if file == A then
                    return { has_cover = "Y", cover_fetched = "Y", cover_w = 1, cover_h = 1 }
                end
                return nil
            end, extracting = { true } }
            local invalid = bim.isCachedCoverInvalid
            bim.isCachedCoverInvalid = function(info, specs)
                if info.cover_w == 1 then
                    error("test broke on purpose")
                end
                return invalid(info, specs)
            end
            local _, logged = stub(bim)
            BookCovers.request({ { path = A }, { path = B } }, SPECS, function() end, always)
            assert.same({ files(B) }, bim.extracted)
            assert.is_true(was_logged(logged, "test broke on purpose"))
        end)
    end)

    describe("arrivals", function()
        it("gives each arrival alone at its check: the first while extraction runs, the second at the end", function()
            local arrived = {}
            local freed = { 0 }
            local bim = manager{
                info = function(file, get_cover)
                    if file == A and arrived[A] then
                        return usable(get_cover and bitmap(freed) or nil)
                    end
                    if file == B and arrived[B] and get_cover then
                        return usable(bitmap(freed))
                    end
                    return nil
                end,
                extracting = { true, true, false },
            }
            local queue = stub(bim)
            local calls, on_arrival, next_check = recorder()
            BookCovers.request({ { path = A }, { path = B } }, SPECS, on_arrival, always)
            next_check()
            run_next(queue)
            assert.same({}, calls)
            arrived[A] = true
            next_check()
            assert.equals(1, run_next(queue).secs)
            assert.same({ { check = 2, paths = { A } } }, calls)
            arrived[B] = true
            next_check()
            run_next(queue)
            assert.same({ { check = 2, paths = { A } }, { check = 3, paths = { B } } }, calls)
            assert.equals(1, freed[1])
            assert.equals(0, #queue)
            assert.equals(3, bim.extracting_calls)
        end)

        it("gives two files arriving at one check in one call", function()
            local arrived = false
            local bim = manager{
                info = function() return arrived and usable(nil) or nil end,
                extracting = { true },
            }
            local queue = stub(bim)
            local calls, on_arrival, next_check = recorder()
            BookCovers.request({ { path = A }, { path = B } }, SPECS, on_arrival, always)
            arrived = true
            next_check()
            run_next(queue)
            assert.same({ { check = 1, paths = { A, B } } }, calls)
            assert.equals(0, #queue)
            assert.equals(0, bim.extracting_calls)
        end)

        it("ends after 30 checks with no call when nothing arrives, freeing the last read's stale bitmaps", function()
            local freed = { 0 }
            local bim = manager{
                info = function(_, get_cover)
                    if get_cover then
                        return { has_cover = "Y", cover_fetched = "Y", cover_w = 50, cover_h = 75,
                            cover_bb = bitmap(freed) }
                    end
                    return nil
                end,
                extracting = { true },
            }
            local queue = stub(bim)
            local calls, on_arrival = recorder()
            BookCovers.request({ { path = A }, { path = B } }, SPECS, on_arrival, always)
            local checks = 0
            while #queue > 0 do
                run_next(queue)
                checks = checks + 1
                assert.truthy(checks <= 30, "more than 30 checks")
            end
            assert.equals(30, checks)
            assert.same({}, calls)
            assert.equals(29, bim.extracting_calls)
            assert.equals(2, freed[1])
        end)

        it("stops at the next check once alive() is false, with no call", function()
            local arrived = false
            local bim = manager{
                info = function() return arrived and usable(nil) or nil end,
                extracting = { true },
            }
            local queue = stub(bim)
            local calls, on_arrival = recorder()
            local live = true
            BookCovers.request({ { path = A } }, SPECS, on_arrival, function() return live end)
            run_next(queue)
            live = false
            arrived = true
            run_next(queue)
            assert.equals(0, #queue)
            assert.same({}, calls)
        end)

        it("logs a check that fails and leaves nothing scheduled", function()
            local arrived = {}
            local bim = manager{
                info = function(file) return arrived[file] and usable(nil) or nil end,
                extracting = { true },
            }
            local queue, logged = stub(bim)
            BookCovers.request({ { path = A }, { path = B } }, SPECS, function()
                error("arrival broke on purpose")
            end, always)
            arrived[A] = true
            run_next(queue)
            assert.equals(0, #queue)
            assert.is_true(was_logged(logged, "arrival broke on purpose"))
        end)
    end)

    describe("cancel and replacement", function()
        it("cancel leaves the queue empty and keeps the files asked", function()
            local bim = manager{ info = function() return nil end, extracting = { true } }
            local queue = stub(bim)
            BookCovers.request({ { path = A } }, SPECS, function() end, always)
            run_next(queue)
            assert.equals(1, #queue)
            BookCovers.cancel()
            assert.equals(0, #queue)
            assert.equals(1, queue.unscheduled)
            BookCovers.request({ { path = A } }, SPECS, function() end, always)
            assert.equals(1, #bim.extracted)
            assert.equals(0, #queue)
        end)

        it("a new request drops the pending one's check and lets its unarrived file be asked again", function()
            local arrived = {}
            local bim = manager{
                info = function(file) return arrived[file] and usable(nil) or nil end,
                extracting = { true },
            }
            local queue = stub(bim)
            local first_calls, first_arrival = recorder()
            BookCovers.request({ { path = A }, { path = B } }, SPECS, first_arrival, always)
            arrived[A] = true
            run_next(queue)
            assert.same({ { check = 0, paths = { A } } }, first_calls)
            local stale = queue[1].fn
            BookCovers.request({ { path = C } }, SPECS, function() end, always)
            assert.same({ files(A, B), files(C) }, bim.extracted)
            assert.equals(1, queue.unscheduled)
            assert.equals(1, #queue)
            assert.are_not.equal(stale, queue[1].fn)
            stale()
            assert.equals(1, #queue)
            assert.equals(1, #first_calls)
            BookCovers.request({ { path = A }, { path = B } }, SPECS, function() end, always)
            assert.same({ files(A, B), files(C), files(B) }, bim.extracted)
        end)

        it("schedules nothing for a fork that fails, logged, and never asks for its files again", function()
            local bim = manager{ info = function() return nil end }
            bim.extractInBackground = function(_, list)
                bim.extracted[#bim.extracted + 1] = list
                return false
            end
            local queue, logged = stub(bim)
            BookCovers.request({ { path = A }, { path = B } }, SPECS, function() end, always)
            assert.equals(0, #queue)
            assert.is_true(was_logged(logged, "extraction didn't start"))
            BookCovers.request({ { path = A }, { path = B } }, SPECS, function() end, always)
            assert.equals(1, #bim.extracted)
            assert.equals(0, #queue)
        end)

        it("schedules nothing for a fork that raises, logged, and never asks for its files again", function()
            local bim = manager{ info = function() return nil end }
            local calls = 0
            bim.extractInBackground = function()
                calls = calls + 1
                error("fork broke on purpose")
            end
            local queue, logged = stub(bim)
            BookCovers.request({ { path = A } }, SPECS, function() end, always)
            assert.equals(0, #queue)
            assert.is_true(was_logged(logged, "fork broke on purpose"))
            BookCovers.request({ { path = A } }, SPECS, function() end, always)
            assert.equals(1, calls)
        end)
    end)
end)
