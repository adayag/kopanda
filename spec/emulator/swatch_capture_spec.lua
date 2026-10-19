-- The swatch screen: the swatch scenario patch opens Tools › KoPanda › Swatches once the home has settled, and the
-- capture is taken on the swatch's own settled signal.
describe("the swatch screen", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-swatch.lua"

    for _, profile in ipairs({ "colorsoft", "paperwhite" }) do
        it("opens from the Tools menu and settles on " .. profile, function()
            local result = driver.capture{
                profile = profile,
                plugin_dir = plugin,
                patches = { scenario },
                shot_screen = "swatch",
            }
            assert.is_nil(result.sidecar.error)
            assert.equals("swatch", result.sidecar.screen)
        end)
    end
end)
