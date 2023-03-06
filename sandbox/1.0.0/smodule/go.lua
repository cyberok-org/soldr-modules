local time = require "time"

local Go = {}
Go.__index = Go

--:: () -> Go
function Go.new()
    local self = {coroutines={}}
    return setmetatable(self, Go)
end

--:: (->) -> ()
function Go:__call(func)
    local co = coroutine.create(func)
    self.coroutines[co] = {}
end

--:: () -> boolean, err::string?
function Go:resume()
    for co in pairs(self.coroutines) do
        local ok, err = coroutine.resume(co)
        if coroutine.status(co) == "dead" then
            self.coroutines[co] = nil end
        if not ok then
            return false, err end
    end
    return true
end

--:: () -> boolean
function Go:idle()
    return next(self.coroutines) == nil
end

--:: () -> boolean, err::string?
function Go:wait()
    while not self:idle() do
        local ok, err = self:resume(); if not ok then
            return ok, err end
        if coroutine.isyieldable() then coroutine.yield() end
    end
    return true
end

function Go.sleep(seconds)
    local deadline = time.clock() + seconds
    repeat coroutine.yield() until time.clock() >= deadline
end

-- Create and return default Go instance:
return Go.new()
