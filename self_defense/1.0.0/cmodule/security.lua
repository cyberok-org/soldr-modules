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
local UNPROTECTED_DACL_SECURITY_INFORMATION = 0x20000000
local PROTECTED_SACL_SECURITY_INFORMATION = 0x40000000
local UNPROTECTED_SACL_SECURITY_INFORMATION = 0x10000000
local SE_DACL_PROTECTED = 0x1000
local SE_SACL_PROTECTED = 0x2000

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

---@class Descriptor: Command
---@field protected sddl string
---@field protected owner ffi.cdata*
---@field protected group ffi.cdata*
---@field protected dacl ffi.cdata*
---@field protected sacl ffi.cdata*
---@field protected descriptor ffi.cdata*
---@field protected info integer
local Descriptor = {}
Descriptor.__index = Descriptor
setmetatable(Descriptor, script.Command)

function Descriptor:new(sddl)
    local buffer = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local buffer_size = ffi.new("ULONG[1]")
    local ok = advapi32.ConvertStringSecurityDescriptorToSecurityDescriptorW(
        windows.utf8_to_wide_char(sddl),
        SDDL_REVISION_1,
        buffer,
        buffer_size
    )
    assert(ok ~= 0, "ToSecurityDescriptorW():" .. windows.get_last_error())
    -- copy descriptor to avoid memory leak
    local descriptor = ffi.cast("SECURITY_DESCRIPTOR*", ffi.new("BYTE[?]", buffer_size[0]))
    ffi.copy(descriptor, buffer[0], buffer_size[0])
    kernel32.LocalFree(buffer[0])
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
    local control = ffi.new("SECURITY_DESCRIPTOR_CONTROL[1]")
    local revision = ffi.new("DWORD[1]")
    local info = 0
    if advapi32.GetSecurityDescriptorOwner(descriptor, owner, owner_defaulted) == 0 then
        assert(nil, "GetSecurityDescriptorOwner():" .. windows.get_last_error())
    end
    if advapi32.GetSecurityDescriptorGroup(descriptor, group, group_defaulted) == 0 then
        assert(nil, "GetSecurityDescriptorGroup():" .. windows.get_last_error())
    end
    if advapi32.GetSecurityDescriptorDacl(descriptor, dacl_present, dacl, dacl_defaulted) == 0 then
        assert(nil, "GetSecurityDescriptorDacl():" .. windows.get_last_error())
    end
    if advapi32.GetSecurityDescriptorSacl(descriptor, sacl_present, sacl, sacl_defaulted) == 0 then
        assert(nil, "GetSecurityDescriptorSacl():" .. windows.get_last_error())
    end
    if advapi32.GetSecurityDescriptorControl(descriptor, control, revision) == 0 then
        assert(nil, "GetSecurityDescriptorControl():" .. windows.get_last_error())
    end
    if owner[0] ~= nil then
        info = bit.bor(info, OWNER_SECURITY_INFORMATION)
    end
    if group[0] ~= nil then
        info = bit.bor(info, GROUP_SECURITY_INFORMATION)
    end
    if dacl_present[0] == 1 then
        info = bit.bor(info, DACL_SECURITY_INFORMATION)
        if bit.band(control[0], SE_DACL_PROTECTED) ~= 0 then
            info = bit.bor(info, PROTECTED_DACL_SECURITY_INFORMATION)
        else
            info = bit.bor(info, UNPROTECTED_DACL_SECURITY_INFORMATION)
        end
    end
    if sacl_present[0] == 1 then
        info = bit.bor(info, SACL_SECURITY_INFORMATION)
        if bit.band(control[0], SE_SACL_PROTECTED) ~= 0 then
            info = bit.bor(info, PROTECTED_SACL_SECURITY_INFORMATION)
        else
            info = bit.bor(info, UNPROTECTED_SACL_SECURITY_INFORMATION)
        end
    end
    return setmetatable({
        owner = owner[0],
        group = group[0],
        dacl = dacl[0],
        sacl = sacl[0],
        info = info,
        descriptor = descriptor[0],
        sddl = sddl,
    }, self)
end

---@class NamedDescriptor: Descriptor
---@field private object_name string
---@field private object_type string
local NamedDescriptor = {}
NamedDescriptor.__index = NamedDescriptor
setmetatable(NamedDescriptor, Descriptor)

function NamedDescriptor:new(object_name, object_type, sddl)
    local obj = Descriptor:new(sddl)
    obj.object_name = object_name
    obj.object_type = object_type
    return setmetatable(obj, self)
end

local function sddl_from_named_object(name, type, info)
    local ok, priv_err = windows.set_process_privilege("SeBackupPrivilege", true)
    if not ok then
        return nil, "set_process_privilege():" .. priv_err
    end
    local descriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")
    local err = advapi32.GetNamedSecurityInfoW(
        windows.utf8_to_wide_char(name),
        type,
        info,
        nil,
        nil,
        nil,
        nil,
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

function NamedDescriptor:run()
    local sddl, sddl_err = sddl_from_named_object(self.object_name, self.object_type, self.info)
    if not sddl then
        return nil, "sddl_from_named_object():" .. sddl_err
    end

    local priv_ok, priv_err = windows.set_process_privilege("SeRestorePrivilege", true)
    if not priv_ok then
        return nil, "set_process_privilege():" .. priv_err
    end

    local err = advapi32.SetNamedSecurityInfoW(
        windows.utf8_to_wide_char(self.object_name),
        self.object_type,
        self.info,
        self.owner,
        self.group,
        self.dacl,
        self.sacl
    )
    windows.set_process_privilege("SeRestorePrivilege", false)
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "SetNamedSecurityInfoW():" .. windows.error_to_string(err)
    end

    return NamedDescriptor:new(self.object_name, self.object_type, sddl)
end

---@class ProcessDescriptor: Descriptor
local ProcessDescriptor = {}
ProcessDescriptor.__index = ProcessDescriptor
setmetatable(ProcessDescriptor, Descriptor)

function ProcessDescriptor:new(sddl)
    local obj = Descriptor:new(sddl)
    return setmetatable(obj, self)
end

local function sddl_from_process(info)
    local pdescriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local err = advapi32.GetSecurityInfo(
        kernel32.GetCurrentProcess(),
        advapi32.SE_KERNEL_OBJECT,
        info,
        nil,
        nil,
        nil,
        nil,
        pdescriptor
    )
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "GetSecurityInfo():" .. windows.error_to_string(err)
    end
    local sddl_string, conversion_err = get_descriptor_sddl(info, pdescriptor[0])
    kernel32.LocalFree(pdescriptor[0])
    return sddl_string, conversion_err
end

function ProcessDescriptor:run()
    local sddl, sddl_err = sddl_from_process(self.info)
    if not sddl then
        return nil, "sddl_from_process():" .. sddl_err
    end
    local err = advapi32.SetSecurityInfo(
        kernel32.GetCurrentProcess(),
        advapi32.SE_KERNEL_OBJECT,
        self.info,
        self.owner,
        self.group,
        self.dacl,
        self.sacl
    )
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, "SetSecurityInfo():" .. windows.error_to_string(err)
    end
    return ProcessDescriptor:new(sddl)
end

function security.service_descriptor(service_name, sddl)
    assert(type(service_name) == "string", "service_name must be a string")
    assert(type(sddl) == "string", "sddl must be a string")
    return NamedDescriptor:new(service_name, advapi32.SE_SERVICE, sddl)
end

function security.file_descriptor(file_name, sddl)
    assert(type(file_name) == "string", "file_name must be a string")
    assert(type(sddl) == "string", "sddl must be a string")
    return NamedDescriptor:new(file_name, advapi32.SE_FILE_OBJECT, sddl)
end

function security.process_descriptor(sddl)
    assert(type(sddl) == "string", "sddl must be a string")
    return ProcessDescriptor:new(sddl)
end

function security.registry_descriptor(path, sddl)
    assert(type(path) == "string", "path must be a string")
    assert(type(sddl) == "string", "sddl must be a string")
    return NamedDescriptor:new(path, advapi32.SE_REGISTRY_KEY, sddl)
end

return security
