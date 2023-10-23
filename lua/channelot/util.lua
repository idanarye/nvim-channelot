local M = {}

---@param env {[string]:any}
---@param command string|string[]
---@param opts? ChannelotJobOptions
---@return {[string]:any}|nil
---@return string|string[]
---@return ChannelotJobOptions
function M.normalize_job_arguments(env, command, opts)
    if type(env) == 'string' or (next(env) and vim.tbl_islist(env)) then
        return vim.empty_dict(), env, command or {}
    else
        return env, command, opts or {}
    end
end

function M.first_non_nil(...)
    local args = {...}
    local some_index = 0
    for i in pairs(args) do
        some_index = i
        break
    end
    for i = 1,some_index do
        local value = args[i]
        if value ~= nil then
            return value
        end
    end
end

return M
