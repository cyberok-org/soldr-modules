local ffi = require("ffi")

local advapi32 = require("waffi.windows.advapi32")
local kernel32 = require("waffi.windows.kernel32")

local script = require("script")
local windows = require("windows")

local security = {}

security.SDDL_REVISION_1 = 1
security.OWNER_SECURITY_INFORMATION = 0x00000001
security.GROUP_SECURITY_INFORMATION = 0x00000002
security.DACL_SECURITY_INFORMATION = 0x00000004
security.SACL_SECURITY_INFORMATION = 0x00000008
security.PROTECTED_DACL_SECURITY_INFORMATION = 0x80000000
security.PROTECTED_SACL_SECURITY_INFORMATION = 0x40000000

---Converts a security descriptor to a SDDL string.
---@param descriptor ffi.cdata*
---@return string|nil # SDDL string or nil if failed
---@return string|nil # error string or nil if succeeded
local function get_descriptor_sddl(info, descriptor)
    local wsddl_string = ffi.new("wchar_t*[1]")
    local wsddl_string_len = ffi.new("ULONG[1]")

    local ok = advapi32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
        ffi.cast("SECURITY_DESCRIPTOR *", descriptor),
        security.SDDL_REVISION_1,
        info,
        wsddl_string,
        wsddl_string_len
    )

    if ok == 0 then
        return nil,
            "ConvertSecurityDescriptorToStringSecurityDescriptorW():" .. windows.get_last_error()
    end

    local sddl_string, _ = windows.wide_char_to_utf8(wsddl_string[0], wsddl_string_len[0])
    kernel32.LocalFree(wsddl_string[0])
    return sddl_string
end

---Returns SDDL string for the object with the specified `object_name` and `object_type`.
---@param object_name string
---@param object_type integer
---@return string|nil # SDDL string or nil if failed
---@return string|nil # error string or nil if succeeded
function security.get_object_sddl(object_name, object_type, info)
    local priv_ok, priv_err = security.set_process_privilege("SeBackupPrivilege", true)
    if not priv_ok then
        return nil, "set_process_privilege():" .. priv_err
    end

    local wobject_name, _ = windows.utf8_to_wide_char(object_name)
    local pdescriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")
    local err = advapi32.GetNamedSecurityInfoW(
        wobject_name,
        object_type,
        info,
        nil, -- ppSidOwner
        nil, -- ppSidGroup
        nil, -- ppDacl,
        nil, -- ppSacl,
        pdescriptor
    )
    security.set_process_privilege("SeBackupPrivilege", false)

    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "GetNamedSecurityInfoW():" .. windows.error_to_string(err)
    end

    local sddl_string, conversion_err = get_descriptor_sddl(info, pdescriptor[0])
    kernel32.LocalFree(pdescriptor[0])

    return sddl_string, conversion_err
end

---Sets the privilege for the current process.
---@param privilege_name string
---@param enable boolean
---@return boolean|nil # true if succeeded, nil if failed
---@return string|nil # error string or nil if succeeded
function security.set_process_privilege(privilege_name, enable)
    local TOKEN_ADJUST_PRIVILEGES = 0x00000020
    local TOKEN_QUERY = 0x00000008
    local SE_PRIVILEGE_ENABLED = 0x00000002

    local wprivilege_name, _ = windows.utf8_to_wide_char(privilege_name)
    local luid = ffi.new("LUID[1]")
    local ok = advapi32.LookupPrivilegeValueW(nil, wprivilege_name, luid)
    if ok == 0 then
        return nil, "LookupPrivilegeValueW():" .. windows.get_last_error()
    end

    local tp = ffi.new("TOKEN_PRIVILEGES[1]")
    tp[0].PrivilegeCount = 1
    tp[0].Privileges[0].Luid = luid[0]
    tp[0].Privileges[0].Attributes = enable and SE_PRIVILEGE_ENABLED or 0

    local token = ffi.new("HANDLE[1]")
    ok = advapi32.OpenProcessToken(
        kernel32.GetCurrentProcess(),
        TOKEN_ADJUST_PRIVILEGES + TOKEN_QUERY,
        token
    )
    if ok == 0 then
        return nil, "OpenProcessToken():" .. windows.get_last_error()
    end

    ok = advapi32.AdjustTokenPrivileges(token[0], false, tp, 0, nil, nil)
    if ok == 0 then
        local err_code = kernel32.GetLastError()
        kernel32.CloseHandle(token[0])
        return nil, "AdjustTokenPrivileges():" .. windows.error_to_string(err_code)
    end
    kernel32.CloseHandle(token[0])
    return true
end

---Sets the security descriptor for the object with the specified `object_name` and `object_type`.
---@param object_name string
---@param object_type integer
---@param descriptor ffi.cdata*
---@return boolean|nil # true if succeeded, nil if failed
---@return string|nil # error string or nil if succeeded
function security.set_object_descriptor(object_name, object_type, info, descriptor)
    local owner = ffi.new("PSID[1]")
    local owner_defaulted = ffi.new("BOOL[1]")
    local group = ffi.new("PSID[1]")
    local group_defaulted = ffi.new("BOOL[1]")
    local dacl_present = ffi.new("BOOL[1]")
    local dacl = ffi.new("PACL[1]")
    local dacl_defaulted = ffi.new("BOOL[1]")
    local sasl_present = ffi.new("BOOL[1]")
    local sasl = ffi.new("PACL[1]")
    local sasl_defaulted = ffi.new("BOOL[1]")
    if advapi32.GetSecurityDescriptorOwner(descriptor, owner, owner_defaulted) == 0 then
        return nil, "GetSecurityDescriptorOwner: " .. windows.get_last_error()
    end
    if advapi32.GetSecurityDescriptorGroup(descriptor, group, group_defaulted) == 0 then
        return nil, "GetSecurityDescriptorGroup: " .. windows.get_last_error()
    end
    if advapi32.GetSecurityDescriptorDacl(descriptor, dacl_present, dacl, dacl_defaulted) == 0 then
        return nil, "GetSecurityDescriptorDacl " .. windows.get_last_error()
    end
    if advapi32.GetSecurityDescriptorSacl(descriptor, sasl_present, sasl, sasl_defaulted) == 0 then
        return nil, "GetSecurityDescriptorSacl " .. windows.get_last_error()
    end

    local priv_ok, priv_err = security.set_process_privilege("SeRestorePrivilege", true)
    if not priv_ok then
        return nil, "set_process_privilege():" .. priv_err
    end

    local wobject_name, _ = windows.utf8_to_wide_char(object_name)
    local err = advapi32.SetNamedSecurityInfoW(
        wobject_name,
        object_type,
        info,
        owner[0],
        group[0],
        dacl_present[0] == 1 and dacl[0] or nil,
        sasl_present[0] == 1 and sasl[0] or nil
    )
    security.set_process_privilege("SeRestorePrivilege", false)
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "SetNamedSecurityInfoW():" .. windows.error_to_string(err)
    end
    return true
end

---Sets the security descriptor from SDDL string for the specified object.
---@param object_name string
---@param object_type integer
---@param sddl string
---@return boolean|nil # true if succeeded, nil if failed
---@return string|nil # error string or nil if succeeded
function security.set_object_sddl(object_name, object_type, info, sddl)
    local psecurity_descriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local psecurity_descriptor_len = ffi.new("ULONG[1]")
    local wsddl, _ = windows.utf8_to_wide_char(sddl)
    local ok = advapi32.ConvertStringSecurityDescriptorToSecurityDescriptorW(
        wsddl,
        security.SDDL_REVISION_1,
        psecurity_descriptor,
        psecurity_descriptor_len
    )
    if ok == 0 then
        return nil,
            "ConvertStringSecurityDescriptorToSecurityDescriptorW():" .. windows.get_last_error()
    end

    local set_ok, set_err =
        security.set_object_descriptor(object_name, object_type, info, psecurity_descriptor[0])
    kernel32.LocalFree(psecurity_descriptor[0])
    return set_ok, set_err
end

---@class NamedObject
---@field private name string
---@field private type integer
local NamedObject = {}
NamedObject.__index = NamedObject

function security.file_object(file_name)
    return setmetatable({
        name = file_name,
        type = advapi32.SE_FILE_OBJECT,
    }, NamedObject)
end

function security.service_object(service_name)
    return setmetatable({
        name = service_name,
        type = advapi32.SE_SERVICE,
    }, NamedObject)
end

function NamedObject:get_sddl(info)
    return security.get_object_sddl(self.name, self.type, info)
end

function NamedObject:set_sddl(info, sddl)
    return security.set_object_sddl(self.name, self.type, info, sddl)
end

---@class Descriptor: Command
---@field private object NamedObject
---@field private info integer
---@field private sddl string
local Descriptor = {}
Descriptor.__index = Descriptor
setmetatable(Descriptor, script.Command)

function Descriptor:new(object, info, sddl)
    return setmetatable({
        object = object,
        info = info,
        sddl = sddl,
    }, self)
end

---Sets the security descriptor for the specified object, returning undo command.
function Descriptor:run()
    local undo_sddl, get_sddl_err = self.object:get_sddl(self.info)
    if not undo_sddl then
        return nil, "object:get_sddl():" .. get_sddl_err
    end

    local ok, set_sddl_err = self.object:set_sddl(self.info, self.sddl)
    if not ok then
        return nil, "object:set_sddl():" .. set_sddl_err
    end

    return Descriptor:new(self.object, self.info, undo_sddl)
end

function security.service_descriptor(service_name, sddl)
    assert(type(service_name) == "string", "service_name must be a string")
    assert(type(sddl) == "string", "sddl must be a string")
    return Descriptor:new(
        security.service_object(service_name),
        security.DACL_SECURITY_INFORMATION,
        sddl
    )
end

function security.file_descriptor(file_name, sddl)
    assert(type(file_name) == "string", "file_name must be a string")
    assert(type(sddl) == "string", "sddl must be a string")
    return Descriptor:new(
        security.file_object(file_name),
        security.OWNER_SECURITY_INFORMATION
            + security.GROUP_SECURITY_INFORMATION
            + security.DACL_SECURITY_INFORMATION
            + security.PROTECTED_DACL_SECURITY_INFORMATION
            + security.SACL_SECURITY_INFORMATION
            + security.PROTECTED_SACL_SECURITY_INFORMATION,
        sddl
    )
end

return security
