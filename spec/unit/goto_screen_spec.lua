-- The Contents and Bookmarks lists over a book, here a fake reader that records its jumps: Contents opens at the page
-- holding the current chapter, the top level shown and the current chapter's parents open, Bookmarks at its first
-- page, each with a note when it's empty, under a one-row header; a parent's toggle opens or closes it in place; a
-- tap elsewhere on a row closes the screen, then jumps; a hold on a bookmark offers Remove bookmark, and nothing on a
-- chapter; its top and bottom edges open nothing; and it never builds a nav bar.
describe("the reader's lists", function()
    local harness = require("plugin_harness")
    local text_of = require("library_fixture").text
    local centre = require("library_fixture").centre
    local Event = require("ui/event")
    local ReaderToc = require("apps/reader/modules/readertoc")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local GotoScreen, Sheet

    before_each(function()
        harness.load()
        GotoScreen = package.loaded["goto_screen"]
        Sheet = package.loaded["sheet"]
    end)

    after_each(function()
        harness.teardown()
    end)

    -- A rolling reader with n chapters ("Chapter 1" on page 1, then a page apart, every third a level deeper, or at
    -- depths[i] where given), at chapter current, and bookmarks, each { page, chapter, datetime }. Its calls record, in
    -- order, each jump as { "stack", shown } (whether a list was shown then), then the event or the goto.
    local function fake_ui(n, current, bookmarks, depths)
        local calls = {}
        local toc = {}
        for i = 1, n do
            toc[i] = { title = "Chapter " .. i, page = i, depth = depths and depths[i] or (i % 3 == 0 and 2 or 1),
                xpointer = "/body/x" .. i }
        end
        local ui = {
            calls = calls,
            document = {
                info = { has_pages = false },
                getXPointer = function()
                    return "/body/here"
                end,
            },
            toc = {
                cleanUpTocTitle = ReaderToc.cleanUpTocTitle,
                fillToc = function(self)
                    self.toc = toc
                end,
                getTocIndexByPage = function()
                    return current
                end,
            },
            annotation = { annotations = bookmarks or {} },
            link = {
                addCurrentLocationToStack = function()
                    calls[#calls + 1] = { "stack", GotoScreen.shown ~= nil }
                end,
            },
        }
        function ui.annotation.getItemIndex(self, item)
            for i, v in ipairs(self.annotations) do
                if v == item then
                    return i
                end
            end
        end
        ui.bookmark = {
            getBookmarkPageString = function(_, page)
                return tostring(page):match("%d+")
            end,
            gotoBookmark = function(_, page)
                calls[#calls + 1] = { "goto_bookmark", page }
            end,
            removeItem = function(_, _, index)
                table.remove(ui.annotation.annotations, index)
            end,
        }
        function ui:getCurrentPage()
            return current
        end
        function ui:handleEvent(event)
            calls[#calls + 1] = { event.handler:sub(3), event.args[1] }
            return true
        end
        return ui
    end

    local function bookmark(i)
        return { page = "/body/x" .. i, chapter = "Chapter " .. i, datetime = ("2026-10-%02d 09:00:00"):format(i) }
    end

    -- Shows ui's list, Contents unless named.
    local function show(ui, list)
        local screen = GotoScreen.show{ ui = ui, list = list or "chapters" }
        assert.is_not_nil(screen)
        harness.tick(2)
        return screen
    end

    local function send(ges, x, y)
        UIManager:sendEvent(Event:new("Gesture", harness.gesture(ges, x, y)))
    end

    local function row_texts(screen)
        local out = {}
        for i, row in ipairs(screen.rows) do
            out[i] = text_of(row.widget[1])
        end
        return out
    end

    -- The TOC indices of the chapter rows on the page shown.
    local function indices(screen)
        local out = {}
        for i, row in ipairs(screen.rows) do
            out[i] = row.chapter.index
        end
        return out
    end

    it("opens Contents at the page holding the current chapter, that row marked", function()
        local screen = show(fake_ui(80, 61))
        assert.equals("chapters", screen.list)
        assert.is_true(screen.pages > 1)
        assert.is_true(screen.page > 1)
        local marked = {}
        for _, row in ipairs(screen.rows) do
            if row.current then
                marked[#marked + 1] = row.chapter.index
            end
        end
        assert.same({ 61 }, marked)
    end)

    it("labels each chapter row's page as the reader's footer does", function()
        local ui = fake_ui(3, nil, nil, { 1, 1, 1 })
        ui.bookmark.getBookmarkPageString = function(_, page)
            return "label " .. page
        end
        local screen = show(ui)
        local labels = {}
        for i, row in ipairs(screen.rows) do
            labels[i] = text_of(row.widget[2]):lower()
        end
        assert.same({ "label /body/x1", "label /body/x2", "label /body/x3" }, labels)
    end)

    it("opens on page 1 with no current chapter", function()
        local screen = show(fake_ui(80, nil))
        assert.equals("chapters", screen.list)
        assert.equals(1, screen.page)
        assert.equals("Chapter 1", row_texts(screen)[1])
    end)

    it("heads each list with the back control and its name on one row, shorter than a detail header", function()
        for list, title in pairs({ chapters = "Contents", bookmarks = "Bookmarks" }) do
            local screen = show(fake_ui(5, 1), list)
            local back = screen.header.back_rect
            assert.equals("book", text_of(screen.header.back_label):lower())
            assert.equals(title, text_of(screen.header.title))
            assert.is_nil(screen.header.aside)
            assert.is_true(back.y + back.h <= screen.header.rect.h)
            assert.is_true(screen.header.rect.h < package.loaded["library_chrome"].detail_header_height(screen.ctx))
            GotoScreen.close()
        end
    end)

    it("keeps the back control clear of the list's name at Extra large on the Paperwhite 7th gen, in every look",
        function()
        local Looks = package.loaded["looks"]
        local Settings = package.loaded["settings"]
        assert.is_true(Settings.set("text_size", "extra_large"))
        harness.at_screen(1072, 1448, function()
            for _, id in ipairs(Looks.ids()) do
                assert.is_true(Settings.set("look", id))
                local screen = show(fake_ui(5, 1), "bookmarks")
                local back, title = screen.header.back_rect, screen.header.title_place
                assert.is_true(back.x + back.w < title.x, id)
                assert.is_true(title.x + screen.header.title:getSize().w <= screen.dimen.w, id)
                GotoScreen.close()
            end
        end)
    end)

    it("fits at least 14 rows on a page of either list on the Colorsoft at the default size, in every look", function()
        local Looks = package.loaded["looks"]
        local Settings = package.loaded["settings"]
        local bookmarks = {}
        for i = 1, 60 do
            bookmarks[i] = bookmark(i)
        end
        local depths = {}
        for i = 1, 60 do
            depths[i] = 1
        end
        harness.at_screen(1264, 1680, function()
            for _, id in ipairs(Looks.ids()) do
                assert.is_true(Settings.set("look", id))
                for _, list in ipairs({ "chapters", "bookmarks" }) do
                    local screen = show(fake_ui(60, 1, bookmarks, depths), list)
                    assert.is_true(#screen.rows >= 14, id .. " " .. list .. ": " .. #screen.rows .. " rows")
                    GotoScreen.close()
                end
            end
        end)
    end)

    it("opens Bookmarks, newest first, at its first page, whether or not the book has chapters", function()
        for _, chapters in ipairs({ 0, 80 }) do
            local screen = show(fake_ui(chapters, chapters > 0 and 61 or nil, { bookmark(3), bookmark(9) }),
                "bookmarks")
            assert.equals("bookmarks", screen.list)
            assert.equals(1, screen.page)
            assert.same({ "Chapter 9", "Chapter 3" }, row_texts(screen))
            assert.is_nil(screen.note)
            GotoScreen.close()
        end
    end)

    it("opens and refreshes Bookmarks without reading the TOC", function()
        local ui = fake_ui(5, 1, { bookmark(3), bookmark(9) })
        ui.toc.fillToc = function()
            error("the TOC failed")
        end
        local screen = show(ui, "bookmarks")
        assert.same({ "Chapter 9", "Chapter 3" }, row_texts(screen))
        screen:refresh()
        assert.same({ "Chapter 9", "Chapter 3" }, row_texts(screen))
    end)

    it("turns a page of either list and stays on it", function()
        local bookmarks, depths = {}, {}
        for i = 1, 60 do
            bookmarks[i], depths[i] = bookmark(i), 1
        end
        for list, title in pairs({ chapters = "Contents", bookmarks = "Bookmarks" }) do
            local screen = show(fake_ui(60, 1, bookmarks, depths), list)
            assert.equals(1, screen.page)
            send("tap", centre(screen.pager.next.rect))
            assert.equals(list, screen.list)
            assert.equals(2, screen.page)
            assert.equals(title, text_of(screen.header.title))
            GotoScreen.close()
        end
    end)

    it("notes a book with no bookmarks on Bookmarks", function()
        local screen = show(fake_ui(5, 1), "bookmarks")
        assert.same({}, screen.rows)
        assert.equals("no bookmarks yet", text_of(screen.note):lower())
    end)

    it("notes a book with no chapters on Contents", function()
        local screen = show(fake_ui(0, nil, { bookmark(3) }))
        assert.equals("chapters", screen.list)
        assert.same({}, screen.rows)
        assert.equals("no chapters in this book", text_of(screen.note):lower())
    end)

    it("closes the screen on a chapter row tap, then jumps to the chapter", function()
        local ui = fake_ui(5, 1)
        local screen = show(ui)
        local row = screen.rows[3]
        assert.equals(4, row.chapter.index)
        send("tap", centre(row.rect))
        assert.is_nil(GotoScreen.shown)
        assert.is_false(UIManager:isWidgetShown(screen))
        assert.same({ { "stack", false }, { "GotoXPointer", "/body/x4" } }, ui.calls)
    end)

    it("opens with the top level shown and only the current chapter's parents open", function()
        local depths = { 1, 2, 3, 2, 1, 2, 1, 2 }
        local screen = show(fake_ui(8, 3, nil, depths))
        assert.same({ 1, 2, 3, 4, 5, 7 }, indices(screen))
        assert.equals(6, screen.count)
        assert.is_true(screen.rows[3].current)
    end)

    it("opens on the page holding a current chapter nested under a parent, its row marked", function()
        local screen = show(fake_ui(80, 60))
        assert.is_true(screen.page > 1)
        local marked = {}
        for _, row in ipairs(screen.rows) do
            if row.current then
                marked[#marked + 1] = row.chapter.index
            end
        end
        assert.same({ 60 }, marked)
    end)

    it("opens and closes a parent on its toggle, the screen kept and nothing jumped to", function()
        local ui = fake_ui(5, 1)
        local screen = show(ui)
        assert.same({ 1, 2, 4, 5 }, indices(screen))
        send("tap", centre(screen.rows[2].toggle))
        assert.equals(screen, GotoScreen.shown)
        assert.same({ 1, 2, 3, 4, 5 }, indices(screen))
        assert.equals(5, screen.count)
        send("tap", centre(screen.rows[2].toggle))
        assert.equals(screen, GotoScreen.shown)
        assert.same({ 1, 2, 4, 5 }, indices(screen))
        assert.same({}, ui.calls)
    end)

    it("keeps the page holding a toggled parent", function()
        local screen = show(fake_ui(80, 61, { bookmark(3) }))
        local page = screen.page
        local parent
        for _, row in ipairs(screen.rows) do
            if row.toggle then
                parent = row.chapter.index
                send("tap", centre(row.toggle))
                break
            end
        end
        assert.is_not_nil(parent)
        assert.equals(page, screen.page)
        assert.is_truthy(table.concat(indices(screen), ","):find(parent .. "," .. parent + 1, 1, true))
    end)

    it("jumps on a tap on a parent row's title, the screen closed first", function()
        local ui = fake_ui(5, 1)
        local screen = show(ui)
        local row = screen.rows[2]
        assert.is_not_nil(row.toggle)
        send("tap", row.toggle.x + row.toggle.w + 5, row.rect.y + math.floor(row.rect.h / 2))
        assert.is_nil(GotoScreen.shown)
        assert.same({ { "stack", false }, { "GotoXPointer", "/body/x2" } }, ui.calls)
    end)

    it("gives a parent's row, current or not, a toggle at the left after its indent, its full height and at least as "
        .. "wide, a leaf none", function()
        local screen = show(fake_ui(6, 5, nil, { 1, 1, 2, 1, 2, 3 }))
        local leaf, plain, current = screen.rows[1], screen.rows[2], screen.rows[4]
        assert.is_nil(leaf.toggle)
        assert.is_true(plain.chapter.has_children)
        assert.equals(0, plain.chapter.depth)
        assert.is_true(current.current)
        assert.is_true(current.chapter.has_children)
        assert.equals(1, current.chapter.depth)
        local step = Screen:scaleBySize(screen.ctx.look.shelf.list.side)
        for _, row in ipairs({ plain, current }) do
            local rect, toggle = row.rect, row.toggle
            assert.equals(rect.y, toggle.y)
            assert.equals(rect.h, toggle.h)
            assert.is_true(toggle.w >= rect.h)
            assert.equals(rect.x + row.chapter.depth * step, toggle.x)
        end
    end)

    it("closes the screen on a bookmark row tap, then jumps to the bookmark", function()
        local ui = fake_ui(0, nil, { bookmark(3), bookmark(9) })
        local screen = show(ui, "bookmarks")
        send("tap", centre(screen.rows[2].rect))
        assert.is_nil(GotoScreen.shown)
        assert.same({ { "stack", false }, { "goto_bookmark", "/body/x3" } }, ui.calls)
    end)

    it("closes the screen on the back control and jumps nowhere", function()
        local ui = fake_ui(5, 1)
        local screen = show(ui)
        send("tap", centre(screen.header.back_rect))
        assert.is_nil(GotoScreen.shown)
        assert.same({}, ui.calls)
    end)

    it("offers Remove bookmark on a hold on a bookmark, which removes it and stays on Bookmarks", function()
        local ui = fake_ui(5, 1, { bookmark(3), bookmark(9) })
        local screen = show(ui, "bookmarks")
        send("hold", centre(screen.rows[1].rect))
        harness.tick(2)
        local sheet = Sheet.shown
        assert.is_not_nil(sheet)
        assert.equals("goto_bookmark", sheet.spec.name)
        assert.equals(1, #sheet.spec.rows)
        assert.equals("Remove bookmark", sheet.spec.rows[1].label)
        assert.equals("Chapter 9", sheet.spec.header.heading)
        assert.equals("Bookmarks", sheet.spec.header.label)
        send("tap", centre(sheet.rows[1].rect))
        harness.tick(2)
        assert.is_nil(Sheet.shown)
        assert.equals(screen, GotoScreen.shown)
        assert.equals("bookmarks", screen.list)
        assert.same({ "Chapter 3" }, row_texts(screen))
        assert.equals(1, #ui.annotation.annotations)
        assert.same({}, ui.calls)
    end)

    it("shows no sheet on a hold on a chapter", function()
        local screen = show(fake_ui(5, 1))
        send("hold", centre(screen.rows[2].rect))
        harness.tick(2)
        assert.is_nil(Sheet.shown)
        assert.equals(screen, GotoScreen.shown)
    end)

    -- In the reader the file manager is closed (readerui.lua:793-794), so focused mode's top-edge rule takes nothing.
    it("opens no sheet and no KOReader menu on a tap, a swipe down or a hold at its top centre", function()
        assert.is_nil(require("apps/filemanager/filemanager").instance)
        assert.is_true(package.loaded["settings"].get("focused.on"))
        local ui = fake_ui(5, 1)
        local screen = show(ui)
        local x = Screen:getWidth() / 2
        send("tap", x, 2)
        local swipe = harness.gesture("swipe", x, 2)
        swipe.direction = "south"
        swipe.distance = Screen:scaleBySize(300)
        UIManager:sendEvent(Event:new("Gesture", swipe))
        send("hold", x, 2)
        harness.tick(2)
        assert.is_nil(Sheet.shown)
        assert.equals(screen, GotoScreen.shown)
        assert.equals(screen, harness.top())
        assert.same({}, ui.calls)
    end)

    -- With no file manager the bottom-edge step takes nothing either; quick settings has its own door here.
    it("opens no sheet on a swipe up from the bottom edge", function()
        assert.is_nil(require("apps/filemanager/filemanager").instance)
        local ui = fake_ui(5, 1)
        local screen = show(ui)
        local swipe = harness.gesture("swipe", Screen:getWidth() / 2, Screen:getHeight() * 15 / 16)
        swipe.direction = "north"
        swipe.distance = Screen:scaleBySize(300)
        UIManager:sendEvent(Event:new("Gesture", swipe))
        harness.tick(2)
        assert.is_nil(Sheet.shown)
        assert.equals(screen, GotoScreen.shown)
        assert.equals(screen, harness.top())
        assert.same({}, ui.calls)
    end)

    it("never builds a nav bar", function()
        for _, list in ipairs({ "chapters", "bookmarks" }) do
            local screen = show(fake_ui(80, 61, { bookmark(3) }), list)
            assert.is_nil(screen.nav)
            local foot = screen.pager.prev.rect
            assert.is_true(foot.y + foot.h <= screen.dimen.h)
            GotoScreen.close()
        end
    end)
end)
