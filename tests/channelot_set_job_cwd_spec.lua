describe('CWD option', function()
    before_each(EnsureSingleWindow)

    local channelot = require'channelot'

    local function read_stdout(job)
        local by_channel = {stdout = {}, stderr = {}}
        for ch, line in job:iter() do
            local cleaned_line = line:gsub('\r', '')
            table.insert(by_channel[ch], cleaned_line)
        end
        if job.exit_status ~= 0 then
            local stderr = table.concat(by_channel.stderr, '\n')
            error(('Job exited with status %d:\n%s'):format(job.exit_status, stderr))
        end
        return table.concat(by_channel.stdout, '\n')
    end

    it('in channelot.job()', function()
        assert.are.same(read_stdout(channelot.job('pwd')), vim.fn.getcwd())
        assert.are.same(read_stdout(channelot.job('pwd', { cwd = '/' })), '/')
    end)

    it('in channelot.terminal_job()', function()
        vim.cmd.new()
        assert.are.same(read_stdout(channelot.terminal_job('pwd')), vim.fn.getcwd())
        vim.cmd.close()
        vim.cmd.new()
        assert.are.same(read_stdout(channelot.terminal_job('pwd', { cwd = '/' })), '/')
        vim.cmd.close()
    end)

    it('in term.job()', function()
        vim.cmd.new()
        local term = channelot.terminal()
        assert.are.same(read_stdout(term:job('pwd')), vim.fn.getcwd())
        assert.are.same(read_stdout(term:job('pwd', { cwd = '/' })), '/')
        vim.cmd.close()
    end)

    it('when terminal has a cwd set', function()
        vim.cmd.new()
        local term = channelot.terminal{ cwd = '/tmp' }
        assert.are.same(read_stdout(term:job('pwd')), '/tmp')
        assert.are.same(read_stdout(term:job('pwd', { cwd = '/' })), '/')
        vim.cmd.close()
    end)
end)
