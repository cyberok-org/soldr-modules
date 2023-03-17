local cjson = require "cjson"
local courl = require "courl"
local curl  = require "libcurl"
local ffi   = require "ffi"
local go    = require "go"
local try   = require "try"

local API = "https://httpbingo.org"
-- local API = "http://127.0.0.173"

local function with_handle(func)
    local h = curl.easy()
    local result = table.pack(try(func, h))
    h:close()
    return table.unpack(result)
end

local function request(url, setup)
    local body = ""
    return with_handle(function(h)
        h:set("URL", url)
        h:set("WRITEFUNCTION", function(buf, size)
            body = body .. ffi.string(buf, size)
            return size
        end)
        if setup then setup(h) end
        assert(courl:perform(h))
        return h:info("RESPONSE_CODE"), body
    end)
end

local function wait()
    repeat
        assert(go:resume())
        assert(courl:wait())
    until go:idle() and courl:idle()
end

describe("CoURL #network", function()
    test("GET", function()
        local code, body
        go(function()
            code, body = assert(request(API.."/base64/encode/TEST")) end)
        wait()
        assert.equal(200, code)
        assert.equal("VEVTVA==", body)
    end)

    test("unsuccessful status code", function()
        local code
        go(function()
            code = assert(request(API.."/status/500")) end)
        wait()
        assert.equal(500, code)
    end)

    test("bad curl easy options", function()
        local ok, err
        go(function()
            ok, err = request("unknown://domain") end)
        wait()
        assert(not ok)
        assert.equal("Unsupported protocol", tostring(err))
    end)

    test("connection error", function()
        local ok, err
        go(function()
            ok, err = request("http://0.0.0.0") end)
        wait()
        assert(not ok)
        assert.equal("Couldn't connect to server", tostring(err))
    end)

    test("POST multipart/form-data", function()
        local code, body
        go(function()
            code, body = assert(request(API.."/post", function(h)
                local mime = h:mime()
                local str = mime:part()
                str:name("String")
                str:data("STRING")
                h:set("MIMEPOST", mime)
            end))
        end)
        wait()
        assert.equal(200, code)
        assert.equal("STRING", cjson.decode(body).form.String[1])
    end)
end)
