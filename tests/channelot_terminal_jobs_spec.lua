describe('channelot.terminal_job()', function()
    before_each(EnsureSingleWindow)

    local channelot = require'channelot'

    it('runs', function()
        channelot.terminal_job('echo hello; echo world'):wait()
        local output = vim.api.nvim_buf_get_lines(0, 0, 2, true)
        assert.are.same(output, {'hello', 'world'})
    end)

    it('respects environment variables', function()
        channelot.terminal_job({
            FOO = 'hello',
            BAR = 'world',
        }, 'echo $FOO $BAR'):wait()
        local output = vim.api.nvim_buf_get_lines(0, 0, 1, true)
        assert.are.same(output, {'hello world'})
    end)

    it('accepts input', function()
        local job = channelot.terminal_job('bc | cat')
        job:writeln('40 + 2')
        job:writeln('quit')
        job:wait()
        local output = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        assert(vim.tbl_contains(output, '42'))
    end)
end)
