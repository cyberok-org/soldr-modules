local Error = require "error"

describe("Error", function()
	local err = Error("Error", "Error message")

	it("sould be convertable to string", function()
		assert.same("Error message", tostring(err))
		assert.same("Error message", string.format("%s", err))
	end)

	it("should use the name of surrounding function", function()
		local function TestError()
			return Error(nil, "Error message")
		end

		local err = TestError("Error message")
		assert.same("TestError", err.name)
		assert.same("Error message", tostring(err))
	end)

	test("forward", function()
		local err = err:forward("AgentID")
		assert.same("AgentID", err.agent_id)
		assert.same("Error message", tostring(err))
	end)
end)
