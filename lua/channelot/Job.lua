---@class ChannelotJobOptions
---@field pty? boolean Enforce a PTY or a non-PTY. Leave nil to use default
local ChannelotJobOptions

---An handle to a Neovim job with functions for controlling it from a Lua coroutine.
---@class ChannelotJob
---@field env {[string]:any}
---@field command string|string[]
---@field pty boolean
---@field job_id integer 
---@field exit_status? integer
local ChannelotJob = {}

---Wait for the job to finish. Must be called from a Lua coroutine.
---@return integer # the job's exit status
function ChannelotJob:wait()
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

---Wait for the job to finish with an exit status. Must be called from a Lua coroutine.
---
---If the command returns an exit status that differs from the provided
--`expected_status`, an error table will be raied -with the exit status in its
--`exit_status` field.
---
---If no `expected_status` is given, it defaults to 0. If a list-like table is
---given, this method will check that the exit status is one of the numbers in
---that table.
---@param expected_status? integer | integer[]
function ChannelotJob:check(expected_status)
    if self.exit_status == nil then
        self:wait()
    end

    local status_ok
    if expected_status == nil then
        status_ok = self.exit_status == 0
    elseif type(expected_status) == 'number' then
        status_ok = self.exit_status == expected_status
    elseif type(expected_status) == 'table' then
        status_ok = vim.tbl_contains(expected_status, self.exit_status)
    end

    if not status_ok then
        error({
            'Channelot job failed with exit status ' .. self.exit_status,
            exit_status = self.exit_status
        })
    end
end

---@class ChannelotJobIterConfig
---@field stdout? "'buffered'"|"'unbuffered'"|"'ignore'"
---@field stderr? "'buffered'"|"'unbuffered'"|"'ignore'"

---Iterate over output from the job. Must be called from a Lua coroutine.
---
---Multiyields each time the type of line (stdout/stderr) and the line data.
---@param opts? ChannelotJobIterConfig
function ChannelotJob:iter(opts)
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

---Write text to a running job's stdin.
---@param text string
function ChannelotJob:write(text)
    vim.api.nvim_chan_send(self.job_id, text)
end

---Write text to a running job's stdin, and add a newline.
---@param text? string leave empty to write only the newline
function ChannelotJob:writeln(text)
    if text == nil then
        self:write('\n')
    else
        self:write(text .. '\n')
    end
end

---Close the job's standard input.
function ChannelotJob:close_stdin()
    vim.fn.chanclose(self.job_id, 'stdin')
end

return ChannelotJob
