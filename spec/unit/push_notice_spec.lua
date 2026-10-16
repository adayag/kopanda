-- Probation and the pull's notices (C10): Home.show tells its finished callback whether the home
-- painted; the first painted home of a process ends probation and shows the apply patch's result;
-- a refused plugin shows the result only when nothing is on probation; each kind has its wording.
describe("the pull's probation and notices", function()
    local harness = require("plugin_harness")
    local InfoMessage = require("ui/widget/infomessage")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local PluginLoader = require("pluginloader")
    local Screen = require("device").screen
    local UIManager = require("ui/uimanager")
    local WidgetContainer = require("ui/widget/container/widgetcontainer")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")
    local push_dir = harness.state_dir .. "/push"
    local probation_file = push_dir .. "/probation.lua"
    local result_file = push_dir .. "/result.lua"
    local original_paint = InputContainer.paintTo
    local original_now = time.now
    local HASH = "0123456789ab" .. string.rep("c", 52)
    local Home

    local function write(path, text)
        lfs.mkdir(harness.state_dir)
        lfs.mkdir(push_dir)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function mode(path)
        return lfs.attributes(path, "mode")
    end

    local function put_result(fields)
        write(result_file, "return " .. require("dump")(fields, nil, true) .. "\n")
    end

    local function put_probation()
        write(probation_file, "return { profile = \"vector\" }\n")
    end

    -- The texts of the InfoMessages on the stack, top first.
    local function notices()
        local texts = {}
        for _, widget in ipairs(harness.stack()) do
            if getmetatable(widget) == InfoMessage then
                texts[#texts + 1] = widget.text
            end
        end
        return texts
    end

    local function fail_paint()
        InputContainer.paintTo = function(self, ...)
            if self.name == "kopanda_home" then
                error("kopanda-test: paint failed")
            end
            return original_paint(self, ...)
        end
    end

    -- Holds UIManager's clock (time.now) where it is until the test ends.
    local function stop_clock()
        local frozen = original_now()
        time.now = function()
            return frozen
        end
    end

    before_each(function()
        harness.load()
        Home = require("home")
    end)

    after_each(function()
        time.now = original_now
        InputContainer.paintTo = original_paint
        harness.teardown()
        os.execute("rm -rf '" .. push_dir .. "'")
    end)

    describe("Home.show's finished callback", function()
        -- Shows a home of its own over a file manager whose first home is closed, and returns
        -- the arguments finished got.
        local function show()
            harness.show_fm()
            harness.tick(2)
            Home.close()
            local calls = {}
            Home.show{
                started = time.monotonic(),
                finished = function(...)
                    calls[#calls + 1] = { n = select("#", ...), ... }
                end,
            }
            harness.tick(3)
            return calls
        end

        it("gets true after a first paint that succeeded", function()
            assert.same({ { n = 1, true } }, show())
        end)

        -- UIManager runs a task scheduled during a task in the same pass, before the repaint,
        -- when time.now() hasn't moved past the pass's start (frontend/ui/uimanager.lua:1081-1104,
        -- 447-456, 1537-1564): so tickAfterNext's task can land before the home's first paint.
        it("gets true after a first paint that succeeded while the clock stands still", function()
            stop_clock()
            assert.same({ { n = 1, true } }, show())
        end)

        it("gets false after a paint that throws while the clock stands still", function()
            stop_clock()
            fail_paint()
            assert.same({ { n = 1, false } }, show())
        end)

        describe("for a home covered before its first paint", function()
            -- Shows a home with a full-screen widget over it, so the repaints skip the home
            -- (frontend/ui/uimanager.lua:1305-1316), and returns the cover and finished's calls.
            local function show_covered()
                harness.show_fm()
                harness.tick(2)
                Home.close()
                local calls = {}
                Home.show{
                    started = time.monotonic(),
                    finished = function(...)
                        calls[#calls + 1] = { n = select("#", ...), ... }
                    end,
                }
                local cover = WidgetContainer:new{ dimen = Screen:getSize(), covers_fullscreen = true }
                UIManager:show(cover)
                harness.tick(3)
                return cover, calls
            end

            it("waits for that paint and gets true once the cover goes", function()
                local cover, calls = show_covered()
                assert.same({}, calls)
                UIManager:close(cover)
                harness.tick(3)
                assert.same({ { n = 1, true } }, calls)
            end)

            it("gets false when the home is closed without painting", function()
                local _, calls = show_covered()
                Home.close()
                harness.tick(2)
                assert.same({ { n = 1, false } }, calls)
            end)
        end)

        it("gets false after a paint that throws", function()
            fail_paint()
            assert.same({ { n = 1, false } }, show())
        end)

        it("gets false after a build that throws", function()
            harness.show_fm()
            harness.tick(2)
            Home.close()
            Home.init = function()
                error("kopanda-test: build failed")
            end
            local calls = {}
            Home.show{
                started = time.monotonic(),
                finished = function(...)
                    calls[#calls + 1] = { n = select("#", ...), ... }
                end,
            }
            harness.tick(2)
            assert.same({ { n = 1, false } }, calls)
        end)

        it("gets false when the home is closed before its first paint", function()
            harness.show_fm()
            harness.tick(2)
            Home.close()
            local calls = {}
            Home.show{
                started = time.monotonic(),
                finished = function(...)
                    calls[#calls + 1] = { n = select("#", ...), ... }
                end,
            }
            Home.close()
            harness.tick(3)
            assert.same({ { n = 1, false } }, calls)
        end)

        it("gets false after a show that throws", function()
            Home.onShow = function()
                error("kopanda-test: show failed")
            end
            assert.same({ { n = 1, false } }, show())
        end)
    end)

    describe("the first home of a process", function()
        it("ends probation and shows the result over the painted home", function()
            put_probation()
            put_result{ ok = true, kind = "applied", profile = "vector", hash = HASH }
            harness.show_fm()
            harness.tick(4)
            assert.is_nil(mode(probation_file))
            assert.is_nil(mode(result_file))
            assert.same({ "KoPanda pulled vector from the studio (bundle 0123456789ab)." }, notices())
            assert.equals(Home.shown, harness.top(2))
        end)

        it("leaves probation and the result when the paint fails", function()
            put_probation()
            put_result{ ok = true, kind = "applied", profile = "vector", hash = HASH }
            fail_paint()
            harness.show_fm()
            harness.tick(4)
            assert.equals("file", mode(probation_file))
            assert.equals("file", mode(result_file))
            assert.same({}, notices())
        end)

        it("leaves probation and the result when the build fails", function()
            put_probation()
            put_result{ ok = true, kind = "applied", profile = "vector", hash = HASH }
            Home.init = function()
                error("kopanda-test: build failed")
            end
            harness.show_fm()
            harness.tick(4)
            assert.equals("file", mode(probation_file))
            assert.equals("file", mode(result_file))
            assert.same({}, notices())
        end)

        it("leaves probation and the result when the show fails", function()
            put_probation()
            put_result{ ok = true, kind = "applied", profile = "vector", hash = HASH }
            Home.onShow = function()
                error("kopanda-test: show failed")
            end
            harness.show_fm()
            harness.tick(4)
            assert.equals("file", mode(probation_file))
            assert.equals("file", mode(result_file))
            assert.same({}, notices())
        end)

        it("shows nothing when there is no result", function()
            put_probation()
            harness.show_fm()
            harness.tick(4)
            assert.is_nil(mode(probation_file))
            assert.same({}, notices())
        end)
    end)

    describe("a refused plugin", function()
        local function refuse()
            table.insert(PluginLoader.enabled_plugins, { name = "simpleui" })
        end

        it("shows the result when nothing is on probation", function()
            refuse()
            put_result{ ok = false, kind = "rolled_back", profile = "vector", hash = HASH }
            harness.show_fm()
            harness.tick(2)
            assert.is_nil(mode(result_file))
            local texts = notices()
            assert.equals(2, #texts)
            local joined = table.concat(texts, "\n")
            assert.truthy(joined:find("KoPanda's home didn't draw after the pull of vector", 1, true))
        end)

        it("shows nothing and leaves both files while on probation", function()
            refuse()
            put_probation()
            put_result{ ok = true, kind = "applied", profile = "vector", hash = HASH }
            harness.show_fm()
            harness.tick(2)
            assert.equals("file", mode(probation_file))
            assert.equals("file", mode(result_file))
            local texts = notices()
            assert.equals(1, #texts)
            assert.falsy(texts[1]:find("pulled", 1, true))
        end)
    end)

    describe("the wording", function()
        local kinds = {
            {
                { ok = true, kind = "applied", profile = "colorsoft", hash = HASH },
                "KoPanda pulled colorsoft from the studio (bundle 0123456789ab).",
            },
            {
                { ok = false, kind = "rolled_back", profile = "colorsoft", hash = HASH },
                "KoPanda's home didn't draw after the pull of colorsoft, so the previous KoPanda and its "
                    .. "settings are back.",
            },
            {
                { ok = false, kind = "failed", profile = "colorsoft", message = "the stage has no settings.lua" },
                "KoPanda couldn't apply the pull of colorsoft: the stage has no settings.lua. Nothing changed.",
            },
            {
                {
                    ok = false,
                    kind = "restore_failed",
                    profile = "colorsoft",
                    message = "could not restore boot_pending",
                },
                "KoPanda couldn't restore the previous version: could not restore boot_pending.",
            },
        }
        for _, case in ipairs(kinds) do
            it("says " .. case[1].kind, function()
                put_result(case[1])
                harness.show_fm()
                harness.tick(4)
                assert.same({ case[2] }, notices())
            end)
        end
    end)
end)
