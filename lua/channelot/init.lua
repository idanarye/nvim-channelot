local M = {}

local Terminal = {}

function M.terminal()
    local obj = setmetatable({}, {__index = Terminal})
    obj.terminal_id = vim.api.nvim_open_term(0, {
        on_input = function(_, _, _, data)
            if obj.current_job ~= nil then
                vim.api.nvim_chan_send(obj.current_job.job_id, data)
            end
        end
    })
    return obj
end

local Job = {}

function Terminal:job(command)
    assert(self.current_job == nil, 'terminal is already running a job')

    local terminal_id = self.terminal_id
    local function on_output(_, data)
        for i, line in pairs(data) do
            if 1 < i then
                vim.api.nvim_chan_send(terminal_id, '\r\n')
            end
            vim.api.nvim_chan_send(terminal_id, line)
        end
    end

    local obj = setmetatable({
        wake_on_exit = {}
    }, {__index = Job})
    obj.job_id = vim.fn.jobstart(command, {
        pty = true;
        stdout_buffered = false;
        on_stdout = on_output;
        on_stderr = on_output;
        on_exit = function(_, exit_status)
            obj.exit_status = exit_status
            self.current_job = nil
            for _, co in ipairs(obj.wake_on_exit) do
                coroutine.resume(co)
            end
        end
    })
    self.current_job = obj
    return obj
end

function Job:wait()
    if self.exit_status ~= nil then
        return self.exit_status
    end
    local co = coroutine.running()
    assert(co, 'job:wait must be called from a coroutine')
    table.insert(self.wake_on_exit, co)
    coroutine.yield()
    assert(self.exit_status, 'job:wait returned but exit status was not set')
    return self.exit_status
end

return M
