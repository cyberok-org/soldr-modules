local courl  = require "courl"
local curl   = require "libcurl"
local json   = require "cjson.safe"
local try    = require "try"
local ffi    = require "ffi"

---@class Cuckoo
---@field base_url string
---@field api_key string
local Cuckoo = {}

---Creates new Cuckoo API instance
---@param base_url string
---@param api_key string
---@return any
function Cuckoo:new(base_url, api_key)
    local o = {
        base_url = base_url,
        api_key = api_key,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

local function with_curl(func)
    local h = curl.easy()
    local result = { try(func, h) }
    h:close()
    return unpack(result)
end

---Creates a task to analyze a file named `filename` in Cuckoo
---@param filename string
---@return integer|boolean|nil # Cuckoo's task id
---@return string? # Error message if any
function Cuckoo:create_task(filename)
    assert(type(filename) == "string", "filename must be string")
    return with_curl(function(h)
        h:set("HTTPHEADER", { "Authorization: Bearer " .. self.api_key })
        h:set("URL", self.base_url .. "/tasks/create/file")
        local mime = h:mime()
        local part = mime:part()
        part:name("file")
        part:file(filename)
        h:set("MIMEPOST", mime)
        local body = ""
        h:set("WRITEFUNCTION", function(buf, size)
            body = body .. ffi.string(buf, size)
            return size
        end)
        assert(courl:perform(h))

        local code = h:info("RESPONSE_CODE")
        assert(code == 200, string.format("got unexpected response code %d", code))
        local task = assert(json.decode(body))
        return task.task_id
    end)
end

return Cuckoo
