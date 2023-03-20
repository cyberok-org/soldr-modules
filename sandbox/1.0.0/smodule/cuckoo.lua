local courl  = require "courl"
local curl   = require "libcurl"
local cjson  = require "cjson"
local try    = require "try"
local ffi    = require "ffi"

---@class CuckooOptions
---@field public package string
---@field public package_options string
---@field public priority integer
---@field public platform string
---@field public machine string
---@field public timeout_sec integer

---@class Cuckoo
---@field private base_url string
---@field private api_key string
---@field private opts? CuckooOptions
local Cuckoo = {}

---Creates new Cuckoo API instance
---@return Cuckoo
function Cuckoo:new()
    local o = {
        base_url = "",
        api_key = "",
        opts = {},
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
---@param url string
---@param key string
---@param opts? CuckooOptions
function Cuckoo:configure(url, key, opts)
    self.base_url = url
    self.api_key = key
    self.opts = opts
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
