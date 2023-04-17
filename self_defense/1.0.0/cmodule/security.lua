local ffi = require("ffi")

local advapi32 = require("waffi.windows.advapi32")
local kernel32 = require("waffi.windows.kernel32")

local script = require("script")
local windows = require("windows")

local security = {}

---@class SecurityDescriptor: Command
---@field private name string
---@field private type integer
---@field private descriptor string
local SecurityDescriptor = {}

---Creates and returns a new SecurityDescriptor object.
---@param name string # name of the object
---@param dtype integer # type of the object
---@param descriptor string # string representation of the service descriptor
---@return SecurityDescriptor # new SecurityDescriptor object
function SecurityDescriptor:new(name, dtype, descriptor)
    assert(type(name) == "string", "name must be a string")
    assert(type(dtype) == "number", "dtype must be a number")
    assert(type(descriptor) == "string", "descriptor must be a string")
    local cmd = script.command()
    setmetatable(cmd, self)
    self.__index = self
    ---@cast cmd SecurityDescriptor
    cmd.name = name
    cmd.type = dtype
    cmd.descriptor = descriptor
    return cmd
end

local SDDL_REVISION_1 = 1
local OWNER_SECURITY_INFORMATION = 0x00000001
local GROUP_SECURITY_INFORMATION = 0x00000002
local DACL_SECURITY_INFORMATION = 0x00000004
local COMMON_SECURITY_INFO = OWNER_SECURITY_INFORMATION
    + GROUP_SECURITY_INFORMATION
    + DACL_SECURITY_INFORMATION

---@private
---Returns security descriptor string for the object with the specified `name` and `type`.
---@param name string # name of the object
---@param type integer # type of the object
---@return string|nil # security descriptor string or nil if failed
---@return string|nil # error string or nil if succeeded
function security.get_descriptor_string(name, type)
    local object_name, _ = windows.utf8_to_wide_char(name)
    local psecurity_descriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")

    local err = advapi32.GetNamedSecurityInfoW(
        object_name,
        type,
        COMMON_SECURITY_INFO,
        nil, -- ppSidOwner
        nil, -- ppSidGroup
        nil, -- ppDacl,
        nil, -- ppSacl,
        psecurity_descriptor
    )
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, windows.error_to_string(err)
    end

    local pstring_security_descriptor = ffi.new("wchar_t*[1]")
    local pstring_security_descriptor_len = ffi.new("ULONG[1]")
    local ok = advapi32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
        ffi.cast("SECURITY_DESCRIPTOR *", psecurity_descriptor[0]),
        SDDL_REVISION_1,
        COMMON_SECURITY_INFO,
        pstring_security_descriptor,
        pstring_security_descriptor_len
    )
    if ok == 0 then
        kernel32.LocalFree(psecurity_descriptor[0])
        return nil, windows.get_last_error()
    end
    kernel32.LocalFree(psecurity_descriptor[0])

    local descriptor_string, _ = windows.wide_char_to_utf8(
        pstring_security_descriptor[0],
        pstring_security_descriptor_len[0]
    )
    if not descriptor_string then
        kernel32.LocalFree(pstring_security_descriptor[0])
        return nil, "unable to convert security descriptor to utf-8"
    end
    kernel32.LocalFree(pstring_security_descriptor[0])
    return descriptor_string
end

---Sets the security descriptor for the specified object, returning undo command.
function SecurityDescriptor:run()
    local undo_descriptor, err = security.get_descriptor_string(self.name, self.type)
    if not undo_descriptor then
        return nil, err
    end

    local psecurity_descriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local psecurity_descriptor_len = ffi.new("ULONG[1]")
    local descriptor, _ = windows.utf8_to_wide_char(self.descriptor)
    local ok = advapi32.ConvertStringSecurityDescriptorToSecurityDescriptorW(
        descriptor,
        SDDL_REVISION_1,
        psecurity_descriptor,
        psecurity_descriptor_len
    )
    if ok == 0 then
        return nil, windows.get_last_error()
    end

    local object_name, _ = windows.utf8_to_wide_char(self.name)
    err = advapi32.SetNamedSecurityInfoW(
        object_name,
        self.type,
        DACL_SECURITY_INFORMATION,
        nil, -- psidOwner
        nil, -- psidGroup
        ffi.cast("PACL", psecurity_descriptor[0]), -- pDacl
        nil -- pSacl
    )
    if err ~= kernel32.ERROR_SUCCESS then
        return nil, windows.error_to_string(err)
    end
    kernel32.LocalFree(psecurity_descriptor[0])

    return SecurityDescriptor:new(self.name, self.type, undo_descriptor)
end

function security.service_descriptor(name, descriptor)
    return SecurityDescriptor:new(name, advapi32.SE_SERVICE, descriptor)
end

function security.file_descriptor(name, descriptor)
    return SecurityDescriptor:new(name, advapi32.SE_FILE_OBJECT, descriptor)
end

return security
