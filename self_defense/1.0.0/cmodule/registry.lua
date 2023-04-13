local script = require("script")

local registry = {}

---@class RegPath
---@field package tree string
---@field package path string

---@class RegValue
---@field package type string
---@field package value any

---@class KeyValue: Command
---@field private path RegPath
---@field private key any
---@field private value? RegValue
local KeyValue = {}

---Creates and returns a new `KeyValue` instance.
---@param path RegPath
---@param key any
---@param value? RegValue
---@return KeyValue
function KeyValue:new(path, key, value)
    assert(type(path) == "table", "path must be table")
    assert(type(key) == "string", "key must be string")
    assert(type(value) == "table", "value must be table")
    local cmd = script.command()
    setmetatable(cmd, self)
    self.__index = self
    ---@cast cmd KeyValue
    cmd.path = path
    cmd.key = key
    cmd.value = value
    return cmd
end

---Returns text representations of the `err` code.
---@param err integer
---@return string
local function winerror_tostring(err)
    -- TODO: Get error string from code
    return tostring(err)
end

---Sets registry `subkey` to the specified `value` returning undo command.
---@return Command|nil # Undo command
---@return error|nil   # Error string, if any
function KeyValue:run()
    return KeyValue:new(self.path, self.key, self.value)
end

---Creates and returns a new `KeyValue` instance.
---@param path RegPath
---@param key string
---@param value? RegValue
---@return KeyValue
function registry.key_value(path, key, value)
    return KeyValue:new(path, key, value)
end

---Builds and returns registry path for the specified `subkey` in
---HKEY_LOCAL_MACHINE tree.
---@param subkey string
---@return RegPath # Full path to the key
function registry.hkey_local_machine(subkey)
    assert(type(subkey) == "string", "subkey must be string")
    return { tree = "", path = "" }
end

---Builds and returns binary registry value with specified `hex` as content.
---@param hex string
---@return RegValue # new binary registry value
function registry.value_bin(hex)
    assert(type(hex) == "string", "hex must be string")
    return { type = "", value = "" }
end

return registry
