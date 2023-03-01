local cjson      = require "cjson"
local dispatcher = require "dispatcher"

--:: string -> string?
function get_agent_token(src)
	local node = __agents.dump()[src]
	for _, info in pairs(__agents.get_by_id(node.ID)) do
		if tostring(info.Type) == "VXAgent" then
			return info.Dst end
	end
end

--:: string, string, string -> ok?
local function request_file(agent_token, task_id, path)
	return __api.send_data_to(agent_token, cjson.encode{
		type    = "request_file",
		task_id = task_id,
		path    = path,
	})
end

local function receive_file(src, path, name)
	local task_id = name
	-- TODO: handle the received file
	return true
end

local handlers = dispatcher.by_action_or_data_type()

function handlers.scan_file(src, data)
	local agent_token = get_agent_token(src)
	if not agent_token then
		__log.errorf("resolve destination to agent: failed")
		return false
	end

	if not request_file(agent_token, "TODO_task_id", data.path) then
		__log.errorf("request file path=%s: failed", data.path)
		return false
	end

	local res = __api.send_data_to(src, cjson.encode({
		type = "connection_error",
	}))
	return true
end

local function update_config()
end
update_config()

__api.add_cbs{
	data    = handlers:as_func(),
	file    = receive_file,
	control = function(cmtype, data)
		if cmtype == "update_config" then update_config() end
		return true
	end,
}
__api.await(-1)
return "success"
