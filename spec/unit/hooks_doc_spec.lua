-- kopanda.koplugin/HOOKS.md names every KOReader surface the plugin touches, and no KoPanda
-- module name can be taken by another module in the same process.
describe("HOOKS.md", function()
    local harness = require("plugin_harness")
    local lfs = require("libs/libkoreader-lfs")
    local emulator = os.getenv("KOPANDA_EMULATOR")
    local hooks_path = harness.plugin_dir .. "/HOOKS.md"

    local function read(path)
        local f = assert(io.open(path, "r"))
        local text = f:read("*a")
        f:close()
        return text
    end

    local function plain_find(text, needle)
        return text:find(needle, 1, true) ~= nil
    end

    -- What HOOKS.md must name, from every plugin file: modules required or read from
    -- package.loaded that are not the plugin's own files, G_reader_settings and G_defaults
    -- keys, and accesses to underscore-prefixed fields and methods.
    local function surfaces()
        local own = {}
        for _, file in ipairs(harness.plugin_files()) do
            own[file:gsub("%.lua$", "")] = true
        end
        local wanted, seen = {}, {}
        local function want(kind, text)
            if not seen[kind .. text] then
                seen[kind .. text] = true
                wanted[#wanted + 1] = { kind = kind, text = text }
            end
        end
        for _, file in ipairs(harness.plugin_files()) do
            local source = read(harness.plugin_dir .. "/" .. file)
            for module in source:gmatch("require%s*%(?%s*[\"']([^\"']+)[\"']") do
                if not own[module] then
                    want("module", module)
                end
            end
            for module in source:gmatch("package%.loaded%[%s*[\"']([^\"']+)[\"']%s*%]") do
                if not own[module] then
                    want("module", module)
                end
            end
            for key in source:gmatch("G_reader_settings:%w+%(%s*[\"']([^\"']+)[\"']") do
                want("key", key)
            end
            for key in source:gmatch("G_defaults:readSetting%(%s*[\"']([^\"']+)[\"']") do
                want("key", key)
            end
            for access in source:gmatch("[%w_]+[%.:]_[%w_]+") do
                want("internal", access)
            end
        end
        return wanted
    end

    -- The surfaces a HOOKS.md text fails to name: modules and keys in backticks, internals as
    -- written in the code.
    local function missing(hooks_text)
        local absent = {}
        for _, surface in ipairs(surfaces()) do
            local needle = surface.kind == "internal" and surface.text or ("`" .. surface.text .. "`")
            if not plain_find(hooks_text, needle) then
                absent[#absent + 1] = surface.kind .. " " .. surface.text
            end
        end
        return absent
    end

    -- The "## Plugin" section's "###" entries that have no file:line.
    local function entries_without_citation(hooks_text)
        local section = hooks_text:match("\n## Plugin[^\n]*\n(.-)\n## ") or hooks_text:match("\n## Plugin[^\n]*\n(.*)$")
        assert.is_string(section, "HOOKS.md has no \"## Plugin\" section")
        local uncited = {}
        for heading, body in (section .. "\n### "):gmatch("### ([^\n]*)\n(.-)\n%f[#]") do
            if not body:find("%.lua:%d+") then
                uncited[#uncited + 1] = heading
            end
        end
        return uncited
    end

    it("names every KOReader module, settings key and internal the plugin uses", function()
        assert.same({}, missing(read(hooks_path)))
    end)

    it("reports a module the document leaves out", function()
        local hooks = read(hooks_path)
        local without = hooks:gsub("`ui/uimanager`", "")
        assert.truthy(#surfaces() > 0)
        assert.same({ "module ui/uimanager" }, missing(without))
    end)

    it("cites a file:line in every entry of the plugin section", function()
        local hooks = read(hooks_path)
        assert.same({}, entries_without_citation(hooks))
        assert.same({ "Broken" }, entries_without_citation(hooks:gsub("\n## Plugin([^\n]*)\n",
            "\n## Plugin%1\n\n### Broken\n\n- no citation here.\n", 1)))
    end)

    it("gives KoPanda modules names no KOReader or bundled plugin module has", function()
        local roots = { emulator .. "/frontend", emulator .. "/common" }
        for entry in lfs.dir(emulator .. "/plugins") do
            if entry:match("%.koplugin$") then
                roots[#roots + 1] = emulator .. "/plugins/" .. entry
            end
        end
        local taken = {}
        for _, module in ipairs(harness.module_names()) do
            for _, root in ipairs(roots) do
                local path = root .. "/" .. module .. ".lua"
                if lfs.attributes(path, "mode") then
                    taken[#taken + 1] = path
                end
            end
        end
        assert.truthy(#harness.module_names() > 0)
        assert.same({}, taken)
    end)
end)
