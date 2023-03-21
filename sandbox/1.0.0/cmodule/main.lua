local cjson     = require "cjson"
local Error     = require "error"
local event     = require "event"
local MethodMap = require "mmap"

local score_threshold

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

function handlers.verdict(src, data)
    if data.score >= score_threshold then
        event.verdict_malware(data.filename, data.score)
    end
    return true
end

function handlers.error(src, data)
    local err = Error.from_data(data)
    __log.error(tostring(err))
    event.error(err)
    return true
end

local controls = MethodMap.new(function(cmtype) return cmtype end)
controls.default = function() return true end

function controls.update_config()
    local c = cjson.decode(__config.get_current_config())
    score_threshold = c.d1_score_threshold
    event.update_config()
    return true
end

-- Module START ----------------------------------------------------------------

__api.add_cbs {
    action  = handlers:as_function(),
    data    = handlers:as_function(),
    control = controls:as_function(),
}
controls.update_config()

__api.await(-1)
return "success"
