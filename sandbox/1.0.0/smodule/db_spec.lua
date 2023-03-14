local DB      = require "db"
local sqlite3 = require "lsqlite3"
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
        for row in stmt:rows(sql) do
            table.insert(rows, row) end
        return rows
    end)
end

describe("DB", function()
    local db, db_filename, db_
    setup(function()
        db_filename = os.tmpname()
        db = assert(DB.open(db_filename))
        db_ = assert(sqlite3.open(db_filename))
    end)
    teardown(function()
        db_:close()
        assert(db:close())
        assert(os.remove(db_filename))
    end)
    before_each(function()
        assert(query(db_, "DELETE FROM scan;"))
    end)

    describe("migration", function()
        test("on repeating opening", function()
            assert(DB.open(db_filename))
        end)
    end)

    test("datetime", function()
        local now = os.time()
        local rows = assert(query(db_, "SELECT datetime(?1,'unixepoch');", now))
        assert.equal(rows[1][1], DB.datetime(now))
    end)

    describe("scan_get", function()
        it("should return info about the requested scanning task", function()
            assert(query(db_, [[
            INSERT INTO scan (scan_id, agent_id, path, status, cuckoo_task_id, created_at, updated_at)
            VALUES
                (10, 'Agent10', 'Path10', 'new',        'Task10', "CreatedAt10", "UpdatedAt10"),
                (20, 'Agent20', 'Path20', 'processing', 'Task20', "CreatedAt20", "UpdatedAt20");
            ]]))
            assert.same({
                scan_id        = "10",
                agent_id       = "Agent10",
                path           = "Path10",
                status         = "new",
                cuckoo_task_id = "Task10",
                created_at     = "CreatedAt10",
                updated_at     = "UpdatedAt10",
            }, assert(db:scan_get("10")))
            assert.same({
                scan_id        = "20",
                agent_id       = "Agent20",
                path           = "Path20",
                status         = "processing",
                cuckoo_task_id = "Task20",
                created_at     = "CreatedAt20",
                updated_at     = "UpdatedAt20",
            }, assert(db:scan_get("20")))
        end)

        test("requested scanning task not found", function()
            local row, err = db:scan_get("UNKNOWN")
            assert.is_nil(row)
            assert.same("not found", err)
        end)
    end)

    describe("scan_new", function()
        it("should create a new scanning task and return id", function()
            local now = os.time()
            local now_dt = DB.datetime(now)

            local scan_id = assert(db:scan_new("Agent10", "Path10", now))
            assert.same("1", scan_id)

            local scan_id = assert(db:scan_new("Agent20", "Path20", now))
            assert.same("2", scan_id)

            local rows = assert(query(db_, [[
                SELECT status, agent_id, path, created_at, updated_at
                  FROM scan
                 ORDER BY scan_id;
            ]]))
            assert.same(2, #rows)
            assert.same({"new", "Agent10", "Path10", now_dt, now_dt}, rows[1])
            assert.same({"new", "Agent20", "Path20", now_dt, now_dt}, rows[2])
        end)
    end)

    describe("scan_set_processing", function()
        it("should udpate status of the scanning task", function()
            local scan_id = assert(db:scan_new("Agent", "Path"))
            assert(db:scan_set_processing(scan_id, "TaskID", 10))

            local task = assert(db:scan_get(scan_id))
            assert.same("processing", task.status)
            assert.same("TaskID", task.cuckoo_task_id)
            assert.same(DB.datetime(10), task.updated_at)
        end)

        test("given scanning task does not exist", function()
            assert(db:scan_set_processing("MISSING", "TaskID"))
        end)
    end)
end)
