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

---Returns a dictionary representation of the command.
---@return table
function Command:dict()
    local subcommands = {}
    for _, cmd in ipairs(self.subcommands) do
        table.insert(subcommands, cmd:dict())
    end
    return {
        name = "script",
        subcommands = subcommands,
    }
end

---Creates and returns a new `Command` instance with provided subcommands.
---@param ... Command subcommands for the new instance
---@return Command
function script.command(...)
    return Command:new(...)
end

local function get_loader(name, ...)
    for _, loader in ipairs({ ... }) do
        if loader.module == name then
            return loader
        end
    end
end

function script.load(cmd_dict, ...)
    assert(type(cmd_dict) == "table", "cmd_dict must be table")
    assert(cmd_dict.name == "script", "cmd_dict.name must be 'script'")
    local subcommands = {}
    for _, subcmd in ipairs(cmd_dict.subcommands) do
        local loader = get_loader(subcmd.name, ...)
        if loader then
            table.insert(subcommands, loader.load(subcmd))
        else
            table.insert(subcommands, script.load(subcmd, ...))
        end
    end
    return script.command(unpack(subcommands))
end

return script
