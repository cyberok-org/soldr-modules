local cjson = require "cjson"
local event = require "event"

local function update_config()
	event.update_config()
end
update_config()

local function handle_request_file(src, data)
	local name = data.task_id
	__api.async_send_file_from_fs_to(src, data.path, name, function(ok)
		event.error(string.format("send file: %s: failed", data.path))
	end)
end

__api.add_cbs{
	data = function(src, data)
		data = cjson.decode(data)
		if data.type == "request_file" then
			return handle_request_file(src, data)
		end
	end,
	control = function() return true end
}
__api.await(-1)
return "success"
