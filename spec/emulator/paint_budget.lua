-- The paint budget the capture specs hold each capture's settled signal to: a screen paints within M.MS of its
-- open, in the emulator on this Mac. A regression tripwire, not a device figure. The signal's cpu_ms, the process's
-- CPU time over the paint, is judged on every run. Its paint_ms, wall time, is judged only when the host's 1-minute
-- load average is at or below its core count, or when either can't be read: a loaded host stretches wall time while
-- the paint does no more work (at load 74-152 on 12 cores, wall 32-372 ms for CPU 26-37 ms). The wall check still
-- catches a paint that waits rather than works, on an idle host. Busted's assertions, which a required module
-- doesn't get as its global assert.
local assert = require("luassert")

local M = {}

M.MS = 250

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

local function run(command)
    local pipe = io.popen(command .. " 2>/dev/null")
    if not pipe then
        return nil
    end
    local text = pipe:read("*a")
    pipe:close()
    return text
end

-- The first number in text, or nil: sysctl -n vm.loadavg prints "{ 2.34 1.98 1.50 }", and
-- /proc/loadavg "2.34 1.98 1.50 1/389 12345".
local function first_number(text)
    return text and tonumber(text:match("%d+%.?%d*"))
end

-- The host's 1-minute load average and its core count, { load, cores }, each nil when it can't
-- be read: sysctl on macOS, /proc/loadavg and getconf on Linux.
function M.host()
    return {
        load = first_number(run("sysctl -n vm.loadavg")) or first_number(read_file("/proc/loadavg")),
        cores = first_number(run("sysctl -n hw.ncpu")) or first_number(run("getconf _NPROCESSORS_ONLN")),
    }
end

-- Whether wall time is judged on a host at load with cores: when load is at or below cores, or
-- when either is unknown. When it isn't, the second value is the line that says so.
function M.judges_wall(load, cores)
    if type(load) ~= "number" or type(cores) ~= "number" or load <= cores then
        return true
    end
    return false, string.format("wall time not judged: host load %.2f over %d cores", load, cores)
end

-- Holds a capture's settled signal (its sidecar) to the budget under label: prints its times, then
-- judges cpu_ms, and paint_ms unless the host is loaded, which it prints a note for instead, a
-- line bin/check keeps from a passing test. host is { load, cores } (default: M.host(), read now);
-- ms is the budget (default: M.MS), for a screen held to a tighter one.
function M.check(label, sidecar, host, ms)
    host = host or M.host()
    ms = ms or M.MS
    local paint_ms, cpu_ms = sidecar.paint_ms, sidecar.cpu_ms
    assert.is_number(paint_ms, label .. ": no paint_ms")
    assert.is_number(cpu_ms, label .. ": no cpu_ms")
    print(string.format("%s: paint_ms=%s cpu_ms=%s", label, paint_ms, cpu_ms))
    assert.truthy(paint_ms > 0, string.format("%s: paint_ms %s", label, paint_ms))
    assert.truthy(cpu_ms <= ms, string.format("%s: cpu_ms %s over the %d ms budget", label, cpu_ms, ms))
    local judged, line = M.judges_wall(host.load, host.cores)
    if judged then
        assert.truthy(paint_ms <= ms,
            string.format("%s: paint_ms %s over the %d ms budget", label, paint_ms, ms))
    else
        print("[  NOTE    ] " .. label .. ": " .. line)
    end
end

return M
