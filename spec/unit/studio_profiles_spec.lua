-- The studio's seed profiles agree with the profiles the emulator specs capture at (C2).
describe("the studio's seed profiles", function()
    local rapidjson = require("rapidjson")
    local root = os.getenv("KOPANDA_ROOT")
    local captured = dofile(root .. "/spec/emulator/profiles.lua")
    local fields = { "width", "height", "dpi", "color" }

    local function read_seed()
        local f = assert(io.open(root .. "/studio/src/server/default-profiles.json", "rb"))
        local data = f:read("*a")
        f:close()
        return assert(rapidjson.decode(data))
    end

    local function sorted_ids(profiles)
        local ids = {}
        for id in pairs(profiles) do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        return ids
    end

    -- One line per field that differs, naming the profile id and the field.
    local function mismatches(seed)
        local found = {}
        for _, id in ipairs(sorted_ids(captured)) do
            for _, field in ipairs(fields) do
                local want, got = captured[id][field], seed[id] and seed[id][field]
                if want ~= got then
                    found[#found + 1] = string.format("%s.%s: seed %s, spec/emulator/profiles.lua %s",
                        id, field, tostring(got), tostring(want))
                end
            end
        end
        return found
    end

    it("holds exactly colorsoft and paperwhite", function()
        assert.same({ "colorsoft", "paperwhite" }, sorted_ids(read_seed()))
    end)

    it("matches spec/emulator/profiles.lua in width, height, dpi and color", function()
        assert.same({}, mismatches(read_seed()))
    end)

    it("names the id and the field of a mismatch", function()
        local seed = read_seed()
        seed.paperwhite.height = seed.paperwhite.height + 1
        local found = mismatches(seed)
        assert.equals(1, #found)
        assert.truthy(found[1]:find("^paperwhite%.height: "))
    end)
end)
