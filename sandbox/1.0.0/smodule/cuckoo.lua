local courl  = require "courl"
local curl   = require "libcurl"
local cjson  = require "cjson"
local try    = require "try"
local ffi    = require "ffi"

---@class Cuckoo
---@field private base_url string
---@field private api_key string
local Cuckoo = {}

---Creates new Cuckoo API instance
---@param config? Cuckoo
---@return Cuckoo
function Cuckoo:new(config)
    local o = config or {
        base_url = "",
        api_key = ""
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

---Reconfigure cuckoo instance
---@param config Cuckoo
function Cuckoo:configure(config)
    self.base_url = config.base_url
    self.api_key = config.api_key
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
            "Authorization: Bearer " .. self.api_key })

        local mime = h:mime()
        local part = mime:part()
        part:name("file")
        part:file(file)
        if filename then
            part:filename(filename)
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

return Cuckoo
