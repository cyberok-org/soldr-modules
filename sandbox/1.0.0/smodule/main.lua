local cjson     = require "cjson"
local courl     = require "courl"
local Cuckoo    = require "cuckoo"
local DB        = require "db"
local Error     = require "error"
local go        = require "go"
local MethodMap = require "mmap"
local time      = require "time"
local try       = require "try"

local function check(dst, ...)
    local ok, err = ...; if not ok then
        __log.error(tostring(err))
        Error.forward(dst, err)
    end; return ...
end

local AgentNotAvailableError = function()
    return Error(nil, "agent is not available")
end

local db, err = check(nil, DB.open("data/"..__pid..".cyberok_sandbox.db"))
if err then
    __api.await(-1)
    return "success"
end

local cuckoo = Cuckoo:new()

local function update_config()
    local module_config = cjson.decode(__config.get_current_config())
    cuckoo:configure(module_config.cuckoo_url, module_config.cuckoo_key)
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
    return nil, AgentNotAvailableError()
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
    check(src, try(function()
        local agent = assert(get_agent_by_src(src))
        local scan_id, err = db:scan_new(agent.ID, data.filename)
        assert(scan_id, string.format("creating a scanning task: %s", err))
        assert(request_file(agent.Dst, scan_id, data.filename),
            string.format("request file %s: failed", data.filename))
        return true
    end))
    return true
end

--:: string, string, string -> ok?
local function receive_file(src, path, name)
    go(function()
        check(src, try(function()
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

function handlers.exec_sql(src, data)
    check(src, try(function()
        local rows, err = db:select(data.query)
        assert(rows, string.format("executing SQL: %s", err))
        assert(__api.send_data_to(src, cjson.encode{
            type = "show_sql_rows",
            data = rows,
        }), "TODO_error")
        return true
    end))
    return true
end

function handlers.error(src, data)
    local err = Error.from_data(data)
    __log.error(tostring(err))
    Error.forward(src, err, "Browser")
    return true
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

    check(nil, go:resume())
    check(nil, courl:wait(timeout))

    local remains = deadline - time.clock()
    __api.await(math.max(1, remains*1000))
until __api.is_close() and courl:idle()

check(nil, db:close())

return "success"
