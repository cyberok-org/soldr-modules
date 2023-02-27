local function update_config()
end
update_config()

local function action_scan(src, data, name)
	return true
end

local function receive_file_to_scan(src, path, name)
	local task_id = name
	-- TODO: handle the received file
	return true
end

__api.add_cbs{
	action = action_scan,
	file   = receive_file_to_scan,

	control = function(cmtype, data)
		if cmtype == "update_config" then update_config() end
		return true
	end,
}
__api.await(-1)
return "success"
