local courl  = require "courl"
local curl   = require "libcurl"
local cjson  = require "cjson"
local try    = require "try"
local ffi    = require "ffi"

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
---@field private opts? CuckooOptions
local Cuckoo = {}

---Creates new Cuckoo API instance
---@param url string
---@param key string
---@param opts? CuckooOptions
---@return Cuckoo
function Cuckoo:new(url, key, opts)
    ---@type Cuckoo
    local o = {
        base_url = url,
        api_key = key,
        opts = opts or {},
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

---Creates a task to analyze a file named `filename` in Cuckoo
---@param file string
---@param filename? string
---@return integer? # Cuckoo's task id
---@return string? # Error message if any
function Cuckoo:create_task(file, filename)
    return with_curl(function(h)
        h:set("URL", self.base_url .. "/tasks/create/file")
        h:set("HTTPHEADER", {
            "Authorization: Bearer " .. self.api_key
        })

        local mime = h:mime()

        local part = mime:part()
        part:name("file")
        part:file(file)
        if filename then
            part:filename(filename)
        end

        for param, value in pairs(self.opts) do
            part = mime:part()
            part:name(param)
            part:data(tostring(value))
        end

        h:set("MIMEPOST", mime)

        local body = ""
        h:set("WRITEFUNCTION", function(buf, size)
            body = body .. ffi.string(buf, size)
            return size
        end)

        assert(courl:perform(h))
        local code = h:info("RESPONSE_CODE")
        assert(code == 200, string.format("got unexpected response code %d", code))

        local task = cjson.decode(body)
        return task.task_id
    end)
end

--:: integer -> string?, error?
function Cuckoo:task_status(task_id)
    return string.format("%06d", math.random(1e6))
end

--:: integer -> number?, error?
function Cuckoo:task_score(task_id)
    return math.random() * 10
end

return Cuckoo
