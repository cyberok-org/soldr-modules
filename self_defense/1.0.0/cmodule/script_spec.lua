---@diagnostic disable: need-check-nil
local process = require("process")
local registry = require("registry")
local script = require("script")
local security = require("security")

local Command = script.Command

---@class TestCommand: Command
---@field private undo Command
---@field private err error
---@field public called integer
local TestCommand = {}
TestCommand.__index = TestCommand
setmetatable(TestCommand, Command)

function TestCommand:new(err, undo)
    local cmd = Command:new()
    setmetatable(cmd, self)
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
    it("is convertable to a dictionary", function()
        local test_cmd1 = TestCommand:new()
        local test_cmd2 = TestCommand:new()
        local cmd = Command:new(test_cmd1, test_cmd2)

        local dict = cmd:dict()

        assert.is_same({
            name = "script",
            subcommands = {
                { name = "script", subcommands = {} },
                { name = "script", subcommands = {} },
            },
        }, dict)
    end)
end)

describe("load", function()
    it("loads a script from a dictionary", function()
        local test_cmd = script.command(
            registry.key_value(
                registry.hkey_local_machine("SOFTWARE\\test"),
                "key",
                registry.value_bin("001111000100110110001101001100000000000000000000")
            ),
            security.process_descriptor("D:(A;;0x1fffff;;;SY)"),
            process.mitigation_policy("data_execution_prevention", {
                Enable = true,
            })
        )
        local cmd_dict = test_cmd:dict()

        local cmd = script.load(cmd_dict, registry, security, process)

        assert.is_not_nil(cmd)
        assert.are_same(cmd_dict, cmd:dict())
    end)
    it("throws an error when dict is not a table", function()
        assert.has_error(function()
            script.load(nil)
        end, "cmd_dict must be table")
    end)
    it("throws an error when dict.name is not 'script'", function()
        assert.has_error(function()
            script.load({ name = "not_script" })
        end, "cmd_dict.name must be 'script'")
    end)
end)
