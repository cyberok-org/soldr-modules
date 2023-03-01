local cjson = require "cjson"

local Dispatcher = {}; Dispatcher.__index = Dispatcher

function Dispatcher.new(select)
	return setmetatable({_select = select}, Dispatcher)
end

function Dispatcher.by_action()
	return Dispatcher.new(function(src, data, name)
		data = cjson.decode(data)
		return name, src, data, name
	end)
end

function Dispatcher.by_type()
	return Dispatcher.new(function(src, data, ...)
		data = cjson.decode(data)
		return data.type, src, data, ...
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

Dispatcher.__call = Dispatcher.dispatch

return Dispatcher
