-- bin/schema-json prints the schema as sorted-key JSON for the studio.
describe("bin/schema-json", function()
    local rapidjson = require("rapidjson")
    local root = os.getenv("KOPANDA_ROOT")

    -- Runs a shell command, returning its combined output and exit status, read from the
    -- output as spec/unit/check_spec.lua does.
    local function run(command)
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "' 2>&1; s=$?; echo; echo $s"))
        local output = pipe:read("*a")
        pipe:close()
        local body, status = output:match("^(.*)\n(%d+)\n$")
        return body, tonumber(status)
    end

    it("prints the schema as JSON, the same bytes on every run", function()
        local first, first_status = run("cd '" .. root .. "' && bin/schema-json")
        local second, second_status = run("cd '" .. root .. "' && bin/schema-json")
        assert.equals(0, first_status)
        assert.equals(0, second_status)
        assert.equals(first, second)
        assert.same(dofile(root .. "/kopanda.koplugin/schema.lua"), rapidjson.decode(first))
    end)

    it("sorts object keys", function()
        local output = run("cd '" .. root .. "' && bin/schema-json")
        local entry_keys = {}
        for key in output:match('"keys": %[%s*(%b{})'):gmatch('\n            "([%w_]+)":') do
            entry_keys[#entry_keys + 1] = key
        end
        assert.same({ "choices", "default", "group", "id", "label", "type" }, entry_keys)
        assert.truthy(output:find('"keys"', 1, true) < output:find('"version"', 1, true))
    end)

    it("refuses with exit 2 when there is no luajit at KOPANDA_EMULATOR", function()
        local output, status = run("cd '" .. root .. "' && KOPANDA_EMULATOR=/nonexistent bin/schema-json")
        assert.equals(2, status)
        assert.truthy(output:find("/nonexistent", 1, true))
    end)
end)
