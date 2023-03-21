local ffi     = require "ffi"
local sqlite3 = require "lsqlite3"

ffi.cdef[[
    int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
]]
local SQLITE_TRANSIENT = ffi.cast("void*", -1)
local libsqlite3 = ffi.load("sqlite3")

local db = sqlite3.open_memory()
local stmt = db:prepare("SELECT 1")
local mt = getmetatable(stmt)
stmt:finalize()
db:close()

local sqlite3_bind = mt.bind
mt.bind = function(...)
    local self, n, value = ...
    -- Fix binding a string value
    if type(value) == "string" then
        self.db:check(libsqlite3.sqlite3_bind_text(self.stmt, n, value, #value, SQLITE_TRANSIENT))
    else return sqlite3_bind(...) end
end

return sqlite3
