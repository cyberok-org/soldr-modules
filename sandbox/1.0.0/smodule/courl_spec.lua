local courl = require "courl"
local go    = require "go"

local API = "https://httpbingo.org"
-- local API = "http://127.0.0.173"

local function wait()
    repeat
        assert(go:resume())
        assert(courl:resume(1))
    until go:idle() and courl:idle()
end

describe("CoURL #network", function()
    test("GET", function()
        go(function()
            code, body = assert(courl:GET(API.."/base64/encode/TEST")) end)
        wait()
        assert.equal(200, code)
        assert.equal("VEVTVA==", body)
    end)

    test("bad URL", function()
        go(function()
            ok, err = courl:GET("unknown://domain") end)
        wait()
        assert(not ok)
        assert.equal("Unsupported protocol", err)
    end)

    test("connection error", function()
        go(function()
            ok, err = courl:GET("http://0.0.0.0") end)
        wait()
        assert(not ok)
        assert.equal("Couldn't connect to server", err)
    end)
end)
