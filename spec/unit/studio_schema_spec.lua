-- The studio's checked-in schema JSON is bin/schema-json's output, byte for byte.
describe("studio/src/schema.json", function()
    local rapidjson = require("rapidjson")
    local root = os.getenv("KOPANDA_ROOT")

    -- Runs a shell command, returning its combined output and exit status, read from the
    -- output as spec/unit/schema_json_spec.lua does.
    local function run(command)
        local quoted = command:gsub("'", "'\\''")
        local pipe = assert(io.popen("sh -c '" .. quoted .. "' 2>&1; s=$?; echo; echo $s"))
        local output = pipe:read("*a")
        pipe:close()
        local body, status = output:match("^(.*)\n(%d+)\n$")
        return body, tonumber(status)
    end

    local function read(path)
        local file = assert(io.open(path, "rb"))
        local content = file:read("*a")
        file:close()
        return content
    end

    -- Whether the file at path holds what a fresh bin/schema-json prints; when not, the message
    -- names the fix.
    local function matches_fresh_schema(path)
        local fresh, status = run("cd '" .. root .. "' && bin/schema-json")
        assert.equals(0, status, fresh)
        if read(path) == fresh then
            return true
        end
        return false, "studio/src/schema.json is stale: run npm run schema in studio/"
    end

    it("is byte-identical to a fresh bin/schema-json run", function()
        local same, message = matches_fresh_schema(root .. "/studio/src/schema.json")
        assert.is_true(same, message)
    end)

    it("fails naming npm run schema when the file differs from bin/schema-json", function()
        local fresh = run("cd '" .. root .. "' && bin/schema-json")
        local schema = rapidjson.decode(fresh)
        table.insert(schema.keys, { id = "extra", type = "boolean", default = false, label = "Extra",
            group = "extra" })
        local stale = os.tmpname()
        local file = assert(io.open(stale, "wb"))
        file:write(rapidjson.encode(schema, { sort_keys = true, pretty = true }), "\n")
        file:close()

        local same, message = matches_fresh_schema(stale)
        os.remove(stale)

        assert.is_false(same)
        assert.truthy(message:find("npm run schema", 1, true))
    end)

    it("fails naming npm run schema when the file differs by a same-length edit", function()
        local fresh = run("cd '" .. root .. "' && bin/schema-json")
        local edited, count = fresh:gsub('"Look"', '"Lool"', 1)
        assert.equals(1, count)
        assert.equals(#fresh, #edited)
        local stale = os.tmpname()
        local file = assert(io.open(stale, "wb"))
        file:write(edited)
        file:close()

        local same, message = matches_fresh_schema(stale)
        os.remove(stale)

        assert.is_false(same)
        assert.truthy(message:find("npm run schema", 1, true))
    end)
end)
