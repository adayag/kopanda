-- The launcher's list operations: move and remove within the top level or a folder, add, the count and the kind line.
-- Every result passes the launcher validator and no input is changed.
describe("EntriesEdit", function()
    require("plugin_harness")
    local util = require("util")
    local EntriesEdit = require("entries_edit")
    local Schema = require("schema")
    local Settings = require("settings")

    local launcher
    for _, key in ipairs(Schema.keys) do
        if key.id == "launcher.entries" then
            launcher = key
        end
    end

    local LIBRARY = { kind = "kopanda", target = "library" }
    local SERIES = { kind = "kopanda", target = "series" }
    local AUTHORS = { kind = "kopanda", target = "authors" }
    local HISTORY = { kind = "koreader", target = "history" }
    local SETTINGS = { kind = "kopanda", target = "settings" }
    local WIFI = { kind = "koreader", target = "wifi" }

    local function action(id)
        return { kind = "action", action = id, label = "Action " .. id, icon = "action" }
    end

    local function folder(label, entries)
        return { kind = "folder", label = label, entries = entries }
    end

    -- Six entries: Library, Series, Authors, History, a Tools folder of three, Settings.
    local function board()
        return { LIBRARY, SERIES, AUTHORS, HISTORY, folder("Tools", { action("a"), action("b"), action("c") }),
            SETTINGS }
    end

    -- Runs op on a deep copy of input, then checks the input unchanged and, when op returned a
    -- list, that the validator takes it. Returns what op returned.
    local function run(input, op)
        local before = util.tableDeepCopy(input)
        local result, extra = op(input)
        assert.same(before, input)
        if result ~= nil then
            assert.is_true(Settings.validators.launcher(launcher, result), "the validator refuses the result")
        end
        return result, extra
    end

    it("reads the schema's max_entries", function()
        assert.equals(6, EntriesEdit.max_entries)
    end)

    describe("move", function()
        it("moves a top-level entry by delta within the top level", function()
            local entries = board()
            assert.same({ SERIES, LIBRARY, AUTHORS, HISTORY, entries[5], SETTINGS },
                run(entries, function(e) return EntriesEdit.move(e, { 1 }, 1) end))
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS, entries[5] },
                run(entries, function(e) return EntriesEdit.move(e, { 6 }, -1) end))
        end)

        it("moves a folder's entry within the folder", function()
            local entries = board()
            local moved = run(entries, function(e) return EntriesEdit.move(e, { 5, 3 }, -1) end)
            assert.same({ action("a"), action("c"), action("b") }, moved[5].entries)
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY }, { moved[1], moved[2], moved[3], moved[4] })
            assert.same(SETTINGS, moved[6])
        end)

        it("returns nil past either end of the top level or a folder", function()
            local entries = board()
            assert.is_nil(run(entries, function(e) return EntriesEdit.move(e, { 1 }, -1) end))
            assert.is_nil(run(entries, function(e) return EntriesEdit.move(e, { 6 }, 1) end))
            assert.is_nil(run(entries, function(e) return EntriesEdit.move(e, { 5, 1 }, -1) end))
            assert.is_nil(run(entries, function(e) return EntriesEdit.move(e, { 5, 3 }, 1) end))
        end)
    end)

    describe("remove", function()
        it("removes a top-level entry", function()
            local entries = board()
            local removed, folder_removed = run(entries, function(e) return EntriesEdit.remove(e, { 2 }) end)
            assert.same({ LIBRARY, AUTHORS, HISTORY, entries[5], SETTINGS }, removed)
            assert.is_false(folder_removed)
        end)

        it("removes a folder with its entries", function()
            local entries = board()
            local removed, folder_removed = run(entries, function(e) return EntriesEdit.remove(e, { 5 }) end)
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS }, removed)
            assert.is_false(folder_removed)
        end)

        it("removes a folder's entry and keeps the folder", function()
            local entries = board()
            local removed, folder_removed = run(entries, function(e) return EntriesEdit.remove(e, { 5, 2 }) end)
            assert.same(folder("Tools", { action("a"), action("c") }), removed[5])
            assert.equals(6, #removed)
            assert.is_false(folder_removed)
        end)

        it("removes the folder with its only entry and says so", function()
            local entries = { LIBRARY, folder("Solo", { action("a") }), SETTINGS }
            local removed, folder_removed = run(entries, function(e) return EntriesEdit.remove(e, { 2, 1 }) end)
            assert.same({ LIBRARY, SETTINGS }, removed)
            assert.is_true(folder_removed)
        end)

        it("empties the launcher, which the validator allows", function()
            assert.same({}, run({ LIBRARY }, function(e) return EntriesEdit.remove(e, { 1 }) end))
        end)
    end)

    describe("add", function()
        it("adds into a folder at its end, past six inside it", function()
            local entries = { LIBRARY, folder("Tools", { action("1"), action("2"), action("3"), action("4"),
                action("5"), action("6") }) }
            local added = run(entries, function(e) return EntriesEdit.add(e, action("7"), 2) end)
            assert.equals(7, #added[2].entries)
            assert.same(action("7"), added[2].entries[7])
            assert.same(action("6"), added[2].entries[6])
            assert.equals(2, #added)
        end)

        it("adds a sixth at the end of a top level of five", function()
            local entries = { LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS }
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, SETTINGS, WIFI },
                run(entries, function(e) return EntriesEdit.add(e, WIFI) end))
        end)

        it("adds to the end of the first top-level folder of a full top level", function()
            local entries = { LIBRARY, SERIES, folder("First", { action("a") }), HISTORY,
                folder("Second", { action("b") }), SETTINGS }
            local added = run(entries, function(e) return EntriesEdit.add(e, WIFI) end)
            assert.equals(6, #added)
            assert.same(folder("First", { action("a"), WIFI }), added[3])
            assert.same(folder("Second", { action("b") }), added[5])
        end)

        it("makes the sixth and the new entry a folder labelled More in slot six, with no folder", function()
            local entries = { LIBRARY, SERIES, AUTHORS, HISTORY, WIFI, SETTINGS }
            local added = run(entries, function(e) return EntriesEdit.add(e, action("x")) end)
            assert.same({ LIBRARY, SERIES, AUTHORS, HISTORY, WIFI,
                { kind = "folder", label = "More", entries = { SETTINGS, action("x") } } }, added)
        end)

        it("adds to an empty launcher", function()
            assert.same({ LIBRARY }, run({}, function(e) return EntriesEdit.add(e, LIBRARY) end))
        end)

        it("never adds a folder", function()
            assert.is_nil(run({ LIBRARY }, function(e)
                return EntriesEdit.add(e, folder("New", { action("a") }))
            end))
        end)

        it("doesn't share the added entry's table with the result", function()
            local entry = action("x")
            local added = run({ LIBRARY }, function(e) return EntriesEdit.add(e, entry) end)
            assert.is_not.equals(entry, added[2])
        end)
    end)

    it("counts the top level", function()
        assert.equals(6, EntriesEdit.count(board()))
        assert.equals(0, EntriesEdit.count({}))
    end)

    describe("kind_line", function()
        it("names each kind and its detail", function()
            assert.equals("KoPanda · library", EntriesEdit.kind_line(LIBRARY))
            assert.equals("KOReader · history", EntriesEdit.kind_line(HISTORY))
            assert.equals("Plugin · terminal", EntriesEdit.kind_line({ kind = "plugin", plugin = "terminal",
                action = "x", label = "Terminal", icon = "terminal" }))
            assert.equals("Action · screenshot", EntriesEdit.kind_line({ kind = "action", action = "screenshot",
                label = "Screenshot", icon = "screenshot" }))
            assert.equals("Folder on disk · /mnt/us/books", EntriesEdit.kind_line({ kind = "directory",
                path = "/mnt/us/books", label = "Books" }))
        end)

        it("counts a folder's entries, one in the singular", function()
            assert.equals("Folder · 3 entries ›", EntriesEdit.kind_line(board()[5]))
            assert.equals("Folder · 1 entry ›", EntriesEdit.kind_line(folder("Solo", { action("a") })))
        end)

        it("puts a suffix in place of the detail", function()
            assert.equals("Plugin · plugin missing", EntriesEdit.kind_line({ kind = "plugin", plugin = "gone",
                action = "x", label = "Gone", icon = "action" }, "plugin missing"))
            assert.equals("KOReader · off", EntriesEdit.kind_line(WIFI, "off"))
        end)
    end)
end)
