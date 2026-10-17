-- The goldens' paint budget (spec/emulator/paint_budget.lua): cpu_ms judged on every run, wall
-- time's paint_ms only on a host whose 1-minute load is at or below its core count, or whose load
-- or cores can't be read; a run that doesn't judge wall time says so.
describe("the paint budget", function()
    local PaintBudget = require("emulator.paint_budget")

    describe("judging wall time", function()
        it("judges it on a host under its core count", function()
            assert.is_true((PaintBudget.judges_wall(3.5, 12)))
        end)

        it("judges it on a host at its core count", function()
            assert.is_true((PaintBudget.judges_wall(12, 12)))
        end)

        it("doesn't judge it on a host over its core count, and says so with the load and cores", function()
            local judged, line = PaintBudget.judges_wall(90.25, 12)
            assert.is_false(judged)
            assert.equals("wall time not judged: host load 90.25 over 12 cores", line)
        end)

        it("judges it when the load can't be read", function()
            assert.is_true((PaintBudget.judges_wall(nil, 12)))
        end)

        it("judges it when the cores can't be read", function()
            assert.is_true((PaintBudget.judges_wall(90.25, nil)))
        end)
    end)

    it("reads this host's 1-minute load average and core count", function()
        local host = PaintBudget.host()
        assert.is_number(host.load)
        assert.is_number(host.cores)
        assert.truthy(host.cores >= 1, host.cores)
    end)

    describe("checking a capture's signal", function()
        local idle = { load = 2, cores = 12 }
        local loaded = { load = 90.25, cores = 12 }
        local printed

        before_each(function()
            printed = {}
            stub(_G, "print", function(line)
                printed[#printed + 1] = line
            end)
        end)

        after_each(function()
            _G.print:revert()
        end)

        local function fails(sidecar, host, message)
            local ok, err = pcall(PaintBudget.check, "night-diner", sidecar, host)
            assert.is_false(ok)
            assert.truthy(tostring(err):find(message, 1, true), tostring(err))
        end

        it("passes a paint within the budget on both clocks and prints its times", function()
            PaintBudget.check("night-diner", { paint_ms = 40, cpu_ms = 30 }, idle)
            assert.same({ "night-diner: paint_ms=40 cpu_ms=30" }, printed)
        end)

        it("fails a paint over the budget in CPU time, idle host or loaded", function()
            fails({ paint_ms = 335, cpu_ms = 330 }, idle, "night-diner: cpu_ms 330 over the 250 ms budget")
            fails({ paint_ms = 335, cpu_ms = 330 }, loaded, "night-diner: cpu_ms 330 over the 250 ms budget")
        end)

        it("fails a paint over the budget in wall time on an idle host", function()
            fails({ paint_ms = 330, cpu_ms = 28 }, idle, "night-diner: paint_ms 330 over the 250 ms budget")
        end)

        it("fails a paint over the budget in wall time when the host can't be read", function()
            fails({ paint_ms = 330, cpu_ms = 28 }, {}, "night-diner: paint_ms 330 over the 250 ms budget")
        end)

        it("passes a paint over the budget in wall time on a loaded host, saying wall time wasn't judged", function()
            PaintBudget.check("night-diner", { paint_ms = 330, cpu_ms = 28 }, loaded)
            assert.same({
                "night-diner: paint_ms=330 cpu_ms=28",
                "[  NOTE    ] night-diner: wall time not judged: host load 90.25 over 12 cores",
            }, printed)
        end)

        it("fails a signal without cpu_ms or paint_ms", function()
            fails({ paint_ms = 40 }, idle, "night-diner: no cpu_ms")
            fails({ cpu_ms = 30 }, idle, "night-diner: no paint_ms")
        end)
    end)
end)
