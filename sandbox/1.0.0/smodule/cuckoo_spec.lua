local courl  = require "courl"
local go     = require "go"
local Cuckoo = require "cuckoo"

local function wait()
    repeat
        assert(go:resume())
        assert(courl:wait())
    until go:idle() and courl:idle()
end

describe("cuckoo:create_task #network", function()
    it("returns error on unavailable server", function()
        local cuckoo = Cuckoo:new("http://cuckoo.invalid", "key")
        local ok, err = true, ""
        go(function()
            ok, err = cuckoo:create_task("/usr/bin/bash")
        end)
        wait()
        assert.is_nil(ok)
        assert.equal("Couldn't resolve host name", err)
    end)

    it("returns task id on success #cuckoo", function()
        local cuckoo = Cuckoo:new(
            "http://192.168.228.236:8090",
            "AWFKI9LcPk_Y5i0pcA6XKA"
        )
        local id, err = 0, ""
        go(function()
            id, err = cuckoo:create_task("/usr/bin/bash", "/usr/bin/bash")
        end)
        wait()
        assert.is_nil(err)
        assert.are.not_equal(0, id)
    end)
end)
