local cjson     = require "cjson"
local event     = require "event"
local MethodMap = require "mmap"

local function get_server_token()
    for _, agent in pairs(__agents.dump()) do
        return agent.Dst
    end
end

local function scan_file(server_token, path)
    return __api.send_data_to(server_token, cjson.encode {
        type = "scan_file",
        path = path,
    })
end

local handlers = MethodMap.new(function(src, data, name)
    data = cjson.decode(data)
    return name or data.type, src, data
end)

-- Action: cyberok_sandbox_scan
function handlers.cyberok_sandbox_scan(src, data)
    return scan_file(get_server_token(), data.data["object.fullpath"])
end

function handlers.request_file(src, data)
    local name = data.task_id
    return __api.async_send_file_from_fs_to(src, data.path, name, function(ok)
        if not ok then
            event.error(string.format("send file: %s: failed", data.path))
        end
    end)
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
