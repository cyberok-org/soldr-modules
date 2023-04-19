local path = require("path")

local process = require("process")
local registry = require("registry")
local script = require("script")
local security = require("security")

local function execution_options(filepath)
    return string.format(
        "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\%s",
        path.file(filepath)
    )
end

local HARDENED = script.command(
    process.mitigation_policy("data_execution_prevention", {
        Enable = true,
        Permanent = true,
        DisableAtlThunkEmulation = true,
    }),
    process.mitigation_policy("address_space_layout_randomization", {
        EnableBottomUpRandomization = true,
        EnableForceRelocateImages = true,
        EnableHighEntropy = true,
        DisallowStrippedImages = true,
    }),
    process.mitigation_policy("dynamic_code", {
        ProhibitDynamicCode = false, -- causes the lua to crash
        AllowThreadOptOut = false,
        AllowRemoteDowngrade = false,
        AuditProhibitDynamicCode = true,
    }),
    process.mitigation_policy("strict_handle_check", {
        RaiseExceptionOnInvalidHandleReference = true,
        HandleExceptionsPermanentlyEnabled = true,
    }),
    process.mitigation_policy("system_call_disable", {
        DisallowWin32kSystemCalls = false,
        AuditDisallowWin32kSystemCalls = false,
    }),
    process.mitigation_policy("extension_point_disable", {
        DisableExtensionPoints = true,
    }),
    process.mitigation_policy("control_flow_guard", {
        EnableControlFlowGuard = false,
        EnableExportSuppression = false,
        StrictMode = false,
        EnableXfg = false,
        EnableXfgAuditMode = false,
    }),
    process.mitigation_policy("binary_signature", {
        MicrosoftSignedOnly = false,
        StoreSignedOnly = false,
        MitigationOptIn = false,
        AuditMicrosoftSignedOnly = false,
        AuditStoreSignedOnly = false,
    }),
    process.mitigation_policy("font_disable", {
        DisableNonSystemFonts = true,
        AuditNonSystemFontLoading = true,
    }),
    process.mitigation_policy("image_load", {
        NoRemoteImages = true,
        NoLowMandatoryLabelImages = true,
        PreferSystem32Images = true,
        AuditNoRemoteImages = true,
        AuditNoLowMandatoryLabelImages = true,
    }),
    process.mitigation_policy("redirection_trust", {
        EnforceRedirectionTrust = true,
        AuditRedirectionTrust = true,
    }),
    process.mitigation_policy("side_channel_isolation", {
        SmtBranchTargetIsolation = true,
        IsolateSecurityDomain = true,
        DisablePageCombine = true,
        SpeculativeStoreBypassDisable = true,
        RestrictCoreSharing = true,
    }),
    process.mitigation_policy("user_shadow_stack", {
        EnableUserShadowStack = true,
        AuditUserShadowStack = true,
        SetContextIpValidation = true,
        AuditSetContextIpValidation = true,
        EnableUserShadowStackStrictMode = true,
        BlockNonCetBinaries = true,
        BlockNonCetBinariesNonEhcont = true,
        CetDynamicApisOutOfProcOnly = true,
        SetContextIpValidationRelaxedMode = false,
    }),
    registry.key_value(
        registry.hkey_local_machine(execution_options(__api.get_exec_path())),
        "MitigationOptions",
        registry.value_bin("001111000100110110001101001100000000000000000000")
    ),
    -- Set Full Access for SYSTEM, and Read access for SERVICE users for the vxagent service
    security.service_descriptor(
        "vxagent",
        "D:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCLCSWLOCRRC;;;SU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
    )
)

---Activates the self-defense of the current process.
---@return boolean|nil ok whether the self-defense was successfully activated
---@return string|nil error string explaining the problem, if any
local function activate()
    local undo, err = HARDENED:run()
    if not undo then
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
