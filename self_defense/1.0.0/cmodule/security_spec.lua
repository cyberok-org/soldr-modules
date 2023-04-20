---@diagnostic disable: need-check-nil
local security = require("security")
local windows = require("windows")

local ffi = require("ffi")

local advapi32 = require("waffi.windows.advapi32")
local kernel32 = require("waffi.windows.kernel32")

local util = {}

describe("file_descriptor", function()
    local file_name = "C:\\Windows\\Temp\\test_file.txt"
    before_each(function()
        io.open(file_name, "w"):close()
    end)
    after_each(function()
        os.remove(file_name)
    end)
    local EVERYONE =
        "O:SYG:S-1-5-21-815770899-3706867064-1381326651-513D:PAI(A;;FA;;;SY)S:PAI(AU;SAFA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
    it("throws error if file name is not string", function()
        assert.has_error(function()
            security.file_descriptor({ "not a string" }, EVERYONE)
        end, "file_name must be a string")
    end)
    it("throws error if sddl is not a string", function()
        assert.has_error(function()
            security.file_descriptor("file_name", { "not a string" })
        end, "sddl must be a string")
    end)
    it("returns error if file does not exist", function()
        local file = security.file_descriptor("non_existing_file.txt", EVERYONE)

        local undo, err = file:run()

        assert.is_nil(undo)
        assert.is_not_nil(err)
    end)
    it("returns error if SDDL string is invalid", function()
        local file = security.file_descriptor(file_name, "INVALID")

        local undo, err = file:run()

        assert.is_nil(undo)
        assert.is_not_nil(err)
    end)
    it("sets file SDDL and returns undo command", function()
        local inital_sddl = util.file_sddl(file_name)
        local file = security.file_descriptor(file_name, EVERYONE)

        assert.are_not_same(EVERYONE, inital_sddl)
        local undo, err = file:run()

        assert.is_nil(err)
        assert.is_not_nil(undo)
        assert.are_same(EVERYONE, util.file_sddl(file_name))
    end)
end)

function util.file_sddl(file_name)
    local DESCRIPTOR_INFO = security.OWNER_SECURITY_INFORMATION
        + security.GROUP_SECURITY_INFORMATION
        + security.DACL_SECURITY_INFORMATION
        + security.PROTECTED_DACL_SECURITY_INFORMATION
        + security.SACL_SECURITY_INFORMATION
        + security.PROTECTED_SACL_SECURITY_INFORMATION
    local descriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")
    local wsddl = ffi.new("wchar_t*[1]")
    local wsddl_len = ffi.new("ULONG[1]")
    assert(security.set_process_privilege("SeBackupPrivilege", true))
    assert(
        advapi32.GetNamedSecurityInfoW(
            windows.utf8_to_wide_char(file_name),
            advapi32.SE_FILE_OBJECT,
            DESCRIPTOR_INFO,
            nil,
            nil,
            nil,
            nil,
            descriptor
        ) == kernel32.ERROR_SUCCESS
    )
    assert(security.set_process_privilege("SeBackupPrivilege", false))
    assert(
        advapi32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
            ffi.cast("PSECURITY_DESCRIPTOR", descriptor[0]),
            security.SDDL_REVISION_1,
            DESCRIPTOR_INFO,
            wsddl,
            wsddl_len
        ) ~= 0
    )
    local sddl = windows.wide_char_to_utf8(wsddl[0], wsddl_len[0])
    kernel32.LocalFree(wsddl[0])
    kernel32.LocalFree(descriptor[0])
    return sddl
end
