require("waffi.headers.windows")
local lk32 = require("waffi.windows.kernel32")
local ffi = require("ffi")
local script = require("script")

local process = {}

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

typedef struct _PROCESS_MITIGATION_ASLR_POLICY {
    union {
        DWORD Flags;
        struct {
            DWORD EnableBottomUpRandomization : 1;
            DWORD EnableForceRelocateImages : 1;
            DWORD EnableHighEntropy : 1;
            DWORD DisallowStrippedImages : 1;
            DWORD ReservedFlags : 28;
        };
    };
} PROCESS_MITIGATION_ASLR_POLICY, *PPROCESS_MITIGATION_ASLR_POLICY;

typedef struct _PROCESS_MITIGATION_DYNAMIC_CODE_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD ProhibitDynamicCode : 1;
      DWORD AllowThreadOptOut : 1;
      DWORD AllowRemoteDowngrade : 1;
      DWORD AuditProhibitDynamicCode : 1;
      DWORD ReservedFlags : 28;
    };
  };
} PROCESS_MITIGATION_DYNAMIC_CODE_POLICY, *PPROCESS_MITIGATION_DYNAMIC_CODE_POLICY;

typedef struct _PROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD RaiseExceptionOnInvalidHandleReference : 1;
      DWORD HandleExceptionsPermanentlyEnabled : 1;
      DWORD ReservedFlags : 30;
    };
  };
} PROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY, *PPROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY;

typedef struct _PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD DisallowWin32kSystemCalls : 1;
      DWORD AuditDisallowWin32kSystemCalls : 1;
      DWORD ReservedFlags : 30;
    };
  };
} PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY, *PPROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY;

typedef struct _PROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD DisableExtensionPoints : 1;
      DWORD ReservedFlags : 31;
    };
  };
} PROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY, *PPROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY;

typedef struct _PROCESS_MITIGATION_CONTROL_FLOW_GUARD_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD EnableControlFlowGuard : 1;
      DWORD EnableExportSuppression : 1;
      DWORD StrictMode : 1;
      DWORD EnableXfg : 1;
      DWORD EnableXfgAuditMode : 1;
      DWORD ReservedFlags : 27;
    };
  };
} PROCESS_MITIGATION_CONTROL_FLOW_GUARD_POLICY, *PPROCESS_MITIGATION_CONTROL_FLOW_GUARD_POLICY;

typedef struct _PROCESS_MITIGATION_BINARY_SIGNATURE_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD MicrosoftSignedOnly : 1;
      DWORD StoreSignedOnly : 1;
      DWORD MitigationOptIn : 1;
      DWORD AuditMicrosoftSignedOnly : 1;
      DWORD AuditStoreSignedOnly : 1;
      DWORD ReservedFlags : 27;
    };
  };
} PROCESS_MITIGATION_BINARY_SIGNATURE_POLICY, *PPROCESS_MITIGATION_BINARY_SIGNATURE_POLICY;

typedef struct _PROCESS_MITIGATION_FONT_DISABLE_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD DisableNonSystemFonts : 1;
      DWORD AuditNonSystemFontLoading : 1;
      DWORD ReservedFlags : 30;
    };
  };
} PROCESS_MITIGATION_FONT_DISABLE_POLICY, *PPROCESS_MITIGATION_FONT_DISABLE_POLICY;

typedef struct _PROCESS_MITIGATION_IMAGE_LOAD_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD NoRemoteImages : 1;
      DWORD NoLowMandatoryLabelImages : 1;
      DWORD PreferSystem32Images : 1;
      DWORD AuditNoRemoteImages : 1;
      DWORD AuditNoLowMandatoryLabelImages : 1;
      DWORD ReservedFlags : 27;
    };
  };
} PROCESS_MITIGATION_IMAGE_LOAD_POLICY, *PPROCESS_MITIGATION_IMAGE_LOAD_POLICY;

typedef struct _PROCESS_MITIGATION_REDIRECTION_TRUST_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD EnforceRedirectionTrust : 1;
      DWORD AuditRedirectionTrust : 1;
      DWORD ReservedFlags : 30;
    };
  };
} PROCESS_MITIGATION_REDIRECTION_TRUST_POLICY, *PPROCESS_MITIGATION_REDIRECTION_TRUST_POLICY;

typedef struct _PROCESS_MITIGATION_SIDE_CHANNEL_ISOLATION_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD SmtBranchTargetIsolation : 1;
      DWORD IsolateSecurityDomain : 1;
      DWORD DisablePageCombine : 1;
      DWORD SpeculativeStoreBypassDisable : 1;
      DWORD RestrictCoreSharing : 1;
      DWORD ReservedFlags : 27;
    };
  };
} PROCESS_MITIGATION_SIDE_CHANNEL_ISOLATION_POLICY, *PPROCESS_MITIGATION_SIDE_CHANNEL_ISOLATION_POLICY;

typedef struct _PROCESS_MITIGATION_USER_SHADOW_STACK_POLICY {
  union {
    DWORD Flags;
    struct {
      DWORD EnableUserShadowStack : 1;
      DWORD AuditUserShadowStack : 1;
      DWORD SetContextIpValidation : 1;
      DWORD AuditSetContextIpValidation : 1;
      DWORD EnableUserShadowStackStrictMode : 1;
      DWORD BlockNonCetBinaries : 1;
      DWORD BlockNonCetBinariesNonEhcont : 1;
      DWORD AuditBlockNonCetBinaries : 1;
      DWORD CetDynamicApisOutOfProcOnly : 1;
      DWORD SetContextIpValidationRelaxedMode : 1;
      DWORD ReservedFlags : 22;
    };
  };
} PROCESS_MITIGATION_USER_SHADOW_STACK_POLICY, *PPROCESS_MITIGATION_USER_SHADOW_STACK_POLICY;

BOOL SetProcessMitigationPolicy(PROCESS_MITIGATION_POLICY MitigationPolicy,
                                PVOID lpBuffer, SIZE_T dwLength);

BOOL GetProcessMitigationPolicy(HANDLE hProcess,
                                PROCESS_MITIGATION_POLICY MitigationPolicy,
                                PVOID lpBuffer, SIZE_T dwLength);
]])

local POLICIES = {
    data_execution_prevention = {
        id = ffi.C.ProcessDEPPolicy,
        schema = "PROCESS_MITIGATION_DEP_POLICY",
    },
    address_space_layout_randomization = {
        id = ffi.C.ProcessASLRPolicy,
        schema = "PROCESS_MITIGATION_ASLR_POLICY",
    },
    dynamic_code = {
        id = ffi.C.ProcessDynamicCodePolicy,
        schema = "PROCESS_MITIGATION_DYNAMIC_CODE_POLICY",
    },
    strict_handle_check = {
        id = ffi.C.ProcessStrictHandleCheckPolicy,
        schema = "PROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY",
    },
    system_call_disable = {
        id = ffi.C.ProcessSystemCallDisablePolicy,
        schema = "PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY",
    },
    extension_point_disable = {
        id = ffi.C.ProcessExtensionPointDisablePolicy,
        schema = "PROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY",
    },
    control_flow_guard = {
        id = ffi.C.ProcessControlFlowGuardPolicy,
        schema = "PROCESS_MITIGATION_CONTROL_FLOW_GUARD_POLICY",
    },
    binary_signature = {
        id = ffi.C.ProcessSignaturePolicy,
        schema = "PROCESS_MITIGATION_BINARY_SIGNATURE_POLICY",
    },
    font_disable = {
        id = ffi.C.ProcessFontDisablePolicy,
        schema = "PROCESS_MITIGATION_FONT_DISABLE_POLICY",
    },
    image_load = {
        id = ffi.C.ProcessImageLoadPolicy,
        schema = "PROCESS_MITIGATION_IMAGE_LOAD_POLICY",
    },
    redirection_trust = {
        id = ffi.C.ProcessRedirectionTrustPolicy,
        schema = "PROCESS_MITIGATION_REDIRECTION_TRUST_POLICY",
    },
    side_channel_isolation = {
        id = ffi.C.ProcessSideChannelIsolationPolicy,
        schema = "PROCESS_MITIGATION_SIDE_CHANNEL_ISOLATION_POLICY",
    },
    user_shadow_stack = {
        id = ffi.C.ProcessUserShadowStackPolicy,
        schema = "PROCESS_MITIGATION_USER_SHADOW_STACK_POLICY",
    },
}

---@class MitigationPolicy: Command
---@field private name string
---@field private params { [string]: boolean }
local MitigationPolicy = {}

---Creates a new `MitigationPolicy` instance.
---@param name string
---@param params { [string]: boolean }
---@return MitigationPolicy
function MitigationPolicy:new(name, params)
    assert(POLICIES[name], string.format("wrong policy name: %s", name))
    assert(type(params) == "table", "params must be a table")
    local cmd = script.command()
    setmetatable(cmd, self)
    self.__index = self
    ---@cast cmd MitigationPolicy
    cmd.name = name
    cmd.params = params
    return cmd
end

---Returns text representations of the `err` code.
---@param err integer
---@return string
local function winerror_tostring(err)
    -- TODO: Get error string from code
    return tostring(err)
end

---Gets the last error as a string.
---@return string error
local function get_last_error()
    return winerror_tostring(lk32.GetLastError())
end

---Sets exploit mitigation policy for the current process, returning undo command.
---@return Command|nil # Undo command
---@return error|nil   # Error string, if any
function MitigationPolicy:run()
    local policy = POLICIES[self.name]
    local buf = ffi.new(policy.schema)
    local buf_len = ffi.sizeof(policy.schema)
    local pid = lk32.GetCurrentProcess()
    local ret = ffi.C.GetProcessMitigationPolicy(pid, policy.id, buf, buf_len)
    if not ret then
        return nil, get_last_error()
    end
    local undo_params = {}
    for key, value in pairs(self.params) do
        undo_params[key] = (buf[key] ~= 0)
        buf[key] = value
    end
    ret = ffi.C.SetProcessMitigationPolicy(policy.id, buf, buf_len)
    if not ret then
        return nil, get_last_error()
    end
    return MitigationPolicy:new(self.name, undo_params)
end

---Creates and returns a new `MitigationPolicy` instance.
---@param policy string
---@param params {[string]: boolean}
---@return MitigationPolicy
function process.mitigation_policy(policy, params)
    return MitigationPolicy:new(policy, params)
end

return process
