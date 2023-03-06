local go = require "go"

local function contains(str, sub)
    return string.find(str, sub, 1, true) ~= nil
end

describe("go", function()
    it("should concurrently run coroutines", function()
        local output = ""
        go(function()
            output = output.."a"; coroutine.yield()
            output = output.."b"; coroutine.yield()
        end)
        go(function()
            output = output.."A"; coroutine.yield()
            output = output.."B"; coroutine.yield()
            output = output.."C"; coroutine.yield()
        end)
        assert(go:wait())
        assert.equal("aabbc", output:lower())
    end)

    test("and error", function()
        go(function() error("FAILED") end)
        local ok, err = go:wait()
        assert(not ok)
        assert(contains(err, "FAILED"),
            string.format("unexpected error message: %s", err))
    end)
end)
