local defense = require("defense_windows")

describe("apply", function()
    it("applies strategies and returns previous profile on success", function()
        local TEST_PROFILE = {
            test_strategy = {
                param = "test",
            },
        }
        local test_strategy = {
            name = "test_strategy",
            apply = function()
                return { param = "old" }
            end,
        }

        local old_profile = defense.apply(TEST_PROFILE, { test_strategy })

        assert.is_table(old_profile)
        assert.same(test_strategy.apply(), old_profile.test_strategy)
    end)
end)
