local lk32 = require("waffi.windows.kernel32")
local adv32 = require("waffi.windows.advapi32")
local ffi = require("ffi")
local script = require("script")

local registry = {}

---Converts a UTF-8 encoded string to a wide character (UTF-16) string.
---@param str string input UTF-8 encoded string
---@return ffi.cdata*|nil # wide character string or nil if conversion failed
---@return number # size of the wide character string or 0 if conversion failed
function registry.utf8_to_wide_char(str)
    local ptr, size = ffi.cast("const char*", str), #str
    local nsize = lk32.MultiByteToWideChar(lk32.CP_UTF8, 0, ptr, size, nil, 0)

    if nsize <= 0 then
        return nil, 0
    end

    local wstr = ffi.new("wchar_t[?]", nsize + 1)
    lk32.MultiByteToWideChar(lk32.CP_UTF8, 0, ptr, size, wstr, nsize)

    return wstr, nsize
end

---@class RegPath
---@field package tree ffi.cdata*
---@field package path ffi.cdata*

---@class RegValue
---@field package type integer
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
    local wsubkey = registry.utf8_to_wide_char(subkey)
    return { tree = ffi.cast("HKEY", adv32.HKEY_LOCAL_MACHINE), path = wsubkey }
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
    local bin = ffi.new("BYTE[?]", #bytes, bytes)
    local RRF_RT_REG_BINARY = 0x00000008
    return { type = RRF_RT_REG_BINARY, value = bin }
end

return registry
