local Error = require "error"

describe("Error", function()
    local err = Error{name="Error", message="Message"}

    it("should have the specified name and message", function()
        assert.same("Error", err.name)
        assert.same("Message", err.message)
    end)

    it("should be convertable to string", function()
        assert.same("Message", tostring(err))
        assert.same("Message", string.format("%s", err))
    end)

    it("should have the name of a surrounding function", function()
        local function TestError()
            return Error("%s message %d", "Test", 123)
        end
        local err = TestError("Error message")
        assert.same("TestError", err.name)
        assert.same("Test message 123", tostring(err))
    end)
end)
