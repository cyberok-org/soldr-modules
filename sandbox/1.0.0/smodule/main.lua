local cjson     = require "cjson"
local courl     = require "courl"
local Cuckoo    = require "cuckoo"
local DB        = require "db"
local Error     = require "error"
local go        = require "go"
local MethodMap = require "mmap"
local time      = require "time"
local try       = require "try"

local db
---@type Cuckoo
local cuckoo

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
    return Error("scan_id=%s: restoring the scanning task: %s", scan_id, err)
end
local ScanListUnfinishedError = function(err)
    return Error("getting unfinished scanning tasks: %s", err)
end
local ScanUpdateError = function(scan_id, status, err)
    return Error("scan_id=%s: updating the scanning task, status=%s: %s", scan_id, status, err)
end
local RequestFileError = function(scan_id, filename)
    return Error("scan_id=%s: request file %s: failed", scan_id, filename)
end
local CuckooCreateTaskError = function(scan_id, err)
    return Error("scan_id=%s: submit the task to Cuckoo: %s", scan_id, err)
end
local CuckooError = function(scan_id, err)
   return Error("scan_id=%s: sending request to Cuckoo: %s", scan_id, err)
end
local ExecSQLError = function(err)
    return Error("exec SQL: %s", err)
end

local handlers = MethodMap.new(function(src, data)
    data = cjson.decode(data)
    return data.type, src, data
end)

-- Search for the agent with ID/Dst == `dst`.
--:: string, string? -> AgentInfo?, error?
local function get_agent(dst, type)
    local agent = __agents.dump()[dst]
    local id = agent and agent.ID or dst
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
    local scan_id, err
    _, err = check(src, try(function()
        local agent = assert(get_agent(src))
        scan_id, err = db:scan_new(agent.ID, data.filename)
        assert(scan_id, ScanCreateError(err))
        assert(request_file(agent.Dst, scan_id, data.filename))
    end))
    if scan_id and err then db:scan_set_error(scan_id, err) end
    return true
end

--:: string, string, string -> ok?
local function receive_file(src, path, name)
    go(function()
        local scan_id = tonumber(name)
        local _, err = check(src, try(function()
            local scan, err = db:scan_get(scan_id)
            assert(scan, ScanGetError(scan_id, err))
            local task_id, err = cuckoo:create_task(path, scan.filename)
            assert(task_id, CuckooCreateTaskError(scan_id, err))
            local ok, err = db:scan_set_task(scan_id, task_id)
            assert(ok, ScanUpdateError(scan_id, scan.status, err))
        end))
        if err then db:scan_set_error(scan_id, err) end
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
    if err.scan_id then
        db:scan_set_error(err.scan_id, err) end
    __log.error(tostring(err))
    Error.forward(src, err, "Browser")
    return true
end

local controls = MethodMap.new(function(cmtype) return cmtype end)
controls.default = function() return true end

function controls.update_config()
    local c = cjson.decode(__config.get_current_config())
    cuckoo = Cuckoo:new(c.a1_cuckoo_url, c.a2_cuckoo_key, {
        package  = c.b1_cuckoo_package,
        options  = c.b2_cuckoo_package_options,
        priority = c.b3_cuckoo_priority,
        platform = c.c1_cuckoo_platform,
        machine  = c.c2_cuckoo_machine,
        timeout  = c.c3_cuckoo_timeout,
    })
    return true
end

local function send_verdict(dst, filename, score)
    __api.send_data_to(dst, cjson.encode{
        type = "verdict", filename = filename, score = score })
end

local function handle_unfinished_scan(scan)
    return try(function()
        -- TODO: handle the staled scanning task

        -- Skip new scanning tasks while receiving a file.
        if not scan.cuckoo_task_id then return true end

        local status, err = cuckoo:task_status(scan.cuckoo_task_id)
        assert(status, CuckooError(scan.scan_id, err))
        if scan.status == status then return true end

        if status == "reported" then
            local score, err = cuckoo:task_score(scan.cuckoo_task_id)
            assert(score, CuckooError(scan.scan_id, err))

            local agent = get_agent(scan.agent_id); if agent then
                send_verdict(agent.Dst, scan.filename, score)
            end
        end

        local ok, err = db:scan_set_status(scan.scan_id, status)
        assert(ok, ScanUpdateError(scan.scan_id, status, err))
        return true
    end)
end

local WATCH_UNFINISHED_SCANS_INTERVAL = 10
local function watch_unfinished_scans()
    while true do
        local scans, err = db:scan_list_unfinished()
        check(nil, scans, ScanListUnfinishedError(err))
        for _, scan in ipairs(scans or {}) do
            check(scan.agent_id, handle_unfinished_scan(scan))
        end
        go.sleep(WATCH_UNFINISHED_SCANS_INTERVAL)
    end
end

-- Returns time remains before `deadline`; `0` if the deadline has passed.
local function till(deadline)
    local delta = deadline - time.clock()
    return delta > 0 and delta or 0
end

-- Module START ----------------------------------------------------------------

db, err = check(nil, DB.open("data/"..__pid..".cyberok_sandbox.db"))
if err then
    __api.await(-1)
    return "success"
end

__api.add_cbs {
    data    = handlers:as_function(),
    file    = receive_file,
    control = controls:as_function(),
}
controls.update_config()

go(watch_unfinished_scans)

repeat
    local deadline = time.clock() + 0.100
    check(nil, go:resume())
    check(nil, courl:wait(till(deadline)))
    __api.await(till(deadline) * 1000)
until __api.is_close() and courl:idle()

check(nil, db:close())

return "success"
