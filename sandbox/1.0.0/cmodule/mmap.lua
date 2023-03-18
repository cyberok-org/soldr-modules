local MethodMap = {}
MethodMap.__index = MethodMap

-- Creates an instance of a mapping table. Cаlling it as a function
-- results in calling one of the methods declared as members of the table.
-- Provided `mapper` should map input arguments of the call to the target
-- method name and arguments for the method.
--:: (any... -> method::string, any...) -> MethodMap
function MethodMap.new(mapper)
    return setmetatable({ _map = mapper }, MethodMap)
end

function MethodMap.default(...)
end

function MethodMap:__call(...)
    local args = table.pack(self._map(...))
    local method = #args > 0 and args[1]
    if method and self[method] then
        return self[method](table.unpack(args, 2))
    end
    return self.default(...)
end

function MethodMap:as_function()
    return function(...) return self(...) end
end

return MethodMap
