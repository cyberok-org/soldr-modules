---@diagnostic disable: invisible, need-check-nil, param-type-mismatch
local ffi = require("ffi")

local advapi32 = require("waffi.windows.advapi32")

local registry = require("registry")
local windows = require("windows")

ffi.cdef([[
    int lstrcmpW(const wchar_t* lpString1, const wchar_t* lpString2);
]])

local function get_test_path_key_value()
    local path = {
        tree = ffi.cast("HKEY", advapi32.HKEY_CURRENT_USER),
        path = windows.utf8_to_wide_char("SOFTWARE\\Test"),
    }
    local key = "TestKey"
    local value = {
        type = advapi32.REG_BINARY,
        data = ffi.new("uint8_t[1]"),
        size = 1,
    }
    return path, key, value
end

describe("key_value", function()
    it("creates KeyValue instance with path, key, and value", function()
        local path, key, value = get_test_path_key_value()
        local kv = registry.key_value(path, key, value)

        assert.are.same(path, kv.path)
        assert.equal(key, kv.key)
        assert.are.same(value, kv.value)
    end)
    it("throws error if path is not a table", function()
        local _, key, value = get_test_path_key_value()
        local path = "invalid_path"
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "path must be table")
    end)
    it("throws error if key is not a string", function()
        local path, _, value = get_test_path_key_value()
        local key = 42
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "key must be string")
    end)
    it("throws error if value is not a table", function()
        local path, key, _ = get_test_path_key_value()
        local value = "invalid_value"
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "value must be table")
    end)
    it("throws error if value.type is not a number", function()
        local path, key, value = get_test_path_key_value()
        value.type = "invalid_value_type"
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "value.type must be number")
    end)
    it("throws error if value.data is not a cdata", function()
        local path, key, value = get_test_path_key_value()
        value.data = "invalid_value_data"
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "value.data must be cdata")
    end)
    it("throws error if value.size is not a number", function()
        local path, key, value = get_test_path_key_value()
        value.size = "invalid_value_data"
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "value.size must be number")
    end)
    it("is convertable to dict", function()
        local path, key, value = get_test_path_key_value()
        local kv = registry.key_value(path, key, value)

        local dict = kv:dict()

        assert.are_same({
            name = "registry",
            path = {
                tree = advapi32.HKEY_CURRENT_USER,
                subkey = "SOFTWARE\\Test",
            },
            key = key,
            value = {
                type = advapi32.REG_BINARY,
                data = "00",
                size = 1,
            },
        }, dict)
    end)
end)

describe("KeyValue:run", function()
    it("returns error if key cannot be accessed", function()
        local path, key, value = get_test_path_key_value()
        path.tree = ffi.cast("HKEY", 3117)

        local kv = registry.key_value(path, key, value)
        local undo, err = kv:run()

        assert.is_nil(undo)
        assert.is_not_nil(err)
    end)
    it("sets and undos the key", function()
        -- DANGEROUS TEST!!! --
        local path, key, value = get_test_path_key_value()

        local kv = registry.key_value(path, key, value)
        local undo, err = kv:run()

        assert.is_not_nil(undo)
        assert.is_nil(err)

        _, err = undo:run()
        assert.is_nil(err)
    end)
end)

describe("hkey_local_machine", function()
    it("creates registry path with given subkey", function()
        local subkey = "SOFTWARE\\Test"
        local expected_value = windows.utf8_to_wide_char(subkey)

        local reg_path = registry.hkey_local_machine(subkey)

        assert.equal(ffi.cast("HKEY", advapi32.HKEY_LOCAL_MACHINE), reg_path.tree)
        assert.equal(0, ffi.C.lstrcmpW(reg_path.path, expected_value))
    end)

    it("throws error if subkey is not a string", function()
        local subkey = 42
        assert.has_error(function()
            registry.hkey_local_machine(subkey)
        end, "subkey must be string")
    end)
end)

describe("value_bin", function()
    it("creates binary value from hex", function()
        local hex = "4a6f686e"
        local expected_value = { 74, 111, 104, 110 }

        local reg_value = registry.value_bin(hex)

        assert.equal(advapi32.REG_BINARY, reg_value.type)
        for i = 1, #expected_value do
            assert.equal(expected_value[i], reg_value.data[i - 1])
        end
    end)
    it("throws error if hex not a string", function()
        local hex = 42
        assert.has_error(function()
            registry.value_bin(hex)
        end, "hex must be string")
    end)
    it("throws error if hex has odd number of chars", function()
        local hex = "4a6f686"
        assert.has_error(function()
            registry.value_bin(hex)
        end, "hex must have an even number of characters")
    end)
    it("throws error if hex has invalid characters", function()
        local hex = "4a6f6g"
        assert.has_error(function()
            registry.value_bin(hex)
        end, "invalid hex chars")
    end)
end)

describe("load", function()
    it("throws error if cmd_dict is not a table", function()
        assert.has_error(function()
            registry.load("not a table")
        end, "cmd_dict must be a table")
    end)
    it("throws error if cmd_dict is not security command", function()
        assert.has_error(function()
            registry.load({ name = "not a registry" })
        end, "cmd_dict.name must be 'registry'")
    end)
    it("loads key value", function()
        local cmd_dict = {
            name = "registry",
            path = {
                tree = advapi32.HKEY_CURRENT_USER,
                subkey = "SOFTWARE\\Test",
            },
            key = "test",
            value = {
                type = advapi32.REG_BINARY,
                data = "00112233445566778899aabbccddeeff",
                size = 16,
            },
        }

        local cmd = registry.load(cmd_dict)

        assert.is_not_nil(cmd)
        assert.are_same(cmd_dict, cmd:dict())
    end)
end)
