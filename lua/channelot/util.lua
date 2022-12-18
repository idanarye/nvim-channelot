local M = {}

---@param env {[string]:any}
---@param command string|string[]
---@param opts? {[string]:any} not used now, will be used later
---@return {[string]:any}|nil
---@return string|string[]
---@return {[string]:any} # not used now, will be used later
function M.normalize_job_arguments(env, command, opts)
    if type(env) == 'string' or (next(env) and vim.tbl_islist(env)) then
        return nil, env, command or {}
    else
        return env, command, opts or {}
    end
end

return M
