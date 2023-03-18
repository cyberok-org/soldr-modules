-- Strips "FILE:LINE:" prefix from an error message produced by assert/error().
local function strip_prefix(err)
    local PATTERN = "^.-:%d-: "
    if type(err) == "string" then
        err = string.gsub(err, PATTERN, "")
    end
    if type(err.message) == "string" then
        err.message = string.gsub(err.message, PATTERN, "")
    end
    return err
end

-- A customized protected call around assert/error.
-- In contrast to pcall/xpcall returns the unchanged list of `func` result
-- arguments on success.
local function try(func, ...)
    local args = table.pack(xpcall(func, strip_prefix, ...))
    if args[1] == true then
        return table.unpack(args, 2) end
    return nil, table.unpack(args, 2)
end

return try
