-- The title bar in the file browser: the upgrade tripwire on KOReader's unwrapped FileManager.setupLayout, then
-- KoPanda's bar built in place of KOReader's for that one call, what it shows as the chooser changes, its pickers,
-- plus, select mode and folder menu, its re-layouts and refusal, and every other title bar left KOReader's.
describe("the file browser's title bar", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local ButtonDialog = require("ui/widget/buttondialog")
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local FileChooser = require("ui/widget/filechooser")
    local Menu = require("ui/widget/menu")
    local PathChooser = require("ui/widget/pathchooser")
    local Screen = require("device").screen
    local Size = require("ui/size")
    local TitleBar = require("ui/widget/titlebar")
    local TouchMenu = require("ui/widget/touchmenu")
    local UIManager = require("ui/uimanager")
    local ffiUtil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")
    local Home, KoTitleBar, Looks, logged

    local scratch = DataStorage:getDataDir() .. "/fm_title_bar_spec"
    local lib = scratch .. "/library"
    local books = { "a-christmas-carol.epub", "frankenstein.epub", "the-time-machine.epub" }

    local function copy(from, to)
        local src = assert(io.open(from, "rb"))
        local data = src:read("*a")
        src:close()
        local dst = assert(io.open(to, "wb"))
        dst:write(data)
        dst:close()
    end

    -- The scratch library: the fixture's three books and a subfolder of one book.
    setup(function()
        os.execute("rm -rf '" .. scratch .. "'")
        assert(lfs.mkdir(scratch))
        assert(lfs.mkdir(lib))
        for _, book in ipairs(books) do
            copy(harness.library .. "/" .. book, lib .. "/" .. book)
        end
        assert(lfs.mkdir(lib .. "/Shelf"))
        copy(harness.library .. "/frankenstein.epub", lib .. "/Shelf/one.epub")
    end)

    teardown(function()
        os.execute("rm -rf '" .. scratch .. "'")
    end)

    -- What a case replaced outside KoPanda's modules, put back after it, latest first.
    local restores = {}

    before_each(function()
        harness.load()
        Home = package.loaded["home"]
        KoTitleBar = package.loaded["title_bar"]
        Looks = package.loaded["looks"]
        logged = spy.on(logger, "err")
    end)

    after_each(function()
        for i = #restores, 1, -1 do
            restores[i]()
        end
        restores = {}
        logger.err:revert()
        FileChooser.show_filter.status = nil
        G_reader_settings:delSetting("home_dir")
        G_reader_settings:delSetting("collate")
        harness.teardown()
    end)

    -- Sets t[name] to value for the case.
    local function stub(t, name, value)
        local original = rawget(t, name)
        restores[#restores + 1] = function()
            t[name] = original
        end
        t[name] = value
    end

    local function send(ges)
        UIManager:sendEvent(Event:new("Gesture", ges))
    end

    local function logged_count(text)
        local count = 0
        for _, call in ipairs(logged.calls) do
            for _, arg in ipairs(call.vals) do
                if tostring(arg):find(text, 1, true) then
                    count = count + 1
                    break
                end
            end
        end
        return count
    end

    -- A file manager on dir (default the scratch library) on top with its home closed, painted.
    local function fm_on_top(dir)
        local fm = harness.show_fm(dir or lib)
        harness.tick(2)
        Home.close()
        harness.tick()
        assert.equals(fm, harness.top())
        return fm
    end

    -- The file manager painted whole into a scratch buffer; what its bar built for that paint.
    local function shown(fm)
        local bb = Blitbuffer.new(Screen:getWidth(), Screen:getHeight(), Blitbuffer.TYPE_BBRGB32)
        fm:paintTo(bb, 0, 0)
        bb:free()
        local state = fm.title_bar.built.state
        return { title = state.title, count = state.count, sort = state.sort, status = state.status,
            icon = state.icon }
    end

    -- The chooser's rows fill its inner height less the bar's and its page footer's
    -- (frontend/ui/widget/menu.lua:666-677).
    local function rows_fit(fm)
        local chooser = fm.file_chooser
        local footer = math.max(chooser.page_return_arrow:getSize().h, chooser.page_info_text:getSize().h)
            + Size.padding.button
        assert.equals(chooser.inner_dimen.h - fm.title_bar:getHeight() - footer, chooser.available_height)
    end

    -- The centre of the bar's area named area, in screen coordinates, after a paint.
    local function area_centre(bar, area)
        local a = bar.areas[area]
        return bar.dimen.x + a.x + math.floor(a.w / 2), bar.dimen.y + math.floor(bar.dimen.h / 2)
    end

    local function texts(items)
        local out = {}
        for i, item in ipairs(items) do
            out[i] = item.text
        end
        return out
    end

    local function item_with(items, text)
        for _, item in ipairs(items) do
            if item.text == text then
                return item
            end
        end
        error("no item " .. text)
    end

    describe("the upgrade tripwire", function()
        -- When a case here fails, KOReader has moved or reshaped how its file manager builds and
        -- uses its title bar: re-read every line HOOKS.md cites under "The file browser's title
        -- bar", change fm_nav.lua, title_bar.lua and HOOKS.md to match, then change the pin.
        it("finds TitleBar with no new of its own", function()
            assert.is_nil(rawget(TitleBar, "new"))
        end)

        it("builds the bar before the chooser, with Home, plus and callbacks, and the chooser keeps it", function()
            local fm = harness.show_fm(lib)
            local order, first = {}, nil
            local title_new, chooser_new = TitleBar.new, FileChooser.new
            stub(TitleBar, "new", function(class, attrs, ...)
                order[#order + 1] = "TitleBar"
                local bar = title_new(class, attrs, ...)
                if not first then
                    first = { attrs = attrs, bar = bar }
                end
                return bar
            end)
            stub(FileChooser, "new", function(...)
                order[#order + 1] = "FileChooser"
                return chooser_new(...)
            end)
            harness.fm_setup_layout(fm)
            TitleBar.new, FileChooser.new = nil, nil
            assert.same({ "TitleBar", "FileChooser" }, { order[1], order[2] })
            assert.equals("home", first.attrs.left_icon)
            assert.equals("plus", first.attrs.right_icon)
            assert.equals("function", type(first.attrs.right_icon_tap_callback))
            assert.equals("function", type(first.attrs.left_icon_hold_callback))
            assert.equals(first.bar, fm.title_bar)
            assert.equals(fm.title_bar, fm.file_chooser.title_bar)
            rows_fit(fm)
        end)

        it("finds KoPanda's bar in the file manager once KoPanda lays it out", function()
            local fm = harness.show_fm(lib)
            assert.equals(KoTitleBar, getmetatable(fm.title_bar))
        end)
    end)

    describe("in place", function()
        it("is the chooser's bar too, in the active look, and the rows fit under it", function()
            local fm = harness.show_fm(lib)
            assert.equals(KoTitleBar, getmetatable(fm.title_bar))
            assert.equals(fm.title_bar, fm.file_chooser.title_bar)
            assert.equals(fm, fm.title_bar.fm)
            assert.equals(Looks.active(), fm.title_bar.look)
            assert.equals(fm[1].look, fm.title_bar.look)
            rows_fit(fm)
            assert.is_nil(rawget(TitleBar, "new"))
        end)

        it("keeps KOReader's callbacks and show_parent and adds the pickers", function()
            local fm = harness.show_fm(lib)
            local bar = fm.title_bar
            assert.equals("function", type(bar.left_icon_hold_callback))
            assert.equals("function", type(bar.right_icon_tap_callback))
            assert.equals("function", type(bar.on_sort))
            assert.equals("function", type(bar.on_status))
            assert.equals(fm.show_parent, bar.show_parent)
        end)

        it("puts back a TitleBar.new that was there before the layout and builds through it", function()
            local Widget = require("ui/widget/widget")
            local built = 0
            local prior = function(class, ...)
                if class == KoTitleBar then
                    built = built + 1
                end
                return Widget.new(class, ...)
            end
            stub(TitleBar, "new", prior)
            local fm = harness.show_fm(lib)
            assert.equals(KoTitleBar, getmetatable(fm.title_bar))
            assert.equals(1, built)
            assert.equals(prior, rawget(TitleBar, "new"))
        end)
    end)

    describe("what it shows", function()
        it("follows the folder, home, the sort and the status filter", function()
            G_reader_settings:saveSetting("home_dir", ffiUtil.realpath(lib))
            local fm = fm_on_top()
            fm.file_chooser:changeToPath(lib .. "/Shelf")
            assert.same({ title = "Shelf", count = 1, sort = "Name", status = "All", icon = "plus" }, shown(fm))
            fm:onHome()
            assert.same({ title = "Library", count = 3, sort = "Name", status = "All", icon = "plus" }, shown(fm))
            fm:onSetSortBy("access")
            assert.same({ title = "Library", count = 3, sort = "Recent", status = "All", icon = "plus" }, shown(fm))
            local FmNav = package.loaded["fm_nav"]
            FmNav.open_status(fm)
            local container = harness.top()
            local menu = container[1]
            menu:onMenuSelect(item_with(menu.item_table, "finished"))
            UIManager:close(container)
            assert.same({ title = "Library", count = 0, sort = "Recent", status = "Finished", icon = "plus" },
                shown(fm))
        end)
    end)

    describe("the pickers", function()
        it("open KOReader's sort items from the sort picker, and a pick sorts and relabels", function()
            local fm = fm_on_top()
            send(harness.gesture("tap", area_centre(fm.title_bar, "sort")))
            local container = harness.top()
            assert.is_not.equals(fm, container)
            local menu = container[1]
            assert.equals(TouchMenu, getmetatable(menu))
            assert.equals(1, #menu.tab_item_table)
            assert.equals("appbar.filebrowser", menu.tab_item_table[1].icon)
            assert.same(texts(fm.menu:getSortingMenuTable().sub_item_table), texts(menu.item_table))
            menu:onMenuSelect(item_with(menu.item_table, "last read date"))
            assert.equals("access", G_reader_settings:readSetting("collate"))
            UIManager:close(container)
            assert.equals("Recent", shown(fm).sort)
        end)

        it("close whole on a tap outside the menu, back to the file manager", function()
            local fm = fm_on_top()
            send(harness.gesture("tap", area_centre(fm.title_bar, "sort")))
            harness.tick()
            local menu = harness.top()[1]
            assert.equals(TouchMenu, getmetatable(menu))
            local x, y = math.floor(Screen:getWidth() / 2), Screen:getHeight() - 5
            assert.truthy(y > menu.dimen.y + menu.dimen.h, y .. " <= " .. menu.dimen.y + menu.dimen.h)
            send(harness.gesture("tap", x, y))
            harness.tick()
            assert.equals(fm, harness.top())
        end)

        it("open KOReader's five status items from the status picker, and a pick filters and relabels", function()
            local fm = fm_on_top()
            send(harness.gesture("tap", area_centre(fm.title_bar, "status")))
            local container = harness.top()
            local menu = container[1]
            assert.equals(TouchMenu, getmetatable(menu))
            assert.equals("appbar.filebrowser", menu.tab_item_table[1].icon)
            local wanted = texts(fm.menu:getShowFilterMenuTable().sub_item_table)
            assert.equals(5, #wanted)
            assert.same(wanted, texts(menu.item_table))
            menu:onMenuSelect(item_with(menu.item_table, "reading"))
            assert.same({ reading = true }, FileChooser.show_filter.status)
            UIManager:close(container)
            local state = shown(fm)
            assert.same({ "Reading", 0 }, { state.status, state.count })
        end)

        it("log a raising menu table and show nothing", function()
            local fm = fm_on_top()
            fm.menu.getSortingMenuTable = function()
                error("kopanda-test: sort table failed")
            end
            fm.menu.getShowFilterMenuTable = function()
                error("kopanda-test: status table failed")
            end
            send(harness.gesture("tap", area_centre(fm.title_bar, "sort")))
            assert.equals(fm, harness.top())
            send(harness.gesture("tap", area_centre(fm.title_bar, "status")))
            assert.equals(fm, harness.top())
            assert.equals(1, logged_count("kopanda-test: sort table failed"))
            assert.equals(1, logged_count("kopanda-test: status table failed"))
        end)
    end)

    describe("the plus and select mode", function()
        it("shows KOReader's plus dialog from the plus", function()
            local fm = fm_on_top()
            send(harness.gesture("tap", area_centre(fm.title_bar, "plus")))
            assert.is_not_nil(fm.plus_dialog)
            assert.equals(fm.plus_dialog, harness.top())
        end)

        it("shows the check in select mode and the plus after it", function()
            local fm = fm_on_top()
            fm:onToggleSelectMode()
            assert.equals("check", shown(fm).icon)
            fm:onToggleSelectMode()
            assert.equals("plus", shown(fm).icon)
        end)

        it("starts from the check when the layout comes in select mode", function()
            local fm = fm_on_top()
            fm:onToggleSelectMode()
            fm:reinit()
            assert.equals(KoTitleBar, getmetatable(fm.title_bar))
            assert.equals("check", shown(fm).icon)
        end)
    end)

    describe("the folder menu", function()
        it("opens from a hold on the title, under the title, and a button changes the folder", function()
            local fm = fm_on_top()
            fm.file_chooser:changeToPath(lib .. "/Shelf")
            harness.tick()
            local calls = 0
            local show_folder_menu = fm.onShowFolderMenu
            fm.onShowFolderMenu = function(...)
                calls = calls + 1
                return show_folder_menu(...)
            end
            local bar = fm.title_bar
            shown(fm)
            local box = bar.boxes.title
            local x, y = bar.dimen.x + box.x + math.floor(box.w / 2), bar.dimen.y + box.y + math.floor(box.h / 2)
            send(harness.gesture("hold", x, y))
            assert.equals(1, calls)
            local dialog = harness.top()
            assert.equals(ButtonDialog, getmetatable(dialog))
            local anchor = dialog.anchor()
            assert.equals(bar.left_button.image.dimen, anchor)
            harness.tick()
            assert.truthy(dialog.movable.dimen.y >= anchor.y + anchor.h,
                dialog.movable.dimen.y .. " < " .. anchor.y + anchor.h)
            assert.is_true(fm:handleEvent(Event:new("Gesture", harness.gesture("hold_release", x, y))))
            -- The buttons run from / down to the folder shown; the one before last is its parent.
            local buttons = dialog.buttons
            buttons[#buttons - 1][1].callback()
            assert.equals(ffiUtil.realpath(lib), fm.file_chooser.path)
        end)
    end)

    describe("a re-layout", function()
        local function in_look(fm, id)
            assert.equals(KoTitleBar, getmetatable(fm.title_bar))
            assert.equals(fm.title_bar, fm.file_chooser.title_bar)
            assert.equals(Looks.get(id), fm.title_bar.look)
            assert.equals(Screen:getWidth(), fm.title_bar.width)
            assert.equals(Screen:getWidth(), fm.title_bar:getSize().w)
            rows_fit(fm)
        end

        it("builds a new bar through reinit", function()
            local fm = fm_on_top()
            local before = fm.title_bar
            fm:reinit()
            assert.is_not.equals(before, fm.title_bar)
            in_look(fm, "diner")
        end)

        it("follows a rotation to landscape and back", function()
            local fm = fm_on_top()
            local mode = Screen:getRotationMode()
            restores[#restores + 1] = function()
                Screen:setRotationMode(mode)
            end
            fm:onSetRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE)
            assert.truthy(Screen:getWidth() > Screen:getHeight())
            in_look(fm, "diner")
            fm:onSetRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
            assert.truthy(Screen:getWidth() < Screen:getHeight())
            in_look(fm, "diner")
        end)

        it("follows a look change through the settings menu", function()
            local fm = fm_on_top()
            local look
            for _, row in ipairs(package.loaded["menu"].items()) do
                if row.kopanda_key == "look" then
                    look = row
                end
            end
            item_with(look.sub_item_table_func(), "Editorial").callback()
            in_look(fm, "editorial")
            assert.equals(Looks.get("editorial"), fm[1].look)
        end)
    end)

    it("is KOReader's when KoPanda is refused", function()
        package.loaded["guards"].refused = function()
            return true
        end
        local fm = harness.show_fm(lib)
        assert.equals(TitleBar, getmetatable(fm.title_bar))
        assert.is_nil(rawget(TitleBar, "new"))
    end)

    describe("every other title bar", function()
        it("stays KOReader's in a Menu, a PathChooser, History and Collections", function()
            local fm = fm_on_top()
            assert.is_nil(rawget(TitleBar, "new"))
            assert.equals(TitleBar, getmetatable(Menu:new{ title = "T", item_table = {} }.title_bar))
            assert.equals(TitleBar, getmetatable(PathChooser:new{ path = harness.library, ui = fm }.title_bar))
            fm.history:onShowHist()
            assert.equals(TitleBar, getmetatable(fm.history.booklist_menu.title_bar))
            fm.collections:onShowColl()
            assert.equals(TitleBar, getmetatable(fm.collections.booklist_menu.title_bar))
        end)

        it("stays KOReader's in a Menu built in the reader", function()
            fm_on_top()
            harness.open_reader("frankenstein.epub")
            harness.tick()
            assert.equals(TitleBar, getmetatable(Menu:new{ title = "T", item_table = {} }.title_bar))
        end)
    end)
end)
