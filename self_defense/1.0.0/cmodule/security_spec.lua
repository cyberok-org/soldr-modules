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
    local EVERYONE = "O:SYG:SYD:PAI(A;;FA;;;SY)S:PAI(AU;SAFA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
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
        assert.has_error(function()
            security.file_descriptor(file_name, "INVALID")
        end, "ToSecurityDescriptorW():The parameter is incorrect.")
    end)
    it("sets file SDDL and returns undo command", function()
        local initial_sddl = util.file_sddl(file_name)
        local file = security.file_descriptor(file_name, EVERYONE)

        assert.are_not_same(EVERYONE, initial_sddl)
        local undo, err = file:run()

        assert.is_nil(err)
        assert.is_not_nil(undo)
        assert.are_same(EVERYONE, util.file_sddl(file_name))
    end)
    it("is convertable to dict", function()
        local file = security.file_descriptor(file_name, EVERYONE)

        local dict = file:dict()

        assert.are_same({
            name = "security",
            type = "named_object",
            object_name = file_name,
            object_type = advapi32.SE_FILE_OBJECT,
            sddl = EVERYONE,
        }, dict)
    end)
end)

describe("registry_descriptor", function()
    local EVERYONE = "O:SYG:SYD:PAI(A;CI;KA;;;WD)"
    it("throws error if path is not string", function()
        assert.has_error(function()
            security.registry_descriptor({ "not a string" }, EVERYONE)
        end, "path must be a string")
    end)
    it("throws error if sddl is not a string", function()
        assert.has_error(function()
            security.registry_descriptor("path", { "not a string" })
        end, "sddl must be a string")
    end)
    it("returns error if registry key does not exist", function()
        local reg = security.registry_descriptor("CURRENT_USER\\non_existing_key", EVERYONE)

        local undo, err = reg:run()

        assert.is_nil(undo)
        assert.is_not_nil(err)
    end)
    it("returns error if SDDL string is invalid", function()
        assert.has_error(function()
            security.registry_descriptor("CURRENT_USER\\Network", "INVALID")
        end, "ToSecurityDescriptorW():The parameter is incorrect.")
    end)
    it("sets registry SDDL and returns undo command", function()
        local initial_sddl = util.registry_sddl("CURRENT_USER\\Network")
        local reg = security.registry_descriptor("CURRENT_USER\\Network", EVERYONE)

        assert.are_not_same(EVERYONE, initial_sddl)
        local undo, err = reg:run()

        assert.is_nil(err)
        assert.is_not_nil(undo)
        assert.are_same(EVERYONE, util.registry_sddl("CURRENT_USER\\Network"))

        _, err = undo:run()
        assert.is_nil(err)
        assert.are_same(initial_sddl, util.registry_sddl("CURRENT_USER\\Network"))
    end)
    it("is convertable to dict", function()
        local reg = security.registry_descriptor("CURRENT_USER\\Network", EVERYONE)

        local dict = reg:dict()

        assert.are_same({
            name = "security",
            type = "named_object",
            object_name = "CURRENT_USER\\Network",
            object_type = advapi32.SE_REGISTRY_KEY,
            sddl = EVERYONE,
        }, dict)
    end)
end)

describe("process_descriptor", function()
    local SYSTEM_ONLY = "D:(A;;0x1fffff;;;SY)"
    it("throws error if sddl is not a string", function()
        assert.has_error(function()
            security.process_descriptor({ "not a string" })
        end, "sddl must be a string")
    end)
    it("returns error if SDDL string is invalid", function()
        assert.has_error(function()
            security.process_descriptor("INVALID")
        end, "ToSecurityDescriptorW():The parameter is incorrect.")
    end)
    it("sets process SDDL and returns undo command", function()
        local initial_sddl = util.process_sddl()
        local proc = security.process_descriptor(SYSTEM_ONLY)

        assert.are_not_same(SYSTEM_ONLY, initial_sddl)
        local undo, err = proc:run()

        assert.is_nil(err)
        assert.is_not_nil(undo)
        assert.are_same(SYSTEM_ONLY, util.process_sddl())

        local _, undo_err = undo:run()
        assert.is_nil(undo_err)
        assert.are_same(initial_sddl, util.process_sddl())
    end)
    it("is convertable to dict", function()
        local proc = security.process_descriptor(SYSTEM_ONLY)

        local dict = proc:dict()

        assert.are_same({ name = "security", type = "current_process", sddl = SYSTEM_ONLY }, dict)
    end)
end)

describe("load", function()
    it("throws error if cmd_dict is not a table", function()
        assert.has_error(function()
            security.load("not a table")
        end, "cmd_dict must be a table")
    end)
    it("throws error if cmd_dict is not security command", function()
        assert.has_error(function()
            security.load({ name = "not a security" })
        end, "cmd_dict.name must be 'security'")
    end)
    it("throws error if cmd_dict has no type", function()
        assert.has_error(function()
            security.load({ name = "security" })
        end, "cmd_dict.type must be a string")
    end)
    it("loads process descriptor", function()
        local cmd_dict = {
            name = "security",
            type = "current_process",
            sddl = "D:(A;;0x1fffff;;;SY)",
        }

        local cmd = security.load(cmd_dict)

        assert.is_not_nil(cmd)
        assert.are_same(cmd_dict, cmd:dict())
    end)
    it("loads named descriptor", function()
        local cmd_dict = {
            name = "security",
            type = "named_object",
            object_type = advapi32.SE_FILE_OBJECT,
            object_name = "C:\\Windows\\System32\\cmd.exe",
            sddl = "D:(A;;0x1fffff;;;SY)",
        }

        local cmd = security.load(cmd_dict)

        assert.is_not_nil(cmd)
        assert.are_same(cmd_dict, cmd:dict())
    end)
end)

local SDDL_REVISION_1 = 1
local OWNER_SECURITY_INFORMATION = 0x00000001
local GROUP_SECURITY_INFORMATION = 0x00000002
local DACL_SECURITY_INFORMATION = 0x00000004
local SACL_SECURITY_INFORMATION = 0x00000008

local function get_sddl(object_type, object_name, security_info)
    local descriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")
    local wsddl = ffi.new("wchar_t*[1]")
    local wsddl_len = ffi.new("ULONG[1]")
    assert(windows.set_process_privilege("SeBackupPrivilege", true))
    assert(
        advapi32.GetNamedSecurityInfoW(
            windows.utf8_to_wide_char(object_name),
            object_type,
            security_info,
            nil,
            nil,
            nil,
            nil,
            descriptor
        ) == 0
    )
    assert(windows.set_process_privilege("SeBackupPrivilege", false))
    assert(
        advapi32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
            ffi.cast("PSECURITY_DESCRIPTOR", descriptor[0]),
            SDDL_REVISION_1,
            security_info,
            wsddl,
            wsddl_len
        ) == 1
    )
    local sddl = windows.wide_char_to_utf8(wsddl[0], wsddl_len[0])
    kernel32.LocalFree(wsddl[0])
    kernel32.LocalFree(descriptor[0])
    return sddl
end

function util.file_sddl(file_name)
    local DESCRIPTOR_INFO = OWNER_SECURITY_INFORMATION
        + GROUP_SECURITY_INFORMATION
        + DACL_SECURITY_INFORMATION
        + SACL_SECURITY_INFORMATION
    return get_sddl(advapi32.SE_FILE_OBJECT, file_name, DESCRIPTOR_INFO)
end

function util.registry_sddl(key)
    local DESCRIPTOR_INFO = OWNER_SECURITY_INFORMATION
        + GROUP_SECURITY_INFORMATION
        + DACL_SECURITY_INFORMATION
    return get_sddl(advapi32.SE_REGISTRY_KEY, key, DESCRIPTOR_INFO)
end

function util.process_sddl()
    local DESCRIPTOR_INFO = DACL_SECURITY_INFORMATION
    local descriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local wsddl = ffi.new("wchar_t*[1]")
    local wsddl_len = ffi.new("ULONG[1]")
    assert(
        advapi32.GetSecurityInfo(
            kernel32.GetCurrentProcess(),
            advapi32.SE_KERNEL_OBJECT,
            DESCRIPTOR_INFO,
            nil,
            nil,
            nil,
            nil,
            descriptor
        ) == kernel32.ERROR_SUCCESS
    )
    assert(
        advapi32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
            ffi.cast("PSECURITY_DESCRIPTOR", descriptor[0]),
            SDDL_REVISION_1,
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
