local Error = require "error"

describe("Error", function()
	local err = Error("Error", "%s message %d", "Test", 10)

	it("should have the specified name", function()
		assert.same("Error", err.name)
	end)

	it("sould be convertable to string", function()
		assert.same("Test message 10", tostring(err))
		assert.same("Test message 10", string.format("%s", err))
	end)

	it("should use the name of surrounding function", function()
		local function TestError()
			return Error(nil, "Error message")
		end

		local err = TestError("Error message")
		assert.same("TestError", err.name)
		assert.same("Error message", tostring(err))
	end)
end)
