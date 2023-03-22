local Error = require "error"

describe("Error", function()
    local err = Error{name="Error", message="Message"}
    err.foo = 123

    it("should have the specified name and message", function()
        assert.same("Error", err.name)
        assert.same("Message", err.message)
    end)

    it("should be convertable to string", function()
        assert.same("Message", tostring(err))
        assert.same("Message", string.format("%s", err))
    end)

    it("should have the name of a surrounding function", function()
        local function FirstError(n)
            return Error("%s message %d", "Test", n)
        end
        local err = FirstError(10)
        assert.same("FirstError", err.name)
        assert.same("Test message 10", tostring(err))

        local foo = {}
        function foo:SecondError(n)
            local err = Error("%s message %d", "Test", n)
            return err
        end
        local err = foo:SecondError(20)
        assert.same("SecondError", err.name)
        assert.same("Test message 20", tostring(err))
    end)

    test("into/from_data", function()
        -- Error
        local data = Error.into_data(err)
        assert.same({
            type = "error",
            error = { name="Error", message="Message", foo=123 },
        }, data)
        local res = Error.from_data(data)
        assert.same(err, res)
        assert(getmetatable(err)==Error, "not Error")

        -- string
        local data = Error.into_data("Message")
        assert.same({
            type = "error",
            error = { message="Message" },
        }, data)
        local res = Error.from_data(data)
        assert.same("Message", tostring(res))
        assert(getmetatable(res)==Error, "not Error")
    end)
end)
