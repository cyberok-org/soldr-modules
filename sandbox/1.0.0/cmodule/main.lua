local cjson     = require "cjson"
local Error     = require "error"
local event     = require "event"
local MethodMap = require "mmap"

local function check(...)
    local ok, err = ...; if not ok and err then
        __log.error(tostring(err))
        event.error(err)
        Error.forward(__aid, err)
    end; return ...
end

local ServerNotAvailableError = function()
    return Error("server is not available")
end
local SendFileError = function(scan_id, filename)
    return Error("scan_id=%s: send file %s: failed", scan_id, filename)
end

--:: () -> string?, error?
local function get_server_dst()
    for _, agent in pairs(__agents.dump()) do
        return agent.Dst
    end
    return nil, ServerNotAvailableError()
end

local handlers = MethodMap.new(function(src, data, name)
    data = cjson.decode(data)
    return name or data.type, src, data
end)

-- Action: cyberok_sandbox_scan
function handlers.cyberok_sandbox_scan(src, data)
    local dst = check(get_server_dst()); if dst then
        local ok = __api.send_data_to(dst, {
            type     = "scan_file",
            filename = data.data["object.fullpath"],
        })
        return check(ok, ServerNotAvailableError())
    end
end

function handlers.request_file(src, data)
    local name = tostring(data.scan_id)
    return __api.async_send_file_from_fs_to(src, data.filename, name, function(ok)
        check(ok, SendFileError(data.scan_id, data.filename))
    end)
end

function handlers.error(src, data)
    local err = Error.from_data(data)
    __log.error(tostring(err))
    event.error(err)
    return true
end

local function update_config()
    event.update_config()
end
update_config()

__api.add_cbs {
    action  = handlers:as_function(),
    data    = handlers:as_function(),
    control = function(cmtype, data)
        if cmtype == "update_config" then update_config() end
        return true
    end,
}
__api.await(-1)
return "success"
