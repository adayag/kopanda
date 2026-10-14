describe("capturing the KoPanda home on the emulator", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local plugin = os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin"

    local function read(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function count(text, needle)
        local n = 0
        for _ in text:gmatch(needle:gsub("%p", "%%%0")) do
            n = n + 1
        end
        return n
    end

    local function has(list, value)
        for _, v in ipairs(list) do
            if v == value then
                return true
            end
        end
        return false
    end

    for _, name in ipairs({ "colorsoft", "paperwhite" }) do
        it("is taken on the plugin's own settled signal on " .. name, function()
            local profile = driver.profiles[name]
            local result = driver.capture{ profile = name, plugin_dir = plugin }
            assert.equals(profile.width, result.width)
            assert.equals(profile.height, result.height)
            assert.equals("home", result.sidecar.screen)
            assert.is_number(result.sidecar.paint_ms)
            assert.truthy(result.sidecar.paint_ms > 0)
            assert.truthy(has(result.sidecar.plugins, "kopanda"))
            local log = read(result.log)
            assert.equals(1, count(log, "KOPANDA_SHOT: saved"))
            assert.equals(0, count(log, "settle cap"))
        end)
    end
end)
