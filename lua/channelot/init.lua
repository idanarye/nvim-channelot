---@mod channelot Channelot - Terminal and Job IO for Lua Coroutines
---@brief [[
---Channelot is a library plugin for operating Neovim jobs from a Lua
---coroutine. It supports:
---
--- * Starting jobs, with and without terminals.
--- * Starting multiple jobs on the same Neovim terminal.
--- * Job control is done via Lua coroutines - Channelot will resume the
---   coroutine once the job is finished and/or when it outputs new data.
---
---Channelot was created as a supplemental plugin for Moonicipal
---(https://github.com/idanarye/nvim-moonicipal), but can be used independent
---of it.
---@brief ]]
local M = {}

---Represents a terminal - a buffer that can handle PTY IO.
---
---A single terminal can run multiple jobs. To only run a single job, prefer
---|channelot.terminal_job|.
---@class ChannelotTerminal
---@see channelot.terminal
local Terminal = {}

---@brief [[
---A terminal is created in the current buffer, so it is advisable to create
---a new buffer in a new split first. Unlike regular Neovim terminals that
---prompt for exit automatically when the process is finished,
---ChannelotTerminal can run multiple jobs so it needs to prompt the user
---manually to be closed.
--->
---    vim.cmd.new()
---    local t = channelot.terminal()
---    t:job('./command arg1 arg2'):wait()
---    t:prompt_exit()
---<
---@brief ]]

---@return ChannelotTerminal
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

---@class ChannelotJob
---@field exit_status? integer
local Job = {}

---@param env {[string]:any}
---@param command string|string[]
---@param opts? {[string]:any} not used now, will be used later
---@return {[string]:any}
---@return string|string[]
local function normalize_job_arguments(env, command, opts)
    if type(env) == 'string' or (next(env) and vim.tbl_islist(env)) then
        return nil, env, command or {}
    else
        return env, command, opts or {}
    end
end

---@param env {[string]:any}
---@param command string|string[]
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
function Terminal:job(env, command)
    env, command = normalize_job_arguments(env, command)

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
        for cbn, callback in pairs(obj.callbacks[event]) do
            callback(event, data)
        end
        for i, text in pairs(data) do
            if 1 < i then
                vim.api.nvim_chan_send(terminal_id, '\r\n')
            end
            vim.api.nvim_chan_send(terminal_id, text)
        end
    end

    obj.job_id = vim.fn.jobstart(command, {
        env = env;
        pty = true;
        stdout_buffered = false;
        on_stdout = on_output;
        on_stderr = on_output;
        on_exit = function(_, exit_status)
            obj.exit_status = exit_status
            self.current_job = nil
            for _, callback in pairs(obj.callbacks.exit) do
                callback('exit', exit_status)
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
    self.callbacks.exit[{}] = function()
        coroutine.resume(co)
    end
    coroutine.yield()
    assert(self.exit_status, 'job:wait returned but exit status was not set')
    return self.exit_status
end

---@class ChannelotJobIterConfig

---@param opts? ChannelotJobIterConfig
function Job:iter(opts)
    opts = opts or {}
    local buffer = {read_from = 0, write_to = 0}

    local function write_to_buffer(...)
        buffer[buffer.write_to] = {...}
        buffer.write_to = buffer.write_to + 1
    end

    local chan_info = vim.api.nvim_get_chan_info(self.job_id)

    local line_buffers = {
        stdout = {},
        stderr = {},
    }

    local co = coroutine.running()

    local handle_data_event_buffered
    if chan_info.pty then
        handle_data_event_buffered = function(event, data)
            local should_resume = false
            local line_buffer = line_buffers[event]
            for _, line in ipairs(data) do
                if vim.endswith(line, '\r') then
                    if next(line_buffer) ~= nil then
                        table.insert(line_buffer, line)
                        line = table.concat(line_buffer)
                        line_buffer = {}
                        line_buffers[event] = line_buffer
                    end
                    write_to_buffer(event, line)
                    should_resume = true
                elseif line ~= '' then
                    table.insert(line_buffer, line)
                end
            end
            if should_resume then
                coroutine.resume(co)
            end
        end
    else
        handle_data_event_buffered = function(event, data)
            local should_resume = false
            local line_buffer = line_buffers[event]
            for i, line in ipairs(data) do
                if i == 1 and next(line_buffer) ~= nil then
                    table.insert(line_buffer, line)
                    line = table.concat(line_buffer)
                    line_buffer = {}
                    line_buffers[event] = line_buffer

                    if data[i + 1] ~= nil then
                        write_to_buffer(event, line)
                        should_resume = true
                    end
                elseif data[i + 1] ~= nil then
                    write_to_buffer(event, line)
                    should_resume = true
                elseif line ~= '' then
                    table.insert(line_buffer, line)
                end
            end
            if should_resume then
                coroutine.resume(co)
            end
        end
    end
    local function handle_data_event_unbuffered(event, data)
        local should_resume = false
        for _, line in ipairs(data) do
            if line ~= '' then
                write_to_buffer(event, line)
                should_resume = true
            end
        end
        if should_resume then
            coroutine.resume(co)
        end
    end

    local handle_streams_with = {
        exit=function()
            coroutine.resume(co)
        end,
    }

    for _, stream_name in ipairs({'stdout', 'stderr'}) do
        local stream_setting = opts[stream_name] or 'buffered'
        if stream_setting == 'buffered' then
            handle_streams_with[stream_name] = handle_data_event_buffered
        elseif stream_setting == 'unbuffered' then
            handle_streams_with[stream_name] = handle_data_event_unbuffered
        elseif stream_setting == 'ignore' then
        else
            error('Invalid stream setting ' .. vim.inspect(stream_setting))
        end
    end

    local callbacks_key = {}
    return function()
        while self.exit_status == nil or buffer.read_from < buffer.write_to do
            if buffer.read_from < buffer.write_to then
                local from_buffer = buffer[buffer.read_from]
                buffer[buffer.read_from] = nil
                buffer.read_from = buffer.read_from + 1
                return unpack(from_buffer)
            end

            for stream_name, stream_handler in pairs(handle_streams_with) do
                self.callbacks[stream_name][callbacks_key] = stream_handler
            end
            coroutine.yield()
            for stream_name in pairs(handle_streams_with) do
                self.callbacks[stream_name][callbacks_key] = nil
            end
        end
    end
end

function Job:write(data)
    vim.api.nvim_chan_send(self.job_id, data)
end

function Job:writeln(data)
    if data == nil then
        self:write('\n')
    else
        self:write(data .. '\n')
    end
end

---@param env {[string]:any}
---@param command string|string[]
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
function M.terminal_job(env, command)
    env, command = normalize_job_arguments(env, command)
    local obj = setmetatable({
        callbacks = {
            exit = {};
            stdout = {};
            stderr = {};
        };
    }, {__index = Job})

    local function on_output(_, data, event)
        for _, callback in pairs(obj.callbacks[event]) do
            callback(event, data)
        end
    end

    obj.job_id = vim.fn.termopen(command, {
        env = env;
        stdout_buffered = false;
        on_stdout = on_output;
        on_stderr = on_output;
        on_exit = function(_, exit_status)
            obj.exit_status = exit_status
            for _, callback in pairs(obj.callbacks.exit) do
                callback('exit', exit_status)
            end
        end
    })
    return obj
end

---@param env {[string]:any}
---@param command string|string[]
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
function M.job(env, command)
    env, command = normalize_job_arguments(env, command)
    local obj = setmetatable({
        callbacks = {
            exit = {};
            stdout = {};
            stderr = {};
        };
    }, {__index = Job})

    local function on_output(_, data, event)
        for _, callback in pairs(obj.callbacks[event]) do
            callback(event, data)
        end
    end

    obj.job_id = vim.fn.jobstart(command, {
        env = env;
        pty = false;
        stdout_buffered = false;
        on_stdout = on_output;
        on_stderr = on_output;
        on_exit = function(_, exit_status)
            obj.exit_status = exit_status
            for _, callback in pairs(obj.callbacks.exit) do
                callback('exit', exit_status)
            end
        end
    })
    return obj
end

return M
