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

-- Search for the agent with ID/Dst == `dst`.
local function find_agent_id(dst)
    for _, agent in pairs(__agents.dump()) do
        if agent.ID == dst or agent.Dst == dst then
            return agent.ID
        end
    end
end

-- Sends `err` to the agents indentified by ID/Dst == `dst`.
--:: AgentType :: "VXAgent" | "Browser"
--:: string, error, AgentType? -> ()
function Error.forward(dst, err, type)
    local id = find_agent_id(dst); if id then
        for _, agent in pairs(__agents.get_by_id(id)) do
            if not type or tostring(agent.Type) == type then
                local data = Error.into_data(err)
                __api.send_data_to(agent.Dst, cjson.encode(data))
            end
        end
    end
end

return Error
