local defense = {}

---Applies the `config` for the set of self-defense policies and returns
---the previous configuration.
---@return table|nil old configuration
---@return string|nil error string explaining the problem, if any
function defense.apply(profile, strategies)
    local old_profile = { strategies = {} }
    for _, strategy_name in ipairs(profile.strategies) do
        local strategy = strategies[strategy_name]
        assert(strategy, string.format("unknown strategy %s", strategy_name))

        local old_config, err = strategy.apply(profile[strategy_name])
        if not old_config then
            -- TODO: rollback applied strategies and return error
            return nil, err
        end
        table.insert(old_profile.strategies, strategy_name)
        old_profile[strategy_name] = old_config
    end
    return old_profile
end

return defense
