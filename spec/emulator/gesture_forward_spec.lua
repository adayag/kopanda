-- A Gestures-plugin binding performed on the home runs its action, and the History list it dispatches is shown by
-- the file manager's History module over the home. The gesture-forward scenario patch binds the file manager's
-- bottom-right corner tap to History, taps it on the first home and reports what it saw on the "scenario" screen.
describe("forwarding a Gestures binding from the home on the emulator", function()
    require("commonrequire")
    local driver = require("emulator.driver")
    local root = os.getenv("KOPANDA_ROOT")
    local plugin = root .. "/kopanda.koplugin"
    local scenario = root .. "/spec/emulator/scenarios/2-scenario-gesture-forward.lua"

    it("shows the History a corner tap dispatches over the home", function()
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            patches = { scenario },
            shot_screen = "scenario",
        }
        local sidecar = result.sidecar
        assert.is_nil(sidecar.error)
        assert.equals("scenario", sidecar.screen)
        assert.is_true(sidecar.home_shown)
        assert.is_true(sidecar.history_shown)
    end)
end)
