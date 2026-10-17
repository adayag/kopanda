-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile by
-- spec/emulator/library_placeholder_golden_spec.lua beside the home fixture patch (at empty) and the
-- library scenario patch (2-scenario-library.lua, at its root step). It sorts before both
-- (frontend/userpatch.lua:60-61, natsort), which does not matter: it reads only the capture
-- library's files, and acts only once a file manager is made.
-- cwngsync is never loaded. A stub stands for it (cwng-placeholders D20): registered on every file
-- manager as cwngsync, as FileManager:init registers a plugin instance under its plugin's name
-- (frontend/apps/filemanager/filemanager.lua:379-384, :424), right after that init returns, so it
-- is on FileManager.instance (:447) before the home or the library lists a book. It has:
--   - isConfigured(), true;
--   - getLibraryState(), a state (cwngsync.koplugin/cwng_library.lua:17-20 at df90d5e) whose one
--     book is a-christmas-carol.epub at the capture library's root as a placeholder of its own
--     size, by the path the library lists it at: KOPANDA_LIBRARY_DIR realpath'd, as the library
--     scenario stores the home folder (2-scenario-library.lua), then "/" and the name;
--   - openLibraryPlaceholder(), which only logs and returns true.
-- On the first library's settled signal it logs the index CloudBooks.index() gives, so a path that
-- matches nothing shows in the log as well as in the missing badge. A failure before the UI runs
-- exits with status 4, as the other scenarios do.
local logger = require("logger")

local PLACEHOLDER = "a-christmas-carol.epub"

local ok, err = pcall(function()
    local EventListener = require("ui/widget/eventlistener")
    local FileManager = require("apps/filemanager/filemanager")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")

    local library_dir = os.getenv("KOPANDA_LIBRARY_DIR")
    local root = library_dir and library_dir ~= "" and ffiutil.realpath(library_dir)
    local path = root and root .. "/" .. PLACEHOLDER
    local size = path and lfs.attributes(path, "size")
    if not size then
        error("no " .. PLACEHOLDER .. " in KOPANDA_LIBRARY_DIR " .. tostring(library_dir))
    end
    local state = { version = 1, books = { ["1"] = { kind = "placeholder", path = path, size = size } } }

    local function stub()
        local cwngsync = EventListener:new{}
        function cwngsync.isConfigured()
            return true
        end
        function cwngsync.getLibraryState()
            return state
        end
        function cwngsync.openLibraryPlaceholder(_, file)
            logger.info("KOPANDA_SCENARIO: cwngsync stub asked to download " .. tostring(file))
            return true
        end
        return cwngsync
    end

    local init = FileManager.init
    FileManager.init = function(self, ...)
        local result = init(self, ...)
        self:registerModule("cwngsync", stub())
        logger.info(string.format("KOPANDA_SCENARIO: cwngsync stub registered: %s, %d bytes", path, size))
        return result
    end

    local logged = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if logged or not args or args.screen ~= "library" then
            return
        end
        logged = true
        local index = require("cloud_books").index()
        local parts = {}
        for known, known_size in pairs(index or {}) do
            parts[#parts + 1] = string.format("%s=%d", known, known_size)
        end
        logger.info("KOPANDA_SCENARIO: CloudBooks.index() " .. (index and table.concat(parts, ", ") or "nil"))
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: cwngsync stub patch failed", err)
    os.exit(4)
end
