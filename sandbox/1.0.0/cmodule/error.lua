local cjson = require "cjson"

local Error = {}
Error.__index = Error

function Error.new(code, format, ...)
    local self = {}
    self.code = code
    self.message = string.format(format, ...)
    return setmetatable(self, Error)
end

function Error.new_this(format, ...)
    local code = debug.getinfo(1, "n").name
    return Error.new(code, format, ...)
end

function Error:__tostring() return self.message end

--:: string? -> Error
function Error:by_agent(agent_id)
    return setmetatable(
        { agent_id = agent_id or __aid },
        { __index = self, __tostring = self.__tostring })
end

function Error.from_data(data)
    if data.type == "error" then
        return Error.new(data.code, data.message)
    end
end

function Error.broadcast(err, type)
    if err.agent_id then
        for _, agent in pairs(__agents.get_by_id(err.agent_id)) do
            if not type or tostring(agent.Type) == type then
                __api.send_data_to(agent.Dst, cjson.encode{
                    type    = "error",
                    code    = err.code,
                    message = tostring(err),
                })
            end end end
end

--------------------------------------------------------------------------------

Error.SendFile = function(filename)
    return Error.new_this("sending file %s: failed", filename)
end

return Error
