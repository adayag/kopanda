-- The device's own numbers: the battery's time left from KOReader's Battery statistics file (the rate its totals work
-- out to, the words it reads in and the read of a file the plugin didn't write), the memory KOReader uses and the
-- storage free.
describe("DeviceStats", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local logger = require("logger")
    local DeviceStats
    local HOUR = 3600
    local FTS_PER_S = 1000000
    local stats_file = DataStorage:getSettingsDir() .. "/battery_stats.lua"
    local fixture = harness.root .. "/spec/fixtures/battery_stats.lua"

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

    local function discharged(percentage, seconds)
        return { discharging = { percentage = percentage, time = seconds * FTS_PER_S } }
    end

    setup(function()
        DeviceStats = require("device_stats")
    end)

    after_each(function()
        os.remove(stats_file)
        os.remove(stats_file .. ".old")
    end)

    describe("time_left", function()
        it("is the percent left at the rate on record", function()
            assert.equals(20 * HOUR, DeviceStats.time_left(74, discharged(37, 10 * HOUR)))
        end)

        it("needs an hour on record", function()
            assert.is_number(DeviceStats.time_left(50, discharged(10, HOUR)))
            assert.is_nil(DeviceStats.time_left(50, discharged(10, HOUR - 1)))
        end)

        it("reads nil from a record that gives no rate", function()
            local nan, inf = 0 / 0, math.huge
            local tables = {
                discharged(0, 10 * HOUR),
                discharged(-5, 10 * HOUR),
                discharged(10, 0),
                discharged(10, -10 * HOUR),
                { discharging = { percentage = nan, time = 10 * HOUR * FTS_PER_S } },
                { discharging = { percentage = 10, time = nan } },
                { discharging = { percentage = inf, time = 10 * HOUR * FTS_PER_S } },
                { discharging = { percentage = 10, time = inf } },
                { discharging = { percentage = "10", time = 10 * HOUR * FTS_PER_S } },
                { discharging = { percentage = 10, time = "long" } },
                { discharging = { percentage = 10 } },
                { discharging = "none" },
                { discharging = 5 },
                { discharging = true },
                {},
                "not a table",
            }
            for i, totals in ipairs(tables) do
                assert.is_nil(DeviceStats.time_left(50, totals), "table " .. i)
            end
            assert.is_nil(DeviceStats.time_left(50, nil))
        end)

        it("reads nil from 90 days up, however healthy the record", function()
            assert.is_number(DeviceStats.time_left(90, discharged(1, 86399)))
            assert.is_nil(DeviceStats.time_left(90, discharged(1, 86400)))
        end)

        it("reads nil from a rate that works out to no sensible time", function()
            assert.is_nil(DeviceStats.time_left(50, discharged(1e-300, 10 * HOUR)))
            assert.is_nil(DeviceStats.time_left(50, { discharging = { percentage = 10, time = 1e308 } }))
        end)
    end)

    describe("left_text", function()
        it("counts whole days from a day up", function()
            assert.equals("about 1 day left", DeviceStats.left_text(86400))
            assert.equals("about 1 day left", DeviceStats.left_text(90000))
            assert.equals("about 3 days left", DeviceStats.left_text(259200))
            assert.equals("about 23 hours left", DeviceStats.left_text(86399))
        end)

        it("counts whole hours from an hour up", function()
            assert.equals("about 2 hours left", DeviceStats.left_text(7200))
            assert.equals("about 1 hour left", DeviceStats.left_text(3600))
            assert.equals("under an hour left", DeviceStats.left_text(3599))
            assert.equals("under an hour left", DeviceStats.left_text(1800))
        end)
    end)

    describe("battery_totals", function()
        it("reads a file in the Battery statistics plugin's shape", function()
            write(stats_file, read(fixture))
            local totals = DeviceStats.battery_totals()
            assert.equals(37, totals.discharging.percentage)
            assert.equals(20 * HOUR, DeviceStats.time_left(74, totals))
        end)

        it("reads an empty table from a missing file, and doesn't make one", function()
            assert.same({}, DeviceStats.battery_totals())
            assert.is_nil(io.open(stats_file, "r"))
        end)

        it("reads no rate from a malformed file", function()
            write(stats_file, "return { discharging = ")
            assert.is_nil(DeviceStats.time_left(50, DeviceStats.battery_totals()))
            write(stats_file, "return 5\n")
            assert.is_nil(DeviceStats.time_left(50, DeviceStats.battery_totals()))
        end)

        it("logs a read that raises and reads nil", function()
            local LuaSettings = require("luasettings")
            local open = stub(LuaSettings, "open", function() error("no") end)
            local err = spy.on(logger, "err")
            local got = DeviceStats.battery_totals()
            open:revert()
            assert.spy(err).was_called()
            err:revert()
            assert.is_nil(got)
        end)
    end)

    describe("rss", function()
        it("reads VmRSS in bytes", function()
            assert.equals(98304 * 1024, DeviceStats.rss("Name:\tluajit\nVmRSS:\t   98304 kB\nThreads:\t1\n"))
        end)

        it("reads nil from text without the line, and from nil", function()
            assert.is_nil(DeviceStats.rss("Name:\tluajit\n"))
            assert.is_nil(DeviceStats.rss(nil))
        end)
    end)

    describe("memory", function()
        local real_open = io.open

        after_each(function()
            io.open = real_open
        end)

        it("reads VmRSS from this process's status", function()
            local status = DataStorage:getSettingsDir() .. "/fake_status"
            write(status, "VmRSS:\t  2048 kB\n")
            finally(function()
                os.remove(status)
            end)
            io.open = function(path, mode)
                return real_open(path == "/proc/self/status" and status or path, mode)
            end
            assert.equals(2048 * 1024, DeviceStats.memory())
        end)

        it("reads nil without /proc", function()
            io.open = function()
                return nil, "no such file"
            end
            assert.is_nil(DeviceStats.memory())
        end)
    end)

    describe("storage", function()
        local util = require("util")
        local filemanagerutil = require("apps/filemanager/filemanagerutil")

        it("reads what is available on the home folder's disk", function()
            local home = stub(filemanagerutil, "getHomeFolder", function()
                return "/mnt/us/books"
            end)
            local asked
            local usage = stub(util, "diskUsage", function(path)
                asked = path
                return { total = 16000000000, used = 4000000000, available = 11800000000 }
            end)
            local got = DeviceStats.storage()
            home:revert()
            usage:revert()
            assert.equals("/mnt/us/books", asked)
            assert.equals(11800000000, got)
        end)

        it("reads nil when the disk can't say", function()
            local usage = stub(util, "diskUsage", function()
                return { total = nil, used = nil, available = nil }
            end)
            local got = DeviceStats.storage()
            usage:revert()
            assert.is_nil(got)
        end)

        it("logs a read that raises and reads nil", function()
            local usage = stub(util, "diskUsage", function() error("no") end)
            local err = spy.on(logger, "err")
            local got = DeviceStats.storage()
            usage:revert()
            assert.spy(err).was_called()
            err:revert()
            assert.is_nil(got)
        end)
    end)

    it("never writes the file", function()
        write(stats_file, read(fixture))
        local before = read(stats_file)
        DeviceStats.time_left(74, DeviceStats.battery_totals())
        assert.equals(before, read(stats_file))
    end)
end)
