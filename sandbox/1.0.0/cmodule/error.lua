local cjson = require "cjson"

-- Looks for a function name upward the call stack, except this function
-- (fname itself) and any of the optionally specified names.
-- string... -> string?
local function fname(...)
    local except = {}
    for _, name in ipairs{...} do except[name] = true end
    for l = 2,10 do
        local info = debug.getinfo(l, "n")
        if info and not except[info.name] then return info.name end
    end
end

local mt = {}
local Error = setmetatable({}, mt)
Error.__index = Error

-- Create a new Error.
-- Two constructing options are available for this type:
-- 1. The surrounding function's name as value of "name" parameter,
--    and `format`ed string as value of "message" parameter.
-- 2. With explicitly provided "name", "message" parameters.
--:: format::string, any... -> Error
--:: {name: string, message: string, ...} -> Error
function Error.new(params, ...)
    if type(params) ~= "table" then
        params = {
            name    = fname("new", "Error"),
            message = string.format(params, ...),
        }
    end
    return setmetatable(params, Error)
end
function mt:__call(...) return Error.new(...) end

function Error:__tostring() return self.message end

--:: error -> {type: "error", error: {...}}
function Error.into_data(err)
    if getmetatable(err) ~= Error then
        err = Error{ message = tostring(err) }
    end
    return { type = "error", error = err }
end

--:: {type: "error", error: {...}} -> Error?
function Error.from_data(data)
    if data.type == "error" then
        return Error(data.error)
    end
end

-- Sends `err` to the agents identified by ID/Dst == `dst`.
--:: AgentType :: "VXAgent" | "Browser"
--:: string, error, AgentType? -> ()
function Error.forward(dst, err, type)
    local agent = __agents.dump()[dst]
    local id = agent and agent.ID or dst
    for _, agent in pairs(__agents.get_by_id(id)) do
        if not type or tostring(agent.Type) == type then
            local data = Error.into_data(err)
            __api.send_data_to(agent.Dst, cjson.encode(data))
        end
    end
end

return Error
