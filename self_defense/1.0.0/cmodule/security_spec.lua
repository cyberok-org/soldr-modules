local path = require("pl.path")

local advapi32 = require("waffi.windows.advapi32")
local security = require("security")

describe("get_descriptor_string", function()
    local file_name
    before_each(function()
        file_name = path.tmpname()
        io.open(file_name, "w"):close()
    end)
    after_each(function()
        os.remove(file_name)
    end)
    it("returns a security descriptor string for an existing file", function()
        local dstring, err = security.get_object_sddl(file_name, advapi32.SE_FILE_OBJECT)

        assert.is_nil(err)
        assert.is_not_nil(dstring)
    end)

    it("returns an error for a non-existing file", function()
        local not_exist = "non_existing_file.txt"

        local dstring, err = security.get_object_sddl(not_exist, advapi32.SE_FILE_OBJECT)

        assert.is_nil(dstring)
        assert.is_not_nil(err)
    end)
end)

describe("Descriptor:run", function()
    local file_name
    before_each(function()
        file_name = path.tmpname()
        io.open(file_name, "w"):close()
    end)
    after_each(function()
        os.remove(file_name)
    end)
    it("returns error if descriptor is invalid", function()
        local undo, err = security.file_descriptor(file_name, "INVALID"):run()

        assert.is_nil(undo)
        assert.same("The parameter is incorrect.", err)
    end)
    it("sets security descriptor and returns undo", function()
        local SYSTEM_ONLY =
            "O:S-1-5-21-815770899-3706867064-1381326651-1001G:S-1-5-21-815770899-3706867064-1381326651-513D:PAI(A;;FA;;;SY)"

        local undo, err = security.file_descriptor(file_name, SYSTEM_ONLY):run()

        assert.is_nil(err)
        assert.is_not_nil(undo)
        print(file_name)
    end)
end)
