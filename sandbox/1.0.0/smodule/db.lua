local cjson   = require "cjson.safe"
local sqlite3 = require "lsqlite3_fix"
local try     = require "try"

local MIGRATE_SQL = [[
CREATE TABLE IF NOT EXISTS scan (
    scan_id  INTEGER PRIMARY KEY,
    agent_id TEXT    NOT NULL,
    filename TEXT    NOT NULL,

    -- enum: new, error, pending, running, completed, reported
    status TEXT NOT NULL DEFAULT 'new',
    error  TEXT,

    task_id      INTEGER,
    task_options TEXT NOT NULL DEFAULT '{}', -- JSON-encoded scanning options
    report       TEXT,                       -- JSON-encoded report
    report_url   TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, -- datetime: YYYY-MM-DD HH:MM:SS
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP  -- datetime: YYYY-MM-DD HH:MM:SS
);
CREATE INDEX IF NOT EXISTS status ON scan (status);
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

--:: sqlite3.DB|Stmt -> {column_1: value_1, ...}
local function get_named_values(db)
    local row = {}
    for i = 1, db:columns() do
        row[db:get_name(i-1)] = db:get_value(i-1)
    end
    return row
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

-- Returns info about the scanning task specified by `scan_id`.
--:: ScanRow :: {scan_id, agent_id, filename, status, ...}
--:: integer -> ScanRow?, error?
function DB:scan_get(scan_id)
    return with_prepare(self._db, [[ SELECT * FROM scan WHERE scan_id=?1 ]], function(stmt)
        stmt[1] = scan_id
        while stmt() do
            local scan = get_named_values(stmt)
            scan.task_options = assert(cjson.decode(scan.task_options))
            return scan
        end
        return nil, "not found"
    end)
end

-- Returns a list of unfinished scanning tasks.
--:: () -> [ScanRow], error?
function DB:scan_list_unfinished()
    return with_prepare(self._db, [[
        SELECT * FROM scan WHERE status NOT IN ('reported', 'error');
    ]], function(stmt)
        local rows = {}
        while stmt() do
            table.insert(rows, get_named_values(stmt)) end
        return rows
    end)
end

-- Creates a new scanning task in the database.
--:: string, string, any, integer? -> scan_id::integer?, error?
function DB:scan_new(agent_id, filename, options, now)
    return with_prepare(self._db, [[
        INSERT INTO scan (status, agent_id, filename, task_options, created_at, updated_at)
        VALUES ('new', ?1, ?2, ?3, ?4, ?4);
    ]], function(stmt)
        stmt[1] = agent_id
        stmt[2] = filename
        stmt[3] = cjson.encode(options)
        stmt[4] = DB.datetime(now)
        stmt()
        return self._db:last_insert_rowid()
    end)
end

-- Complements the scanning task with scanning process details.
--:: integer, integer, integer? -> boolean, error?
function DB:scan_set_task(scan_id, task_id, now)
    return with_prepare(self._db, [[
        UPDATE scan SET task_id=?2, updated_at=?3 WHERE scan_id=?1
    ]], function(stmt)
        stmt[1], stmt[2], stmt[3] = scan_id, task_id, DB.datetime(now)
        return stmt() == false
    end)
end

-- Updates status of the scanning task.
--:: integer, string, integer? -> boolean, error?
function DB:scan_set_status(scan_id, status, now)
    return with_prepare(self._db, [[
        UPDATE scan SET status=?2, updated_at=?3 WHERE scan_id=?1
    ]], function(stmt)
        stmt[1], stmt[2], stmt[3] = scan_id, status, DB.datetime(now)
        return stmt() == false
    end)
end

-- Updates status of the scanning task, status=error.
--:: integer, error, integer? -> boolean, error?
function DB:scan_set_error(scan_id, err, now)
    return with_prepare(self._db, [[
        UPDATE scan SET status='error', error=?2, updated_at=?3 WHERE scan_id=?1
    ]], function(stmt)
        stmt[1], stmt[2], stmt[3] = scan_id, tostring(err), DB.datetime(now)
        return stmt() == false
    end)
end

---Save a scanning report and a corresponding link in Cuckoo of the scanning task.
---@param scan_id integer
---@param report_url string
---@param now integer
---@return boolean? # whether the request was successful or not
---@return string? #Error message if any
function DB:scan_set_report(scan_id, report, report_url, now)
    return with_prepare(self._db, [[
        UPDATE scan SET report=?2, report_url=?3, updated_at=?4 WHERE scan_id=?1
    ]], function(stmt)
        stmt[1] = scan_id
        stmt[2] = cjson.encode(report)
        stmt[3] = report_url
        stmt[4] = DB.datetime(now)
        return stmt() == false
    end)
end

local LIMITED_LENGTH = 256
local CUTTING_LENGTH = 32
local function limit_length(value)
    if type(value) == "string" and #value > LIMITED_LENGTH then
        value = string.sub(value, 1, CUTTING_LENGTH) .. "…"
    end
    return value
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
            for i, value in pairs(row) do
                row[i] = limit_length(value)
            end
            table.insert(rows, row)
        end
        return rows
    end)
end

return DB
