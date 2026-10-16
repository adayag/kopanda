-- The settings menu's rows, generated from the schema (device-menus' C1 and C3's menu part): one
-- row per key in schema order, cut to a group, each type's row text and tap, and what a write
-- does after it, against a real settings file under the scratch KO_HOME.
describe("the settings menu's rows", function()
    local harness = require("plugin_harness")
    -- spec/home_gestures.lua, required before harness.load() puts the plugin's own home_gestures in
    -- the require cache.
    local gestures = require("home_gestures")
    local InfoMessage = require("ui/widget/infomessage")
    local NetworkMgr = require("ui/network/manager")
    local logger = require("logger")
    local Home, Schema, SchemaMenu, Settings

    before_each(function()
        harness.load()
        Home = require("home")
        Schema = require("schema")
        SchemaMenu = require("menu")
        Settings = require("settings")
    end)

    after_each(function()
        harness.teardown()
    end)

    local function read_file(path)
        local f = io.open(path, "rb")
        if not f then
            return nil
        end
        local bytes = f:read("*a")
        f:close()
        return bytes
    end

    -- The row for key in items.
    local function row(items, key)
        for _, item in ipairs(items) do
            if item.kopanda_key == key then
                return item
            end
        end
    end

    -- The submenu item reading text.
    local function choice(sub, text)
        for _, item in ipairs(sub) do
            if item.text == text then
                return item
            end
        end
    end

    -- Every Settings.set call's key and value, calling through.
    local function record_sets()
        local sets = {}
        local set = Settings.set
        Settings.set = function(key, value)
            sets[#sets + 1] = { key, value }
            return set(key, value)
        end
        finally(function()
            Settings.set = set
        end)
        return sets
    end

    -- The notes on the stack, top first, as their texts.
    local function notes()
        local texts = {}
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == InfoMessage then
                texts[#texts + 1] = widget.text
            end
        end
        return texts
    end

    -- A shown home whose refreshes are appended to log as "refresh", calling through.
    local function home_logging(log)
        gestures.fm_with_home()
        local home = Home.shown
        local refresh = home.refresh
        home.refresh = function(self)
            log[#log + 1] = "refresh"
            return refresh(self)
        end
        return home
    end

    local function connected(value)
        local is_connected = NetworkMgr.isConnected
        NetworkMgr.isConnected = function()
            return value
        end
        finally(function()
            NetworkMgr.isConnected = is_connected
        end)
    end

    describe("the list", function()
        it("has one row per schema key, in schema order, a separator ending each group but the last", function()
            local items = SchemaMenu.items()
            local keys, separated = {}, {}
            for i, item in ipairs(items) do
                keys[i] = item.kopanda_key
                if item.separator then
                    separated[#separated + 1] = item.kopanda_key
                end
            end
            local ids = {}
            for i, entry in ipairs(Schema.keys) do
                ids[i] = entry.id
            end
            assert.same(ids, keys)
            assert.same({ "text_size", "layout.rows", "weather.units", "quote.source", "stats.show",
                "featured.pinned" }, separated)
        end)

        it("cuts to a group's keys, with no separator", function()
            local items = SchemaMenu.items("weather")
            assert.equals(2, #items)
            assert.equals("weather.location", items[1].kopanda_key)
            assert.equals("weather.units", items[2].kopanda_key)
            assert.is_falsy(items[1].separator)
            assert.is_falsy(items[2].separator)
        end)

        it("lists every key for a group with no keys, or no group", function()
            local full = #Schema.keys
            assert.equals(full, #SchemaMenu.items("date"))
            assert.equals(full, #SchemaMenu.items("clock"))
            assert.equals(full, #SchemaMenu.items(nil))
            assert.equals(full, #SchemaMenu.items("nope"))
        end)

        it("leaves out a key of a type with no row, logging it once", function()
            Schema.keys[#Schema.keys + 1] = { id = "bogus.key", type = "bogus", default = 1, label = "Bogus",
                group = "bogus" }
            finally(function()
                Schema.keys[#Schema.keys] = nil
            end)
            local logged = spy.on(logger, "err")
            finally(function()
                logger.err:revert()
            end)
            local items = SchemaMenu.items()
            SchemaMenu.items()
            assert.equals(#Schema.keys - 1, #items)
            assert.is_nil(row(items, "bogus.key"))
            local mentions = 0
            for _, call in ipairs(logged.calls) do
                for _, arg in ipairs(call.vals) do
                    if tostring(arg):find("bogus", 1, true) then
                        mentions = mentions + 1
                        break
                    end
                end
            end
            assert.equals(1, mentions)
        end)
    end)

    describe("a choice row", function()
        it("reads its label and the stored choice, offering the choices as radio items", function()
            local look = row(SchemaMenu.items(), "look")
            assert.equals("Look · Diner", look.text_func())
            local sub = look.sub_item_table_func()
            assert.equals(2, #sub)
            assert.equals("Diner", sub[1].text)
            assert.equals("Editorial", sub[2].text)
            assert.is_true(sub[1].radio)
            assert.is_true(sub[2].radio)
            assert.is_true(sub[1].checked_func())
            assert.is_false(sub[2].checked_func())
        end)

        it("writes another choice once and refreshes a shown home once", function()
            local log = {}
            home_logging(log)
            local sets = record_sets()
            local look = row(SchemaMenu.items(), "look")
            choice(look.sub_item_table_func(), "Editorial").callback()
            assert.same({ { "look", "editorial" } }, sets)
            assert.same({ "refresh" }, log)
            assert.equals("editorial", Settings.get("look"))
            assert.equals("Look · Editorial", look.text_func())
        end)

        it("writes nothing and refreshes nothing for the choice already stored", function()
            assert.is_true(Settings.set("look", "diner"))
            local bytes = read_file(harness.settings_file)
            local log = {}
            home_logging(log)
            local sets = record_sets()
            local look = row(SchemaMenu.items(), "look")
            choice(look.sub_item_table_func(), "Diner").callback()
            assert.same({}, sets)
            assert.same({}, log)
            assert.equals(bytes, read_file(harness.settings_file))
        end)
    end)

    describe("the boolean row", function()
        it("is checked by its value and writes the negation on each tap", function()
            local sets = record_sets()
            local stats = row(SchemaMenu.items(), "stats.show")
            assert.equals("Show reading stats", stats.text or stats.text_func())
            assert.is_true(stats.checked_func())
            stats.callback()
            assert.is_false(stats.checked_func())
            stats.callback()
            assert.is_true(stats.checked_func())
            assert.same({ { "stats.show", false }, { "stats.show", true } }, sets)
        end)
    end)

    describe("the featured row", function()
        -- A book file under the scratch KO_HOME whose sidecar gives its title, so the title read
        -- doesn't depend on what another spec left in CoverBrowser's cache or a fixture's sidecar.
        local function book()
            local DocSettings = require("docsettings")
            local util = require("util")
            local dir = os.getenv("KO_HOME") .. "/menu-spec-books"
            util.makePath(dir)
            local file = dir .. "/pinned.epub"
            local f = assert(io.open(file, "w"))
            f:write("not really an epub")
            f:close()
            local sidecar_dir = DocSettings:getSidecarDir(file, "dir")
            util.makePath(sidecar_dir)
            f = assert(io.open(sidecar_dir .. "/" .. DocSettings.getSidecarFilename(file), "w"))
            f:write('return { doc_props = { title = "The Pinned Book" } }')
            f:close()
            return file
        end

        it("reads Most recent with no pin, offering only that, checked", function()
            local featured = row(SchemaMenu.items(), "featured.pinned")
            assert.equals("Featured book · Most recent", featured.text_func())
            local sub = featured.sub_item_table_func()
            assert.equals(1, #sub)
            assert.equals("Most recent book", sub[1].text)
            assert.is_true(sub[1].radio)
            assert.is_true(sub[1].checked_func())
        end)

        it("reads the pinned book's title and unpins from Most recent book", function()
            assert.is_true(Settings.set("featured.pinned", book()))
            local featured = row(SchemaMenu.items(), "featured.pinned")
            assert.equals("Featured book · The Pinned Book", featured.text_func())
            local sub = featured.sub_item_table_func()
            assert.equals(2, #sub)
            assert.equals("Most recent book", sub[1].text)
            assert.equals("The Pinned Book", sub[2].text)
            assert.is_true(sub[2].radio)
            assert.is_false(sub[1].checked_func())
            assert.is_true(sub[2].checked_func())
            local sets = record_sets()
            sub[1].callback()
            assert.same({ { "featured.pinned", false } }, sets)
            assert.is_true(sub[1].checked_func())
            assert.equals("Featured book · Most recent", featured.text_func())
        end)

        it("reads a pin to a gone file as Most recent, and its tap writes false", function()
            local gone = os.getenv("KO_HOME") .. "/kopanda-gone-book.epub"
            assert.is_true(Settings.set("featured.pinned", gone))
            local featured = row(SchemaMenu.items(), "featured.pinned")
            assert.equals("Featured book · Most recent", featured.text_func())
            local sub = featured.sub_item_table_func()
            assert.equals(1, #sub)
            assert.is_true(sub[1].checked_func())
            local sets = record_sets()
            sub[1].callback()
            assert.same({ { "featured.pinned", false } }, sets)
        end)
    end)

    describe("the location row", function()
        it("stores the picked place exactly, keeps the menu open and redraws its row", function()
            local LocationSearch = require("location_search")
            local paris = { name = "Paris, Île-de-France", latitude = 48.85341, longitude = 2.3488 }
            local ask = LocationSearch.ask
            LocationSearch.ask = function(on_pick)
                on_pick({ name = paris.name, latitude = paris.latitude, longitude = paris.longitude })
            end
            finally(function()
                LocationSearch.ask = ask
            end)
            local location = row(SchemaMenu.items(), "weather.location")
            assert.equals("Weather location · Chicago, Illinois", location.text_func())
            assert.is_true(location.keep_menu_open)
            local updates = 0
            location.callback({
                updateItems = function()
                    updates = updates + 1
                end,
            })
            assert.same(paris, Settings.get("weather.location"))
            assert.same(paris, dofile(harness.settings_file)["weather.location"])
            assert.equals(1, updates)
            assert.equals("Weather location · Paris, Île-de-France", location.text_func())
        end)
    end)

    describe("the weather after a write", function()
        local function fetch_logging(log)
            local Weather = require("weather")
            local fetch = Weather.fetch
            Weather.fetch = function()
                log[#log + 1] = "fetch"
                return true
            end
            finally(function()
                Weather.fetch = fetch
            end)
        end

        it("fetches once before the home's one refresh when connected", function()
            local log = {}
            home_logging(log)
            connected(true)
            fetch_logging(log)
            local units = row(SchemaMenu.items(), "weather.units")
            choice(units.sub_item_table_func(), "Celsius").callback()
            assert.same({ "fetch", "refresh" }, log)
        end)

        it("only refreshes when offline", function()
            local log = {}
            home_logging(log)
            connected(false)
            fetch_logging(log)
            local units = row(SchemaMenu.items(), "weather.units")
            choice(units.sub_item_table_func(), "Celsius").callback()
            assert.same({ "refresh" }, log)
        end)

        it("doesn't fetch for a key that isn't the weather's", function()
            local log = {}
            home_logging(log)
            connected(true)
            fetch_logging(log)
            local look = row(SchemaMenu.items(), "look")
            choice(look.sub_item_table_func(), "Editorial").callback()
            assert.same({ "refresh" }, log)
        end)
    end)

    describe("the Layout and Launcher rows", function()
        local Editor

        before_each(function()
            Editor = require("editor")
        end)

        it("opens edit layout from the next tick", function()
            gestures.fm_with_home()
            local layout = row(SchemaMenu.items(), "layout.rows")
            assert.equals("Layout", layout.text or layout.text_func())
            assert.is_nil(layout.checked_func)
            assert.is_falsy(layout.keep_menu_open)
            layout.callback()
            assert.is_nil(Editor.shown)
            harness.tick()
            assert.is_not_nil(Editor.shown)
            assert.equals("edit_layout", Editor.shown.spec.screen)
        end)

        it("opens launcher management from the next tick", function()
            gestures.fm_with_home()
            local launcher = row(SchemaMenu.items(), "launcher.entries")
            assert.equals("Launcher", launcher.text or launcher.text_func())
            assert.is_nil(launcher.checked_func)
            assert.is_falsy(launcher.keep_menu_open)
            launcher.callback()
            assert.is_nil(Editor.shown)
            harness.tick()
            assert.is_not_nil(Editor.shown)
            assert.equals("launcher", Editor.shown.spec.screen)
        end)
    end)

    describe("a write that fails", function()
        it("shows a note, logs and leaves the settings file as it was when the write is refused", function()
            assert.is_true(Settings.set("text_size", "large"))
            local bytes = read_file(harness.settings_file)
            local log = {}
            home_logging(log)
            local logged = spy.on(logger, "err")
            local set = Settings.set
            Settings.set = function()
                return false, "kopanda-test: refused"
            end
            finally(function()
                Settings.set = set
                logger.err:revert()
            end)
            local look = row(SchemaMenu.items(), "look")
            choice(look.sub_item_table_func(), "Editorial").callback()
            assert.same({ "Couldn't save Look." }, notes())
            assert.equals(bytes, read_file(harness.settings_file))
            assert.same({}, log)
            assert.spy(logged).was.called()
        end)

        it("logs a raising callback and writes nothing", function()
            assert.is_true(Settings.set("text_size", "large"))
            local bytes = read_file(harness.settings_file)
            local sets = record_sets()
            local logged = spy.on(logger, "err")
            local get = Settings.get
            Settings.get = function()
                error("kopanda-test: read failed")
            end
            finally(function()
                Settings.get = get
                logger.err:revert()
            end)
            local stats = row(SchemaMenu.items(), "stats.show")
            assert.has_no.errors(function()
                stats.callback()
            end)
            assert.is_false(stats.checked_func())
            assert.equals("Show reading stats", stats.text or stats.text_func())
            local look = row(SchemaMenu.items(), "look")
            assert.equals("Look", look.text_func())
            assert.same({}, row(SchemaMenu.items(), "featured.pinned").sub_item_table_func())
            assert.same({}, sets)
            assert.equals(bytes, read_file(harness.settings_file))
            local found = false
            for _, call in ipairs(logged.calls) do
                for _, arg in ipairs(call.vals) do
                    if tostring(arg):find("kopanda-test: read failed", 1, true) then
                        found = true
                    end
                end
            end
            assert.is_true(found)
        end)
    end)
end)
