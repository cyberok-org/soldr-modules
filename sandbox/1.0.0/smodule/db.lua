local sqlite3 = require "lsqlite3"
local try     = require "try"

local MIGRATE_SQL = [[
CREATE TABLE IF NOT EXISTS scan (
    scan_id  INTEGER PRIMARY KEY,
    agent_id TEXT    NOT NULL,
    filename TEXT    NOT NULL,
    status   TEXT    NOT NULL DEFAULT 'new', -- enum: new, processing

    cuckoo_task_id TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, -- datetime: YYYY-MM-DD HH:MM:SS
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP  -- datetime: YYYY-MM-DD HH:MM:SS
);
]]

-- Apply migration onto the given database.
--:: sqlite3.Db -> true?, error?
local function migrate(db)
    local ok, err = try(function()
        db:exec(MIGRATE_SQL)
        return true
    end)
    return ok, string.format("failed to apply migration: %s", err)
end

--:: sqlite3.Db, string, (sqlite3.Stmt -> ...) -> ...
local function with_prepare(db, sql, func)
    return try(function()
        local stmt = db:prepare(sql)
        local result = table.pack(try(func, stmt))
        stmt:finalize()
        return table.unpack(result)
    end)
end

-- DB stores the state of scanning tasks.
local DB = {}; DB.__index = DB

-- Creates an instance of DB with openning an SQLite database from the file.
-- A new database will be created unless the file exists.
--:: string -> DB?, error?
function DB.open(filename)
    return try(function()
        local db = assert(sqlite3.open(filename))
        assert(migrate(db))
        return setmetatable({_db = db}, DB)
    end)
end

-- Instructs DB to close the internal SQLite database connection.
--:: () -> true?, error?
function DB:close()
    return try(function()
        self._db:close()
        return true
    end)
end

-- Converts unix time (seconds) to SQLite's datetime format: YYYY-MM-DD HH:MM:SS.
--:: integer? -> string
function DB.datetime(now)
    return os.date("!%F %T", now)
end

-- Returns info about the requested scanning task.
--:: ScanRow :: {scan_id, agent_id, filename, status, ...}
--:: string -> ScanRow?, error?
function DB:scan_get(scan_id)
    return with_prepare(self._db, [[
        SELECT CAST(scan_id AS TEXT), agent_id, filename, status, cuckoo_task_id, created_at, updated_at
          FROM scan
         WHERE scan_id=?1;
    ]], function(stmt)
        stmt[1] = tonumber(scan_id)
        if not stmt() then
            return nil, "not found" end
        local r = {}
        r.scan_id, r.agent_id, r.filename, r.status, r.cuckoo_task_id, r.created_at, r.updated_at
            = table.unpack(stmt:get_values())
        return r
    end)
end

-- Creates a new scanning task in the database.
--:: string, string, integer? -> scan_id::string?, error?
function DB:scan_new(agent_id, filename, now)
    return with_prepare(self._db, [[
        INSERT INTO scan (status, agent_id, filename, created_at, updated_at)
        VALUES ('new', ?1, ?2, ?3, ?3);
    ]], function(stmt)
        stmt[1], stmt[2], stmt[3] = agent_id, filename, DB.datetime(now)
        stmt()
        return tostring(self._db:last_insert_rowid())
    end)
end

-- Updates status of the scanning task: status=processing.
--:: string, string, integer? -> boolean, error?
function DB:scan_set_processing(scan_id, cuckoo_task_id, now)
    return with_prepare(self._db, [[
        UPDATE scan SET status='processing', cuckoo_task_id=?2, updated_at=?3
         WHERE scan_id=?1
    ]], function(stmt)
        stmt[1], stmt[2], stmt[3] = tonumber(scan_id), cuckoo_task_id, DB.datetime(now)
        stmt()
        return true
    end)
end

-- Executes the given SQL-query on the database.
-- Returns result rows as the table:
-- {
--   {column_1, column_2, ..., column_N }, -- column names
--   {value_1,  value_2,  ..., value_N  }, -- row_1
--   ...
--   {value_1,  value_2,  ..., value_N  }, -- row_M
-- }
--:: string -> {...}?, error?
function DB:select(sql)
    return with_prepare(self._db, sql, function(stmt)
        local columns = {}
        for c = 1,stmt:columns() do
            table.insert(columns, stmt:get_name(c-1))
        end
        local rows = { columns }
        for row in stmt:rows() do
            table.insert(rows, row)
        end
        return rows
    end)
end

return DB
