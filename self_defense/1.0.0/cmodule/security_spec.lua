local ffi = require("ffi")
local adv32 = require("waffi.windows.advapi32")
local security = require("security")

describe("get_descriptor_string", function()
    it("returns a security descriptor string for an existing file", function()
        local file_name = "test_file.txt"
        io.open(file_name, "w"):close()

        local dstring, err = security.get_descriptor_string(file_name, adv32.SE_FILE_OBJECT)

        assert.is_nil(err)
        assert.is_not_nil(dstring)
        os.remove(file_name)
    end)

    it("returns an error for a non-existing file", function()
        local file_name = "non_existing_file.txt"

        local dstring, err = security.get_descriptor_string(file_name, adv32.SE_FILE_OBJECT)

        assert.is_nil(dstring)
        assert.is_not_nil(err)
    end)
end)
