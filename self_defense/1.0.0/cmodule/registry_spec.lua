---@diagnostic disable: invisible, need-check-nil, param-type-mismatch
local registry = require("registry")
local ffi = require("ffi")
local adv32 = require("waffi.windows.advapi32")

ffi.cdef([[
    int lstrcmpW(const wchar_t* lpString1, const wchar_t* lpString2);
]])

describe("key_value", function()
    it("creates KeyValue instance with path, key, and value", function()
        local path = {
            tree = ffi.cast("HKEY", adv32.HKEY_LOCAL_MACHINE),
            path = registry.utf8_to_wide_char("SOFTWARE\\Test"),
        }
        local key = "TestKey"
        local value = { type = 0x00000008, value = "SomeValue" }
        local kv = registry.key_value(path, key, value)

        assert.are.same(path, kv.path)
        assert.are.same(key, kv.key)
        assert.are.same(value, kv.value)
    end)

    it("throws error if path is not a table", function()
        local path = "invalid_path"
        local key = "TestKey"
        local value = { type = 0x00000008, value = "SomeValue" }
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "path must be table")
    end)

    it("throws error if key is not a string", function()
        local path = {
            tree = ffi.cast("HKEY", adv32.HKEY_LOCAL_MACHINE),
            path = registry.utf8_to_wide_char("SOFTWARE\\Test"),
        }
        local key = 42
        local value = { type = 0x00000008, value = "SomeValue" }
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "key must be string")
    end)

    it("throws error if value is not a table", function()
        local path = {
            tree = ffi.cast("HKEY", adv32.HKEY_LOCAL_MACHINE),
            path = registry.utf8_to_wide_char("SOFTWARE\\Test"),
        }
        local key = "TestKey"
        local value = "invalid_value"
        assert.has_error(function()
            registry.key_value(path, key, value)
        end, "value must be table")
    end)
end)

describe("hkey_local_machine", function()
    it("creates registry path with given subkey", function()
        local subkey = "SOFTWARE\\Test"
        local expected_value = registry.utf8_to_wide_char(subkey)

        local reg_path = registry.hkey_local_machine(subkey)

        assert.equal(ffi.cast("HKEY", adv32.HKEY_LOCAL_MACHINE), reg_path.tree)
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

        assert.equal(0x00000008, reg_value.type)
        for i = 1, #expected_value do
            assert.equal(
                ffi.cast("uint8_t", reg_value.value[i - 1]),
                expected_value[i]
            )
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
