-- The swatch screen goldens (C11): the swatch scenario patch opens Tools › KoPanda › Swatches
-- once the home has settled, and the capture is taken on the swatch's own settled signal.
describe("the swatch screen goldens", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-swatch.lua"

    for _, profile in ipairs({ "colorsoft", "paperwhite" }) do
        it("match a fresh capture of the swatch screen on " .. profile, function()
            local result = driver.capture{
                profile = profile,
                plugin_dir = plugin,
                patches = { scenario },
                shot_screen = "swatch",
            }
            assert.is_nil(result.sidecar.error)
            assert.equals("swatch", result.sidecar.screen)
            local checked = golden.assert_golden("swatch", profile, result)
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_true(checked.ok)
            end
        end)
    end
end)
