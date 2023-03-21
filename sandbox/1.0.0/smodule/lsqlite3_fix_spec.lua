local sqlite3 = require "lsqlite3_fix"
local try     = require "try"

local function with_prepare(db, sql, func)
    return try(function()
        local stmt = db:prepare(sql)
        local result = table.pack(try(func, stmt))
        stmt:finalize()
        return table.unpack(result)
    end)
end

local function query(db, sql, ...)
    local values = table.pack(...)
    return with_prepare(db, sql, function(stmt)
        stmt:bind_values(table.unpack(values))
        local rows = {}
        for row in stmt:rows() do
            table.insert(rows, row) end
        return rows
    end)
end

describe("fix", function()
    test("binding a string value", function()
        local db = assert(sqlite3.open_memory())
        assert(query(db, "CREATE TABLE test (a TEXT, b TEXT)"))
        assert(query(db, "INSERT INTO test (a, b) VALUES ('VALUE', ?1)", "VALUE"))

        local rows = assert(query(db, "SELECT a, b, a==b FROM test"))
        assert.same({"VALUE", "VALUE", 1}, rows[1])
    end)
end)
