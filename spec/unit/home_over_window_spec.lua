-- The home brought up while a chrome window is shown: the file manager's top menu, opened by a tap at the top centre
-- that the window forwards (HomeGestures.forward), and its Home tab tapped, which runs the plugin's goHome. The home
-- closes the window, as a window's show closes the home, so it never hides one, and a target run from it shows its
-- window on top at its first page.
describe("the home brought up over a chrome window", function()
    local harness = require("plugin_harness")
    local fixture = require("shelf_fixture")
    local library_fixture = require("library_fixture")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local AuthorsScreen, Home, LauncherEntries, Library, NavBar, SeriesScreen

    local LIST = { kind = "list" }
    local NAMES = { kopanda_home = true, kopanda_library = true, kopanda_series = true, kopanda_authors = true }

    before_each(function()
        harness.load()
        AuthorsScreen = package.loaded["authors_screen"]
        Home = package.loaded["home"]
        LauncherEntries = package.loaded["launcher_entries"]
        Library = package.loaded["library"]
        NavBar = package.loaded["nav_bar"]
        SeriesScreen = package.loaded["series_screen"]
        -- The library's root on one page; thirty authors give the Authors list more than one.
        local records = {}
        for i = 1, 30 do
            records[i] = fixture.book(("Book %02d"):format(i), { authors = { ("Ann B%02d"):format(i) } })
        end
        library_fixture.install({ [library_fixture.ROOT] = { books = library_fixture.books(2) } })
        fixture.install(records)
    end)

    after_each(function()
        library_fixture.restore()
        harness.teardown()
    end)

    -- KoPanda's windows on the stack, top first.
    local function kopanda_windows()
        local out = {}
        for _, widget in ipairs(harness.stack()) do
            if NAMES[widget.name] then
                out[#out + 1] = widget
            end
        end
        return out
    end

    -- The windows the home is brought up over, each away from where a target would put it where it
    -- can be: the Authors list at its page 2.
    local OPEN = {
        { name = "Library", module = "library", show = function()
            return Library.show{}
        end },
        { name = "Authors", module = "authors_screen", show = function()
            local screen = AuthorsScreen.show{ view = LIST, page = 2 }
            assert.equals(2, screen.page)
            return screen
        end },
        { name = "Series", module = "series_screen", show = function()
            return SeriesScreen.show{}
        end },
    }

    -- The file manager with the window of open shown, then the home brought up over it through the
    -- top menu's Home tab. Returns the file manager and the window.
    local function home_over(open)
        local fm = harness.show_fm()
        harness.tick(2)
        Home.close()
        local window = open.show()
        assert.is_not_nil(window)
        harness.tick(2)
        assert.equals(window, harness.top())
        local width = require("device").screen:getWidth()
        UIManager:sendEvent(Event:new("Gesture", harness.gesture("tap", width / 2, 2)))
        local menu = fm.menu.menu_container
        assert.is_not_nil(menu)
        assert.equals(menu, harness.top())
        menu[1]:switchMenuTab(2)
        harness.tick(2)
        return fm, window
    end

    for _, open in ipairs(OPEN) do
        it("closes the " .. open.name .. " window and goes up alone over the file manager", function()
            local fm, window = home_over(open)
            assert.is_nil(require(open.module).shown)
            assert.is_false(UIManager:isWidgetShown(window))
            assert.is_not_nil(Home.shown)
            assert.equals(Home.shown, harness.top())
            assert.equals(fm, harness.top(2))
            assert.same({ Home.shown }, kopanda_windows())
        end)
    end

    -- Each target the home runs, and the module of the window it shows.
    local TARGETS = {
        { name = "launcher's Library entry", module = "library", run = function()
            LauncherEntries.run({ kind = "kopanda", target = "library" }, {})
        end },
        { name = "launcher's Authors entry", module = "authors_screen", run = function()
            LauncherEntries.run({ kind = "kopanda", target = "authors" }, {})
        end },
        { name = "nav bar's Library tab", module = "library", run = function()
            NavBar.run("library", "home")
        end },
        { name = "nav bar's Authors tab", module = "authors_screen", run = function()
            NavBar.run("authors", "home")
        end },
    }

    -- The folder or view a window shows, and its page.
    local function at(window)
        if window.dir then
            return { window.dir, window.page }
        end
        return { window:view(), window.page }
    end

    for _, open in ipairs(OPEN) do
        for _, target in ipairs(TARGETS) do
            it("over the " .. open.name .. " window, runs the " .. target.name .. ": the home closes and its "
                .. "window is on top at its first page", function()
                    local fm = home_over(open)
                    target.run()
                    local shown = require(target.module).shown
                    assert.is_not_nil(shown)
                    assert.is_nil(Home.shown)
                    assert.equals(shown, harness.top())
                    assert.equals(fm, harness.top(2))
                    assert.same({ shown }, kopanda_windows())
                    local first = target.module == "library" and { library_fixture.ROOT, 1 } or { LIST, 1 }
                    assert.same(first, at(shown))
                end)
        end
    end
end)
