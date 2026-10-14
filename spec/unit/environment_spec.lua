describe("the Busted environment bin/check builds", function()
    local lfs = require("libs/libkoreader-lfs")
    local root = os.getenv("KOPANDA_ROOT")
    local emulator = os.getenv("KOPANDA_EMULATOR")
    local ko_home = os.getenv("KO_HOME")

    local function carries(path, entry)
        return path:find(entry, 1, true) ~= nil
    end

    it("loads KOReader's commonrequire", function()
        assert.truthy(require("commonrequire"))
    end)

    it("loads KOReader frontend modules", function()
        assert.truthy(require("luasettings"))
        assert.truthy(require("ui/widget/container/widgetcontainer"))
    end)

    it("exports KOPANDA_ROOT and KOPANDA_EMULATOR", function()
        assert.is_string(root)
        assert.is_string(emulator)
    end)

    it("points KO_HOME at a fresh directory outside the emulator and the repo", function()
        assert.is_string(ko_home)
        assert.equals("directory", lfs.attributes(ko_home, "mode"))
        assert.not_equals(emulator, ko_home)
        assert.is_nil(ko_home:find(root, 1, true))
    end)

    it("keeps G_reader_settings under KO_HOME", function()
        require("commonrequire")
        assert.equals(1, G_reader_settings.file:find(ko_home, 1, true))
    end)

    it("puts the repo's spec/ and kopanda.koplugin/ on package.path", function()
        assert.truthy(carries(package.path, root .. "/spec/?.lua"))
        assert.truthy(carries(package.path, root .. "/kopanda.koplugin/?.lua"))
    end)

    it("strips the Busted rocks from package.path and package.cpath", function()
        assert.falsy(carries(package.path, "spec/rocks/"))
        assert.falsy(carries(package.cpath, "spec/rocks/"))
    end)
end)
