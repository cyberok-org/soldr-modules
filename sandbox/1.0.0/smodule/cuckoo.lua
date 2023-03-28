local cjson  = require "cjson.safe"
local courl  = require "courl"
local curl   = require "libcurl"
local ffi    = require "ffi"
local try    = require "try"
local uri    = require "uri"

---@class CuckooOptions
---@field public package string Analysis package to be used for the analysis
---@field public options string Options to pass to the analysis package
---@field public priority integer Priority to assign to the task (1-3)
---@field public platform string Name of the platform to select the analysis machine from (e.g. “windows”)
---@field public machine string Label of the analysis machine to use for the analysis
---@field public timeout integer Analysis timeout (in seconds)

---@class Cuckoo
---@field private base_url string
---@field private api_key string
local Cuckoo = {}

---Creates new Cuckoo API instance
---@param url string
---@param key string
---@return Cuckoo
function Cuckoo:new(url, key)
    ---@type Cuckoo
    local o = {
        base_url = url,
        api_key = key,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

local function with_curl(func)
    local h = curl.easy()
    local result = table.pack(try(func, h))
    h:close()
    return table.unpack(result)
end

-- Does a request to Cuckoo API. To customize a CURL handle, that will be using
-- during the request, a caller can provide `setup` function.
-- Returns a reponse decoded from JSON returned by the API. The function ensures
-- that the API responded with HTTP 200 OK, otherwise an error will be returned.
--:: SetupFn :: libcurl.CURL -> ()
--:: string, SetupFn? -> {...}?, error?
function Cuckoo:request(resource, setup)
    return with_curl(function(h)
        h:set("URL", self.base_url .. resource)
        h:set("HTTPHEADER", {
            "Authorization: Bearer " .. self.api_key })
        local body = ""
        h:set("WRITEFUNCTION", function(buf, size)
            body = body .. ffi.string(buf, size)
            return size
        end)
        if setup then setup(h) end

        assert(courl:perform(h))

        local code = h:info("RESPONSE_CODE")
        assert(code == 200, string.format("received unexpected response code: %d", code))

        local data, err = cjson.decode(body)
        assert(data, string.format("parse a reponse as json: %s", err))
        return data
    end)
end

---Creates a task to analyze a file named `filename` in Cuckoo
---@param file string
---@param filename string
---@param options CuckooOptions
---@return integer? # Cuckoo's task id
---@return string? # Error message if any
function Cuckoo:create_task(file, filename, options)
    return try(function()
        local data = assert(self:request("/tasks/create/file", function(h)
            local mime = h:mime()
            -- Provide the file (with the filename):
            local part = mime:part()
            part:name("file")
            part:file(file)
            part:filename(filename or "file")
            -- Provide the analysis options:
            for name, value in pairs(options) do
                if value ~=nil and value ~= "" then
                    part = mime:part()
                    part:name(name)
                    part:data(tostring(value))
                end
            end
            h:set("MIMEPOST", mime)
        end))
        return data.task_id
    end)
end

---@alias task_status
---| '"pending"' # The task has been created and is awaiting execution
---| '"running"' # The task is currently running
---| '"completed"' # The task has been completed, and the report is preparing
---| '"reported"' # The report has been prepared and is ready to be received

---Returns the current status of the task with the specified `task_id`.
---@param task_id integer
---@return task_status? # The current state of task completion
---@return string? # Error message if any
function Cuckoo:task_status(task_id)
    return try(function()
        local data = assert(self:request("/tasks/view/" .. task_id))
        return data.task.status
    end)
end

---Returns a scanning report for the task with the specified `task_id`.
---@param task_id integer
---@return table? # A scanning result report
---@return string? # Error message if any
--:: integer -> {...}?, error?
function Cuckoo:task_report(task_id)
    return try(function()
        return assert(self:request("/tasks/summary/" .. task_id))
    end)
end

---Returns URL to the report for the task with the specified `task_id`
---@param task_id integer
---@return string
function Cuckoo:task_report_url(task_id)
    local report = uri.parse(self.base_url)
    report.port = nil
    report.path = string.format("/analysis/%d/summary", task_id)
    return uri.format(report)
end

-- Extracts properties from the scanning report in the format of verdict event.
function Cuckoo.verdict(report)
    local verdict = {}

    verdict["info.id"]      = report.info.id
    verdict["info.score"]   = report.info.score
    verdict["info.package"] = report.info.package

    verdict["object.category"]      = report.target.category
    verdict["object.file.type"]     = report.target.file.type
    verdict["object.file.name"]     = report.target.file.name
    verdict["object.file.mimetype"] = report.target.file.mimetype
    verdict["object.file.sha1"]     = report.target.file.sha1
    verdict["object.file.size"]     = report.target.file.size

    for i, signature in pairs(report.signatures) do
        verdict["signatures["..(i-1).."].name"]        = signature.name
        verdict["signatures["..(i-1).."].description"] = signature.description
        verdict["signatures["..(i-1).."].severity"]    = signature.severity
        verdict["signatures["..(i-1).."].markcount"]   = signature.markcount
        for j, mark in pairs(signature.marks) do
            verdict["signatures["..(i-1).."].marks["..(j-1).."].rule"]     = mark.rule
            verdict["signatures["..(i-1).."].marks["..(j-1).."].ioc"]      = mark.ioc
            verdict["signatures["..(i-1).."].marks["..(j-1).."].category"] = mark.category
        end
    end

    -- TODO:
    -- verdict["suricata.alerts"] = report.suricata.alerts
    -- verdict["snort.alerts"]    = report.snort.alerts

    verdict["count_ioc_matched"] = #(report.misp or {})

    return verdict
end

return Cuckoo
