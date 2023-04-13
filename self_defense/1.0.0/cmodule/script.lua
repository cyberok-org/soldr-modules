local script = {}

---@alias error string

---@class Command
---@field private subcommands Command[] Subcommand instances array
local Command = {}
script.Command = Command

---Creates a new `Command` instance.
---@param ... Command subcommands for the new instance
---@return Command
function Command:new(...)
    local cmd = { subcommands = { ... } }
    setmetatable(cmd, self)
    self.__index = self
    return cmd
end

---Executes subcommands, returning undo command.
---Attempts to undo previously executed subcommands on failure.
---@return Command|nil # Undo command
---@return error|nil   # Error string, if any
function Command:run()
    ---@type Command[]
    local undo_cmds = {}
    for _, cmd in ipairs(self.subcommands) do
        local undo, err = cmd:run()
        if not undo then
            Command:new(unpack(undo_cmds)):run()
            return nil, err
        end
        table.insert(undo_cmds, 1, undo)
    end
    return Command:new(unpack(undo_cmds))
end

---Creates and returns a new `Command` instance with provided subcommands.
---@param ... Command subcommands for the new instance
---@return Command
function script.command(...)
    return Command:new(...)
end

return script
