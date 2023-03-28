local cjson  = require "cjson"
local courl  = require "courl"
local Cuckoo = require "cuckoo"
local go     = require "go"

local function wait()
    repeat
        assert(go:resume())
        assert(courl:wait())
    until go:idle() and courl:idle()
end

describe("Cuckoo:create_task #network", function()
    it("returns error on unavailable server", function()
        local cuckoo = Cuckoo:new("http://cuckoo.invalid", "AWFKI9LcPk_Y5i0pcA6XKA")
        local ok, err
        go(function()
            ok, err = cuckoo:create_task("/usr/bin/bash", "bash", {})
        end)
        wait()
        assert.is_nil(ok)
        assert.equal("Couldn't resolve host name", err)
    end)

    it("returns task id in pending state on success #cuckoo", function()
        local cuckoo = Cuckoo:new("http://192.168.228.236:8090", "AWFKI9LcPk_Y5i0pcA6XKA")
        local id
        go(function()
            id = assert(cuckoo:create_task("/usr/bin/bash", "/usr/bin:with/bash", {
                package  = "exe",
                options  = "free=yes,procmemdump=no,human=no",
                priority = 3,
                platform = "linux",
                machine  = "cuckoo1",
                timeout  = 10,
            }))
        end)
        wait()

        assert.are.same("number", type(id))

        local status
        go(function()
            status = assert(cuckoo:task_status(id))
        end)
        wait()
        assert.are.equal("pending", status)
    end)
end)

describe("Cuckoo:task_report_url", function()
    it("returns url to report for task with the specified id", function()
        local cuckoo = Cuckoo:new("http://cuckoo.com:8090", "AWFKI9LcPk_Y5i0pcA6XKA")

        local report_url = cuckoo:task_report_url(100)

        assert.are.equal("http://cuckoo.com/analysis/100/summary", report_url)
    end)
end)

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local data = assert(f:read("a"))
    f:close()
    return data
end

describe("Cuckoo.verdict", function()
    it("returns a verdict built from a scanning report", function()
        local report = cjson.decode(read_file("testdata/report.json"))
        local verdict = cjson.decode(read_file("testdata/verdict.json"))
        assert.same(verdict, Cuckoo.verdict(report))
    end)
end)
