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
    local ok, err = ...; if not ok and err then
        __log.error(tostring(err))
        Error.forward(dst, err)
    end; return ...
end

local AgentNotAvailableError = function()
    return Error("agent is not available")
end
local ScanCreateError = function(err)
    return Error("creating a new scanning task: %s", err)
end
local ScanGetError = function(scan_id, err)
    return Error("scan_id=%s: getting task info: %s", scan_id, err)
end
local ScanUpdateError = function(scan_id, status, err)
    return Error("scan_id=%s: updating task, status=%s: %s", scan_id, status, err)
end
local RequestFileError = function(scan_id, filename)
    return Error("scan_id=%s: request file %s: failed", scan_id, filename)
end
local CuckooCreateTaskError = function(scan_id, err)
    return Error("scan_id=%s: submit the task to Cuckoo: %s", scan_id, err)
end
local ExecSQLError = function(err)
    return Error("exec SQL: %s", err)
end

local db, err = check(nil, DB.open("data/"..__pid..".cyberok_sandbox.db"))
if err then
    __api.await(-1)
    return "success"
end

local cuckoo = Cuckoo:new()

local function update_config()
    local c = cjson.decode(__config.get_current_config())
    cuckoo:configure(c.cuckoo_a1_url, c.cuckoo_a2_key, {
        package         = c.cuckoo_b1_package,
        package_options = c.cuckoo_b2_package_options,
        priority        = c.cuckoo_b3_priority,
        platform        = c.cuckoo_c1_platform,
        machine         = c.cuckoo_c2_machine,
        timeout_sec     = c.cuckoo_c3_timeout,
    })
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

--:: string, string, string -> boolean, error?
local function request_file(dst, scan_id, filename)
    return __api.send_data_to(dst, cjson.encode{
        type     = "request_file",
        scan_id  = scan_id,
        filename = filename,
    }), RequestFileError(scan_id, filename)
end

function handlers.scan_file(src, data)
    check(src, try(function()
        local agent = assert(get_agent_by_src(src))
        local scan_id, err = db:scan_new(agent.ID, data.filename)
        assert(scan_id, ScanCreateError(err))
        assert(request_file(agent.Dst, scan_id, data.filename))
    end))
    return true
end

--:: string, string, string -> ok?
local function receive_file(src, path, name)
    go(function()
        check(src, try(function()
            local scan_id = tonumber(name)
            local scan, err = db:scan_get(scan_id)
            assert(scan, ScanGetError(scan_id, err))
            local task_id, err = cuckoo:create_task(path, scan.filename)
            assert(task_id, CuckooCreateTaskError(scan_id, err))
            local ok, err = db:scan_set_processing(scan_id, task_id)
            assert(ok, ScanUpdateError(scan_id, "processing", err))
        end))
    end)
    return true
end

function handlers.exec_sql(src, data)
    check(src, try(function()
        local rows, err = db:select(data.query)
        assert(rows, ExecSQLError(err))
        __api.send_data_to(src,
            cjson.encode{ type = "show_sql_rows", data = rows })
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
