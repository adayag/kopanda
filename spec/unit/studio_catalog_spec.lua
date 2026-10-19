-- The studio's checked-in catalog is bin/catalog-json's output, byte for byte, and holds what the
-- launcher editor offers: the file-browser action sections, the bundled plugins the file manager
-- loads, the icon registry and the screen tables.
describe("studio/src/catalog.json", function()
    local rapidjson = require("rapidjson")
    local root = os.getenv("KOPANDA_ROOT")
    local emulator = os.getenv("KOPANDA_EMULATOR")

    -- Runs a shell command, returning its stdout and exit status, read from the output as
    -- spec/unit/studio_schema_spec.lua does. stderr goes to a file of its own, returned third.
    local function run(command)
        local errors = os.tmpname()
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "' 2>'" .. errors .. "'; s=$?; echo; echo $s"))
        local output = pipe:read("*a")
        pipe:close()
        local file = assert(io.open(errors, "rb"))
        local stderr = file:read("*a")
        file:close()
        os.remove(errors)
        local body, status = output:match("^(.*)\n(%d+)\n$")
        return body, tonumber(status), stderr
    end

    local function read(path)
        local file = assert(io.open(path, "rb"))
        local content = file:read("*a")
        file:close()
        return content
    end

    -- bin/catalog-json's output, run once for the file.
    local fresh_output
    local function fresh()
        if not fresh_output then
            local output, status, stderr = run("cd '" .. root .. "' && bin/catalog-json")
            assert.equals(0, status, stderr)
            fresh_output = output
        end
        return fresh_output
    end

    local function catalog()
        return rapidjson.decode(fresh())
    end

    -- Whether the file at path holds what a fresh bin/catalog-json prints; when not, the message
    -- names the fix.
    local function matches_fresh_catalog(path)
        if read(path) == fresh() then
            return true
        end
        return false, "studio/src/catalog.json is stale: run npm run catalog in studio/"
    end

    local function ids(actions)
        local list = {}
        for _, action in ipairs(actions) do
            list[#list + 1] = action.id
        end
        return list
    end

    local function every_action_id(sections)
        local all = {}
        for _, section in ipairs(sections) do
            for _, action in ipairs(section.actions) do
                all[action.id] = section.title
            end
        end
        return all
    end

    it("is byte-identical to a fresh bin/catalog-json run", function()
        local same, message = matches_fresh_catalog(root .. "/studio/src/catalog.json")
        assert.is_true(same, message)
    end)

    it("fails naming npm run catalog when the file lacks an action a fresh run lists", function()
        local stale_catalog = catalog()
        table.remove(stale_catalog.actions[1].actions, 1)
        local stale = os.tmpname()
        local file = assert(io.open(stale, "wb"))
        file:write(rapidjson.encode(stale_catalog, { sort_keys = true, pretty = true }), "\n")
        file:close()

        local same, message = matches_fresh_catalog(stale)
        os.remove(stale)

        assert.is_false(same)
        assert.truthy(message:find("npm run catalog", 1, true))
    end)

    it("prints only the JSON on stdout, the same bytes on every run", function()
        local second, status = run("cd '" .. root .. "' && bin/catalog-json")
        assert.equals(0, status)
        assert.equals(fresh(), second)
        assert.equals("{", fresh():sub(1, 1))
        assert.equals("}\n", fresh():sub(-2))
    end)

    describe("actions", function()
        it("are the action tree's four file-browser sections, in order, and no reader section", function()
            local titles = {}
            for _, section in ipairs(catalog().actions) do
                titles[#titles + 1] = section.title
            end
            assert.same({ "General", "Device", "Screen and lights", "File browser" }, titles)
        end)

        it("list history in General as History, in English", function()
            local general = catalog().actions[1]
            local history
            for _, action in ipairs(general.actions) do
                if action.id == "history" then
                    history = action
                end
            end
            assert.same({ id = "history", title = "History" }, history)
        end)

        -- toggle_wifi is a `none` action (frontend/dispatcher.lua:124); ignore_hold_corners is an
        -- `absolutenumber` one (:101) and set_night_mode a `string` one (:139), both in the
        -- file-browser sections and available on the emulator, whose ticks store a value, not true.
        it("hold only actions whose tick stores true", function()
            local all = every_action_id(catalog().actions)
            assert.equals("Device", all.toggle_wifi)
            assert.is_nil(all.ignore_hold_corners)
            assert.is_nil(all.set_night_mode)
        end)

        -- add_location_to_history is a reader-only `none` action (frontend/dispatcher.lua:202).
        it("leave out the reader's actions", function()
            assert.is_nil(every_action_id(catalog().actions).add_location_to_history)
        end)

        -- Reading statistics registers toggle_statistics when the file manager instantiates it
        -- (plugins/statistics.koplugin/main.lua:98).
        it("include the actions bundled plugins register", function()
            assert.equals("General", every_action_id(catalog().actions).toggle_statistics)
        end)

        it("are listed with ids unique within a section", function()
            for _, section in ipairs(catalog().actions) do
                local seen = {}
                for _, id in ipairs(ids(section.actions)) do
                    assert.is_nil(seen[id], id)
                    seen[id] = true
                end
            end
        end)
    end)

    describe("plugins", function()
        -- BUILTIN_PLUGINS is local to frontend/pluginloader.lua (:26-64), so its names are read
        -- from the file.
        local function builtin_plugins()
            local source = read(emulator .. "/frontend/pluginloader.lua")
            local body = assert(source:match("local BUILTIN_PLUGINS = (%b{})"))
            local names = {}
            for name in body:gmatch('%["([%w_]+)"%] = true') do
                names[name] = true
            end
            return names
        end

        it("are bundled with KOReader, none external", function()
            local builtin = builtin_plugins()
            assert.truthy(builtin.statistics)
            local plugins = catalog().plugins
            assert.is_true(#plugins > 0)
            for _, plugin in ipairs(plugins) do
                assert.is_true(builtin[plugin.name] == true, plugin.name)
            end
        end)

        it("leave out the is_doc_only plugins and kopanda", function()
            for _, plugin in ipairs(catalog().plugins) do
                assert.not_equals("autoturn", plugin.name)
                assert.not_equals("coverimage", plugin.name)
                assert.not_equals("kosync", plugin.name)
                assert.not_equals("perceptionexpander", plugin.name)
                assert.not_equals("kopanda", plugin.name)
            end
        end)

        it("are labelled by their fullname and sorted by label", function()
            local plugins = catalog().plugins
            local labels = {}
            local statistics
            for _, plugin in ipairs(plugins) do
                labels[#labels + 1] = plugin.label
                if plugin.name == "statistics" then
                    statistics = plugin
                end
            end
            -- plugins/statistics.koplugin/_meta.lua's fullname.
            assert.same({ name = "statistics", label = "Reading statistics" }, statistics)
            local sorted = { unpack(labels) }
            table.sort(sorted)
            assert.same(sorted, labels)
        end)
    end)

    describe("icons", function()
        it("are the registry's entries in order, each with its label and its file's SVG text", function()
            require("plugin_harness")
            local Icons = require("icons")
            local icons = catalog().icons
            local expected_ids, got_ids, has_action = {}, {}, false
            for i, entry in ipairs(Icons.entries) do
                expected_ids[i] = entry.id
            end
            for i, icon in ipairs(icons) do
                got_ids[i] = icon.id
                has_action = has_action or icon.id == "action"
            end
            assert.same(expected_ids, got_ids)
            assert.is_true(has_action)
            for i, entry in ipairs(Icons.entries) do
                assert.equals(entry.label, icons[i].label)
                assert.equals(read(root .. "/kopanda.koplugin/" .. entry.file), icons[i].svg)
            end
        end)
    end)

    describe("screens", function()
        it("are the KoPanda and KOReader tables' labels and icons", function()
            require("plugin_harness")
            local LauncherEntries = require("launcher_entries")
            local function label_and_icon(by_target)
                local rows = {}
                for target, row in pairs(by_target) do
                    rows[target] = { label = row.label, icon = row.icon }
                end
                return rows
            end
            assert.same({
                kopanda = label_and_icon(LauncherEntries.KOPANDA),
                koreader = label_and_icon(LauncherEntries.KOREADER),
            }, catalog().screens)
        end)
    end)

    it("refuses with exit 2 naming the path when there is no luajit at KOPANDA_EMULATOR", function()
        local _, status, stderr = run("cd '" .. root .. "' && KOPANDA_EMULATOR=/nonexistent bin/catalog-json")
        assert.equals(2, status)
        assert.truthy(stderr:find("/nonexistent", 1, true))
    end)
end)
