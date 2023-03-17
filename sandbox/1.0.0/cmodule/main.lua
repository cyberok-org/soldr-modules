local cjson     = require "cjson"
local Error     = require "error"
local event     = require "event"
local MethodMap = require "mmap"

local function SendFileError(filename)
    return Error(nil, "send file %s: failed", filename)
end

local function check(...)
    local ok, err = ...; if not ok then
        __log.error(tostring(err))
        event.error(err)
        Error.send(err)
    end; return ...
end

--:: () -> string?, error?
local function get_server_dst()
    for _, agent in pairs(__agents.dump()) do
        return agent.Dst
    end
    return nil, "failed to resolve destinaton to server"
end

local handlers = MethodMap.new(function(src, data, name)
    data = cjson.decode(data)
    return name or data.type, src, data
end)

-- Action: cyberok_sandbox_scan
function handlers.cyberok_sandbox_scan(src, data)
    local dst = check(get_server_dst())
    return __api.send_data_to(dst, cjson.encode{
        type     = "scan_file",
        filename = data.data["object.fullpath"],
    })
end

function handlers.request_file(src, data)
    local name = data.scan_id
    return __api.async_send_file_from_fs_to(src, data.filename, name, function(ok)
        check(ok, SendFileError(data.filename):forward())
    end)
end

function handlers.error(src, data)
    __log.error(data.message)
    event.error(data.message)
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
