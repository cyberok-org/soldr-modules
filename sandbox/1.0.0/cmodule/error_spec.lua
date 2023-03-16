local Error = require "error"

describe("Error", function()
	local err = Error.new("Error", "Error message")

	it("sould be convertable to string", function()
		assert.same("Error message", tostring(err))
		assert.same("Error message", string.format("%s", err))
	end)

	test("new_this", function()
		local function TestError()
			return Error.new_this("Error message")
		end

		local err = TestError("Error message")
		assert.same("TestError", err.code)
		assert.same("Error message", tostring(err))
	end)

	test("by_agent", function()
		local err = err:by_agent("AgentID")
		assert.same("AgentID", err.agent_id)
		assert.same("Error message", tostring(err))
	end)
end)
