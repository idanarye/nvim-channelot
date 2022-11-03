local M = {}

local Terminal = {}

function M.terminal()
    local obj = setmetatable({
        input_callbacks = {};
    }, {__index = Terminal})
    obj.terminal_id = vim.api.nvim_open_term(0, {
        on_input = function(_, _, _, data)
            for _, callback in ipairs(obj.input_callbacks) do
                callback(data)
            end
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

    local obj = setmetatable({
        callbacks = {
            exit = {};
            stdout = {};
            stderr = {};
        };
    }, {__index = Job})

    local function on_output(_, data, event)
        for _, callback in ipairs(obj.callbacks[event]) do
            callback(data)
        end
        for i, text in pairs(data) do
            if 1 < i then
                vim.api.nvim_chan_send(terminal_id, '\r\n')
            end
            vim.api.nvim_chan_send(terminal_id, text)
        end
    end

    obj.job_id = vim.fn.jobstart(command, {
        pty = true;
        stdout_buffered = false;
        on_stdout = on_output;
        on_stderr = on_output;
        on_exit = function(_, exit_status)
            obj.exit_status = exit_status
            self.current_job = nil
            for _, callback in ipairs(obj.callbacks.exit) do
                callback(exit_status)
            end
        end
    })
    self.current_job = obj
    return obj
end

function Terminal:raw_write(text)
    vim.api.nvim_chan_send(self.terminal_id, text)
end

function Terminal:writeln(text)
    self:raw_write(string.gsub(text, '\n', '\r\n') .. '\r\n')
end

function Terminal:read_key()
    local co = coroutine.running()
    local function read_key_callback(data)
        for idx, callback in ipairs(self.input_callbacks) do
            if callback == read_key_callback then
                table.remove(self.input_callbacks, idx)
            end
        end
        coroutine.resume(co, data)
    end

    table.insert(self.input_callbacks, read_key_callback)
    return coroutine.yield()
end

function Terminal:prompt_exit(prompt)
    if prompt == nil then
        prompt = '[Press any key in terminal mode to exit]'
    end
    if prompt then
        self:raw_write('\r\n' .. prompt)
    end
    local key_pressed = self:read_key()
    local chan_info = vim.api.nvim_get_chan_info(self.terminal_id)
    local co = coroutine.running()
    vim.schedule(function()
        vim.api.nvim_buf_delete(chan_info.buffer, {force = true})
        coroutine.resume(co)
    end)
    coroutine.yield()
    return key_pressed
end

function Job:wait()
    if self.exit_status ~= nil then
        return self.exit_status
    end
    local co = coroutine.running()
    assert(co, 'job:wait must be called from a coroutine')
    table.insert(self.callbacks.exit, function()
        coroutine.resume(co)
    end)
    coroutine.yield()
    assert(self.exit_status, 'job:wait returned but exit status was not set')
    return self.exit_status
end

return M
