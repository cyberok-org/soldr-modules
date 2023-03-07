-- Strips "FILE:LINE:" prefix from an error message.
--:: string -> string
local function strip_place(err)
	return string.gsub(tostring(err), "^.-:.-: ", "")
end

-- Customized protected call around assert/error.
-- In contrast to pcall/xpcall returns unchanged list of the result arguments
-- of `func` on success.
local function try(func, ...)
	local args = {xpcall(func, strip_place, ...)}
	if args[1] == true then
		return unpack(args, 2) end
	return unpack(args)
end

return try
