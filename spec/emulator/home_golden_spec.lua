describe("the placeholder home goldens", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local plugin = os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin"

    for _, profile in ipairs({ "colorsoft", "paperwhite" }) do
        it("match a fresh capture of kopanda.koplugin on " .. profile, function()
            local result = driver.capture{ profile = profile, plugin_dir = plugin }
            local checked = golden.assert_golden("home-placeholder", profile, result)
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)
    end
end)
