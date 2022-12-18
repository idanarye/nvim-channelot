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

---Convert the current buffer to a |ChannelotTerminal|.
---@return ChannelotTerminal
function M.terminal()
    local obj = setmetatable({
        input_callbacks = {};
    }, {__index = require'channelot/Terminal'})
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

---Start a job on the current buffer, converting it to a terminal
---@param env {[string]:any} Environment variables for the command
---@param command string|(string[]) The command as a string or as a list of arguments
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
function M.terminal_job(env, command)
    env, command = require'channelot/util'.normalize_job_arguments(env, command)
    local obj = setmetatable({
        callbacks = {
            exit = {};
            stdout = {};
            stderr = {};
        };
    }, {__index = require'channelot/Job'})

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

---Start a job without a terminal attached to it.
---
---Note: this job will not have a PTY.
---@param env {[string]:any} Environment variables for the command
---@param command string|(string[]) The command as a string or as a list of arguments
---@return ChannelotJob
---@overload fun(command: string|string[]): ChannelotJob
function M.job(env, command)
    env, command = require'channelot/util'.normalize_job_arguments(env, command)
    local obj = setmetatable({
        callbacks = {
            exit = {};
            stdout = {};
            stderr = {};
        };
    }, {__index = require'channelot/Job'})

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
