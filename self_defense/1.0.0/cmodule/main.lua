local defender = require("defender_windows")

---Activates the self-defense of the current process.
---@return boolean|nil ok whether the self-defense was successfully activated
---@return string|nil error string explaining the problem, if any
local function activate()
    local ok, err = defender.activate()
    if not ok then
        __log.errorf("failed to activate self-defense: %s", err)
    end
    return ok, err
end

---Deactivates the self-protection of the current process.
---@return boolean|nil ok whether the self-defense was successfully deactivated
---@return string|nil error string explaining the problem, if any
local function deactivate()
    local ok, err = defender.deactivate()
    if not ok then
        __log.errorf("failed to deactivate self-defense: %s", err)
    end
    return ok, err
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
