local cjson     = require "cjson"
local courl     = require "courl"
local go        = require "go"
local MethodMap = require "mmap"
local time      = require "time"
local try       = require "try"
local Cuckoo    = require "cuckoo"

local cuckoo

local function check(...)
    local ok, err = ...; if not ok then
        -- TODO: send the error to an agent
        __log.error(err)
    end; return ...
end


--:: string -> string?
local function get_agent_token(src)
    local node = __agents.dump()[src]
    for _, info in pairs(__agents.get_by_id(node.ID)) do
        if tostring(info.Type) == "VXAgent" then
            return info.Dst
        end
    end
    return nil, "failed to resolve destination to agent"
end

--:: string, string, string -> ok?
local function request_file(agent_token, task_id, path)
    return __api.send_data_to(agent_token, cjson.encode {
        type    = "request_file",
        task_id = task_id,
        path    = path,
    })
end

--:: string,string,string -> ok?
local function receive_file(src, path, name)
    go(function()
        local task_id = check(cuckoo:create_task(path))
    end)
    return true
end

local handlers = MethodMap.new(function(src, data)
    data = cjson.decode(data)
    return data.type, src, data
end)

function handlers.scan_file(src, data)
    return check(try(function()
        local agent_token = assert(get_agent_token(src))
        assert(request_file(agent_token, "TODO_task_id", data.path),
            string.format("request file %s: failed", data.path))
        return true
    end))
end

local function update_config()
    -- todo: stop current connections
    cuckoo = Cuckoo:new(
        "http://192.168.220.236:8090",
        "AWFKI9LcPk_Y5i0pcA6XKA"
    )
end
update_config()

__api.add_cbs {
    data    = handlers:as_function(),
    file    = receive_file,
    control = function(cmtype, data)
        if cmtype == "update_config" then update_config() end
        return true
    end,
}

repeat
    local timeout = 0.100
    local deadline = time.clock() + timeout

    check(go:resume())
    check(courl:wait(timeout))

    local remains = deadline - time.clock()
    __api.await(math.max(1, remains*1000))
until __api.is_close() and courl:idle()

return "success"
