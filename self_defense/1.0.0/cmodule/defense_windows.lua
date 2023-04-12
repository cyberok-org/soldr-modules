local defense = {}

---Applies the `config` for the set of self-defense policies and returns
---the previous configuration.
---@return table|nil old configuration
---@return string|nil error string explaining the problem, if any
function defense.apply(profile, strategies)
    local old_profile = {}
    for _, strategy in ipairs(strategies) do
        if profile[strategy.name] then
            local old_config, err = strategy.apply(profile[strategy.name])
            if not old_config then
                -- TODO: rollback applied strategies and return error
                return nil, err
            end
            old_profile[strategy.name] = old_config
        end
    end
    return old_profile
end

return defense
