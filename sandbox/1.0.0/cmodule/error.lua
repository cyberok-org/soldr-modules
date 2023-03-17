local cjson = require "cjson"

local Error = {}
Error.__index = Error

--:: string?, string, any... -> Error
function Error.new(name, format, ...)
    local self = {}
    self.name = name or debug.getinfo(1, "n").name
    self.message = string.format(format, ...)
    return setmetatable(self, Error)
end

local mt = {}
function mt:__call(...) return Error.new(...) end
setmetatable(Error, mt)

function Error:__tostring() return self.message end

--:: () -> Error
function Error:copy()
    local copy = {}
    for k, v in pairs(self) do copy[k] = v end
    return setmetatable(copy, Error)
end

--:: string? -> Error
function Error:forward(agent_id)
    local copy = self:copy()
    copy.agent_id = agent_id or __aid
    return copy
end

--:: error -> {type: "error", ...}
function Error.into_data(err)
    return { type = "error", name = err.name, message = tostring(err) }
end

--:: {type: "error", ...} -> Error?
function Error.from_data(data)
    if data.type == "error" then
        return Error.new(data.name, data.message)
    end
end

--:: AgentType :: "VXAgent" | "Browser"
--:: error, AgentType? -> ()
function Error.send(err, type)
    for _, agent in pairs(__agents.get_by_id(err.agent_id)) do
        if not type or tostring(agent.Type) == type then
            local data = Error.into_data(err)
            __api.send_data_to(agent.Dst, cjson.encode(data))
        end
    end
end

return Error
