local script = require("script")
local Command = script.Command

---@class TestCommand: Command
---@field private undo Command
---@field private err error
---@field public called integer
local TestCommand = {}
function TestCommand:new(err, undo)
    local cmd = Command:new()
    setmetatable(cmd, self)
    self.__index = self
    cmd.err = err
    if err then
        cmd.undo = nil
    else
        cmd.undo = undo or Command:new()
    end
    cmd.called = 0
    return cmd
end

function TestCommand:run()
    self.called = self.called + 1
    return self.undo, self.err
end

describe("Command", function()
    it("executes a single subcommand", function()
        local test_cmd = TestCommand:new()
        local cmd = Command:new(test_cmd)

        local undo, err = cmd:run()

        assert.is_not_nil(undo)
        assert.is_nil(err)
        assert.equal(1, test_cmd.called)
    end)
    it("executes multiple subcommands", function()
        local test_cmd1 = TestCommand:new()
        local test_cmd2 = TestCommand:new()
        local cmd = Command:new(test_cmd1, test_cmd2)

        local undo, err = cmd:run()

        assert.is_not_nil(undo)
        assert.is_nil(err)
        assert.equal(1, test_cmd1.called)
        assert.equal(1, test_cmd2.called)
    end)
    it("returns an error when a subcommand fails", function()
        local test_cmd1 = TestCommand:new()
        local test_cmd2 = TestCommand:new()
        local failing_command = TestCommand:new("failing_command failed")
        local cmd = Command:new(test_cmd1, failing_command, test_cmd2)

        local undo, err = cmd:run()

        assert.is_nil(undo)
        assert.is_not_nil(err)
        assert.is_same("failing_command failed", err)
        assert.equal(1, test_cmd1.called)
        assert.equal(0, test_cmd2.called)
    end)
    it("rolls back successfully executed subcommands on failure", function()
        local test_cmd1_undo = mock(TestCommand:new())
        local test_cmd1 = mock(TestCommand:new(nil, test_cmd1_undo))
        local failing_command = mock(TestCommand:new("failing_command failed"))
        local cmd = Command:new(test_cmd1, failing_command)

        local undo, err = cmd:run()

        assert.is_nil(undo)
        assert.is_not_nil(err)
        assert.equal(1, test_cmd1_undo.called)
    end)
end)
