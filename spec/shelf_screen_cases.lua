-- The cases the Series and Authors windows share, which series_screen_spec.lua and authors_screen_spec.lua run for
-- their window inside their own describe blocks, each passing its window's row (w) of what the cases differ in:
-- shown full-screen one window at a time, the pager in each look's words with its dead arrows, the nav bar, the
-- empty note, the list for a gone view, the rebuild on a variant or size change, the re-listing on the metadata
-- events, the sort kept between page turns, and the settled signal. A module required from a spec file doesn't see
-- the spec's globals: it and after_each come from Busted's API, assert from luassert, the same table.
local assert = require("luassert")
local busted = require("busted")
local fixture = require("shelf_fixture")
local harness = require("plugin_harness")
local text_of = require("library_fixture").text
local Blitbuffer = require("ffi/blitbuffer")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local it, after_each = busted.it, busted.after_each

local M = {}

M.LIST = { kind = "list" }
local LIST = M.LIST

local function lower(text)
    return text and text:lower()
end

local function window(w)
    return package.loaded[w.module]
end

function M.each_look(fn)
    for _, id in ipairs({ "diner", "editorial" }) do
        assert.is_true(package.loaded["settings"].set("look", id))
        fn(id)
    end
end
local each_look = M.each_look

-- Wraps ShelfOrder.authors and ShelfOrder.series to count their calls from here.
function M.count_sorts()
    local ShelfOrder = package.loaded["shelf_order"]
    local sorts = { authors = 0, series = 0 }
    for _, name in ipairs({ "authors", "series" }) do
        local sort = ShelfOrder[name]
        ShelfOrder[name] = function(...)
            sorts[name] = sorts[name] + 1
            return sort(...)
        end
    end
    return sorts
end

local function times(sorts, n)
    return { authors = sorts.authors * n, series = sorts.series * n }
end

-- Inside "the window".
function M.window(w)
    it("shows full-screen over the file manager as " .. w.Module .. ".shown, and closes", function()
        fixture.install(w.shelf(2))
        local screen, fm = w.show()
        assert.equals("kopanda_" .. w.id, screen.name)
        assert.equals(w.id, screen.screen)
        assert.is_true(screen.covers_fullscreen)
        assert.equals(screen, window(w).shown)
        assert.equals(fm, harness.top(2))
        window(w).close()
        assert.is_nil(window(w).shown)
        assert.equals(fm, harness.top())
    end)

    it("closes " .. w.before.name .. " before showing, one window at a time", function()
        fixture.install(w.shelf(2))
        local before = w.before.show()
        assert.is_not_nil(before)
        local screen = window(w).show{}
        assert.is_nil(package.loaded[w.before.module].shown)
        assert.is_false(UIManager:isWidgetShown(before))
        assert.equals(screen, harness.top())
    end)
end

-- Inside "the list".
function M.list(w)
    it("labels the pager in each look's words, the first page's previous and the last's next dead", function()
        fixture.install(w.shelf(w.paged.n))
        local wanted = { diner = "page %d of %d", editorial = "%d / %d" }
        each_look(function(id)
            local screen = w.show()
            local pages = screen.pages
            assert.is_true(pages >= w.paged.pages, id)
            for page = 1, pages do
                screen:go(LIST, page)
                assert.equals(wanted[id]:format(page, pages), lower(text_of(screen.pager.label)), id)
                assert.same({ page > 1, page < pages }, { screen.pager.prev.live, screen.pager.next.live }, id)
            end
            screen:go(LIST, 99)
            assert.equals(pages, screen.page, id .. ": a page past the end is the last")
            harness.teardown()
        end)
    end)

    it("carries the nav bar at the bottom with " .. w.nav.says, function()
        local NavBar = package.loaded["nav_bar"]
        fixture.install(w.shelf(2))
        each_look(function(id)
            local screen = w.show()
            for _, view in ipairs(w.nav.views) do
                screen:go(view, 1)
                local nav = screen.nav
                assert.equals(w.id, nav.where, id)
                assert.equals(w.nav.lit, nav.active and NavBar.TABS[nav.active].id, id)
                local bar_y = Screen:getHeight() - NavBar.height(screen.ctx.look, Screen)
                assert.same({ 0, bar_y, Screen:getWidth() }, { nav.dimen.x, nav.dimen.y, nav.dimen.w }, id)
            end
            harness.teardown()
        end)
    end)

    -- A book in no series and by no author, and one not downloaded.
    it("shows the empty note and page 1 of 1 with no " .. w.id, function()
        fixture.install({ fixture.book("Loose"), fixture.remote("Remote") })
        each_look(function(id)
            local screen = w.show()
            if w.empty.aside then
                assert.equals(w.empty.aside, lower(text_of(screen.header.aside)), id)
            end
            assert.equals(w.empty.note, lower(text_of(screen.note)), id)
            for _, list in ipairs(w.empty.lists) do
                assert.same({}, screen[list], id .. " " .. list)
            end
            assert.same({ 1, 1 }, { screen.page, screen.pages }, id)
            assert.same({ false, false }, { screen.pager.prev.live, screen.pager.next.live }, id)
            harness.teardown()
        end)
        fixture.install(w.shelf(1))
        local screen = w.show()
        assert.is_nil(screen.note)
    end)
end

-- Inside "one series" or "one author".
function M.one(w)
    it("shows the list at page 1 for " .. w.a_one .. " no entry has any more", function()
        fixture.install(w.shelf(w.paged.n))
        local screen = w.show({ kind = w.detail.kind, name = "Gone" }, w.paged.pages)
        assert.same(LIST, screen.showing)
        assert.equals(1, screen.page)
        assert.equals(w.id, lower(text_of(screen.header.title)))
        assert.equals(w.first, screen.rows[1].entry.name)
    end)
end

-- Inside "paint".
function M.paint(w)
    it("rebuilds before painting when the variant changed since its build", function()
        fixture.install(w.shelf(3, 1))
        local screen = w.show()
        local frame = screen[1]
        package.loaded["looks"].variant = function()
            return "night"
        end
        local bb = Blitbuffer.new(screen.dimen.w, screen.dimen.h, Blitbuffer.TYPE_BBRGB32)
        screen:paintTo(bb, 0, 0)
        bb:free()
        assert.equals("night", screen.ctx.variant)
        assert.is_not.equals(frame, screen[1])
        assert.equals(screen, window(w).shown)
    end)

    it("rebuilds before painting when the screen's size changed since its build", function()
        fixture.install(w.shelf(3, 1))
        local screen = w.show(w.detail)
        local frame = screen[1]
        local get_size = Screen.getSize
        Screen.getSize = function()
            return Geom:new{ x = 0, y = 0, w = 800, h = 600 }
        end
        local ok, err = pcall(function()
            local bb = Blitbuffer.new(800, 600, Blitbuffer.TYPE_BBRGB32)
            screen:paintTo(bb, 0, 0)
            bb:free()
        end)
        Screen.getSize = get_size
        assert.is_true(ok, tostring(err))
        assert.same({ 800, 600 }, { screen.dimen.w, screen.dimen.h })
        assert.equals(800, screen.nav.dimen.w)
        assert.is_not.equals(frame, screen[1])
        assert.same(w.detail, screen.showing)
    end)
end

-- Inside "kept current".
function M.kept_current(w)
    it("re-lists the books on BookMetadataChanged and on InvalidateMetadataCache", function()
        local records = w.shelf(1)
        fixture.install(records)
        local screen = w.show()
        assert.same({ w.relisted[1] }, fixture.names(screen))
        records[#records + 1] = w.relist[1]
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
        harness.tick()
        assert.same({ w.relisted[1], w.relisted[2] }, fixture.names(screen))
        records[#records + 1] = w.relist[2]
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", records[#records].path))
        harness.tick()
        assert.same(w.relisted, fixture.names(screen))
        assert.equals(screen, harness.top())
    end)

    -- The window's build counted from after the show; a metadata change's events, as the book-info
    -- editor broadcasts them (filemanagerbookinfo.lua:276-280, :556-557), sent to the shown window,
    -- then between() if given, then the UI loop run twice.
    local function builds_after(events, between)
        fixture.install(w.shelf(2))
        w.show()
        local Window = window(w)
        local build = Window.build
        local builds = 0
        Window.build = function(...)
            builds = builds + 1
            return build(...)
        end
        local ok, err = pcall(function()
            for _, event in ipairs(events) do
                UIManager:broadcastEvent(Event:new(event))
            end
            if between then
                between()
            end
            harness.tick(2)
        end)
        Window.build = build
        assert.is_true(ok, tostring(err))
        return builds
    end

    it("rebuilds once for one change's InvalidateMetadataCache and BookMetadataChanged", function()
        assert.equals(1, builds_after({ "InvalidateMetadataCache", "BookMetadataChanged" }))
    end)

    it("rebuilds once when the summary changed too", function()
        assert.equals(1, builds_after({ "InvalidateMetadataCache", "BookMetadataChanged", "BookMetadataChanged" }))
    end)

    it("does not rebuild a window closed between the events and the tick", function()
        assert.equals(0, builds_after({ "InvalidateMetadataCache", "BookMetadataChanged" }, function()
            window(w).close()
        end))
        assert.is_nil(window(w).shown)
    end)
end

-- Inside "kept sorted": w.sorted's shelf installed, each view's sorts counted (the list's and one
-- entry's), and whether a refresh there reads progress again.
function M.kept_sorted(w)
    -- Returns the calls (fixture.install's) and the sorts counted.
    local function install()
        local calls = fixture.install(w.sorted.install())
        return calls, M.count_sorts()
    end

    for _, case in ipairs(w.sorted.cases) do
        local where, view, once = case[1], case[2], case[3]

        it("sorts once at a show and not at a page turn, nor reads progress, in " .. where, function()
            local calls, sorts = install()
            local screen = w.show(view)
            assert.same(once, sorts)
            assert.is_true(screen.pages > 1)
            calls.progress = {}
            screen:turn(1)
            assert.equals(2, screen.page)
            screen:onNextPage()
            screen:onPrevPage()
            screen:turn(-1)
            assert.equals(1, screen.page)
            assert.same(once, sorts)
            assert.same({}, calls.progress)
        end)

        it("sorts " .. (case.reads and "and reads progress " or "") .. "again once at refresh() and at a metadata "
            .. "change, in " .. where, function()
            local calls, sorts = install()
            local screen = w.show(view)
            screen:turn(1)
            calls.progress = {}
            screen:refresh()
            assert.same(times(once, 2), sorts)
            if case.reads then
                assert.is_true(#calls.progress > 0)
            end
            assert.equals(2, screen.page)
            calls.progress = {}
            UIManager:broadcastEvent(Event:new("InvalidateMetadataCache"))
            UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
            harness.tick(2)
            assert.same(times(once, 3), sorts)
            if case.reads then
                assert.is_true(#calls.progress > 0)
            end
            screen:turn(1)
            assert.same(times(once, 3), sorts)
        end)
    end

    -- A status written through a sheet shows even when the re-list fails: the sort is dropped before
    -- the read, not only when the read replaces the records.
    it("sorts and reads progress again at a refresh() whose re-list fails", function()
        local calls, sorts = install()
        local detail = w.sorted.cases[2]
        local screen = w.show(detail[2])
        local Books = package.loaded["books"]
        local all = Books.all
        Books.all = function()
            error("kopanda-test: disk gone")
        end
        calls.progress = {}
        screen:refresh()
        Books.all = all
        assert.same(times(detail[3], 2), sorts)
        assert.is_true(#calls.progress > 0)
        assert.equals(screen, window(w).shown)
    end)

    it("shows a turned-to page as a show at that page does", function()
        install()
        local turned = w.sorted.turned
        local screen = w.show(turned.view)
        screen:turn(1)
        local items = turned.items(screen)
        window(w).close()
        local direct = w.show(turned.view, 2)
        assert.same(turned.items(direct), items)
    end)
end

-- Inside "the settled signal".
function M.settled(w)
    local listener

    after_each(function()
        if listener then
            UIManager.event_hook:unregister("KoPandaSettled", listener)
            listener = nil
        end
    end)

    it("is sent once per show after its first paint, with screen " .. w.id .. " and a numeric paint_ms", function()
        local signals = {}
        listener = function(args)
            signals[#signals + 1] = args
        end
        UIManager.event_hook:register("KoPandaSettled", listener)
        fixture.install(w.shelf(w.paged.n))
        local screen = w.show()
        local function count()
            local n = 0
            for _, args in ipairs(signals) do
                if args.screen == w.id then
                    n = n + 1
                    assert.is_number(args.paint_ms)
                end
            end
            return n
        end
        assert.equals(1, count())
        screen:go(LIST, 2)
        harness.tick(3)
        screen:go(w.detail, 1)
        harness.tick(3)
        assert.equals(1, count())
        window(w).close()
        window(w).show{}
        harness.tick(3)
        assert.equals(2, count())
    end)
end

return M
