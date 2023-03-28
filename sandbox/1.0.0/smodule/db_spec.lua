local DB      = require "db"
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
        it("returns info about the requested scanning task", function()
            assert(query(db_, [[
            INSERT INTO scan (scan_id, agent_id, filename, status, error, task_id, task_options, created_at, updated_at)
            VALUES
                (10, 'Agent10', 'File10', 'new',   NULL,      100, '{}',        "CreatedAt10", "UpdatedAt10"),
                (20, 'Agent20', 'File20', 'error', 'Error20', 200, '{"Two":2}', "CreatedAt20", "UpdatedAt20");
            ]]))
            assert.same({
                scan_id      = 10,
                agent_id     = "Agent10",
                filename     = "File10",
                status       = "new",
                task_id      = 100,
                task_options = {},
                created_at   = "CreatedAt10",
                updated_at   = "UpdatedAt10",
            }, assert(db:scan_get(10)))
            assert.same({
                scan_id      = 20,
                agent_id     = "Agent20",
                filename     = "File20",
                status       = "error",
                error        = "Error20",
                task_id      = 200,
                task_options = {Two=2},
                created_at   = "CreatedAt20",
                updated_at   = "UpdatedAt20",
            }, assert(db:scan_get(20)))
        end)

        test("requested scanning task not found", function()
            local scan, err = db:scan_get("UNKNOWN")
            assert.is_nil(scan)
            assert.same("not found", err)
        end)
    end)

    describe("scan_list_unfinished", function()
        test("empty result", function()
            local scans = assert(db:scan_list_unfinished())
            assert.same({}, scans)
        end)

        it("returns a list of unfinished scanning tasks", function()
            assert(query(db_, [[
            INSERT INTO scan (scan_id, agent_id, filename, status) VALUES
                (10, '', '', 'new'),
                (20, '', '', 'pending'),
                (30, '', '', 'running'),
                (40, '', '', 'reported'),
                (50, '', '', 'error');
            ]]))
            local scans = assert(db:scan_list_unfinished())
            assert.same(3, #scans)
            assert.same(10, scans[1].scan_id)
            assert.same(20, scans[2].scan_id)
            assert.same(30, scans[3].scan_id)
        end)
    end)

    describe("scan_new", function()
        it("should create a new scanning task and return id", function()
            local now = os.time()
            local now_dt = DB.datetime(now)

            local scan_id = assert(db:scan_new("Agent10", "File10", {One=1}, now))
            assert.same(1, scan_id)

            local scan_id = assert(db:scan_new("Agent20", "File20", {Two=2}, now))
            assert.same(2, scan_id)

            local rows = assert(query(db_, [[
                SELECT status, agent_id, filename, task_options, created_at, updated_at
                  FROM scan
                 ORDER BY scan_id;
            ]]))
            assert.same(2, #rows)
            assert.same({"new", "Agent10", "File10", '{"One":1}', now_dt, now_dt}, rows[1])
            assert.same({"new", "Agent20", "File20", '{"Two":2}', now_dt, now_dt}, rows[2])
        end)
    end)

    describe("scan_set_task", function()
        it("should enrich the scanning task with additional info", function()
            local scan_id = assert(db:scan_new("Agent", "filename"))
            assert(db:scan_set_task(scan_id, 100, 10))

            local scan = assert(db:scan_get(scan_id))
            assert.same(100, scan.task_id)
            assert.same(DB.datetime(10), scan.updated_at)
        end)

        test("given scanning task does not exist", function()
            assert(db:scan_set_task("MISSING", 100))
        end)
    end)

    describe("scan_set_status", function()
        it("should update status of the scanning task", function()
            local scan_id = assert(db:scan_new("Agent", "filename"))
            assert(db:scan_set_status(scan_id, "STATUS", 10))

            local scan = assert(db:scan_get(scan_id))
            assert.same("STATUS", scan.status)
            assert.same(DB.datetime(10), scan.updated_at)
        end)

        test("given scanning task does not exist", function()
            assert(db:scan_set_status("MISSING", "STATUS"))
        end)
    end)

    describe("scan_set_error", function()
        it("should update status of the scanning task", function()
            local scan_id = assert(db:scan_new("Agent", "filename"))
            assert(db:scan_set_error(scan_id, "ERROR", 10))

            local scan = assert(db:scan_get(scan_id))
            assert.same("error", scan.status)
            assert.same("ERROR", scan.error)
            assert.same(DB.datetime(10), scan.updated_at)
        end)

        test("given scanning task does not exist", function()
            assert(db:scan_set_error("MISSING", "ERROR"))
        end)
    end)

    describe("scan_set_report", function()
        it("should update report of the scanning task", function()
            local scan_id = assert(db:scan_new("Agent", "filename"))
            assert(db:scan_set_report(scan_id, {report="Report"}, "ReportURL", 10))

            local scan = assert(db:scan_get(scan_id))
            assert.same('{"report":"Report"}', scan.report)
            assert.same("ReportURL", scan.report_url)
            assert.same(DB.datetime(10), scan.updated_at)
        end)

        test("given scanning task does not exist", function()
            assert(db:scan_set_report("MISSING", {}, ""))
        end)
    end)

    test("select", function()
        assert(query(db_, [[
            INSERT INTO scan (scan_id, agent_id, filename) VALUES
                (10, 'Agent10', 'File10'),
                (20, 'Agent20', 'File20');
        ]]))
        local rows = assert(db:select[[
            SELECT 10 * scan_id, agent_id || ':' || filename AS Foo FROM scan;
        ]])
        assert.same(3, #rows)
        assert.same({"10 * scan_id", "Foo"}, rows[1])
        assert.same({100, "Agent10:File10"}, rows[2])
        assert.same({200, "Agent20:File20"}, rows[3])
    end)
end)
