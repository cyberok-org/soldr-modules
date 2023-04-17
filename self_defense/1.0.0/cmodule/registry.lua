local ffi = require("ffi")

local advapi32 = require("waffi.windows.advapi32")
local kernel32 = require("waffi.windows.kernel32")

local script = require("script")
local windows = require("windows")

local registry = {}

---@class RegPath
---@field package tree ffi.cdata*
---@field package path ffi.cdata*

---@class RegValue
---@field package type integer
---@field package data ffi.cdata*
---@field package size integer

---@class KeyValue: Command
---@field private path RegPath
---@field private key string
---@field private value? RegValue
local KeyValue = {}

---Creates and returns a new `KeyValue` instance.
---@param path RegPath
---@param key string
---@param val? RegValue
---@return KeyValue
function KeyValue:new(path, key, val)
    local cmd = script.command()
    setmetatable(cmd, self)
    self.__index = self
    ---@cast cmd KeyValue
    cmd.path = path
    cmd.key = key
    cmd.value = val
    return cmd
end

local function get_key_value(path, key)
    local RRF_RT_ANY = 0x0000ffff
    local value_type = ffi.new("DWORD[1]")
    local value_size = ffi.new("DWORD[1]")
    local reg_get_val = function(value_data)
        return advapi32.RegGetValueW(
            path.tree,
            path.path,
            key,
            RRF_RT_ANY,
            value_type,
            value_data,
            value_size
        )
    end
    local err = reg_get_val()
    if err == kernel32.ERROR_FILE_NOT_FOUND then
        return nil
    elseif err ~= kernel32.ERROR_SUCCESS then
        return nil, windows.error_to_string(err)
    end
    local value_data = ffi.new("uint8_t[?]", value_size[0])
    err = reg_get_val(value_data)
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, windows.error_to_string(err)
    end
    return { type = value_type[0], data = value_data, size = value_size[0] }
end

---Sets registry `subkey` to the specified `value`, returning undo command.
---@return Command|nil # Undo command
---@return error|nil   # Error string, if any
function KeyValue:run()
    local wkey = windows.utf8_to_wide_char(self.key)
    local undo_value, err = get_key_value(self.path, wkey)
    if err and not undo_value then
        return nil, err
    end
    if self.value then
        err = advapi32.RegSetKeyValueW(
            self.path.tree,
            self.path.path,
            wkey,
            self.value.type,
            self.value.data,
            self.value.size
        )
        if err ~= kernel32.ERROR_SUCCESS then
            return nil, windows.error_to_string(err)
        end
    else
        err = advapi32.RegDeleteKeyValueW(self.path.tree, self.path.path, wkey)
        if err ~= kernel32.ERROR_SUCCESS and err ~= kernel32.ERROR_FILE_NOT_FOUND then
            return nil, windows.error_to_string(err)
        end
    end
    return KeyValue:new(self.path, self.key, undo_value)
end

---Creates and returns a new `KeyValue` instance.
---@param path RegPath
---@param key string
---@param val? RegValue
---@return KeyValue
function registry.key_value(path, key, val)
    assert(type(path) == "table", "path must be table")
    assert(type(key) == "string", "key must be string")
    assert(not val or type(val) == "table", "value must be table")
    assert(not val or type(val.type) == "number", "value.type must be number")
    assert(not val or type(val.data) == "cdata", "value.data must be cdata")
    assert(not val or type(val.size) == "number", "value.size must be number")
    return KeyValue:new(path, key, val)
end

---Builds and returns registry path for the specified `subkey` in
---HKEY_LOCAL_MACHINE tree.
---@param subkey string
---@return RegPath # Full path to the key
function registry.hkey_local_machine(subkey)
    assert(type(subkey) == "string", "subkey must be string")
    local wsubkey = windows.utf8_to_wide_char(subkey)
    return { tree = ffi.cast("HKEY", advapi32.HKEY_LOCAL_MACHINE), path = wsubkey }
end

---Builds and returns binary registry value with specified `hex` as content.
---@param hex string
---@return RegValue # new binary registry value
function registry.value_bin(hex)
    assert(type(hex) == "string", "hex must be string")
    assert(#hex % 2 == 0, "hex must have an even number of characters")

    local bytes = {}
    for i = 1, #hex, 2 do
        local hex_byte = hex:sub(i, i + 1)
        assert(hex_byte:match("^%x%x$"), "invalid hex chars")
        local byte = tonumber(hex_byte, 16)
        table.insert(bytes, byte)
    end
    local bin = ffi.new("uint8_t[?]", #bytes, bytes)
    return { type = advapi32.REG_BINARY, data = bin, size = #bytes }
end

return registry
