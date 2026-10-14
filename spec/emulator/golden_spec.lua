describe("probe goldens", function()
    require("commonrequire")
    local lfs = require("libs/libkoreader-lfs")
    local rapidjson = require("rapidjson")
    local driver = require("emulator.driver")
    local golden = require("emulator.golden")
    local root = os.getenv("KOPANDA_ROOT")
    local ko_home = os.getenv("KO_HOME")
    local probe = root .. "/spec/fixtures/probe.koplugin"
    local fixtures = root .. "/spec/fixtures/png"

    local counter = 0
    local function fresh_dir(name)
        counter = counter + 1
        local dir = string.format("%s/golden-spec-%s-%d", ko_home, name, counter)
        assert(lfs.mkdir(dir))
        return dir
    end

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    -- A capture result as driver.capture returns it, made from a committed 4×4 fixture
    -- copied into a fresh capture dir, so the golden helper's file handling is tested
    -- without an emulator run.
    local function fake_capture(fixture)
        local dir = fresh_dir("capture")
        local png = dir .. "/colorsoft.png"
        write(png, read(fixtures .. "/" .. fixture))
        local w, h = driver.png_size(png)
        return { png = png, width = w, height = h,
            sidecar = { paint_ms = 12.5, koreader = "e1fe1ac", width = w, height = h } }
    end

    local function error_of(fn, ...)
        local ok, err = pcall(fn, ...)
        assert.is_false(ok)
        return tostring(err)
    end

    local function contains(text, needle)
        assert.truthy(text:find(needle, 1, true), "expected «" .. needle .. "» in: " .. text)
    end

    for _, profile in ipairs({ "colorsoft", "paperwhite" }) do
        it("matches the committed probe golden on " .. profile, function()
            local result = driver.capture{ profile = profile, plugin_dir = probe, library_dir = fresh_dir("library") }
            local checked = golden.assert_golden("probe", profile, result)
            if os.getenv("KOPANDA_UPDATE_GOLDENS") ~= "1" then
                assert.is_nil(checked.updated)
                assert.is_true(checked.ok)
            end
        end)
    end

    it("fails on a missing golden naming the regeneration flag and the path", function()
        local dir = fresh_dir("goldens")
        local err = error_of(golden.check, "probe", "colorsoft", fake_capture("base.png"),
            { golden_dir = dir, update = false })
        contains(err, "no golden at " .. dir .. "/probe-colorsoft.png")
        contains(err, "KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/golden_spec.lua")
        assert.is_nil(lfs.attributes(dir .. "/probe-colorsoft.png", "mode"))
    end)

    it("writes the capture as the golden with its sidecar when updating", function()
        local dir = fresh_dir("goldens")
        local capture = fake_capture("base.png")
        local result = golden.check("probe", "colorsoft", capture, { golden_dir = dir, update = true })
        assert.same({ updated = true }, result)
        assert.equals(read(capture.png), read(dir .. "/probe-colorsoft.png"))
        local sidecar = rapidjson.decode(read(dir .. "/probe-colorsoft.json"))
        assert.equals("probe", sidecar.name)
        assert.equals("colorsoft", sidecar.profile)
        assert.equals(4, sidecar.width)
        assert.equals(4, sidecar.height)
        assert.equals(12.5, sidecar.paint_ms)
        assert.equals("e1fe1ac", sidecar.koreader)
        assert.truthy(tostring(sidecar.captured_at):match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"),
            sidecar.captured_at)
        assert.same({}, sidecar.masks)
        assert.truthy(read(dir .. "/probe-colorsoft.json"):find('"masks":%s*%[%s*%]'), "masks not a JSON array")
    end)

    it("keeps the masks and notes of an existing sidecar when updating", function()
        local dir = fresh_dir("goldens")
        local masks = { { x = 1, y = 1, w = 2, h = 2 } }
        write(dir .. "/probe-colorsoft.json",
            rapidjson.encode({ name = "probe", masks = masks, notes = "clock masked" }))
        golden.check("probe", "colorsoft", fake_capture("block.png"), { golden_dir = dir, update = true })
        local sidecar = rapidjson.decode(read(dir .. "/probe-colorsoft.json"))
        assert.same(masks, sidecar.masks)
        assert.equals("clock masked", sidecar.notes)
    end)

    it("compares against the golden with the sidecar's masks", function()
        local dir = fresh_dir("goldens")
        local artifacts = fresh_dir("artifacts") .. "/goldens"
        golden.check("probe", "colorsoft", fake_capture("base.png"), { golden_dir = dir, update = true })
        local block = fake_capture("block.png")
        local err = error_of(golden.check, "probe", "colorsoft", block,
            { golden_dir = dir, update = false, artifact_dir = artifacts })
        local actual = artifacts .. "/probe-colorsoft.actual.png"
        local diff = artifacts .. "/probe-colorsoft.diff.png"
        contains(err, dir .. "/probe-colorsoft.png")
        contains(err, actual)
        contains(err, diff)
        contains(err, "25.00 %")
        assert.equals(read(block.png), read(actual))
        assert.equals("file", lfs.attributes(diff, "mode"))

        local sidecar_path = dir .. "/probe-colorsoft.json"
        local sidecar = rapidjson.decode(read(sidecar_path))
        sidecar.masks = { { x = 1, y = 1, w = 2, h = 2 } }
        write(sidecar_path, rapidjson.encode(sidecar))
        assert.is_nil(golden.check("probe", "colorsoft", fake_capture("block.png"),
            { golden_dir = dir, update = false, artifact_dir = artifacts }).updated)
    end)

    it("keeps a failing run's capture and diff under spec/.artifacts/goldens by default", function()
        local dir = fresh_dir("goldens")
        golden.check("default-artifacts", "colorsoft", fake_capture("base.png"), { golden_dir = dir, update = true })
        local err = error_of(golden.check, "default-artifacts", "colorsoft", fake_capture("block.png"),
            { golden_dir = dir, update = false })
        local artifacts = root .. "/spec/.artifacts/goldens"
        local actual = artifacts .. "/default-artifacts-colorsoft.actual.png"
        local diff = artifacts .. "/default-artifacts-colorsoft.diff.png"
        local actual_mode, diff_mode = lfs.attributes(actual, "mode"), lfs.attributes(diff, "mode")
        os.remove(actual)
        os.remove(diff)
        contains(err, actual)
        contains(err, diff)
        assert.equals("file", actual_mode)
        assert.equals("file", diff_mode)
    end)

    it("removes a stale capture and diff when the capture matches", function()
        local dir = fresh_dir("goldens")
        local artifacts = fresh_dir("artifacts")
        golden.check("probe", "colorsoft", fake_capture("base.png"), { golden_dir = dir, update = true })
        write(artifacts .. "/probe-colorsoft.actual.png", "stale")
        write(artifacts .. "/probe-colorsoft.diff.png", "stale")
        local result = golden.check("probe", "colorsoft", fake_capture("base.png"),
            { golden_dir = dir, update = false, artifact_dir = artifacts })
        assert.is_true(result.ok)
        assert.is_nil(lfs.attributes(artifacts .. "/probe-colorsoft.actual.png", "mode"))
        assert.is_nil(lfs.attributes(artifacts .. "/probe-colorsoft.diff.png", "mode"))
    end)

    it("fails a capture of the wrong size on its size, pointing at the profile", function()
        local dir = fresh_dir("goldens")
        golden.check("probe", "colorsoft", fake_capture("base.png"), { golden_dir = dir, update = true })
        local wide = fake_capture("wide.png")
        local err = error_of(golden.check, "probe", "colorsoft", wide, { golden_dir = dir, update = false })
        contains(err, "5×4")
        contains(err, "4×4")
        contains(err, "profile colorsoft")
        assert.is_nil(err:find("differ", 1, true))
    end)
end)
