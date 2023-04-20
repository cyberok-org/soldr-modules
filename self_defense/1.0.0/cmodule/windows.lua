local ffi = require("ffi")

local kernel32 = require("waffi.windows.kernel32")

local windows = {}

---Converts a UTF-8 encoded string to a wide character (UTF-16) string.
---@param str string input UTF-8 encoded string
---@return ffi.cdata*|nil # wide character string or nil if conversion failed
---@return number # size of the wide character string or 0 if conversion failed
function windows.utf8_to_wide_char(str)
    local ptr, size = ffi.cast("const char*", str), #str
    local nsize = kernel32.MultiByteToWideChar(kernel32.CP_UTF8, 0, ptr, size, nil, 0)

    if nsize <= 0 then
        return nil, 0
    end

    local wstr = ffi.new("wchar_t[?]", nsize + 1)

    kernel32.MultiByteToWideChar(kernel32.CP_UTF8, 0, ptr, size, wstr, nsize)

    return wstr, nsize
end

---Converts a wide character (UTF-16) string to a UTF-8 encoded string.
---@param str ffi.cdata* wide character string
---@param size number size of the wide character string
---@return string|nil # UTF-8 encoded string or nil if conversion failed
---@return number # size of the wide character string or 0 if conversion failed
function windows.wide_char_to_utf8(str, size)
    local nsize = kernel32.WideCharToMultiByte(kernel32.CP_UTF8, 0, str, size, nil, 0, nil, nil)

    if nsize <= 0 then
        return nil, 0
    end

    local utf8 = ffi.new("char[?]", nsize)
    nsize = kernel32.WideCharToMultiByte(kernel32.CP_UTF8, 0, str, size, utf8, nsize, nil, nil)
    return tostring(ffi.string(utf8, nsize - 2)), nsize - 2
end

---Returns text representations of the windows error code `err`.
---@param err integer
---@return string # string representation of the error code
function windows.error_to_string(err)
    local FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
    local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
    local FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100

    local flags = FORMAT_MESSAGE_FROM_SYSTEM
        + FORMAT_MESSAGE_IGNORE_INSERTS
        + FORMAT_MESSAGE_ALLOCATE_BUFFER
    local buffer = ffi.new("wchar_t*[1]")
    local size = kernel32.FormatMessageW(flags, nil, err, 0, ffi.cast("LPWSTR", buffer), 0, nil)
    if size == 0 then
        return "unknown error"
    end
    local msg, _ = windows.wide_char_to_utf8(buffer[0], size)
    kernel32.LocalFree(buffer[0])
    if msg then
        return string.gsub(msg, "[\r\n]", "")
    end
    return tostring(err)
end

---Gets the last error as a string.
---@return string error
function windows.get_last_error()
    return windows.error_to_string(kernel32.GetLastError())
end

return windows
