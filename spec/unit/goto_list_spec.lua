-- The Contents and Bookmarks lists' model: a reader's TOC flattened in order with depths from the shallowest and the
-- current chapter found by KOReader's own lookup, its annotations newest first by kind, and the jumps and the removal
-- sent through KOReader's own calls, here to a fake reader that records them.
describe("the Contents and Bookmarks lists' model", function()
    local harness = require("plugin_harness")
    local ReaderToc = require("apps/reader/modules/readertoc")
    local GotoList

    before_each(function()
        harness.load()
        GotoList = require("goto_list")
    end)

    after_each(function()
        harness.teardown()
    end)

    -- A reader over toc (KOReader's items, depth from 1) and annotations, rolling unless opts.paging, at page 40 or
    -- at the xpointer "/body/x40". Its calls record what reaches it, in order: "fill", { "index", pn_or_xp },
    -- "stack", each event as { name, args... }, { "goto_bookmark", page, marker }, { "remove", item, index }.
    local function fake_ui(toc, annotations, opts)
        opts = opts or {}
        local calls = {}
        local ui = {
            calls = calls,
            document = {
                info = { has_pages = opts.paging or false },
                getXPointer = function()
                    return "/body/x40"
                end,
            },
            toc = {
                cleanUpTocTitle = ReaderToc.cleanUpTocTitle,
                fillToc = function(self)
                    calls[#calls + 1] = "fill"
                    self.toc = toc
                end,
                getTocIndexByPage = function(_, pn_or_xp, skip_ignored_ticks)
                    calls[#calls + 1] = { "index", pn_or_xp, skip_ignored_ticks }
                    return opts.current
                end,
            },
            annotation = {
                annotations = annotations or {},
                getItemIndex = function(self, item)
                    for i, v in ipairs(self.annotations) do
                        if v == item then
                            return i
                        end
                    end
                end,
            },
            bookmark = {
                getBookmarkPageString = function(_, page)
                    return "p" .. tostring(page)
                end,
                gotoBookmark = function(_, page, marker)
                    calls[#calls + 1] = { "goto_bookmark", page, marker }
                end,
                removeItem = function(_, item, index)
                    calls[#calls + 1] = { "remove", item, index }
                end,
            },
            link = {
                addCurrentLocationToStack = function()
                    calls[#calls + 1] = "stack"
                end,
            },
        }
        function ui:getCurrentPage()
            return 40
        end
        function ui:handleEvent(event)
            local call = { event.handler:sub(3) }
            for i = 1, event.args.n do
                call[#call + 1] = event.args[i]
            end
            calls[#calls + 1] = call
            return true
        end
        return ui
    end

    local NESTED = {
        { title = "Letter 1", page = 3, depth = 2, xpointer = "/body/x3" },
        { title = "Chapter 1\13", page = 20, depth = 2, xpointer = "/body/x20" },
        { title = "Part", page = 30, depth = 3, xpointer = "/body/x30" },
        { title = "  ", page = 40, depth = 4, xpointer = "/body/x40" },
        { title = "Chapter 2", page = 50, depth = 2, xpointer = "/body/x50" },
    }

    describe("chapters", function()
        it("flattens a nested TOC in order, depths from the shallowest, titles cleaned", function()
            local list = GotoList.chapters(fake_ui(NESTED, {}, { current = 4 }))
            assert.same({
                { title = "Letter 1", depth = 0, page = 3, xpointer = "/body/x3", index = 1, page_label = "p/body/x3",
                    has_children = false },
                { title = "Chapter 1", depth = 0, page = 20, xpointer = "/body/x20", index = 2,
                    page_label = "p/body/x20", has_children = true },
                { title = "Part", depth = 1, page = 30, xpointer = "/body/x30", index = 3, page_label = "p/body/x30",
                    parent = 2, has_children = true },
                { title = "\u{2013}", depth = 2, page = 40, xpointer = "/body/x40", index = 4,
                    page_label = "p/body/x40", parent = 3, has_children = false },
                { title = "Chapter 2", depth = 0, page = 50, xpointer = "/body/x50", index = 5,
                    page_label = "p/body/x50", has_children = false },
            }, list.rows)
            assert.equals(4, list.current)
        end)

        it("gives each row its parent, the nearest shallower entry before it, and whether it has children", function()
            local depths = { 1, 3, 2, 3, 1, 1 }
            local toc = {}
            for i, depth in ipairs(depths) do
                toc[i] = { title = "T" .. i, page = i, depth = depth }
            end
            local rows = GotoList.chapters(fake_ui(toc, {})).rows
            local parents, nesting = {}, {}
            for i, row in ipairs(rows) do
                parents[i] = row.parent or 0
                nesting[i] = row.has_children
            end
            assert.same({ 0, 1, 1, 3, 0, 0 }, parents)
            assert.same({ true, false, true, false, false, false }, nesting)
        end)

        it("labels a paging document's chapters by their page, as its footer does", function()
            local toc = { { title = "One", page = 3, depth = 1 }, { title = "Two", page = 20, depth = 1 } }
            local list = GotoList.chapters(fake_ui(toc, {}, { paging = true }))
            assert.same({ "p3", "p20" }, { list.rows[1].page_label, list.rows[2].page_label })
        end)

        it("asks a rolling document for the chapter at its xpointer, every level counted", function()
            local ui = fake_ui(NESTED, {}, { current = 4 })
            GotoList.chapters(ui)
            assert.same({ "fill", { "index", "/body/x40" } }, ui.calls)
        end)

        it("asks a paging document for the chapter at its page", function()
            local ui = fake_ui(NESTED, {}, { paging = true, current = 4 })
            GotoList.chapters(ui)
            assert.same({ "fill", { "index", 40 } }, ui.calls)
        end)

        it("gives an empty TOC no rows and no current", function()
            local list = GotoList.chapters(fake_ui({}, {}))
            assert.same({ rows = {} }, list)
        end)

        it("leaves KOReader's TOC items as they were", function()
            local toc = { { title = "One\13", page = 1, depth = 1 } }
            GotoList.chapters(fake_ui(toc, {}))
            assert.same({ { title = "One\13", page = 1, depth = 1 } }, toc)
        end)
    end)

    describe("bookmarks", function()
        it("lists bookmarks, highlights and notes newest first, each with its kind, text, chapter and page", function()
            local old = { page = "/body/x3", chapter = "Letter 1", datetime = "2026-10-01 09:00:00" }
            local new = { page = "/body/x50", chapter = "Chapter 2", datetime = "2026-11-01 21:30:00" }
            local mid = { page = "/body/x20", datetime = "2026-10-15 12:00:00" }
            local highlight = { page = "/body/x30", drawer = "lighten", chapter = "Part", text = "It was\nthe best",
                datetime = "2026-11-02 08:00:00" }
            local note = { page = "/body/x40", drawer = "lighten", chapter = "Part", text = "of times",
                note = "Dickens", datetime = "2026-10-20 08:00:00" }
            local list = GotoList.bookmarks(fake_ui({}, { old, mid, highlight, new, note }))
            assert.same({
                { item = highlight, kind = "highlight", text = "It was\nthe best", chapter = "Part",
                    page_label = "p/body/x30" },
                { item = new, kind = "bookmark", text = "", chapter = "Chapter 2", page_label = "p/body/x50" },
                { item = note, kind = "note", text = "of times", chapter = "Part", page_label = "p/body/x40" },
                { item = mid, kind = "bookmark", text = "", chapter = "No chapter", page_label = "p/body/x20" },
                { item = old, kind = "bookmark", text = "", chapter = "Letter 1", page_label = "p/body/x3" },
            }, list)
        end)

        it("orders annotations of one time last made first, whatever their kind", function()
            local at = "2026-10-01 09:00:00"
            local first = { page = "/body/x3", datetime = at }
            local second = { page = "/body/x4", drawer = "lighten", text = "Two", datetime = at }
            local list = GotoList.bookmarks(fake_ui({}, { first, second }))
            assert.same({ second, first }, { list[1].item, list[2].item })
        end)

        it("gives a highlight with no text an empty text, as KOReader's list does", function()
            local item = { page = 3, drawer = "lighten", datetime = "2026-10-01 09:00:00" }
            local list = GotoList.bookmarks(fake_ui({}, { item }))
            assert.same({ "highlight", "" }, { list[1].kind, list[1].text })
        end)

        it("is empty with no bookmarks", function()
            assert.same({}, GotoList.bookmarks(fake_ui({}, {})))
        end)
    end)

    describe("the jumps", function()
        it("pushes the location stack, then goes to a chapter's xpointer", function()
            local ui = fake_ui(NESTED, {})
            GotoList.jump_chapter(ui, { page = 20, xpointer = "/body/x20" })
            assert.same({ "stack", { "GotoXPointer", "/body/x20", "/body/x20" } }, ui.calls)
        end)

        it("pushes the location stack, then goes to a chapter's page without an xpointer", function()
            local ui = fake_ui(NESTED, {}, { paging = true })
            GotoList.jump_chapter(ui, { page = 20 })
            assert.same({ "stack", { "GotoPage", 20 } }, ui.calls)
        end)

        it("pushes the location stack, then goes to a bookmark as KOReader's list does", function()
            local item = { page = "/body/x20", pos0 = "/body/x20.0", datetime = "2026-10-15 12:00:00" }
            local ui = fake_ui({}, { item })
            GotoList.jump_bookmark(ui, { item = item })
            assert.same({ "stack", { "goto_bookmark", "/body/x20", "/body/x20.0" } }, ui.calls)
        end)
    end)

    describe("the removal", function()
        it("removes the bookmark at its own index", function()
            local a = { page = "/body/x3", datetime = "2026-10-01 09:00:00" }
            local b = { page = "/body/x20", datetime = "2026-10-15 12:00:00" }
            local ui = fake_ui({}, { a, b })
            GotoList.remove_bookmark(ui, { item = b })
            assert.same({ { "remove", b, 2 } }, ui.calls)
        end)

        it("removes a highlight or a note at its own index, for KOReader to route by its drawer", function()
            local a = { page = "/body/x3", drawer = "lighten", datetime = "2026-10-01 09:00:00" }
            local b = { page = "/body/x20", drawer = "lighten", note = "N", datetime = "2026-10-15 12:00:00" }
            local ui = fake_ui({}, { a, b })
            GotoList.remove_bookmark(ui, { item = b })
            GotoList.remove_bookmark(ui, { item = a })
            assert.same({ { "remove", b, 2 }, { "remove", a, 1 } }, ui.calls)
        end)

        it("removes nothing when the bookmark is no longer among the annotations", function()
            local a = { page = "/body/x3", drawer = "lighten", datetime = "2026-10-01 09:00:00" }
            local gone = { page = "/body/x20", datetime = "2026-10-15 12:00:00" }
            local ui = fake_ui({}, { a })
            GotoList.remove_bookmark(ui, { item = gone })
            assert.same({}, ui.calls)
        end)
    end)
end)
