---@diagnostic disable: param-type-mismatch
local process = require("process")

describe("mitigation_policy", function()
    it("returns a valid MitigationPolicy object", function()
        local cmd = process.mitigation_policy("data_execution_prevention", {
            Enable = true,
        })

        assert.is_not_nil(cmd)
        ---@diagnostic disable-next-line: invisible
        assert.are.equal("data_execution_prevention", cmd.name)
    end)
    it("throws an error for invalid policy names", function()
        assert.has_error(function()
            process.mitigation_policy("invalid_policy", { Enable = true })
        end, "wrong policy name: invalid_policy")
    end)
    it("throws an error for invalid params", function()
        assert.has_error(function()
            process.mitigation_policy(
                "data_execution_prevention",
                ---@diagnostic disable-next-line: param-type-mismatch
                "invalid_params"
            )
        end, "params must be a table")
    end)
    it("runs the mitigation policy successfully", function()
        local cmd = process.mitigation_policy("data_execution_prevention", {
            Enable = true,
        })

        local undo, err = cmd:run()
        assert.is_not_nil(undo)
        assert.is_nil(err)
    end)
    it("is convertable to dict", function()
        local cmd = process.mitigation_policy("data_execution_prevention", {
            Enable = true,
        })

        local dict = cmd:dict()

        assert.are_same({
            name = "process",
            policy = "data_execution_prevention",
            params = { Enable = true },
        }, dict)
    end)
end)

describe("load", function()
    it("throws error if cmd_dict is not a table", function()
        assert.has_error(function()
            process.load("not a table")
        end, "cmd_dict must be a table")
    end)
    it("throws error if cmd_dict is not process command", function()
        assert.has_error(function()
            process.load({ name = "not a process" })
        end, "cmd_dict.name must be 'process'")
    end)
    it("loads a process command from dict", function()
        local cmd_dict = {
            name = "process",
            policy = "data_execution_prevention",
            params = { Enable = true },
        }

        local cmd = process.load(cmd_dict)

        assert.is_not_nil(cmd)
        assert.are_same(cmd_dict, cmd:dict())
    end)
end)
