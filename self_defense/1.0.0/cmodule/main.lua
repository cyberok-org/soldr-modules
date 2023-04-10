local profile = require("defender_windows")

---Activates the self-defense of the current process.
---@return boolean|nil ok whether the self-defense was successfully activated
---@return string|nil error string explaining the problem, if any
local function activate()
    local old_profile, err = profile.apply()
    if not old_profile then
        __log.errorf("failed to activate self-defense: %s", err)
        return nil, err
    end
    -- TODO: store old profile if it wasn't stored yet
    return true
end

---Deactivates the self-protection of the current process.
---@return boolean|nil ok whether the self-defense was successfully deactivated
---@return string|nil error string explaining the problem, if any
local function deactivate()
    -- TODO: restore old profile
    return true
end

---Handles control messages.
---@param cmtype string
---@param data string
local function control(cmtype, data)
    if cmtype == "quit" and data == "module_remove" then
        deactivate()
    end
    return true
end

---Module's entrypoint.
---@return string
local function run()
    __api.add_cbs({ control = control })
    activate()
    __api.await(-1)
    return "success"
end

return run()
