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

---@brief [[
---A terminal is created in the current buffer, so it is advisable to create
---a new buffer in a new split first. Unlike regular Neovim terminals that
---prompt for exit automatically when the process is finished,
---ChannelotTerminal can run multiple jobs so it needs to prompt the user
---manually to be closed:
--->
---    vim.cmd.new()
---    local t = channelot.terminal()
---    t:job('./command arg1 arg2'):wait()
---    t:prompt_exit()
---<
---A terminal with a job can also be created directly - in which case the user
---will be prompted automatically to close it, by Neovim itself:
--->
---    vim.cmd.new()
---    local j = channelot.terminal_job('./command arg1 arg2')
---    j:wait()
---<
---Jobs without a terminal can also be created:
--->
---    --No need to create a new window because we don't convert the current
---    --buffer to a terminal.
---    channelot.job('./command arg1 arg2')
---<
---Note that the job can be given as either as single string (with shell
---expansion) or as a list of strings (with no shell expansion):
--->
---    --Equivalent:
---    channelot.job[[./command a b\ c]]
---    channelot.job{'./command', 'a', 'b c'}
---<
---Also, environment variables can be given as a table before the command:
--->
---    --Equivalent (on POSIX shells):
---    channelot.job({
---        FOO='bar',
---        BAZ='qux',
---    }, {'./command', 'arg'})
---    channelot.job'FOO=bar BAZ=qux ./command arg'
---<
---All these methods create a |ChannelotJob| object, which can be used to
---control the job from within a Lua coroutine. |ChannelotJob:wait()| can be
---used to wait for the job to finish, and get its exit status:
--->
---    local exit_status = channelot.job'sleep 5':wait()
---<
---|ChannelotJob:iter()| can be used to get the stdout and stderr of a job:
--->
---    for _, line in channelot.job'ls':iter() do
---        print('Has file', line)
---    end
---<
---Note that jobs with PTY behave differently than jobs without PTY regarding
---their output.
---
---|ChannelotJob:write()| and |ChannelotJob:writeln()| can be used to write to
---a running job:
--->
---    local job = channelot.job'bc'
---    job:writeln('1 + 2')
---    job:close_stdin()
---    for _, line in job:iter() do
---        print('1 + 2 =', line)
---        break
---    end
---<
---@brief ]]

---@class ChannelotCreateWindowForTerminalOpts
---@field bufnr? number Use an existing buffer instead of creating a new one

---Create a new window suitable for running terminal jobs.
---
---* When the terminal window is closed, the focus will return (if possible) to
---  the original window from which this function was invoked.
---* Automatically goes into insert mode inside the new window.
---* Does not actually start the terminal.
---
---@param opts? ChannelotCreateWindowForTerminalOpts
function M.create_window_for_terminal(opts)
    opts = opts or {}
    local prev_win_id = vim.fn.win_getid(vim.fn.winnr())
    vim.cmd'botright 20new'
    local bufnr
    if opts.bufnr then
        bufnr = opts.bufnr
        vim.api.nvim_win_set_buf(0, bufnr)
    else
        bufnr = vim.api.nvim_get_current_buf()
    end
    vim.api.nvim_create_autocmd('WinEnter', {
        buffer = bufnr,
        callback = function()
            prev_win_id = vim.fn.win_getid(vim.fn.winnr('#'))
        end,
    })
    vim.api.nvim_create_autocmd('WinClosed', {
        buffer = bufnr,
        callback = function()
            vim.fn.win_gotoid(prev_win_id)
        end,
    })
    vim.cmd.startinsert()
end

---@class ChannelotTerminalOpts
---@field bufnr? number Use the specified buffer instead of the current buffer
---@field cwd? string Run jobs ceated in this terminal under a different directory.

---Convert the current buffer to a |ChannelotTerminal|.
---@param opts? ChannelotTerminalOpts
---@return ChannelotTerminal
function M.terminal(opts)
    opts = opts or {}
    local obj = setmetatable({
        cwd = opts.cwd;
        input_callbacks = {};
    }, {__index = require'channelot.Terminal'})
    obj.terminal_id = vim.api.nvim_open_term(opts.bufnr or 0, {
        on_input = function(_, _, _, data)
            for _, callback in ipairs(obj.input_callbacks) do
                callback(data)
            end
            if obj.current_job ~= nil and obj.current_job.pty then
                vim.api.nvim_chan_send(obj.current_job.job_id, data)
            end
        end
    })
    return obj
end

---Similar to |channelot.terminal|, but automatically creates a window with
---|channelot.create_window_for_terminal| to put the new terminal in.
---@param opts? ChannelotTerminalOpts
---@return ChannelotTerminal
function M.windowed_terminal(opts)
    opts = opts or {}
    M.create_window_for_terminal {
        bufnr = opts.bufnr,
    }
    return M.terminal(opts)
end

---Similar to |channelot.terminal|, but without creating a window.
---
---A window can be created later using |ChannelotTerminal:expose|.
---@return ChannelotTerminal
function M.shadow_terminal()
    return M.terminal {
        bufnr = vim.api.nvim_create_buf(true, false),
    }
end

---Start a job on the current buffer, converting it to a terminal
---@param env table<string,any> Environment variables for the command
---@param command string|string[] The command as a string or as a list of arguments
---@param opts? ChannelotJobOptions
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
---@overload fun(command: string|string[], opts: ChannelotJobOptions): ChannelotJob
function M.terminal_job(env, command, opts)
    env, command, opts = require'channelot.util'.normalize_job_arguments(env, command, opts)
    local pty = require'channelot.util'.first_non_nil(opts.pty, true)

    if not pty then
        local terminal = M.terminal()
        local job = terminal:job(env, command, opts)
        table.insert(job.callbacks.exit, function(_, exit_status)
            local co = coroutine.create(function()
                terminal:prompt_exit('[Process exited ' .. exit_status .. ']')
            end)
            coroutine.resume(co)
        end)
        return job
    end

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
        for _, callback in pairs(obj.callbacks[event]) do
            callback(event, data)
        end
    end

    obj.job_id = vim.fn.termopen(command, {
        env = env;
        pty = pty;
        cwd = opts.cwd;
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

---Similar to |channelot.terminal_job|, but automatically creates a window with
---|channelot.create_window_for_terminal| to run the terminal job in.
---@param env table<string,any> Environment variables for the command
---@param command string|string[] The command as a string or as a list of arguments
---@param opts? ChannelotJobOptions
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
---@overload fun(command: string|string[], opts: ChannelotJobOptions): ChannelotJob
function M.windowed_terminal_job(env, command, opts)
    M.create_window_for_terminal()
    return M.terminal_job(env, command, opts)
end

---Start a job without a terminal attached to it.
---
---Note: this job will not have a PTY, unless `{ pty = true }` is passed in the `opts`.
---@param env table<string,any> Environment variables for the command
---@param command string|string[] The command as a string or as a list of arguments
---@param opts? ChannelotJobOptions
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
---@overload fun(command: string|string[], opts: ChannelotJobOptions): ChannelotJob
function M.job(env, command, opts)
    env, command, opts = require'channelot.util'.normalize_job_arguments(env, command, opts)
    local pty = require'channelot.util'.first_non_nil(opts.pty, false)
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
        for _, callback in pairs(obj.callbacks[event]) do
            callback(event, data)
        end
    end

    obj.job_id = vim.fn.jobstart(command, {
        env = env;
        pty = pty;
        cwd = opts.cwd;
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
