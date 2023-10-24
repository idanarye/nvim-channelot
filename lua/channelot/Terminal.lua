---Represents a terminal - a buffer that can handle PTY IO.
---
---A single terminal can run multiple jobs. To only run a single job, prefer
---|channelot.terminal_job|.
---@see channelot.terminal
---@class ChannelotTerminal
---@field terminal_id integer
local ChannelotTerminal = {}

---Start a job on a |ChannelotTerminal|.
---@param env {[string]:any} Environment variables for the command
---@param command string|(string[]) The command as a string or as a list of arguments
---@param opts? ChannelotJobOptions
---@return ChannelotJob
---@overload fun(command: string|(string[])): ChannelotJob
---@overload fun(command: string|(string[]), opts: table): ChannelotJob
function ChannelotTerminal:job(env, command, opts)
    env, command, opts = require'channelot.util'.normalize_job_arguments(env, command, opts)
    local pty = require'channelot.util'.first_non_nil(opts.pty, true)

    assert(self.current_job == nil, 'terminal is already running a job')

    local terminal_id = self.terminal_id

    local obj = setmetatable({
        env = env,
        command = command,
        pty = pty,
        callbacks = {
            exit = {};
            stdout = {};
            stderr = {};
        };
    }, {__index = require'channelot.Job'})

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
        pty = pty;
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

---Write text as is directly to the terminal (NOT! the job - the terminal)
---
---Note that multiline text will come up weird if `\n` is used alone without
---`\r`. This is a property of Neovim's terminal, not of Channelot. To fix
---that, use |ChannelotTerminal:write| or |ChannelotTerminal:writeln|.
---@param text string
function ChannelotTerminal:raw_write(text)
    vim.api.nvim_chan_send(self.terminal_id, text)
end

---Write text directly to the terminal (NOT! the job - the terminal)
---
---This will also fix the linefeed in multipline text.
---@param text string
function ChannelotTerminal:write(text)
    self:raw_write(string.gsub(text, '\n', '\r\n'))
end

---Write text directly to the terminal (NOT! the job - the terminal), and add CRLF.
---
---This will also fix the linefeed in multipline text.
---@param text string
function ChannelotTerminal:writeln(text)
    self:raw_write(string.gsub(text, '\n', '\r\n') .. '\r\n')
end

---Read a single key press from the terminal.
---@return string # the pressed keycode
function ChannelotTerminal:read_key()
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

---Prompt the user to press a key and close the terminal.
---
---When using a job on a |channelot.terminal|, the terminal will not close
---automatically after the job - because it can be used to run more jobs. Use
---this method to prompt the user to close it.
---@param prompt? string
---@return string # the key the user pressed to close the terminal
function ChannelotTerminal:prompt_exit(prompt)
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

---Run a code block (function) with the terminal, and then prompt the user to close it.
---
---If the block raises, as an error, a table with an `exit_status` fields (such
---as the one job:check()` raises) the exception will be swallowed and the exit
---status will be shown in the terminal's exit prompt.
---@param block fun(terminal: ChannelotTerminal)
function ChannelotTerminal:with(block)
    local ok, err = pcall(block, self)
    if ok then
        self:prompt_exit()
    elseif type(err) == 'table' and err.exit_status then
        self:prompt_exit('[Process exited ' .. err.exit_status .. ']')
    else
        self:prompt_exit('[Error occured inside terminal block]')
        error(err)
    end
end

return ChannelotTerminal
