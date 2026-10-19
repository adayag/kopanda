-- The device's side of the bundle format (C5): over the shared vectors in spec/fixtures/push/ it
-- computes every sha256 and the bundle hash the studio's manifest names, accepts that manifest
-- for its own profile, and refuses every manifest and path the feature lists.
describe("the push bundle", function()
    local PushBundle = require("push_bundle")
    local lfs = require("libs/libkoreader-lfs")
    local rapidjson = require("rapidjson")
    local root = os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/push"
    local tree = root .. "/tree"
    local ko_home = os.getenv("KO_HOME")
    local HEX = string.rep("a", 64)

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

    local function vectors()
        return assert(rapidjson.decode(read(root .. "/manifest.json")))
    end

    -- A plain manifest for profile vector with the required files; fields overrides its fields.
    local function manifest(fields)
        local doc = {
            format = 1,
            profile = "vector",
            hash = HEX,
            files = {
                { path = "plugin/_meta.lua", size = 1, sha256 = HEX },
                { path = "plugin/main.lua", size = 1, sha256 = HEX },
                { path = "settings.lua", size = 1, sha256 = HEX },
            },
        }
        for k, v in pairs(fields or {}) do
            doc[k] = v
        end
        return doc
    end

    -- The manifest with path inserted into its files, kept in byte order.
    local function with_path(path)
        local doc = manifest()
        table.insert(doc.files, { path = path, size = 0, sha256 = HEX })
        table.sort(doc.files, function(a, b)
            return a.path < b.path
        end)
        return doc
    end

    local function refused(doc, profile)
        local ok, why = PushBundle.check_manifest(doc, profile or "vector")
        assert.is_nil(ok)
        assert.is_string(why)
        return why
    end

    describe("the shared vectors", function()
        it("computes every sha256 the manifest names", function()
            for _, file in ipairs(vectors().files) do
                assert.equals(file.sha256, PushBundle.sha256_file(tree .. "/" .. file.path))
            end
        end)

        it("computes the manifest's bundle hash", function()
            local doc = vectors()
            assert.equals(doc.hash, PushBundle.bundle_hash(tree, doc.files))
        end)

        it("hashes the files in byte order whatever order they are given in", function()
            local doc = vectors()
            local reversed = {}
            for i = #doc.files, 1, -1 do
                reversed[#reversed + 1] = doc.files[i]
            end
            assert.equals(doc.hash, PushBundle.bundle_hash(tree, reversed))
        end)

        it("accepts the manifest for profile vector", function()
            local checked = assert(PushBundle.check_manifest(vectors(), "vector"))
            assert.equals("vector", checked.profile)
            assert.equals(4, #checked.files)
        end)

        it("refuses the manifest for profile colorsoft", function()
            assert.truthy(refused(vectors(), "colorsoft"):find("colorsoft", 1, true))
        end)

        it("verifies the tree against its manifest", function()
            assert.is_true(PushBundle.verify_files(tree, vectors()))
        end)
    end)

    describe("safe_path", function()
        local cases = {
            { "settings.lua", true },
            { "plugin/main.lua", true },
            { "plugin/icons/a.svg", true },
            { "plugin/a_b-c.D9", true },
            { "plugin/.hidden", true },
            { "", false },
            { "/plugin/main.lua", false },
            { "plugin\\main.lua", false },
            { "plugin//main.lua", false },
            { "plugin/", false },
            { "plugin/./main.lua", false },
            { "plugin/../main.lua", false },
            { ".", false },
            { "..", false },
            { "plugin/ma in.lua", false },
            { "plugin/mäin.lua", false },
            { "plugin/main.lua~?", false },
            { "plugin/a:b", false },
        }
        for _, case in ipairs(cases) do
            it(string.format("%s %q", case[2] and "accepts" or "refuses", case[1]), function()
                assert.equals(case[2], PushBundle.safe_path(case[1]))
            end)
        end

        it("refuses a non-string", function()
            assert.is_false(PushBundle.safe_path(nil))
            assert.is_false(PushBundle.safe_path(12))
        end)
    end)

    describe("check_manifest", function()
        it("accepts a minimal manifest and returns plain tables", function()
            local checked = assert(PushBundle.check_manifest(manifest(), "vector"))
            local expected = manifest()
            expected.settings = true
            assert.same(expected, checked)
        end)

        it("refuses JSON that is not an object", function()
            refused(rapidjson.decode("[1, 2]"))
            refused("manifest")
            refused(nil)
        end)

        it("refuses another format", function()
            refused(manifest{ format = 2 })
            refused(manifest{ format = "1" })
        end)

        it("refuses another profile", function()
            refused(manifest{ profile = "colorsoft" })
        end)

        it("refuses a hash that is not 64 lowercase hex", function()
            refused(manifest{ hash = string.rep("a", 63) })
            refused(manifest{ hash = string.rep("A", 64) })
            refused(manifest{ hash = string.rep("g", 64) })
            refused(manifest{ hash = 12 })
        end)

        it("refuses files that are not a non-empty array of objects", function()
            refused(manifest{ files = {} })
            refused(manifest{ files = "plugin/main.lua" })
            refused(manifest{ files = { "plugin/main.lua" } })
            refused(rapidjson.decode('{"format":1,"profile":"vector","hash":"' .. HEX .. '","files":{}}'))
        end)

        it("refuses a file whose sha256 is not 64 hex", function()
            local doc = manifest()
            doc.files[1].sha256 = string.rep("a", 65)
            refused(doc)
            doc.files[1].sha256 = nil
            refused(doc)
        end)

        it("refuses a size that is not a non-negative integer", function()
            for _, size in ipairs{ -1, 1.5, "1", math.huge } do
                local doc = manifest()
                doc.files[1].size = size
                refused(doc)
            end
            local doc = manifest()
            doc.files[1].size = nil
            refused(doc)
        end)

        it("accepts a size of zero", function()
            assert.truthy(PushBundle.check_manifest(with_path("plugin/empty"), "vector"))
        end)

        it("refuses a path that is not a string", function()
            local doc = manifest()
            doc.files[1].path = 1
            refused(doc)
        end)

        it("refuses every unsafe path", function()
            for _, path in ipairs{ "plugin//x", "plugin/../x", "plugin/./x", "plugin/x y", "plugin/x\\y", "/x" } do
                assert.truthy(refused(with_path(path)):find(path, 1, true))
            end
        end)

        it("refuses a path neither settings.lua nor under plugin/", function()
            refused(with_path("other.lua"))
            refused(with_path("plugins/x.lua"))
            refused(with_path("settings.lua.old"))
        end)

        it("refuses two paths equal ignoring case", function()
            refused(with_path("plugin/Main.lua"))
        end)

        it("refuses a duplicate path", function()
            refused(with_path("plugin/main.lua"))
        end)

        it("refuses a manifest missing settings.lua, plugin/main.lua or plugin/_meta.lua", function()
            for i = 1, 3 do
                local doc = manifest()
                local missing = table.remove(doc.files, i)
                assert.truthy(refused(doc):find(missing.path, 1, true))
            end
        end)

        -- A release's manifest: the plugin's files only.
        local function plugin_only(fields)
            local doc = manifest(fields)
            table.remove(doc.files, 3)
            doc.settings = false
            return doc
        end

        it("accepts a plugin-only manifest without settings.lua and says so", function()
            local checked = assert(PushBundle.check_manifest(plugin_only(), "vector"))
            assert.is_false(checked.settings)
            assert.same({ "plugin/_meta.lua", "plugin/main.lua" }, { checked.files[1].path, checked.files[2].path })
            assert.equals(2, #checked.files)
        end)

        it("refuses a plugin-only manifest that names settings.lua", function()
            local doc = manifest{ settings = false }
            assert.equals("a plugin-only manifest names settings.lua", refused(doc))
        end)

        it("still requires plugin/main.lua and plugin/_meta.lua in a plugin-only manifest", function()
            for i = 1, 2 do
                local doc = plugin_only()
                local missing = table.remove(doc.files, i)
                assert.truthy(refused(doc):find(missing.path, 1, true))
            end
        end)

        it("takes any settings value but false for a manifest that carries settings", function()
            for _, value in ipairs{ true, 0, "false", {} } do
                local checked = assert(PushBundle.check_manifest(manifest{ settings = value }, "vector"))
                assert.is_true(checked.settings)
                local doc = plugin_only()
                doc.settings = value
                assert.truthy(refused(doc):find("settings.lua", 1, true))
            end
        end)

        it("refuses paths out of byte order", function()
            local doc = manifest()
            doc.files[1], doc.files[2] = doc.files[2], doc.files[1]
            refused(doc)
            -- Byte order puts upper case first.
            local upper = with_path("plugin/Z.lua")
            assert.equals("plugin/Z.lua", upper.files[1].path)
            assert.truthy(PushBundle.check_manifest(upper, "vector"))
        end)
    end)

    describe("verify_files", function()
        local dir

        before_each(function()
            dir = ko_home .. "/push-bundle-" .. tostring(os.time()) .. "-" .. tostring(math.random(1e9))
            os.execute("mkdir -p '" .. dir .. "' && cp -R '" .. tree .. "/.' '" .. dir .. "/'")
        end)

        after_each(function()
            os.execute("rm -rf '" .. dir .. "'")
        end)

        it("reads each file once", function()
            local doc = vectors()
            local open = spy.on(io, "open")
            local ok, verified = pcall(PushBundle.verify_files, dir, doc)
            open:revert()
            assert.is_true(ok, verified)
            assert.is_true(verified)
            assert.spy(open).was.called(#doc.files)
            for _, file in ipairs(doc.files) do
                assert.spy(open).was.called_with(dir .. "/" .. file.path, "rb")
            end
        end)

        it("verifies a file of several blocks, and refuses it with two blocks swapped", function()
            local blocks = { ("1"):rep(65536), ("2"):rep(65536), "tail" }
            write(dir .. "/plugin/big.bin", table.concat(blocks))
            local doc = vectors()
            table.insert(doc.files, 2, {
                path = "plugin/big.bin",
                size = 2 * 65536 + 4,
                sha256 = PushBundle.sha256_file(dir .. "/plugin/big.bin"),
            })
            doc.hash = PushBundle.bundle_hash(dir, doc.files)
            assert.is_true(PushBundle.verify_files(dir, doc))
            write(dir .. "/plugin/big.bin", blocks[2] .. blocks[1] .. blocks[3])
            doc.files[2].sha256 = PushBundle.sha256_file(dir .. "/plugin/big.bin")
            local ok, why = PushBundle.verify_files(dir, doc)
            assert.is_nil(ok)
            assert.truthy(why:find("bundle hash", 1, true))
        end)

        it("refuses a manifest whose paths are out of byte order", function()
            local doc = vectors()
            doc.files[1], doc.files[2] = doc.files[2], doc.files[1]
            local ok, why = PushBundle.verify_files(dir, doc)
            assert.is_nil(ok)
            assert.truthy(why:find("byte order", 1, true))
        end)

        it("refuses a manifest that names a path twice", function()
            local doc = vectors()
            table.insert(doc.files, 2, doc.files[1])
            local ok, why = PushBundle.verify_files(dir, doc)
            assert.is_nil(ok)
            assert.truthy(why:find("byte order", 1, true))
        end)

        it("refuses a missing file", function()
            os.remove(dir .. "/plugin/icons/a.svg")
            local ok, why = PushBundle.verify_files(dir, vectors())
            assert.is_nil(ok)
            assert.truthy(why:find("plugin/icons/a.svg", 1, true))
        end)

        it("refuses a file of the wrong size", function()
            write(dir .. "/plugin/main.lua", read(dir .. "/plugin/main.lua") .. "x")
            local ok, why = PushBundle.verify_files(dir, vectors())
            assert.is_nil(ok)
            assert.truthy(why:find("plugin/main.lua", 1, true))
            assert.truthy(why:find("bytes", 1, true))
        end)

        it("refuses a file of the right size and the wrong sha256", function()
            local text = read(dir .. "/plugin/main.lua")
            write(dir .. "/plugin/main.lua", ("x"):rep(#text))
            local ok, why = PushBundle.verify_files(dir, vectors())
            assert.is_nil(ok)
            assert.truthy(why:find("plugin/main.lua", 1, true))
        end)

        it("refuses a file it cannot read", function()
            assert.truthy(os.execute("chmod 000 '" .. dir .. "/plugin/main.lua'"))
            local readable = io.open(dir .. "/plugin/main.lua", "rb")
            if readable then
                readable:close()
                return pending("chmod 000 does not stop reading as root")
            end
            local ok, why = PushBundle.verify_files(dir, vectors())
            assert.is_nil(ok)
            assert.truthy(why:find("plugin/main.lua", 1, true))
        end)

        it("refuses a hash that does not recompute", function()
            local doc = vectors()
            doc.hash = HEX
            local ok, why = PushBundle.verify_files(dir, doc)
            assert.is_nil(ok)
            assert.truthy(why:find("hash", 1, true))
        end)

        it("refuses a symlink in place of a file", function()
            os.remove(dir .. "/plugin/main.lua")
            assert.truthy(os.execute("ln -s '" .. tree .. "/plugin/main.lua' '" .. dir .. "/plugin/main.lua'"))
            assert.equals("link", lfs.symlinkattributes(dir .. "/plugin/main.lua", "mode"))
            local ok, why = PushBundle.verify_files(dir, vectors())
            assert.is_nil(ok)
            assert.truthy(why:find("plugin/main.lua", 1, true))
        end)

        it("refuses a file with a second hard link", function()
            assert.truthy(os.execute("ln '" .. dir .. "/plugin/main.lua' '" .. dir .. "/extra'"))
            local ok, why = PushBundle.verify_files(dir, vectors())
            assert.is_nil(ok)
            assert.truthy(why:find("plugin/main.lua", 1, true))
        end)
    end)
end)
