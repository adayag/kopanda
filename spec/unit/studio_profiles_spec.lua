-- The studio's seed profiles agree with the profiles the emulator specs capture at.
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

    it("holds exactly colorsoft, paperwhite and paperwhite7", function()
        assert.same({ "colorsoft", "paperwhite", "paperwhite7" }, sorted_ids(read_seed()))
    end)

    it("captures and seeds the Paperwhite 7th gen at its panel's 1072 by 1448, 300 dpi, in grey", function()
        assert.same({ width = 1072, height = 1448, dpi = 300, color = false }, captured.paperwhite7)
        assert.same({ name = "Paperwhite 7th gen", device = "Kindle Paperwhite (7th gen)",
            width = 1072, height = 1448, dpi = 300, color = false }, read_seed().paperwhite7)
    end)

    it("matches spec/emulator/profiles.lua in width, height, dpi and color", function()
        assert.same({}, mismatches(read_seed()))
    end)

    it("names the id and the field of a mismatch in each compared field", function()
        for _, field in ipairs({ "width", "height", "dpi", "color" }) do
            local seed = read_seed()
            local value = seed.paperwhite[field]
            if type(value) == "boolean" then
                seed.paperwhite[field] = not value
            else
                seed.paperwhite[field] = value + 1
            end
            local found = mismatches(seed)
            assert.equals(1, #found, field)
            assert.truthy(found[1]:find("^paperwhite%." .. field .. ": "), found[1])
        end
    end)
end)
