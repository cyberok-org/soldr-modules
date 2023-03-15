local cjson     = require "cjson"
local courl     = require "courl"
local Cuckoo    = require "cuckoo"
local DB        = require "db"
local go        = require "go"
local MethodMap = require "mmap"
local time      = require "time"
local try       = require "try"

local function check(...)
    local ok, err = ...; if not ok then
        -- TODO: send the error to an agent
        __log.error(err)
    end; return ...
end

local db, err = check(DB.open("data/"..__pid..".cyberok_sandbox.db"))
if err then
    __api.await(-1)
    return "success"
end

local cuckoo

local function update_config()
    -- todo: stop current connections
    cuckoo = Cuckoo:new(
        "http://192.168.220.236:8090",
        "AWFKI9LcPk_Y5i0pcA6XKA"
    )
end
update_config()

local handlers = MethodMap.new(function(src, data)
    data = cjson.decode(data)
    return data.type, src, data
end)

--:: string, string? -> AgentInfo?, error?
local function get_agent_by_src(src, type)
    local id = __agents.dump()[src].ID
    for _, agent in pairs(__agents.get_by_id(id)) do
        if tostring(agent.Type) == (type or "VXAgent") then
            return agent
        end
    end
    return nil, "agent not found"
end

--:: string, string, string -> ok?
local function request_file(dst, scan_id, filename)
    return __api.send_data_to(dst, cjson.encode{
        type     = "request_file",
        scan_id  = scan_id,
        filename = filename,
    })
end

function handlers.scan_file(src, data)
    return check(try(function()
        local agent = assert(get_agent_by_src(src))
        local scan_id, err = db:scan_new(agent.ID, data.filename),
        assert(scan_id, string.format("creating a scanning task: %s", err))
        assert(request_file(agent.Dst, scan_id, data.filename),
            string.format("request file %s: failed", data.filename))
        return true
    end))
end

--:: string, string, string -> ok?
local function receive_file(src, path, name)
    go(function()
        check(try(function()
            local scan_id = name
            local scan, err = db:scan_get(scan_id)
            assert(scan, string.format(
                "getting the scanning task: scan_id=%s: %s", scan_id, err))

            local task_id, err = cuckoo:create_task(path, scan.filename)
            assert(task_id, string.format("cuckoo: creating a task: %s", err))

            local ok, err = db:scan_set_processing(scan_id, task_id)
            assert(ok, string.format("update the scanning task: %s", err))
            return true
        end))
    end)
    return true
end

function handlers.request_data(src, data)
    return check(try(function()
        local rows = assert(db:select(data.query))
        assert(__api.send_data_to(src, cjson.encode{
            type = "display_data",
            data = rows,
        }), "TODO_error")
        return true
    end))
end

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

check(db:close())

return "success"
