-- The studio's push routes, served from files for spec/emulator/push_spec.lua. Run with the
-- emulator's luajit from its koreader directory, LUA_PATH '?.lua;common/?.lua;frontend/?.lua'
-- and LUA_CPATH '?.so;common/?.so' (common/socket.lua is Lua over common/socket/score.so):
--
--   ./luajit push_server.lua <root> <port_file> <lifetime_s>
--
-- Binds 127.0.0.1 on a port the system picks (common/socket.lua:27-40), writes the port to
-- port_file once it listens, and answers one connection at a time, GET only, from what
-- spec/emulator/push_bundles.lua wrote under root:
--   /api/push/profiles                   <root>/profiles.json
--   /api/push/<id>/manifest              <root>/<id>/manifest.json
--   /api/push/<id>/files/<hash>/<path>   <root>/<id>/tree/<path>, for a path the manifest lists;
--                                        409 { error, hash } when <hash> is not the manifest's
-- and 404 { error } for anything else. Every answer has Content-Length and Connection: close.
-- It exits after lifetime_s with no connection, so a spec that dies leaves no server behind.
local rapidjson = require("rapidjson")
local socket = require("socket")

local root, port_file, lifetime_s = arg[1], arg[2], tonumber(arg[3])
if not (root and port_file and lifetime_s) then
    io.stderr:write("usage: push_server.lua <root> <port_file> <lifetime_s>\n")
    os.exit(2)
end

local CLIENT_TIMEOUT_S = 10
local REASONS = { [200] = "OK", [404] = "Not Found", [409] = "Conflict" }

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local bytes = f:read("*a")
    f:close()
    return bytes
end

local function json(status, value)
    return status, "application/json", rapidjson.encode(value)
end

local function not_found()
    return json(404, { error = "not found" })
end

-- A profile id names a folder under root, so only a plain name is one.
local function bundle(id)
    if not id:match("^[A-Za-z0-9_-]+$") then
        return nil
    end
    local text = read_file(root .. "/" .. id .. "/manifest.json")
    return text and { text = text, manifest = rapidjson.decode(text) }
end

-- status, content type and body for a GET of target.
local function route(target)
    if target == "/api/push/profiles" then
        local text = read_file(root .. "/profiles.json")
        if not text then
            return not_found()
        end
        return 200, "application/json", text
    end
    local id = target:match("^/api/push/([^/]+)/manifest$")
    if id then
        local found = bundle(id)
        if not found then
            return not_found()
        end
        return 200, "application/json", found.text
    end
    local hash, path
    id, hash, path = target:match("^/api/push/([^/]+)/files/([^/]+)/(.+)$")
    if not id then
        return not_found()
    end
    local found = bundle(id)
    if not found then
        return not_found()
    end
    if hash ~= found.manifest.hash then
        return json(409, { error = "the bundle changed", hash = found.manifest.hash })
    end
    for _, file in ipairs(found.manifest.files) do
        if file.path == path then
            local bytes = read_file(root .. "/" .. id .. "/tree/" .. path)
            if not bytes then
                return not_found()
            end
            return 200, "application/octet-stream", bytes
        end
    end
    return not_found()
end

local function answer(client)
    client:settimeout(CLIENT_TIMEOUT_S)
    local request_line = client:receive("*l")
    if not request_line then
        return
    end
    repeat
        local header = client:receive("*l")
    until not header or header == ""
    local method, target = request_line:match("^(%S+) (%S+) HTTP/%d%.%d$")
    local status, content_type, body
    if method == "GET" then
        status, content_type, body = route(target)
    else
        status, content_type, body = not_found()
    end
    print(string.format("push_server: %s %s %d", tostring(method), tostring(target), status))
    client:send(table.concat({
        string.format("HTTP/1.1 %d %s", status, REASONS[status]),
        "Content-Type: " .. content_type,
        "Content-Length: " .. #body,
        "Connection: close",
        "",
        body,
    }, "\r\n"))
end

local server = assert(socket.bind("127.0.0.1", 0))
local _, port = server:getsockname()
local tmp = port_file .. ".tmp"
local f = assert(io.open(tmp, "w"))
f:write(port, "\n")
f:close()
assert(os.rename(tmp, port_file))
io.stdout:setvbuf("line")

server:settimeout(lifetime_s)
while true do
    local client = server:accept()
    if not client then
        break
    end
    local ok, err = pcall(answer, client)
    if not ok then
        print("push_server: " .. tostring(err))
    end
    client:close()
end
server:close()
