local exploit_mitigation = require("exploit_mitigation")

local defense = {}

defense.HARDENED_PROFILE = {
    strategies = { "exploit_mitigation" },
    exploit_mitigation = {
        data_execution_prevention = {
            Enable = true,
            Permanent = true,
            DisableAtlThunkEmulation = true,
        },
        address_space_layout_randomization = {
            EnableBottomUpRandomization = true,
            EnableForceRelocateImages = true,
            EnableHighEntropy = true,
            DisallowStrippedImages = true,
        },
        dynamic_code = {
            ProhibitDynamicCode = false, -- causes the lua to crash
            AllowThreadOptOut = false,
            AllowRemoteDowngrade = false,
            AuditProhibitDynamicCode = true,
        },
        strict_handle_check = {
            RaiseExceptionOnInvalidHandleReference = true,
            HandleExceptionsPermanentlyEnabled = true,
        },
        system_call_disable = {
            DisallowWin32kSystemCalls = false,
            AuditDisallowWin32kSystemCalls = false,
        },
        extension_point_disable = {
            DisableExtensionPoints = true,
        },
        control_flow_guard = {
            EnableControlFlowGuard = false,
            EnableExportSuppression = false,
            StrictMode = false,
            EnableXfg = false,
            EnableXfgAuditMode = false,
        },
        binary_signature = {
            MicrosoftSignedOnly = false,
            StoreSignedOnly = false,
            MitigationOptIn = false,
            AuditMicrosoftSignedOnly = false,
            AuditStoreSignedOnly = false,
        },
        font_disable = {
            DisableNonSystemFonts = true,
            AuditNonSystemFontLoading = true,
        },
        image_load = {
            NoRemoteImages = true,
            NoLowMandatoryLabelImages = true,
            PreferSystem32Images = true,
            AuditNoRemoteImages = true,
            AuditNoLowMandatoryLabelImages = true,
        },
        redirection_trust = {
            EnforceRedirectionTrust = true,
            AuditRedirectionTrust = true,
        },
        side_channel_isolation = {
            SmtBranchTargetIsolation = true,
            IsolateSecurityDomain = true,
            DisablePageCombine = true,
            SpeculativeStoreBypassDisable = true,
            RestrictCoreSharing = true,
        },
        user_shadow_stack = {
            EnableUserShadowStack = true,
            AuditUserShadowStack = true,
            SetContextIpValidation = true,
            AuditSetContextIpValidation = true,
            EnableUserShadowStackStrictMode = true,
            BlockNonCetBinaries = true,
            BlockNonCetBinariesNonEhcont = true,
            CetDynamicApisOutOfProcOnly = true,
            SetContextIpValidationRelaxedMode = false,
        },
    },
}

local strategies = {
    exploit_mitigation = exploit_mitigation,
}

---Applies the `config` for the set of self-defense policies and returns
---the previous configuration.
---@return table|nil old configuration
---@return string|nil error string explaining the problem, if any
function defense.apply(profile)
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
