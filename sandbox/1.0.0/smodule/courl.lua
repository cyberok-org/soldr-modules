local curl = require "libcurl"
local ffi  = require "ffi"
local time = require "time"
local try  = require "try"

local CoURL = {}
CoURL.__index = CoURL

function CoURL.new()
    local self = {}
    self._multi = curl.multi()
    self._queued = {}
    return setmetatable(self, CoURL)
end

--:: libcurl.CURL -> boolean, err::string?
function CoURL:perform(h)
    local context = {}
    self._multi:add(h)
    self._queued[tostring(h)] = context
    while not context.done do coroutine.yield() end

    self._queued[tostring(h)] = nil
    self._multi:remove(h)
    return context.ok, context.err
end

--:: seconds? -> boolean, err::string?
function CoURL:resume(timeout)
    local timeout = timeout or 0
    local deadline = time.clock() + timeout
    return try(function()
        repeat
            local n = assert(self._multi:wait(timeout))
            assert(self:_resume())
            timeout = deadline - time.clock()
        until n == 0 or timeout <= 0
        return true
    end)
end

--:: () -> boolean, err::string?
function CoURL:_resume()
    local ok, err = self._multi:perform()
    if not ok then
        return false, err end
    repeat
        local m = self._multi:info_read(); if m then
            local context = self._queued[tostring(m.easy_handle)]
            context.done = true
            context.ok  = m.data.result == 0
            context.err = curl.easy.strerror(m.data.result)
        end
    until not m
    return true
end

--:: () -> boolean
function CoURL:idle()
    return next(self._queued) == nil
end

--:: HandleOpt :: string | {libcurl.CURLOPT_*} | (libcurl.CURL -> ())
--:: HandleOpt -> libcurl.CURL
local function make_handle(opt)
    if type(opt) == "function" then
        local h = curl.easy()
        opt(h)
        return h
    end
    return curl.easy(opt)
end

--:: WithHandle :: libcurl.CURL -> Result...
--:: HandleOpt, WithHandle -> Result...
--:: HandleOpt, WithHandle -> (nil, err::string)
local function with_handle(opt, func)
    local h = make_handle(opt)
    local result = {try(func, h)}
    h:close()
    return unpack(result)
end

--:: WithFile :: io.file -> Result...
--:: string, string, WithFile -> Result...
--:: string, string, WithFile -> (nil, err::string)
local function with_open(path, mode, func)
    return try(function()
        local file = assert(io.open(path, mode))
        local result = {try(func, file)}
        file:close()
        return unpack(result)
    end)
end

local function readfunction_cb(file)
    return function(buf, size, n)
        local bytes = file:read(tonumber(size * n));
        if not bytes then return 0 end
        ffi.copy(buf, bytes, #bytes)
        return #bytes
    end
end

--:: HandleOpt -> response_code::int, body::string
--:: HandleOpt -> nil, err::string
function CoURL:GET(opt)
    local body = ""
    return with_handle(opt, function(h)
        h:set("HTTPGET", true)
        h:set("WRITEFUNCTION", function(buf, size)
            body = body .. ffi.string(buf, size)
            return size
        end)
        assert(self:perform(h))
        return h:info("RESPONSE_CODE"), body
    end)
end

function CoURL:read_and_POST(opt, path)
    return with_handle(opt, function(h)
        return with_open(path, "r", function(file)
            h:set("POST", true)
            h:set("READFUNCTION", readfunction_cb(file))
            h:set("WRITEFUNCTION", function(buf, size) return size end)
            assert(self:perform(h))
            return h:info("RESPONSE_CODE")
        end)
    end)
end

-- Create and return default CoURL instance:
return CoURL.new()
