local ffi = require("ffi")

local advapi32 = require("waffi.windows.advapi32")
local kernel32 = require("waffi.windows.kernel32")

local script = require("script")
local windows = require("windows")

local security = {}

---@class Descriptor: Command
---@field private object_name string
---@field private object_type integer
---@field private sddl string
local Descriptor = {}

---Creates and returns a new Descriptor object.
---@param object_name string
---@param object_type integer
---@param sddl string
---@return Descriptor
function Descriptor:new(object_name, object_type, sddl)
    assert(type(object_name) == "string", "object_name must be a string")
    assert(type(object_type) == "number", "object_type must be a number")
    assert(type(sddl) == "string", "sddl must be a string")
    local cmd = script.command()
    setmetatable(cmd, self)
    self.__index = self
    ---@cast cmd Descriptor
    cmd.object_name = object_name
    cmd.object_type = object_type
    cmd.sddl = sddl
    return cmd
end

local SDDL_REVISION_1 = 1
local OWNER_SECURITY_INFORMATION = 0x00000001
local GROUP_SECURITY_INFORMATION = 0x00000002
local DACL_SECURITY_INFORMATION = 0x00000004
local COMMON_SECURITY_INFO = OWNER_SECURITY_INFORMATION
    + GROUP_SECURITY_INFORMATION
    + DACL_SECURITY_INFORMATION

---Converts a security descriptor to a SDDL string.
---@param descriptor ffi.cdata*
---@return string|nil # SDDL string or nil if failed
---@return string|nil # error string or nil if succeeded
local function get_descriptor_sddl(descriptor)
    local wsddl_string = ffi.new("wchar_t*[1]")
    local wsddl_string_len = ffi.new("ULONG[1]")

    local ok = advapi32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
        ffi.cast("SECURITY_DESCRIPTOR *", descriptor),
        SDDL_REVISION_1,
        COMMON_SECURITY_INFO,
        wsddl_string,
        wsddl_string_len
    )

    if ok == 0 then
        return nil, windows.get_last_error()
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
function security.get_object_sddl(object_name, object_type)
    local wobject_name, _ = windows.utf8_to_wide_char(object_name)
    local pdescriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")

    local err = advapi32.GetNamedSecurityInfoW(
        wobject_name,
        object_type,
        COMMON_SECURITY_INFO,
        nil, -- ppSidOwner
        nil, -- ppSidGroup
        nil, -- ppDacl,
        nil, -- ppSacl,
        pdescriptor
    )

    if err ~= kernel32.ERROR_SUCCESS then
        return nil, windows.error_to_string(err)
    end

    local sddl_string, conversion_err = get_descriptor_sddl(pdescriptor[0])
    kernel32.LocalFree(pdescriptor[0])

    return sddl_string, conversion_err
end

---Sets the security descriptor from SDDL string for the specified object.
---@param object_name string
---@param object_type integer
---@param sddl string
---@return boolean|nil # true if succeeded, nil if failed
---@return string|nil # error string or nil if succeeded
function security.set_object_sddl(object_name, object_type, sddl)
    local psecurity_descriptor = ffi.new("PSECURITY_DESCRIPTOR[1]")
    local psecurity_descriptor_len = ffi.new("ULONG[1]")
    local wsddl, _ = windows.utf8_to_wide_char(sddl)
    local ok = advapi32.ConvertStringSecurityDescriptorToSecurityDescriptorW(
        wsddl,
        SDDL_REVISION_1,
        psecurity_descriptor,
        psecurity_descriptor_len
    )
    if ok == 0 then
        return nil, windows.get_last_error()
    end

    local wobject_name, _ = windows.utf8_to_wide_char(object_name)
    local err = advapi32.SetNamedSecurityInfoW(
        wobject_name,
        object_type,
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
    return true
end

---Sets the security descriptor for the specified object, returning undo command.
function Descriptor:run()
    local undo_sddl, err = security.get_object_sddl(self.object_name, self.object_type)
    if not undo_sddl then
        return nil, err
    end

    local ok, err = security.set_object_sddl(self.object_name, self.object_type, self.sddl)
    if not ok then
        return nil, err
    end
    return Descriptor:new(self.object_name, self.object_type, undo_sddl)
end

function security.service_descriptor(object_name, sddl)
    return Descriptor:new(object_name, advapi32.SE_SERVICE, sddl)
end

function security.file_descriptor(object_name, sddl)
    return Descriptor:new(object_name, advapi32.SE_FILE_OBJECT, sddl)
end

return security
