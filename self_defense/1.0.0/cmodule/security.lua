local ffi = require("ffi")

local advapi32 = require("waffi.windows.advapi32")
local kernel32 = require("waffi.windows.kernel32")

local script = require("script")
local windows = require("windows")

local SDDL_REVISION_1 = 1
local OWNER_SECURITY_INFORMATION = 0x00000001
local GROUP_SECURITY_INFORMATION = 0x00000002
local DACL_SECURITY_INFORMATION = 0x00000004
local SACL_SECURITY_INFORMATION = 0x00000008
local PROTECTED_DACL_SECURITY_INFORMATION = 0x80000000
local PROTECTED_SACL_SECURITY_INFORMATION = 0x40000000

local security = {}

---Converts a security descriptor to a SDDL string.
---@param info number flag combination indicating the security descriptor
---                   components to include in the SDDL string
---@param descriptor ffi.cdata* the security descriptor to convert
---@return string|nil # SDDL string or nil if failed
---@return string|nil # error string or nil if succeeded
local function get_descriptor_sddl(info, descriptor)
    local wsddl_string = ffi.new("wchar_t*[1]")
    local wsddl_string_len = ffi.new("ULONG[1]")

    local ok = advapi32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
        ffi.cast("SECURITY_DESCRIPTOR *", descriptor),
        SDDL_REVISION_1,
        info,
        wsddl_string,
        wsddl_string_len
    )

    if ok == 0 then
        return nil, "ToStringSecurityDescriptorW():" .. windows.get_last_error()
    end

    local sddl_string = windows.wide_char_to_utf8(wsddl_string[0], wsddl_string_len[0])
    kernel32.LocalFree(wsddl_string[0])
    return sddl_string
end

---@class ProcessObject
local ProcessObject = {}
ProcessObject.__index = ProcessObject

local function process_object()
    return setmetatable({}, ProcessObject)
end

function ProcessObject:get_sddl(info)
    local pdescriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local err = advapi32.GetSecurityInfo(
        kernel32.GetCurrentProcess(),
        advapi32.SE_KERNEL_OBJECT,
        info,
        nil, -- ppSidOwner
        nil, -- ppSidGroup
        nil, -- ppDacl,
        nil, -- ppSacl,
        pdescriptor
    )
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "GetSecurityInfo():" .. windows.error_to_string(err)
    end
    local sddl_string, conversion_err = get_descriptor_sddl(info, pdescriptor[0])
    kernel32.LocalFree(pdescriptor[0])

    return sddl_string, conversion_err
end

function ProcessObject:set_descriptor(_, descriptor)
    local dacl_present = ffi.new("BOOL[1]")
    local dacl = ffi.new("PACL[1]")
    local dacl_defaulted = ffi.new("BOOL[1]")
    if advapi32.GetSecurityDescriptorDacl(descriptor, dacl_present, dacl, dacl_defaulted) == 0 then
        return nil, "GetSecurityDescriptorDacl():" .. windows.get_last_error()
    end
    local info = 0
    if dacl_present ~= 0 then
        info = bit.bor(info, DACL_SECURITY_INFORMATION)
    end
    local err = advapi32.SetSecurityInfo(
        kernel32.GetCurrentProcess(),
        advapi32.SE_KERNEL_OBJECT,
        info,
        nil,
        nil,
        dacl_present[0] == 1 and dacl[0] or nil,
        nil
    )
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "SetSecurityInfo():" .. windows.error_to_string(err)
    end
    return true
end

function ProcessObject:set_sddl(info, sddl)
    local descriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local descriptor_size = ffi.new("ULONG[1]")
    local ok = advapi32.ConvertStringSecurityDescriptorToSecurityDescriptorW(
        windows.utf8_to_wide_char(sddl),
        SDDL_REVISION_1,
        descriptor,
        descriptor_size
    )
    if ok == 0 then
        return nil, "ToSecurityDescriptorW():" .. windows.get_last_error()
    end

    local set_ok, set_err = self:set_descriptor(info, descriptor[0])
    kernel32.LocalFree(descriptor[0])
    return set_ok, set_err
end

---@class NamedObject
---@field private name string
---@field private type integer
local NamedObject = {}
NamedObject.__index = NamedObject

local function file_object(file_name)
    return setmetatable({ name = file_name, type = advapi32.SE_FILE_OBJECT }, NamedObject)
end

local function service_object(service_name)
    return setmetatable({ name = service_name, type = advapi32.SE_SERVICE }, NamedObject)
end

local function registry_object(registry_key)
    return setmetatable({ name = registry_key, type = advapi32.SE_REGISTRY_KEY }, NamedObject)
end

function NamedObject:get_sddl(info)
    local ok, priv_err = windows.set_process_privilege("SeBackupPrivilege", true)
    if not ok then
        return nil, "set_process_privilege():" .. priv_err
    end

    local descriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")
    local err = advapi32.GetNamedSecurityInfoW(
        windows.utf8_to_wide_char(self.name),
        self.type,
        info,
        nil, -- ppSidOwner
        nil, -- ppSidGroup
        nil, -- ppDacl,
        nil, -- ppSacl,
        descriptor
    )
    windows.set_process_privilege("SeBackupPrivilege", false)

    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "GetNamedSecurityInfoW():" .. windows.error_to_string(err)
    end

    local sddl_string, conversion_err = get_descriptor_sddl(info, descriptor[0])
    kernel32.LocalFree(descriptor[0])

    return sddl_string, conversion_err
end

---Sets the security descriptor for the object with the specified `object_name` and `object_type`.
---@param object_name string
---@param object_type integer
---@param info integer
---@param descriptor ffi.cdata*
---@return boolean|nil # true if succeeded, nil if failed
---@return string|nil # error string or nil if succeeded
local function set_object_descriptor(object_name, object_type, info, descriptor)
    local owner = ffi.new("PSID[1]")
    local owner_defaulted = ffi.new("BOOL[1]")
    local group = ffi.new("PSID[1]")
    local group_defaulted = ffi.new("BOOL[1]")
    local dacl_present = ffi.new("BOOL[1]")
    local dacl = ffi.new("PACL[1]")
    local dacl_defaulted = ffi.new("BOOL[1]")
    local sacl_present = ffi.new("BOOL[1]")
    local sacl = ffi.new("PACL[1]")
    local sacl_defaulted = ffi.new("BOOL[1]")
    if advapi32.GetSecurityDescriptorOwner(descriptor, owner, owner_defaulted) == 0 then
        return nil, "GetSecurityDescriptorOwner():" .. windows.get_last_error()
    end
    if advapi32.GetSecurityDescriptorGroup(descriptor, group, group_defaulted) == 0 then
        return nil, "GetSecurityDescriptorGroup():" .. windows.get_last_error()
    end
    if advapi32.GetSecurityDescriptorDacl(descriptor, dacl_present, dacl, dacl_defaulted) == 0 then
        return nil, "GetSecurityDescriptorDacl():" .. windows.get_last_error()
    end
    if advapi32.GetSecurityDescriptorSacl(descriptor, sacl_present, sacl, sacl_defaulted) == 0 then
        return nil, "GetSecurityDescriptorSacl():" .. windows.get_last_error()
    end

    local priv_ok, priv_err = windows.set_process_privilege("SeRestorePrivilege", true)
    if not priv_ok then
        return nil, "set_process_privilege():" .. priv_err
    end

    local err = advapi32.SetNamedSecurityInfoW(
        windows.utf8_to_wide_char(object_name),
        object_type,
        info,
        owner[0],
        group[0],
        dacl_present[0] == 1 and dacl[0] or nil,
        sacl_present[0] == 1 and sacl[0] or nil
    )
    windows.set_process_privilege("SeRestorePrivilege", false)
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "SetNamedSecurityInfoW():" .. windows.error_to_string(err)
    end
    return true
end

function NamedObject:set_sddl(info, sddl)
    local descriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local descriptor_size = ffi.new("ULONG[1]")
    local ok = advapi32.ConvertStringSecurityDescriptorToSecurityDescriptorW(
        windows.utf8_to_wide_char(sddl),
        SDDL_REVISION_1,
        descriptor,
        descriptor_size
    )
    if ok == 0 then
        return nil, "ToSecurityDescriptorW():" .. windows.get_last_error()
    end

    local set_ok, set_err = set_object_descriptor(self.name, self.type, info, descriptor[0])
    kernel32.LocalFree(descriptor[0])
    return set_ok, set_err
end

---@class Descriptor: Command
---@field private object NamedObject
---@field private info integer
---@field private sddl string
local Descriptor = {}
Descriptor.__index = Descriptor
setmetatable(Descriptor, script.Command)

function Descriptor:new(object, info, sddl)
    return setmetatable({ object = object, info = info, sddl = sddl }, self)
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
    return Descriptor:new(service_object(service_name), DACL_SECURITY_INFORMATION, sddl)
end

function security.file_descriptor(file_name, sddl)
    assert(type(file_name) == "string", "file_name must be a string")
    assert(type(sddl) == "string", "sddl must be a string")
    return Descriptor:new(
        file_object(file_name),
        OWNER_SECURITY_INFORMATION
            + GROUP_SECURITY_INFORMATION
            + DACL_SECURITY_INFORMATION
            + PROTECTED_DACL_SECURITY_INFORMATION
            + SACL_SECURITY_INFORMATION
            + PROTECTED_SACL_SECURITY_INFORMATION,
        sddl
    )
end

function security.process_descriptor(sddl)
    assert(type(sddl) == "string", "sddl must be a string")
    return Descriptor:new(process_object(), DACL_SECURITY_INFORMATION, sddl)
end

function security.registry_descriptor(path, sddl)
    assert(type(path) == "string", "path must be a string")
    assert(type(sddl) == "string", "sddl must be a string")
    return Descriptor:new(
        registry_object(path),
        OWNER_SECURITY_INFORMATION
            + GROUP_SECURITY_INFORMATION
            + DACL_SECURITY_INFORMATION
            + PROTECTED_DACL_SECURITY_INFORMATION,
        sddl
    )
end

return security
