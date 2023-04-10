local defense = require("defense_windows")

describe("mitigation", function()
    it("applies DEP policy config and returns the previous one", function()
        local dep = defense.mitigation("data_execution_prevention", {
            Enable = true,
            Permanent = true,
            DisableAtlThunkEmulation = true,
        })
        assert.is_table(dep)
        assert.is_boolean(dep.Enable)
        assert.is_boolean(dep.Permanent)
        assert.is_boolean(dep.DisableAtlThunkEmulation)
    end)
end)

describe("apply", function()
    it("applies self-defense config and returns the previous one ", function()
        local old = defense.apply()
        assert.is_table(old)
        assert.is_not_nil(old["Enable"])
        assert.is_not_nil(old["Permanent"])
        assert.is_not_nil(old["DisableAtlThunkEmulation"])
    end)
end)
