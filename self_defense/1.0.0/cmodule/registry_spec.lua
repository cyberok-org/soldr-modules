---@diagnostic disable: invisible, need-check-nil, param-type-mismatch
local registry = require("registry")

local path = { tree = "HKEY_LOCAL_MACHINE", path = "Software\\Test" }
local key = "key1"
local value = { type = "REG_BINARY", value = "01" }

describe("KeyValue", function()
    it("should create a new KeyValue instance", function()
        local kv = registry.key_value(path, key, value)
        assert.are.same(path, kv.path)
        assert.are.same(key, kv.key)
        assert.are.same(value, kv.value)
    end)

    it("should return an undo command", function()
        local kv = registry.key_value(path, key, value)
        local undo = kv:run()
        assert.are.same(kv.path, undo.path)
        assert.are.same(kv.key, undo.key)
        assert.are.same(kv.value, undo.value)
    end)
end)

describe("registry", function()
    it("should create a RegPath for hkey_local_machine", function()
        local subkey = "Software\\Test"
        local regPath = registry.hkey_local_machine(subkey)
        assert.is_not_nil(regPath.tree)
        assert.is_not_nil(regPath.path)
    end)

    it("should create a RegValue for value_bin", function()
        local hex = "01"
        local regValue = registry.value_bin(hex)
        assert.is_not_nil(regValue.type)
        assert.is_not_nil(regValue.value)
    end)
end)

describe("Error handling", function()
    it("should throw errors for invalid input types", function()
        assert.has_error(function()
            registry.key_value(nil, key, value)
        end, "path must be table")
        assert.has_error(function()
            registry.key_value(path, nil, value)
        end, "key must be string")
        assert.has_error(function()
            registry.key_value(path, key, nil)
        end, "value must be table")
        assert.has_error(function()
            registry.hkey_local_machine(nil)
        end, "subkey must be string")
        assert.has_error(function()
            registry.value_bin(nil)
        end, "hex must be string")
    end)
end)
