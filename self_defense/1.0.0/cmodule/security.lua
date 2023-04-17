local adv32 = require("waffi.windows.advapi32")
local lk32 = require("waffi.windows.kernel32")
local ffi = require("ffi")
local script = require("script")

local security = {}

---Converts a UTF-8 encoded string to a wide character (UTF-16) string.
---@param str string input UTF-8 encoded string
---@return ffi.cdata*|nil # wide character string or nil if conversion failed
---@return number # size of the wide character string or 0 if conversion failed
function security.utf8_to_wide_char(str)
    local ptr, size = ffi.cast("const char*", str), #str
    local nsize = lk32.MultiByteToWideChar(lk32.CP_UTF8, 0, ptr, size, nil, 0)

    if nsize <= 0 then
        return nil, 0
    end

    local wstr = ffi.new("wchar_t[?]", nsize + 1)
    lk32.MultiByteToWideChar(lk32.CP_UTF8, 0, ptr, size, wstr, nsize)

    return wstr, nsize
end

---Converts a wide character (UTF-16) string to a UTF-8 encoded string.
---@param str ffi.cdata* wide character string
---@param size number size of the wide character string
---@return string|nil # UTF-8 encoded string or nil if conversion failed
function security.wide_char_to_utf8(str, size)
    local nsize = lk32.WideCharToMultiByte(lk32.CP_UTF8, 0, str, size, nil, 0, nil, nil)

    if nsize <= 0 then
        return nil
    end

    local utf8 = ffi.new("char[?]", nsize + 1)
    lk32.WideCharToMultiByte(lk32.CP_UTF8, 0, str, size, utf8, nsize, nil, nil)
    return ffi.string(utf8, nsize)
end

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

---Returns text representations of the windows error code `err`.
---@param err integer
---@return string # string representation of the error code
local function winerror_tostring(err)
    -- TODO: Get error string from code
    return tostring(err)
end

---Gets the last error as a string.
---@return string error
local function get_last_error()
    return winerror_tostring(lk32.GetLastError())
end

---@private
---Returns security descriptor string for the object with the specified `name` and `type`.
---@param name string # name of the object
---@param type integer # type of the object
---@return string|nil # security descriptor string or nil if failed
---@return string|nil # error string or nil if succeeded
function security.get_descriptor_string(name, type)
    local OWNER_SECURITY_INFORMATION = 0x00000001
    local GROUP_SECURITY_INFORMATION = 0x00000002
    local DACL_SECURITY_INFORMATION = 0x00000004
    local SECURITY_INFO_QUERY = OWNER_SECURITY_INFORMATION + GROUP_SECURITY_INFORMATION + DACL_SECURITY_INFORMATION
    local object_name = security.utf8_to_wide_char(name)
    local psecurity_descriptor = ffi.new("PSECURITY_DESCRIPTOR_RELATIVE[1]")

    local err = adv32.GetNamedSecurityInfoW(
        object_name,
        type,
        SECURITY_INFO_QUERY,
        nil, -- ppSidOwner
        nil, -- ppSidGroup
        nil, -- ppDacl,
        nil, -- ppSacl,
        psecurity_descriptor
    )
    if err ~= lk32.ERROR_SUCCESS then
        return nil, winerror_tostring(err)
    end

    local SDDL_REVISION_1 = 1
    local pstring_security_descriptor = ffi.new("wchar_t*[1]")
    local pstring_security_descriptor_len = ffi.new("ULONG[1]")
    local ok = adv32.ConvertSecurityDescriptorToStringSecurityDescriptorW(
        ffi.cast("SECURITY_DESCRIPTOR *", psecurity_descriptor[0]),
        SDDL_REVISION_1,
        SECURITY_INFO_QUERY,
        pstring_security_descriptor,
        pstring_security_descriptor_len
    )
    if ok == 0 then
        lk32.LocalFree(psecurity_descriptor[0])
        return nil, get_last_error()
    end
    lk32.LocalFree(psecurity_descriptor[0])

    local undo_name = security.wide_char_to_utf8(pstring_security_descriptor[0], pstring_security_descriptor_len[0])
    if not undo_name then
        lk32.LocalFree(pstring_security_descriptor[0])
        return nil, "unable to convert security descriptor to utf-8"
    end
    lk32.LocalFree(pstring_security_descriptor[0])
    return undo_name
end

---Sets the security descriptor for the specified object, returning undo command.
function SecurityDescriptor:run()
    local undo_descriptor, err = security.get_descriptor_string(self.name, self.type)
    if not undo_descriptor then
        return nil, err
    end
    return SecurityDescriptor:new(self.name, self.type, undo_descriptor)
end

function security.service_descriptor(name, descriptor)
    return SecurityDescriptor:new(name, adv32.SE_SERVICE, descriptor)
end

return security
