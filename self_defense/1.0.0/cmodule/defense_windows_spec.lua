local defense = require("defense_windows")

describe("apply", function()
    it("applies strategies and returns previous profile on success", function()
        local TEST_PROFILE = {
            strategies = { "test_strategy" },
            test_strategy = {
                param = "test",
            },
        }
        local test_strategy = {
            apply = function()
                return { param = "old" }
            end,
        }
        local strategies = { test_strategy = test_strategy }

        local old_profile = defense.apply(TEST_PROFILE, strategies)

        assert.is_table(old_profile)
        assert.same(TEST_PROFILE.strategies, old_profile.strategies)
        assert.same(test_strategy.apply(), old_profile.test_strategy)
    end)
end)
