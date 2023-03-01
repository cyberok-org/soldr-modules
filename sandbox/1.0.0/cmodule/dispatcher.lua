local cjson = require "cjson"

local Dispatcher = {}; Dispatcher.__index = Dispatcher

function Dispatcher.new(select)
	return setmetatable({_select = select}, Dispatcher)
end

function Dispatcher.by_action_or_data_type()
	return Dispatcher.new(function(src, data, name)
		data = cjson.decode(data)
		return name or data.type, src, data, name
	end)
end

function Dispatcher:dispatch(...)
	local args = table.pack(self._select(...))
	local method = #args > 0 and args[1]
	if method and self[method] then
		return self[method](table.unpack(args, 2))
	end
	__log.errorf("unsupported method: %s", method)
end

function Dispatcher:as_func()
	return function(...) return self:dispatch(...) end
end

return Dispatcher
