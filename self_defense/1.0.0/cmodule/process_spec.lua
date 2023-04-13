local process = require("process")

describe("MitigationPolicy", function()
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
end)
