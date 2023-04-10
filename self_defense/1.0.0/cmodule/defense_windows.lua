require("waffi.headers.windows")
local lk32 = require("waffi.windows.kernel32")
local ffi = require("ffi")

local defense = {}

--- Gets the last error as a string.
---@return string error
local function get_last_error()
    return tostring(lk32.GetLastError())
end

ffi.cdef([[
typedef enum _PROCESS_MITIGATION_POLICY {
    ProcessDEPPolicy,
    ProcessASLRPolicy,
    ProcessDynamicCodePolicy,
    ProcessStrictHandleCheckPolicy,
    ProcessSystemCallDisablePolicy,
    ProcessMitigationOptionsMask,
    ProcessExtensionPointDisablePolicy,
    ProcessControlFlowGuardPolicy,
    ProcessSignaturePolicy,
    ProcessFontDisablePolicy,
    ProcessImageLoadPolicy,
    ProcessSystemCallFilterPolicy,
    ProcessPayloadRestrictionPolicy,
    ProcessChildProcessPolicy,
    ProcessSideChannelIsolationPolicy,
    ProcessUserShadowStackPolicy,
    ProcessRedirectionTrustPolicy,
    ProcessUserPointerAuthPolicy,
    ProcessSEHOPPolicy,
    MaxProcessMitigationPolicy
} PROCESS_MITIGATION_POLICY, *PPROCESS_MITIGATION_POLICY;

typedef struct _PROCESS_MITIGATION_DEP_POLICY {
    union {
        DWORD Flags;
        struct {
            DWORD Enable : 1;
            DWORD DisableAtlThunkEmulation : 1;
            DWORD ReservedFlags : 30;
        };
    };
    BOOLEAN Permanent;
} PROCESS_MITIGATION_DEP_POLICY, *PPROCESS_MITIGATION_DEP_POLICY;
]])

local mitigation_policies = {
    data_execution_prevention = {
        id = ffi.C.ProcessDEPPolicy,
        schema = "PROCESS_MITIGATION_DEP_POLICY",
    },
}

ffi.cdef([[
BOOL SetProcessMitigationPolicy(PROCESS_MITIGATION_POLICY MitigationPolicy,
                                PVOID lpBuffer, SIZE_T dwLength);

BOOL GetProcessMitigationPolicy(HANDLE hProcess,
                                PROCESS_MITIGATION_POLICY MitigationPolicy,
                                PVOID lpBuffer, SIZE_T dwLength);
]])

---Applies the `config` for the specified mitigation policy `name`
---and returns the previous configuration.
---@param name string name of the mitigation policy
---@param config table configuration to apply
---@return table|nil old configuration
---@return string|nil error string explaining the problem, if any
function defense.mitigation(name, config)
    local policy = mitigation_policies[name]
    local buf = ffi.new(policy.schema)
    local len = ffi.sizeof(policy.schema)
    local process = lk32.GetCurrentProcess()
    local ret = ffi.C.GetProcessMitigationPolicy(process, policy.id, buf, len)
    if not ret then
        return nil, get_last_error()
    end
    local old_config = {}
    for key, value in pairs(config) do
        old_config[key] = (buf[key] ~= 0)
        buf[key] = value
    end
    ret = ffi.C.SetProcessMitigationPolicy(policy.id, buf, len)
    if not ret then
        return nil, get_last_error()
    end
    return old_config
end

---Applies the `config` for the set of self-defense policies and returns
---the previous configuration.
---@return table|nil old configuration
---@return string|nil error string explaining the problem, if any
function defense.apply()
    return defense.mitigation("data_execution_prevention", {
        Enable = 1,
        Permanent = 1,
        DisableAtlThunkEmulation = 1,
    })
end

return defense
