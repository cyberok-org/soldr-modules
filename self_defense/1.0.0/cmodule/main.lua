local defense = require("defense_windows")
local exploit_mitigation = require("exploit_mitigation")

local HARDENED_PROFILE = {
    exploit_mitigation = {
        process = {
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
        executables = {
            {
                name = __api.get_exec_path(),
                flags = 0,
            },
        },
    },
}

---Activates the self-defense of the current process.
---@return boolean|nil ok whether the self-defense was successfully activated
---@return string|nil error string explaining the problem, if any
local function activate()
    local old_profile, err = defense.apply(HARDENED_PROFILE, {
        exploit_mitigation,
    })
    if not old_profile then
        __log.errorf("failed to activate self-defense: %s", err)
        return nil, err
    end
    -- TODO: store old profile if it wasn't stored yet
    return true
end

---Deactivates the self-protection of the current process.
---@return boolean|nil ok whether the self-defense was successfully deactivated
---@return string|nil error string explaining the problem, if any
local function deactivate()
    -- TODO: restore old profile
    return true
end

---Handles control messages.
---@param cmtype string
---@param data string
local function control(cmtype, data)
    if cmtype == "quit" and data == "module_remove" then
        deactivate()
    end
    return true
end

---Module's entrypoint.
---@return string
local function run()
    __api.add_cbs({ control = control })
    activate()
    __api.await(-1)
    return "success"
end

return run()
