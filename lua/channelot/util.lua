local M = {}

---@param env {[string]:any}
---@param command string|string[]
---@param opts? ChannelotJobOptions
---@return {[string]:any}|nil
---@return string|string[]
---@return ChannelotJobOptions
function M.normalize_job_arguments(env, command, opts)
    if type(env) == 'string' or (next(env) and vim.islist(env)) then
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

function M.defer_to_coroutine(dlg, ...)
    local co = coroutine.create(function(...)
        xpcall(dlg, function(err)
            if type(err) ~= 'string' then
                err = vim.inspect(err)
            end
            local traceback = debug.traceback(err, 2)
            traceback = string.gsub(traceback, '\t', string.rep(' ', 8))
            vim.notify(traceback, vim.log.levels.ERROR, {
                title = 'ERROR in a coroutine'
            })
        end, ...)
    end)
    coroutine.resume(co, ...)
    return co
end

return M
