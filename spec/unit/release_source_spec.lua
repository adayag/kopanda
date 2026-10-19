-- The release source: GitHub's latest release read into a version, its notes and its two asset
-- URLs; versions ordered; the installed version read from _meta.lua; and a release's bundle
-- downloaded, unpacked from a real zip built here with ffi/archiver's Writer, and verified
-- against its manifest. socket.http's request is stubbed to answer from a table of URL -> status
-- and body; no test touches the network.
describe("the release source", function()
    -- KOReader's spec setup: socketutil and util reach the device, which reads G_reader_settings.
    require("commonrequire")
    local Archiver = require("ffi/archiver")
    local PushApply = require("push_apply")
    local PushBundle = require("push_bundle")
    local ReleaseSource = require("release_source")
    local http = require("socket.http")
    local lfs = require("libs/libkoreader-lfs")
    local rapidjson = require("rapidjson")
    local socketutil = require("socketutil")
    local ko_home = os.getenv("KO_HOME")
    local API = "https://api.github.com/repos/adayag/kopanda/releases/latest"
    local DOWNLOAD = "https://github.com/adayag/kopanda/releases/download/v0.2.0/"

    local counter = 0
    -- The scratch folder, the routes the stub answers from, the requests made and the stub.
    local dir, routes, requests, request_stub

    local function read(path)
        local f = io.open(path, "rb")
        if not f then
            return nil
        end
        local text = f:read("*a")
        f:close()
        return text
    end

    local function write(path, text)
        local f = assert(io.open(path, "wb"))
        f:write(text)
        f:close()
    end

    local function mode(path)
        return lfs.symlinkattributes(path, "mode")
    end

    local function sh(command)
        assert.truthy(os.execute(command))
    end

    -- Every entry under root as relative path -> bytes ("<dir>" for a folder); {} for none.
    local function tree(root)
        local out = {}
        if mode(root) ~= "directory" then
            return out
        end
        local function walk(path, rel)
            for name in lfs.dir(path) do
                if name ~= "." and name ~= ".." then
                    local child_rel = rel == "" and name or rel .. "/" .. name
                    local child = path .. "/" .. name
                    if mode(child) == "directory" then
                        out[child_rel] = "<dir>"
                        walk(child, child_rel)
                    else
                        out[child_rel] = read(child)
                    end
                end
            end
        end
        walk(root, "")
        return out
    end

    before_each(function()
        counter = counter + 1
        dir = ko_home .. "/release-source-" .. counter
        sh("mkdir -p '" .. dir .. "'")
        routes, requests = {}, {}
        request_stub = stub(http, "request", function(request)
            requests[#requests + 1] = { url = request.url, headers = request.headers }
            local reply = routes[request.url] or { 404, '{"message":"Not Found"}' }
            if type(reply) == "function" then
                return reply(request)
            end
            request.sink(reply[2])
            request.sink(nil)
            return 1, reply[1], {}, "HTTP/1.1 " .. reply[1]
        end)
    end)

    after_each(function()
        request_stub:revert()
        os.execute("rm -rf '" .. dir .. "'")
    end)

    describe("latest", function()
        -- GitHub's answer for the latest release, its fields overridden by fields.
        local function release_json(fields)
            local doc = {
                tag_name = "v0.2.0",
                name = "v0.2.0",
                body = "- home: a quieter clock\n- library: faster covers",
                assets = {
                    { name = "manifest.json", browser_download_url = DOWNLOAD .. "manifest.json" },
                    { name = "kopanda.koplugin.zip", browser_download_url = DOWNLOAD .. "kopanda.koplugin.zip" },
                },
            }
            for k, v in pairs(fields or {}) do
                doc[k] = v
            end
            return rapidjson.encode(doc)
        end

        local function refused()
            local release, why = ReleaseSource.latest()
            assert.is_nil(release)
            assert.is_string(why)
            return why
        end

        it("reads the version, the notes and the two asset URLs", function()
            routes[API] = { 200, release_json() }
            assert.same({
                version = "0.2.0",
                notes = "- home: a quieter clock\n- library: faster covers",
                manifest_url = DOWNLOAD .. "manifest.json",
                zip_url = DOWNLOAD .. "kopanda.koplugin.zip",
            }, ReleaseSource.latest())
            assert.equals(API, requests[1].url)
            assert.equals(socketutil.USER_AGENT, requests[1].headers["User-Agent"])
        end)

        it("takes a release without a body for one without notes", function()
            routes[API] = { 200, release_json{ body = rapidjson.null } }
            assert.equals("", ReleaseSource.latest().notes)
        end)

        it("says there is no release yet on a 404", function()
            assert.equals("No release yet.", refused())
        end)

        it("says why GitHub couldn't be read", function()
            routes[API] = { 403, '{"message":"API rate limit exceeded"}' }
            assert.truthy(refused():find("403", 1, true))
            routes[API] = function()
                return nil, "host or service not provided, or not known"
            end
            assert.truthy(refused():find("not known", 1, true))
        end)

        it("refuses an answer that is not JSON or names no tag", function()
            routes[API] = { 200, "<html>" }
            assert.truthy(refused():find("JSON", 1, true))
            routes[API] = { 200, '{"assets":[]}' }
            refused()
            routes[API] = { 200, "[1]" }
            refused()
        end)

        it("refuses a tag that is not vX.Y.Z", function()
            for _, tag in ipairs{ "0.2.0", "v0.2", "v0.2.0-rc1", "release" } do
                routes[API] = { 200, release_json{ tag_name = tag } }
                assert.truthy(refused():find(tag, 1, true))
            end
        end)

        it("refuses a release missing either asset", function()
            for _, keep in ipairs{ 1, 2 } do
                local doc = rapidjson.decode(release_json())
                doc.assets = { doc.assets[keep] }
                routes[API] = { 200, rapidjson.encode(doc) }
                local missing = keep == 1 and "kopanda.koplugin.zip" or "manifest.json"
                assert.truthy(refused():find(missing, 1, true))
            end
            routes[API] = { 200, release_json{ assets = "none" } }
            refused()
        end)

        it("refuses an asset URL outside the repo's release downloads", function()
            for _, url in ipairs{
                "https://example.com/adayag/kopanda/releases/download/v0.2.0/manifest.json",
                "http://github.com/adayag/kopanda/releases/download/v0.2.0/manifest.json",
                "https://github.com/other/kopanda/releases/download/v0.2.0/manifest.json",
                "https://github.com/adayag/kopanda/releases/download.evil/manifest.json",
            } do
                local doc = rapidjson.decode(release_json())
                doc.assets[1].browser_download_url = url
                routes[API] = { 200, rapidjson.encode(doc) }
                assert.truthy(refused():find("manifest.json", 1, true))
            end
        end)
    end)

    describe("compare", function()
        it("orders versions by number, component by component", function()
            assert.truthy(ReleaseSource.compare("0.1.10", "0.1.9") > 0)
            assert.truthy(ReleaseSource.compare("0.1.9", "0.1.10") < 0)
            assert.truthy(ReleaseSource.compare("1.0.0", "0.99.99") > 0)
            assert.truthy(ReleaseSource.compare("0.2.0", "0.1.3") > 0)
            assert.equals(0, ReleaseSource.compare("0.1.3", "0.1.3"))
        end)

        it("takes a version that doesn't parse as older than any that does", function()
            assert.truthy(ReleaseSource.compare("0.0.0-dev", "0.0.1") < 0)
            assert.truthy(ReleaseSource.compare("0.0.1", "0.0.0-dev") > 0)
            assert.truthy(ReleaseSource.compare("0.0.0-dev", "0.0.0") < 0)
            assert.truthy(ReleaseSource.compare(nil, "0.0.0") < 0)
            assert.equals(0, ReleaseSource.compare("0.0.0-dev", "dev"))
            assert.equals(0, ReleaseSource.compare(nil, 12))
        end)
    end)

    describe("installed_version", function()
        it("reads _meta.lua's version", function()
            write(dir .. "/_meta.lua", 'return { fullname = "KoPanda", version = "0.1.3" }\n')
            assert.equals("0.1.3", ReleaseSource.installed_version(dir))
        end)

        it("gives 0.0.0-dev for a missing, broken or versionless _meta.lua", function()
            assert.equals("0.0.0-dev", ReleaseSource.installed_version(dir))
            write(dir .. "/_meta.lua", "return {")
            assert.equals("0.0.0-dev", ReleaseSource.installed_version(dir))
            write(dir .. "/_meta.lua", "return { version = 3 }\n")
            assert.equals("0.0.0-dev", ReleaseSource.installed_version(dir))
            write(dir .. "/_meta.lua", "return os.exit(1)\n")
            assert.equals("0.0.0-dev", ReleaseSource.installed_version(dir))
        end)

        it("takes the repo's own plugin for older than any release", function()
            local repo = os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin"
            assert.equals("0.0.0-dev", ReleaseSource.installed_version(repo))
            assert.truthy(ReleaseSource.compare(ReleaseSource.installed_version(repo), "0.0.1") < 0)
        end)
    end)

    describe("source", function()
        local release = {
            version = "0.2.0",
            notes = "",
            manifest_url = DOWNLOAD .. "manifest.json",
            zip_url = DOWNLOAD .. "kopanda.koplugin.zip",
        }
        local PLUGIN = {
            ["_meta.lua"] = 'return { fullname = "KoPanda", version = "0.2.0" }\n',
            ["icons/a.svg"] = "<svg/>\n",
            ["main.lua"] = "-- released\n",
        }
        local paths, manifest, zips

        -- The plugin's files under root/kopanda.koplugin.
        local function write_plugin(root)
            sh("mkdir -p '" .. root .. "/kopanda.koplugin/icons'")
            for rel, text in pairs(PLUGIN) do
                write(root .. "/kopanda.koplugin/" .. rel, text)
            end
        end

        -- The release manifest of PLUGIN, as the studio's release bundle writes it.
        local function release_manifest()
            local root = dir .. "/manifest-tree"
            sh("mkdir -p '" .. root .. "/plugin/icons'")
            local files = {}
            for _, rel in ipairs{ "_meta.lua", "icons/a.svg", "main.lua" } do
                local path = "plugin/" .. rel
                write(root .. "/" .. path, PLUGIN[rel])
                files[#files + 1] = { path = path, size = #PLUGIN[rel],
                    sha256 = PushBundle.sha256_file(root .. "/" .. path) }
            end
            return { format = 1, profile = "release", settings = false,
                hash = PushBundle.bundle_hash(root, files), files = files }
        end

        -- A zip of entries ({ path, bytes } pairs, in order) built with ffi/archiver's Writer.
        -- Each entry is added from a file on disk, so it keeps the file's permissions:
        -- addFileFromMemory's are the decimal 644 (ffi/archiver.lua:264), which no zip has.
        -- addPath returns false even when it worked, its loop ending at ARCHIVE_EOF
        -- (ffi/archiver.lua:305-355), so its err is checked instead.
        local function zip_of(entries)
            zips = zips + 1
            local path = dir .. "/built-" .. zips .. ".zip"
            local writer = Archiver.Writer:new()
            assert.truthy(writer:open(path, "zip"))
            writer:setZipCompression("deflate")
            for i, entry in ipairs(entries) do
                local source = path .. "." .. i
                write(source, entry[2])
                writer:addPath(entry[1], source)
                assert.is_nil(writer.err)
            end
            writer:close()
            return read(path)
        end

        -- The zip's entries for PLUGIN, in byte order of their paths.
        local function plugin_entries()
            local entries = {}
            for _, rel in ipairs{ "_meta.lua", "icons/a.svg", "main.lua" } do
                entries[#entries + 1] = { "kopanda.koplugin/" .. rel, PLUGIN[rel] }
            end
            return entries
        end

        local function serve(zip_bytes, doc)
            routes[release.manifest_url] = { 200, rapidjson.encode(doc or manifest) }
            routes[release.zip_url] = { 200, zip_bytes }
        end

        local function run()
            return ReleaseSource.source(release)(paths)
        end

        local function refused()
            local ok, why = run()
            assert.is_nil(ok)
            assert.is_string(why)
            return why
        end

        before_each(function()
            paths = PushApply.paths(dir .. "/data")
            sh("mkdir -p '" .. paths.download .. "'")
            manifest = release_manifest()
            zips = 0
        end)

        it("downloads, unpacks and verifies the release into download/plugin", function()
            serve(zip_of(plugin_entries()))
            local checked = assert(run())
            assert.is_false(checked.settings)
            assert.equals("release", checked.profile)
            assert.equals(manifest.hash, checked.hash)
            assert.same({
                plugin = "<dir>",
                ["plugin/_meta.lua"] = PLUGIN["_meta.lua"],
                ["plugin/icons"] = "<dir>",
                ["plugin/icons/a.svg"] = PLUGIN["icons/a.svg"],
                ["plugin/main.lua"] = PLUGIN["main.lua"],
            }, tree(paths.download))
            assert.same({ release.manifest_url, release.zip_url }, { requests[1].url, requests[2].url })
        end)

        it("unpacks a zip that holds folder entries, as zip -r writes them", function()
            local src = dir .. "/src"
            write_plugin(src)
            local zip_path = dir .. "/with-folders.zip"
            local writer = Archiver.Writer:new()
            assert.truthy(writer:open(zip_path, "zip"))
            writer:addPath("kopanda.koplugin", src .. "/kopanda.koplugin", true)
            assert.is_nil(writer.err)
            writer:close()
            local reader = Archiver.Reader:new()
            assert.truthy(reader:open(zip_path))
            local kinds = {}
            for entry in reader:iterate() do
                kinds[entry.mode] = true
            end
            reader:close()
            assert.is_true(kinds.directory)
            serve(read(zip_path))
            assert.truthy(run())
            assert.equals(PLUGIN["icons/a.svg"], read(paths.download .. "/plugin/icons/a.svg"))
        end)

        it("refuses a manifest that carries settings, fetching no zip", function()
            local doc = release_manifest()
            doc.settings = nil
            doc.files[#doc.files + 1] = { path = "settings.lua", size = 0, sha256 = string.rep("a", 64) }
            assert.truthy(PushBundle.check_manifest(doc, "release"))
            serve(zip_of(plugin_entries()), doc)
            assert.truthy(refused():find("settings", 1, true))
            assert.equals(1, #requests)
        end)

        it("refuses a manifest the device's checks refuse, fetching no zip", function()
            local doc = release_manifest()
            doc.profile = "vector"
            serve(zip_of(plugin_entries()), doc)
            assert.truthy(refused():find("manifest", 1, true))
            assert.same({ release.manifest_url }, { requests[1].url })
            assert.equals(1, #requests)
        end)

        it("says why the manifest or the zip couldn't be downloaded", function()
            assert.truthy(refused():find("404", 1, true))
            routes[release.manifest_url] = { 200, rapidjson.encode(manifest) }
            routes[release.zip_url] = function()
                return nil, "timeout"
            end
            assert.truthy(refused():find("timeout", 1, true))
        end)

        it("refuses a download that is not a zip", function()
            serve("not a zip at all")
            refused()
            assert.is_nil(mode(paths.download .. "/plugin/main.lua"))
        end)

        local bad_entries = {
            { "a file outside the plugin's folder", { "evil.lua", "-- evil\n" }, "not under" },
            { "another top-level folder", { "other.koplugin/main.lua", "-- other\n" }, "not under" },
            { "a path climbing out", { "kopanda.koplugin/../evil.lua", "-- evil\n" }, "not under" },
            { "an unsafe name", { "kopanda.koplugin/ev il.lua", "-- evil\n" }, "not under" },
            { "a file the manifest doesn't name", { "kopanda.koplugin/extra.lua", "-- extra\n" },
                "not in the manifest" },
            { "a second copy of a file", { "kopanda.koplugin/main.lua", "-- released\n" }, "twice" },
            { "a name the manifest's differs from only in case", { "kopanda.koplugin/Main.lua", "-- released\n" },
                "not in the manifest" },
        }
        for _, case in ipairs(bad_entries) do
            it("refuses a zip with " .. case[1], function()
                local entries = plugin_entries()
                entries[#entries + 1] = case[2]
                serve(zip_of(entries))
                local why = refused()
                assert.truthy(why:find(case[2][1], 1, true))
                assert.truthy(why:find(case[3], 1, true))
                assert.is_nil(mode(dir .. "/data/settings/kopanda/push/evil.lua"))
                assert.is_nil(mode(dir .. "/data/settings/kopanda/evil.lua"))
            end)
        end

        it("refuses a zip holding a link", function()
            local src = dir .. "/src"
            write_plugin(src)
            sh("ln -s main.lua '" .. src .. "/kopanda.koplugin/link.lua'")
            local zip_path = dir .. "/with-link.zip"
            local writer = Archiver.Writer:new()
            assert.truthy(writer:open(zip_path, "zip"))
            writer:addPath("kopanda.koplugin", src .. "/kopanda.koplugin", true)
            assert.is_nil(writer.err)
            writer:close()
            serve(read(zip_path))
            local why = refused()
            assert.truthy(why:find("kopanda.koplugin/link.lua", 1, true))
            assert.truthy(why:find("not a regular file", 1, true))
            assert.is_nil(mode(paths.download .. "/plugin/link.lua"))
        end)

        it("refuses a file whose size isn't the manifest's before unpacking it", function()
            local entries = plugin_entries()
            entries[1] = { "kopanda.koplugin/_meta.lua", PLUGIN["_meta.lua"] .. "-- longer\n" }
            serve(zip_of(entries))
            local why = refused()
            assert.truthy(why:find("kopanda.koplugin/_meta.lua", 1, true))
            assert.truthy(why:find("size", 1, true))
            assert.same({}, tree(paths.download .. "/plugin"))
        end)

        -- A ustar archive (libarchive reads any format, whatever the name) of entries: { path,
        -- bytes } for a file, plus link for a hard link to that path, given in a pax header so
        -- its length is free. A pax hard link carries its data (libarchive's tar reader).
        local function tar_of(entries)
            local function octal(n, width)
                return string.format("%0" .. (width - 1) .. "o", n) .. "\0"
            end
            local function field(text, width)
                return text .. string.rep("\0", width - #text)
            end
            local function padded(data)
                return data .. string.rep("\0", (512 - #data % 512) % 512)
            end
            local function header(name, size, typeflag, linkname)
                local block = table.concat{
                    field(name, 100), octal(420, 8), octal(0, 8), octal(0, 8), octal(size, 12),
                    octal(0, 12), string.rep(" ", 8), typeflag, field(linkname or "", 100),
                    "ustar\0", "00", field("", 32), field("", 32), field("", 8), field("", 8),
                    field("", 155), field("", 12),
                }
                local sum = 0
                for i = 1, #block do
                    sum = sum + block:byte(i)
                end
                return block:sub(1, 148) .. string.format("%06o", sum) .. "\0 " .. block:sub(157)
            end
            local out = {}
            for _, entry in ipairs(entries) do
                if entry.link then
                    local rest = " linkpath=" .. entry.link .. "\n"
                    local length = #rest + 1
                    while #rest + #tostring(length) ~= length do
                        length = #rest + #tostring(length)
                    end
                    local record = length .. rest
                    out[#out + 1] = header("PaxHeader", #record, "x") .. padded(record)
                end
                out[#out + 1] = header(entry[1], #entry[2], entry.link and "1" or "0", entry.link and "link")
                    .. padded(entry[2])
            end
            out[#out + 1] = string.rep("\0", 1024)
            return table.concat(out)
        end

        it("refuses a hard link served as the zip, writing nothing through it", function()
            local victim = dir .. "/victim.txt"
            write(victim, "-- victim's\n")
            local entries = plugin_entries()
            entries[3] = { "kopanda.koplugin/main.lua", "-- evil!!!!\n", link = victim }
            assert.equals(#PLUGIN["main.lua"], #entries[3][2])
            serve(tar_of(entries))
            refused()
            assert.equals("-- victim's\n", read(victim))
        end)

        it("refuses a zip whose file differs from the manifest", function()
            local entries = plugin_entries()
            entries[3] = { "kopanda.koplugin/main.lua", "-- tampered\n" }
            serve(zip_of(entries))
            assert.truthy(refused():find("plugin/main.lua", 1, true))
        end)

        it("refuses a zip missing a file the manifest names", function()
            local entries = plugin_entries()
            table.remove(entries, 2)
            serve(zip_of(entries))
            assert.truthy(refused():find("plugin/icons/a.svg", 1, true))
        end)
    end)
end)
