local cjson      = require "cjson"
local dispatcher = require "dispatcher"
local event      = require "event"

local function update_config()
	event.update_config()
end
update_config()

local function get_server_token()
	for _, agent in pairs(__agents.dump()) do
		return agent.Dst
	end
end

local function scan_file(server_token, path)
	return __api.send_data_to(server_token, cjson.encode{
		type = "scan_file",
		path = path,
	})
end

local function action_scan(src, data, name)
	data = cjson.decode(data)
	return scan_file(get_server_token(), data.data["object.fullpath"])
end

local handlers = dispatcher.by_type()

function handlers.request_file(src, data)
	local name = data.task_id
	return __api.async_send_file_from_fs_to(src, data.path, name, function(ok)
		event.error(string.format("send file: %s: failed", data.path))
	end)
end

__api.add_cbs{
	action  = action_scan,
	data    = function(...) handlers(...) end,
	control = function(cmtype, data)
		if cmtype == "update_config" then update_config() end
		return true
	end,
}
__api.await(-1)
return "success"
