local curl = require "libcurl"
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

--:: libcurl.CURL -> boolean, error?
function CoURL:perform(h)
    local context = {}
    self._multi:add(h)
    self._queued[tostring(h)] = context
    while not context.done do coroutine.yield() end

    self._queued[tostring(h)] = nil
    self._multi:remove(h)
    return context.ok, context.err
end

--:: () -> boolean, error?
function CoURL:resume()
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

--:: seconds? -> boolean, error?
function CoURL:wait(timeout)
    local timeout = timeout or 1e6
    local deadline = time.clock() + timeout
    return try(function()
        repeat
            local n = assert(self._multi:wait(timeout))
            assert(self:resume())
            timeout = deadline - time.clock()
        until n == 0 or timeout <= 0
        return true
    end)
end

--:: () -> boolean
function CoURL:idle()
    return next(self._queued) == nil
end

-- Create and return default CoURL instance:
return CoURL.new()
