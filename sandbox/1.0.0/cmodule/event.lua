require("engine")
local M = {}

local event_engine
local action_engine

-- Must be called on "update_config" control event to adjust new configuration
-- of event/action links.
function M.update_config()
    local prefix_db     = __gid .. "."
    local fields_schema = __config.get_fields_schema()
    local event_config  = __config.get_current_event_config()
    local module_info   = __config.get_module_info()

    event_engine  = CEventEngine(fields_schema, event_config, module_info, prefix_db, false)
    action_engine = CActionEngine({}, false)
end

-- Emits an event with specified `name` and `data`.
-- string, {...}? -> ()
local function push_event(name, data)
    local result, list = event_engine:push_event {
        name = name,
        data = data or {},
    }
    if result then action_engine:exec(__aid, list) end
end

-- Used to emit "cyberok_sandbox_verdict_suspicious" event.
function M.verdict_suspicious(verdict)
    push_event("cyberok_sandbox_verdict_suspicious", verdict)
end

-- Used to emit "cyberok_sandbox_verdict_clean" event.
function M.verdict_clean(verdict)
    push_event("cyberok_sandbox_verdict_clean", verdict)
end

-- Used to emit "cyberok_sandbox_error" event.
function M.error(err)
    push_event("cyberok_sandbox_error", {
        name    = err.name,
        message = tostring(err),
    })
end

M.update_config()
return M
