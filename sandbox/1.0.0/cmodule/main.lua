local function get_server_token()
	for _, agent in pairs(__agents.dump()) do
		return agent.Dst
	end
	return nil
end

local function send_file_to_scan(task_id, path)
	local token = get_server_token()
	local name = task_id
	__api.async_send_file_from_fs_to(token, path, name, function(ok)
		-- TODO: handle `ok` status
	end)
end

__api.add_cbs{
	control = function() return true end
}
__api.await(-1)
return "success"
