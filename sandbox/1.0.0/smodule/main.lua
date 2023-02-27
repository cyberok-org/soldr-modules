local function update_config()
end
update_config()

local function action_scan(src, data, name)
	return true
end

__api.add_cbs{
	action  = action_scan,

	control = function(cmtype, data)
		if cmtype == "update_config" then update_config() end
		return true
	end,
}
__api.await(-1)
return "success"
