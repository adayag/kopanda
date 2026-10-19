-- The pull: on scratch data folders under the run's KO_HOME, with socket.http's request
-- stubbed to answer from a table of URL -> status and body (the bodies read from a scratch copy
-- of the shared vectors' tree), a verified bundle is staged and the apply patch armed, and every
-- refusal leaves download/ purged, no staged.lua and an earlier stage byte-identical. No test
-- touches the network.
describe("the pull", function()
    -- KOReader's spec setup: socketutil and util reach the device, which reads G_reader_settings.
    require("commonrequire")
    local PushApply = require("push_apply")
    local PushPull = require("push_pull")
    local http = require("socket.http")
    local lfs = require("libs/libkoreader-lfs")
    local rapidjson = require("rapidjson")
    local socketutil = require("socketutil")
    local ko_home = os.getenv("KO_HOME")
    local fixtures = os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/push"
    local apply_source = os.getenv("KOPANDA_ROOT") .. "/kopanda.koplugin/push_apply.lua"
    local BASE = "http://192.168.1.20:4490"
    local ADDRESS = "192.168.1.20:4490"

    local counter = 0
    -- The scratch data folder, its push paths, the running plugin's folder, the bundle tree the
    -- stub serves from, the manifest it serves (a table, encoded per request unless raw is
    -- set), the requests made, overrides of the routes and the request stub.
    local dir, p, plugin_dir, bundle, served, raw, requests, routes, request_stub

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

    local function decode(text)
        return assert(rapidjson.decode(text))
    end

    local function file_url(path, hash)
        return BASE .. "/api/push/vector/files/" .. (hash or served.hash) .. "/" .. path
    end

    -- How the stub answers url: an override from routes, the manifest, a file of the bundle,
    -- or a 404 with a JSON error.
    local function answer(url)
        if routes[url] then
            return routes[url]
        end
        if url == BASE .. "/api/push/vector/manifest" then
            return { 200, raw or rapidjson.encode(served) }
        end
        local hash, path = url:match("^" .. BASE:gsub("%p", "%%%0") .. "/api/push/vector/files/(%x+)/(.+)$")
        if hash == served.hash and read(bundle .. "/" .. path) then
            return { 200, read(bundle .. "/" .. path) }
        end
        return { 404, '{"error":"not found"}' }
    end

    local function stub_requests()
        request_stub = stub(http, "request", function(request)
            requests[#requests + 1] = {
                url = request.url,
                method = request.method,
                headers = request.headers,
                scheme = request.scheme,
                create = request.create,
                maxredirects = request.maxredirects,
                block = socketutil.block_timeout,
                total = socketutil.total_timeout,
            }
            local reply = answer(request.url)
            if type(reply) == "function" then
                return reply(request)
            end
            -- Fed in two chunks, then the end, as LTN12 pumps a body.
            local body = reply[2]
            local half = math.floor(#body / 2)
            request.sink(body:sub(1, half))
            request.sink(body:sub(half + 1))
            request.sink(nil)
            return 1, reply[1], { ["content-type"] = "application/octet-stream" }, "HTTP/1.1 " .. reply[1]
        end)
    end

    local function pull(fields)
        local opts = {
            address = ADDRESS,
            profile = "vector",
            data_dir = dir,
            plugin_dir = plugin_dir,
            disable = { "ennUI" },
        }
        for k, v in pairs(fields or {}) do
            opts[k] = v
        end
        return PushPull.pull(opts)
    end

    -- The stage and the armed patch, to compare before and after a refused pull.
    local function stage_snapshot()
        return {
            staged = tree(p.staged),
            record = read(p.staged_record),
            patch = read(p.patches .. "/1-kopanda-apply.lua"),
        }
    end

    -- A first good pull of the vectors, then the served manifest reset for the case.
    local function good_stage()
        assert.is_true(pull())
        assert.equals("file", mode(p.staged_record))
        requests = {}
        served = decode(read(fixtures .. "/manifest.json"))
        return stage_snapshot()
    end

    -- Runs a pull that must be refused over an earlier good stage, once break_bundle has changed
    -- what the studio serves; checks the stage is untouched and download/ gone, and returns the
    -- message and code.
    local function refused_over_stage(break_bundle)
        local before = good_stage()
        break_bundle()
        local ok, message, code = pull()
        assert.is_nil(ok)
        assert.is_string(message)
        assert.is_nil(mode(p.download))
        assert.same(before, stage_snapshot())
        return message, code
    end

    -- A refused_over_stage whose manifest did the refusing: nothing but the manifest requested,
    -- and the message says so.
    local function refused_manifest(break_bundle)
        local message, code = refused_over_stage(break_bundle)
        local urls = {}
        for i, request in ipairs(requests) do
            urls[i] = request.url
        end
        assert.same({ BASE .. "/api/push/vector/manifest" }, urls)
        assert.truthy(message:find("manifest", 1, true))
        return message, code
    end

    before_each(function()
        counter = counter + 1
        dir = ko_home .. "/push-pull-" .. counter
        p = PushApply.paths(dir)
        plugin_dir = dir .. "/plugins/kopanda.koplugin"
        bundle = dir .. "/served"
        sh("mkdir -p '" .. plugin_dir .. "' '" .. bundle .. "'")
        sh("cp '" .. apply_source .. "' '" .. plugin_dir .. "/push_apply.lua'")
        sh("cp -R '" .. fixtures .. "/tree/.' '" .. bundle .. "/'")
        served = decode(read(fixtures .. "/manifest.json"))
        raw = nil
        requests = {}
        routes = {}
        stub_requests()
    end)

    after_each(function()
        request_stub:revert()
        os.execute("chmod -R u+w '" .. dir .. "' 2>/dev/null")
        os.execute("rm -rf '" .. dir .. "'")
    end)

    describe("a verified bundle", function()
        it("is staged, recorded and armed", function()
            assert.is_true(pull{ plugin_dir = dir .. "/plugins//kopanda.koplugin" })
            assert.same(tree(fixtures .. "/tree"), tree(p.staged))
            assert.is_nil(mode(p.download))
            local record = dofile(p.staged_record)
            assert.equals(1, record.format)
            assert.equals("vector", record.profile)
            assert.equals(served.hash, record.hash)
            assert.equals(dir .. "/plugins/kopanda.koplugin", record.plugin_dir)
            assert.same({ "ennUI" }, record.disable)
            assert.truthy(record.at:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
            assert.equals(read(apply_source), read(p.patches .. "/1-kopanda-apply.lua"))
        end)

        it("makes a relative plugin folder absolute under the working directory", function()
            local cwd = lfs.currentdir()
            finally(function()
                lfs.chdir(cwd)
            end)
            assert.truthy(lfs.chdir(dir))
            local here = lfs.currentdir()
            assert.is_true(pull{ plugin_dir = "plugins/kopanda.koplugin" })
            lfs.chdir(cwd)
            assert.equals(here .. "/plugins/kopanda.koplugin", dofile(p.staged_record).plugin_dir)
        end)

        it("records an empty disable list when no shell is enabled", function()
            assert.is_true(pull{ disable = {} })
            assert.same({}, dofile(p.staged_record).disable)
        end)

        it("fetches the manifest, then each file under the manifest's hash, with file timeouts", function()
            assert.is_true(pull{ address = "  " .. ADDRESS .. "/ " })
            local urls = {}
            for i, request in ipairs(requests) do
                urls[i] = request.url
                assert.equals("GET", request.method)
                assert.equals("identity", request.headers["Accept-Encoding"])
                assert.equals(socketutil.FILE_BLOCK_TIMEOUT, request.block)
                assert.equals(socketutil.FILE_TOTAL_TIMEOUT, request.total)
            end
            local expected = { BASE .. "/api/push/vector/manifest" }
            for _, file in ipairs(served.files) do
                expected[#expected + 1] = file_url(file.path)
            end
            assert.same(expected, urls)
            assert.equals(socketutil.DEFAULT_BLOCK_TIMEOUT, socketutil.block_timeout)
            assert.equals(socketutil.DEFAULT_TOTAL_TIMEOUT, socketutil.total_timeout)
        end)

        it("keeps an address with its own scheme", function()
            assert.is_true(pull{ address = BASE })
            assert.equals(BASE .. "/api/push/vector/manifest", requests[1].url)
        end)

        it("replaces an earlier stage", function()
            good_stage()
            write(bundle .. "/plugin/main.lua", "-- changed\n")
            served.files[3].size = #"-- changed\n"
            served.files[3].sha256 = require("push_bundle").sha256_file(bundle .. "/plugin/main.lua")
            served.hash = require("push_bundle").bundle_hash(bundle, served.files)
            assert.is_true(pull())
            assert.equals("-- changed\n", read(p.staged .. "/plugin/main.lua"))
            assert.equals(served.hash, dofile(p.staged_record).hash)
        end)

        it("purges a leftover download/ first, never following a link", function()
            local outside = dir .. "/outside"
            sh("mkdir -p '" .. outside .. "' '" .. p.download .. "/plugin'")
            write(outside .. "/keep.txt", "keep\n")
            write(p.download .. "/stray.txt", "stray\n")
            sh("ln -s '" .. outside .. "' '" .. p.download .. "/plugin/link'")
            assert.is_true(pull())
            assert.equals("keep\n", read(outside .. "/keep.txt"))
            assert.is_nil(mode(p.staged .. "/stray.txt"))
            assert.is_nil(mode(p.staged .. "/plugin/link"))
        end)
    end)

    describe("refused before any request", function()
        -- Refused with nothing requested and nothing written.
        local function refused_untouched(fields)
            local ok, message = pull(fields)
            assert.is_nil(ok)
            assert.is_string(message)
            assert.same({}, requests)
            assert.is_nil(mode(p.push))
            assert.is_nil(mode(p.patches .. "/1-kopanda-apply.lua"))
            return message
        end

        it("with no address", function()
            refused_untouched{ address = false }
            refused_untouched{ address = "  " }
        end)

        it("with no profile", function()
            refused_untouched{ profile = false }
            refused_untouched{ profile = "" }
        end)

        it("with user patches disabled", function()
            sh("mkdir -p '" .. p.patches .. "'")
            write(p.patches .. "/.patches_disabled", "")
            assert.truthy(refused_untouched():find(".patches_disabled", 1, true))
        end)

        it("while the last pull is on probation", function()
            sh("mkdir -p '" .. p.push .. "'")
            write(p.probation, "return {}\n")
            local ok, message = pull()
            assert.is_nil(ok)
            assert.truthy(message:find("probation", 1, true))
            assert.same({}, requests)
            assert.same({ ["probation.lua"] = "return {}\n" }, tree(p.push))
        end)

        it("from a plugin folder not named kopanda.koplugin", function()
            local other = dir .. "/plugins/kopanda-dev.koplugin"
            sh("mkdir -p '" .. other .. "'")
            assert.truthy(refused_untouched{ plugin_dir = other }:find("kopanda-dev.koplugin", 1, true))
        end)
    end)

    describe("a refused manifest", function()
        it("that is not JSON", function()
            refused_manifest(function()
                raw = "<html>not json</html>"
            end)
        end)

        it("that is not an object", function()
            refused_manifest(function()
                raw = "[1, 2]"
            end)
        end)

        it("of another format", function()
            refused_manifest(function()
                served.format = 2
            end)
        end)

        it("of another profile", function()
            refused_manifest(function()
                served.profile = "colorsoft"
            end)
        end)

        it("with a hash that is not 64 hex", function()
            refused_manifest(function()
                served.hash = "abc"
            end)
        end)

        it("with a sha256 that is not 64 hex", function()
            refused_manifest(function()
                served.files[1].sha256 = "abc"
            end)
        end)

        for _, size in ipairs{ -1, 1.5 } do
            it("with a size of " .. size, function()
                refused_manifest(function()
                    served.files[1].size = size
                end)
            end)
        end

        for _, path in ipairs{ "plugin/../x", "plugin//x", "plugin/./x", "plugin/x y", "plugin/x\\y" } do
            it("with the unsafe path " .. path, function()
                refused_manifest(function()
                    table.insert(served.files, 3, { path = path, size = 0, sha256 = string.rep("a", 64) })
                    table.sort(served.files, function(a, b)
                        return a.path < b.path
                    end)
                end)
            end)
        end

        it("with an absolute path", function()
            refused_manifest(function()
                table.insert(served.files, 1, { path = "/x", size = 0, sha256 = string.rep("a", 64) })
            end)
        end)

        it("with a path neither settings.lua nor under plugin/", function()
            refused_manifest(function()
                table.insert(served.files, { path = "zzz.lua", size = 0, sha256 = string.rep("a", 64) })
            end)
        end)

        it("with two paths equal ignoring case", function()
            refused_manifest(function()
                table.insert(served.files, 1, { path = "plugin/Main.lua", size = 0, sha256 = string.rep("a", 64) })
            end)
        end)

        for _, required in ipairs{ "settings.lua", "plugin/main.lua", "plugin/_meta.lua" } do
            it("missing " .. required, function()
                refused_manifest(function()
                    for i, file in ipairs(served.files) do
                        if file.path == required then
                            table.remove(served.files, i)
                            break
                        end
                    end
                end)
            end)
        end

        it("with paths out of byte order", function()
            refused_manifest(function()
                served.files[1], served.files[2] = served.files[2], served.files[1]
            end)
        end)

        it("answered 404 for a profile the studio no longer has", function()
            local message, code = refused_manifest(function()
                routes[BASE .. "/api/push/vector/manifest"] = { 404, '{"error":"no profile \\"vector\\""}' }
            end)
            assert.equals(404, code)
            assert.truthy(message:find("no profile", 1, true))
        end)
    end)

    describe("a refused file", function()
        it("answered 409: changed in the studio during the pull", function()
            local message, code = refused_over_stage(function()
                local body = '{"error":"changed","hash":"' .. string.rep("b", 64) .. '"}'
                routes[file_url("plugin/main.lua")] = { 409, body }
            end)
            assert.equals("vector changed in the studio during the pull; pull again.", message)
            assert.equals(409, code)
        end)

        it("answered 404, naming the path", function()
            local message = refused_over_stage(function()
                routes[file_url("plugin/icons/a.svg")] = { 404, '{"error":"no file"}' }
            end)
            assert.truthy(message:find("plugin/icons/a.svg", 1, true))
        end)

        it("whose request fails, naming the path", function()
            local message = refused_over_stage(function()
                routes[file_url("settings.lua")] = function()
                    return nil, "timeout"
                end
            end)
            assert.truthy(message:find("settings.lua", 1, true))
            assert.truthy(message:find("timeout", 1, true))
        end)

        it("whose request raises, with socketutil reset after", function()
            local message = refused_over_stage(function()
                routes[file_url("plugin/main.lua")] = function()
                    error("kopanda-test: request raised")
                end
            end)
            assert.truthy(message:find("plugin/main.lua", 1, true))
            assert.equals(socketutil.DEFAULT_BLOCK_TIMEOUT, socketutil.block_timeout)
            assert.equals(socketutil.DEFAULT_TOTAL_TIMEOUT, socketutil.total_timeout)
        end)

        it("whose manifest request raises, with socketutil reset after", function()
            refused_manifest(function()
                routes[BASE .. "/api/push/vector/manifest"] = function()
                    error("kopanda-test: request raised")
                end
            end)
            assert.equals(socketutil.DEFAULT_BLOCK_TIMEOUT, socketutil.block_timeout)
            assert.equals(socketutil.DEFAULT_TOTAL_TIMEOUT, socketutil.total_timeout)
        end)

        it("of the wrong size", function()
            local message = refused_over_stage(function()
                routes[file_url("plugin/main.lua")] = { 200, read(bundle .. "/plugin/main.lua") .. "x" }
            end)
            assert.truthy(message:find("plugin/main.lua", 1, true))
            assert.truthy(message:find("bytes", 1, true))
        end)

        it("of the right size and the wrong sha256", function()
            assert.truthy(refused_over_stage(function()
                local text = read(bundle .. "/plugin/main.lua")
                routes[file_url("plugin/main.lua")] = { 200, ("x"):rep(#text) }
            end):find("plugin/main.lua", 1, true))
        end)

        it("in a bundle whose hash does not recompute", function()
            refused_over_stage(function()
                served.hash = string.rep("c", 64)
            end)
        end)
    end)

    describe("the arm", function()
        it("leaves no staged.lua when it fails", function()
            sh("mkdir -p '" .. p.patches .. "' && chmod 555 '" .. p.patches .. "'")
            local ok, message = pull()
            assert.is_nil(ok)
            assert.is_string(message)
            assert.is_nil(mode(p.staged_record))
            assert.is_nil(mode(p.download))
            assert.is_nil(mode(p.patches .. "/1-kopanda-apply.lua"))
        end)
    end)

    describe("from a source", function()
        local PushBundle = require("push_bundle")

        -- A source that writes a plugin-only bundle into download/ and returns its checked
        -- manifest, recording the paths it was given.
        local given
        local function plugin_only_source(paths)
            given = paths
            sh("mkdir -p '" .. paths.download .. "/plugin'")
            write(paths.download .. "/plugin/_meta.lua", "return { version = \"0.2.0\" }\n")
            write(paths.download .. "/plugin/main.lua", "-- released\n")
            local files = {}
            for _, rel in ipairs{ "plugin/_meta.lua", "plugin/main.lua" } do
                local path = paths.download .. "/" .. rel
                files[#files + 1] = { path = rel, size = lfs.attributes(path, "size"),
                    sha256 = PushBundle.sha256_file(path) }
            end
            return assert(PushBundle.check_manifest({ format = 1, profile = "release", settings = false,
                hash = PushBundle.bundle_hash(paths.download, files), files = files }, "release"))
        end

        it("stages what the source downloaded, with no address and no request", function()
            given = nil
            assert.is_true(pull{ address = false, profile = "release", source = plugin_only_source })
            assert.same(p, given)
            assert.same({}, requests)
            assert.same({
                plugin = "<dir>",
                ["plugin/_meta.lua"] = "return { version = \"0.2.0\" }\n",
                ["plugin/main.lua"] = "-- released\n",
            }, tree(p.staged))
            assert.is_nil(mode(p.download))
            local record = dofile(p.staged_record)
            assert.equals("release", record.profile)
            assert.is_false(record.settings)
            assert.equals(read(apply_source), read(p.patches .. "/1-kopanda-apply.lua"))
        end)

        it("records that a studio bundle carries its settings", function()
            assert.is_true(pull())
            assert.is_true(dofile(p.staged_record).settings)
        end)

        it("still needs a profile", function()
            local ok, message = pull{ address = false, profile = false, source = plugin_only_source }
            assert.is_nil(ok)
            assert.equals("Choose a profile first.", message)
        end)

        it("returns the source's refusal, download/ purged and an earlier stage untouched", function()
            local before = good_stage()
            local ok, message, code = pull{ profile = "release", source = function(paths)
                write(paths.download .. "/partial", "x")
                return nil, "kopanda-test: no release yet", 404
            end }
            assert.is_nil(ok)
            assert.equals("kopanda-test: no release yet", message)
            assert.equals(404, code)
            assert.is_nil(mode(p.download))
            assert.same(before, stage_snapshot())
        end)

        it("says the pull failed when the source raises, download/ purged", function()
            local ok, message = pull{ profile = "release", source = function()
                error("kopanda-test: source raised", 0)
            end }
            assert.is_nil(ok)
            assert.equals("The pull failed: kopanda-test: source raised.", message)
            assert.is_nil(mode(p.download))
            assert.is_nil(mode(p.staged_record))
        end)
    end)

    describe("fetch_json and fetch_file", function()
        it("decode an answer and send extra headers beside Accept-Encoding", function()
            routes["https://example.test/doc"] = { 200, '{"a":1}' }
            assert.same({ a = 1 }, PushPull.fetch_json("https://example.test/doc", { ["User-Agent"] = "ua" }))
            assert.equals("ua", requests[1].headers["User-Agent"])
            assert.equals("identity", requests[1].headers["Accept-Encoding"])
        end)

        it("write an answer to a file, or say why with the status", function()
            routes["https://example.test/file"] = { 200, "bytes" }
            routes["https://example.test/gone"] = { 404, "{}" }
            sh("mkdir -p '" .. dir .. "/out'")
            assert.is_true(PushPull.fetch_file("https://example.test/file", dir .. "/out/f"))
            assert.equals("bytes", read(dir .. "/out/f"))
            local ok, why, code = PushPull.fetch_file("https://example.test/gone", dir .. "/out/g")
            assert.is_nil(ok)
            assert.equals("HTTP status 404", why)
            assert.equals(404, code)
        end)
    end)

    describe("an https request", function()
        local https = require("ssl.https")

        it("connects through a verifying connection, kept across one redirect at most", function()
            routes["https://example.test/doc"] = { 200, '{"a":1}' }
            assert.same({ a = 1 }, PushPull.fetch_json("https://example.test/doc"))
            assert.equals("https", requests[1].scheme)
            assert.is_function(requests[1].create)
            assert.equals(1, requests[1].maxredirects)
        end)

        it("is not made for an http URL, which LuaSocket connects as before", function()
            assert.truthy(PushPull.fetch_json(BASE .. "/api/push/vector/manifest"))
            assert.is_nil(requests[1].scheme)
            assert.is_nil(requests[1].create)
            assert.is_nil(requests[1].maxredirects)
        end)

        -- LuaSec's tcp stubbed: the parameters it gets, and a connection whose handshake gives a
        -- certificate naming names.
        local function connection(names)
            local params
            local tcp_stub = stub(https, "tcp", function(given)
                params = given
                return function()
                    local conn = { sock = {} }
                    function conn.sock.getpeercertificate()
                        return { extensions = function()
                            return { ["2.5.29.17"] = { dNSName = names } }
                        end }
                    end
                    function conn.connect(_, host, port)
                        conn.connected = { host, port }
                        return 1
                    end
                    return conn
                end
            end)
            routes["https://example.test/doc"] = { 200, "{}" }
            PushPull.fetch_json("https://example.test/doc")
            tcp_stub:revert()
            return requests[#requests].create(), params
        end

        it("checks the chain against KOReader's CA bundle, TLS 1.1 and up", function()
            local _, params = connection{ "github.com" }
            assert.equals("peer", params.verify)
            assert.equals("data/ca-bundle.crt", params.cafile)
            assert.equals("any", params.protocol)
            assert.same({ "all", "no_sslv2", "no_sslv3", "no_tlsv1" }, params.options)
        end)

        it("takes a certificate that names the host", function()
            local conn = connection{ "www.github.com", "*.github.com" }
            assert.equals(1, conn:connect("api.github.com", 443))
            assert.same({ "api.github.com", 443 }, conn.connected)
        end)

        it("refuses a certificate that doesn't name the host", function()
            local conn = connection{ "github.com", "www.github.com" }
            local ok, why = conn:connect("api.github.com", 443)
            assert.is_nil(ok)
            assert.truthy(why:find("api.github.com", 1, true))
            assert.is_nil(connection{}:connect("github.com", 443))
            assert.is_nil(connection(nil):connect("github.com", 443))
        end)
    end)

    describe("host_matches", function()
        it("takes a name equal to the host, ignoring case", function()
            assert.is_true(PushPull.host_matches("github.com", { "github.com" }))
            assert.is_true(PushPull.host_matches("GitHub.com", { "github.COM" }))
            assert.is_true(PushPull.host_matches("api.github.com", { "github.com", "api.github.com" }))
        end)

        it("takes a wildcard for exactly one label", function()
            assert.is_true(PushPull.host_matches("api.github.com", { "*.github.com" }))
            assert.is_true(PushPull.host_matches("release-assets.githubusercontent.com",
                { "*.githubusercontent.com" }))
            assert.is_true(PushPull.host_matches("API.GitHub.com", { "*.github.COM" }))
        end)

        it("refuses every other host", function()
            assert.is_false(PushPull.host_matches("github.com", { "*.github.com" }))
            assert.is_false(PushPull.host_matches("evilgithub.com", { "github.com", "*.github.com" }))
            assert.is_false(PushPull.host_matches("a.b.github.com", { "*.github.com" }))
            assert.is_false(PushPull.host_matches("github.com.evil", { "github.com", "*.github.com" }))
            assert.is_false(PushPull.host_matches("github.com", { "*.com" }))
            assert.is_false(PushPull.host_matches("github.com", { "*" }))
            assert.is_false(PushPull.host_matches("api.github.com", { "a*.github.com" }))
            assert.is_false(PushPull.host_matches("github.com", {}))
        end)
    end)

    describe("fetch_profiles", function()
        it("lists the studio's profiles", function()
            routes[BASE .. "/api/push/profiles"] = { 200,
                '{"profiles":[{"id":"colorsoft","name":"Colorsoft","device":"kindle"},'
                .. '{"id":"vector","name":"Vector"}]}' }
            local profiles = assert(PushPull.fetch_profiles(ADDRESS))
            assert.same({ { id = "colorsoft", name = "Colorsoft" }, { id = "vector", name = "Vector" } }, profiles)
            assert.equals(BASE .. "/api/push/profiles", requests[1].url)
        end)

        it("says why when the studio can't be read", function()
            routes[BASE .. "/api/push/profiles"] = function()
                return nil, "connection refused"
            end
            local ok, message = PushPull.fetch_profiles(ADDRESS)
            assert.is_nil(ok)
            assert.truthy(message:find("connection refused", 1, true))
            routes[BASE .. "/api/push/profiles"] = { 200, '{"profiles":"none"}' }
            assert.is_nil((PushPull.fetch_profiles(ADDRESS)))
            routes[BASE .. "/api/push/profiles"] = { 403, '{"error":"loopback only"}' }
            ok, message = PushPull.fetch_profiles(ADDRESS)
            assert.is_nil(ok)
            assert.truthy(message:find("loopback only", 1, true))
        end)
    end)
end)
