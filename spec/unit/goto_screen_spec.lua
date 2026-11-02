-- The Go to screen over a book, here a fake reader that records its jumps: it opens on Chapters at the page holding
-- the current chapter, the top level shown and the current chapter's parents open, or on Bookmarks without chapters,
-- with a note for an empty tab; a chip switches the tab; a parent's toggle opens or closes it in place; a tap
-- elsewhere on a row closes the screen, then jumps; a hold on a bookmark offers Remove bookmark, and nothing on a
-- chapter; and it never builds a nav bar.
describe("the Go to screen", function()
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

    -- A rolling reader of "Frankenstein" with n chapters ("Chapter 1" on page 1, then a page apart, every third a
    -- level deeper, or at depths[i] where given), at chapter current, and bookmarks, each { page, chapter, datetime }.
    -- Its calls record, in order, each jump as { "stack", shown } (whether a Go to screen was shown then), then the
    -- event or the goto.
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
            doc_props = { display_title = "Frankenstein" },
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

    local function show(ui)
        local screen = GotoScreen.show{ ui = ui }
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

    it("opens on Chapters at the page holding the current chapter, that row marked", function()
        local screen = show(fake_ui(80, 61))
        assert.equals("chapters", screen.tab)
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
        local ui = fake_ui(3, 3)
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
        assert.equals("chapters", screen.tab)
        assert.equals(1, screen.page)
        assert.equals("Chapter 1", row_texts(screen)[1])
    end)

    it("heads the screen with the back control, Go to, the book's title and the two chips", function()
        local screen = show(fake_ui(5, 1))
        assert.equals("book", text_of(screen.header.back_label):lower())
        assert.equals("Go to", text_of(screen.header.title))
        assert.equals("Frankenstein", text_of(screen.header.aside))
        assert.is_not_nil(screen.chips.chapters)
        assert.is_not_nil(screen.chips.bookmarks)
        assert.is_true(screen.chips.chapters.x < screen.chips.bookmarks.x)
    end)

    it("cuts a long book title short of the chips", function()
        local ui = fake_ui(5, 1)
        ui.doc_props.display_title = ("Frankenstein, or the Modern Prometheus "):rep(8):sub(1, 300)
        local screen = show(ui)
        local side = Screen:scaleBySize(screen.ctx.look.shelf.detail.padding.side)
        assert.is_true(side + screen.header.aside:getSize().w <= screen.chips.chapters.x)
    end)

    it("marks the active tab's chip in ink with a paper label, the other on the sort fill, in every look", function()
        local Looks = package.loaded["looks"]
        local Settings = package.loaded["settings"]
        local function rgb(color)
            if not color then
                return nil
            end
            local c = color:getColorRGB32()
            return ("%d,%d,%d"):format(c.r, c.g, c.b)
        end
        local function line_color(line)
            return line.fgcolor or line_color(line[1])
        end
        -- The chip box drawn at rect in the header, the frame's first child.
        local function chip_at(screen, rect)
            local header = screen[1][1]
            for i, child in ipairs(header) do
                if header.places[i].x == rect.x and header.places[i].y == rect.y then
                    return child
                end
            end
        end
        local ok, err = pcall(function()
            for _, night in ipairs({ false, true }) do
                Screen.night_mode = night
                for _, id in ipairs(Looks.ids()) do
                    assert.is_true(Settings.set("look", id))
                    local screen = show(fake_ui(5, 1))
                    local color = Looks.colorer(screen.ctx)
                    local where = id .. " " .. screen.ctx.variant
                    assert.equals(night and "night" or "day", screen.ctx.variant)
                    local active, inactive = chip_at(screen, screen.chips.chapters),
                        chip_at(screen, screen.chips.bookmarks)
                    assert.equals(rgb(color("ink")), rgb(active.fill_color), where)
                    assert.equals(rgb(color("paper")), rgb(line_color(active[1])), where)
                    assert.equals(rgb(color(screen.ctx.look.library.header.sort_fill_color)),
                        rgb(inactive.fill_color), where)
                    assert.not_equals(rgb(active.fill_color), rgb(inactive.fill_color), where)
                    for _, box in ipairs({ active, inactive }) do
                        local left = box.places[1].x
                        local right = box:getSize().w - (left + box[1]:getSize().w)
                        assert.is_true(left > 0 and right > 0, where .. ": the label touches its chip's edge")
                    end
                    GotoScreen.close()
                end
            end
        end)
        Screen.night_mode = false
        assert(ok, err)
    end)

    it("opens on Bookmarks, newest first, when the book has no chapters", function()
        local screen = show(fake_ui(0, nil, { bookmark(3), bookmark(9) }))
        assert.equals("bookmarks", screen.tab)
        assert.same({ "Chapter 9", "Chapter 3" }, row_texts(screen))
        assert.is_nil(screen.note)
    end)

    it("opens on Bookmarks with its note when the book has neither", function()
        local screen = show(fake_ui(0, nil))
        assert.equals("bookmarks", screen.tab)
        assert.same({}, screen.rows)
        assert.equals("no bookmarks yet", text_of(screen.note):lower())
    end)

    it("notes a book with no chapters on the Chapters tab", function()
        local screen = show(fake_ui(0, nil, { bookmark(3) }))
        send("tap", centre(screen.chips.chapters))
        assert.equals("chapters", screen.tab)
        assert.equals("no chapters in this book", text_of(screen.note):lower())
    end)

    it("switches the tab on a chip tap: Bookmarks at page 1, Chapters back at the current chapter's page", function()
        local screen = show(fake_ui(80, 61, { bookmark(3) }))
        local current_page = screen.page
        send("tap", centre(screen.chips.bookmarks))
        assert.equals("bookmarks", screen.tab)
        assert.equals(1, screen.page)
        assert.same({ "Chapter 3" }, row_texts(screen))
        send("tap", centre(screen.chips.chapters))
        assert.equals("chapters", screen.tab)
        assert.equals(current_page, screen.page)
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

    it("keeps the page holding a toggled parent, and the open parents across a tab switch", function()
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
        local count = screen.count
        send("tap", centre(screen.chips.bookmarks))
        send("tap", centre(screen.chips.chapters))
        assert.equals(count, screen.count)
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
        local screen = show(ui)
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
        local screen = show(ui)
        send("tap", centre(screen.chips.bookmarks))
        send("hold", centre(screen.rows[1].rect))
        harness.tick(2)
        local sheet = Sheet.shown
        assert.is_not_nil(sheet)
        assert.equals("goto_bookmark", sheet.spec.name)
        assert.equals(1, #sheet.spec.rows)
        assert.equals("Remove bookmark", sheet.spec.rows[1].label)
        assert.equals("Chapter 9", sheet.spec.header.heading)
        send("tap", centre(sheet.rows[1].rect))
        harness.tick(2)
        assert.is_nil(Sheet.shown)
        assert.equals(screen, GotoScreen.shown)
        assert.equals("bookmarks", screen.tab)
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

    it("never builds a nav bar", function()
        local screen = show(fake_ui(80, 61, { bookmark(3) }))
        assert.is_nil(screen.nav)
        send("tap", centre(screen.chips.bookmarks))
        assert.is_nil(screen.nav)
        local foot = screen.pager.prev.rect
        assert.is_true(foot.y + foot.h <= screen.dimen.h)
    end)
end)
