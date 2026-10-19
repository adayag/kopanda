describe("the fixture library", function()
    local lfs = require("libs/libkoreader-lfs")
    local sha256 = require("ffi/sha2").sha256
    local dir = os.getenv("KOPANDA_ROOT") .. "/spec/fixtures/library"
    local manifest = dofile(dir .. "/manifest.lua")

    local function read(path)
        local f = assert(io.open(path, "rb"))
        local data = f:read("*a")
        f:close()
        return data
    end

    local function le16(data, offset)
        local a, b = data:byte(offset, offset + 1)
        return a + b * 256
    end

    local function le32(data, offset)
        local a, b, c, d = data:byte(offset, offset + 3)
        return ((d * 256 + c) * 256 + b) * 256 + a
    end

    it("has exactly three entries", function()
        assert.equals(3, #manifest)
    end)

    it("has every entry's file, with the entry's SHA-256", function()
        for _, entry in ipairs(manifest) do
            local path = dir .. "/" .. entry.file
            assert.equals("file", lfs.attributes(path, "mode"), entry.file .. " missing")
            assert.equals(entry.sha256, sha256(read(path)), entry.file .. " hash")
        end
    end)

    it("lists every EPUB in the folder", function()
        local listed = {}
        for _, entry in ipairs(manifest) do
            listed[entry.file] = true
        end
        for name in lfs.dir(dir) do
            if name:match("%.epub$") then
                assert.truthy(listed[name], name .. " is not in the manifest")
            end
        end
    end)

    it("gives every entry a title, an author and an https source", function()
        for _, entry in ipairs(manifest) do
            assert.is_string(entry.title)
            assert.truthy(entry.title ~= "", entry.file .. " title")
            assert.is_string(entry.author)
            assert.truthy(entry.author ~= "", entry.file .. " author")
            assert.is_string(entry.source)
            assert.truthy(entry.source:find("^https://"), entry.file .. " source")
        end
    end)

    -- The EPUB container rule: the first entry of the zip is an uncompressed file named mimetype holding
    -- application/epub+zip. A zip local file header is 30 bytes: the signature PK\3\4, the compression method at bytes
    -- 9-10, the compressed size at 19-22, the name length at 27-28, the extra field length at 29-30, then the name.
    it("stores each EPUB's mimetype first, as application/epub+zip", function()
        for _, entry in ipairs(manifest) do
            local data = read(dir .. "/" .. entry.file)
            assert.equals("PK\3\4", data:sub(1, 4), entry.file .. " is not a zip")
            assert.equals(0, le16(data, 9), entry.file .. " mimetype is compressed")
            local size, name_len, extra_len = le32(data, 19), le16(data, 27), le16(data, 29)
            assert.equals("mimetype", data:sub(31, 30 + name_len), entry.file .. " first entry")
            local start = 31 + name_len + extra_len
            assert.equals("application/epub+zip", data:sub(start, start + size - 1), entry.file .. " mimetype")
        end
    end)
end)
