require("engine")
local json = require("cjson")
local path = require("path")

local process = require("process")
local registry = require("registry")
local script = require("script")
local security = require("security")

local event_engine
local action_engine

local function push_event(name, data)
    local result, list = event_engine:push_event({
        name = name,
        data = data or {},
    })
    if result then
        action_engine:exec(__aid, list)
    end
end

local function error(name, ...)
    push_event("cyberok_self_defense_error", {
        name = name,
        message = string.format(...),
    })
end

local function started()
    push_event("cyberok_self_defense_started")
end

local function stopped()
    push_event("cyberok_self_defense_stopped")
end

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
        "D:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCLCSWLOCRRC;;;SU)"
    ),
    -- Set Full Access for SYSTEM exclusively, and audit access for Everyone
    security.file_descriptor(
        path.dir((__api.get_exec_path())),
        "O:SYG:SYD:PAI(A;OICI;FA;;;SY)S:PAI(AU;OICISAFA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
    ),
    -- Set Full access for SYSTEM exclusively
    security.process_descriptor("D:(A;;0x1fffff;;;SY)"),
    -- Set Full acces for SYSTEM and SERVICE exclusively
    security.registry_descriptor(
        "MACHINE\\System\\CurrentControlSet\\Services\\vxagent",
        "O:SYG:SYD:PAI(A;CI;KA;;;SU)(A;CI;KA;;;SY)"
    )
)

local function save(cmd, backup_path)
    local backup, err = io.open(backup_path, "rb")
    if not backup then
        backup, err = io.open(backup_path, "wb")
        if not backup then
            return nil, err
        end
        backup:write(json.encode(cmd:dict()))
    end
    backup:close()
    return true
end

local function load(backup_path)
    local backup, err = io.open(backup_path, "rb")
    if not backup then
        return nil, err
    end
    local cmd = script.load(json.decode(backup:read("*a")), registry, process, security)
    backup:close()
    return cmd
end

---Activates the self-defense of the current process.
---@return boolean|nil ok whether the self-defense was successfully activated
---@return string|nil error string explaining the problem, if any
local function activate()
    local undo, errors = HARDENED:run()
    if not undo then
        for _, v in ipairs(errors) do
            error("activation_error", "failed to activate self-defense: %s", v)
        end
        return nil, errors[1]
    end
    started()
    local backup_path = path.combine(path.dir((__api.get_exec_path())), "self-defense.bak")
    local ok, err_save = save(undo, backup_path)
    if not ok then
        error("backup_save_error", "failed to save backup: %s", err_save)
        return nil, err_save
    end
    return true
end

---Deactivates the self-protection of the current process.
---@return boolean|nil ok whether the self-defense was successfully deactivated
---@return string|nil error string explaining the problem, if any
local function deactivate()
    local backup_path = path.combine(path.dir((__api.get_exec_path())), "self-defense.bak")
    local undo, err = load(backup_path)
    if not undo then
        error("backup_load_error", "failed to load backup: %s", err)
        return nil, err
    end
    local _, errors = undo:run()
    if #errors > 0 then
        for _, v in ipairs(errors) do
            error("deactivation_error", "failed to deactivate self-defense: %s", v)
        end
        return nil, errors[1]
    end
    os.remove(backup_path)
    stopped()
    return true
end

local function update_config()
    local prefix_db = __gid .. "."
    local fields_schema = __config.get_fields_schema()
    local event_config = __config.get_current_event_config()
    local module_info = __config.get_module_info()

    event_engine = CEventEngine(fields_schema, event_config, module_info, prefix_db, false)
    action_engine = CActionEngine({}, false)
end

---Handles control messages.
---@param cmtype string
---@param data string
local function control(cmtype, data)
    if cmtype == "quit" and data == "module_remove" then
        return deactivate()
    elseif cmtype == "update_config" then
        update_config()
    end
    return true
end

---Module's entrypoint.
---@return string
local function run()
    update_config()
    __api.add_cbs({ control = control })
    activate()
    __api.await(-1)
    return "success"
end

return run()
