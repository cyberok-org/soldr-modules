local defense = require("defense_windows")

describe("apply", function()
    it("applies self-defense config and returns the previous one ", function()
        local old_profile = defense.apply(defense.HARDENED_PROFILE)

        assert.is_table(old_profile)
        assert.same(defense.HARDENED_PROFILE.strategies, old_profile.strategies)

        local exploit_mitigation = defense.HARDENED_PROFILE.exploit_mitigation
        local old_exploit_mitigation = old_profile.exploit_mitigation
        for policy_name, config in pairs(exploit_mitigation) do
            local old_config = old_exploit_mitigation[policy_name]
            assert.is_table(old_config)
            for key, value in pairs(config) do
                assert.equal(type(value), type(old_config[key]))
            end
        end
    end)
end)
