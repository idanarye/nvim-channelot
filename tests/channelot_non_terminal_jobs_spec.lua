describe('channelot.job()', function()
    local channelot = require'channelot'
    it('runs', function()
        local t1 = vim.fn.tempname()
        channelot.job('echo hello > ' .. t1):wait()
        local t1_data = vim.fn.readfile(t1)
        assert.are.same(t1_data, {'hello'})

        local t2 = vim.fn.tempname()
        assert(t1 ~= t2)
        channelot.job{'cp', t1, t2}:wait()
        local t2_data = vim.fn.readfile(t2)
        assert.are.same(t2_data, t1_data)
    end)

    it('prints output', function()
        local job = channelot.job[[
        echo hello
        echo foo >&2
        echo world
        echo bar >&2
        exit 42
        ]]
        local results = {
            stdout = {},
            stderr = {},
        }
        for evt, line in job:iter() do
            table.insert(results[evt], line)
        end
        assert.are.same(job.exit_status, 42)
        assert.are.same(results, {
            stdout = {'hello', 'world'},
            stderr = {'foo', 'bar'},
        })
    end)

    it('respects environment variables', function()
        local job = channelot.job({
            FOO = 'hello',
            BAR = 'world',
        }, 'echo $FOO $BAR')
        local output
        for _, line in job:iter() do
            output = line
            break
        end
        assert.are.same(output, 'hello world')
    end)

    it('accepts input', function()
        local job = channelot.job{'bc'}
        job:writeln('1 + 2')
        job:close_stdin()
        local output
        for _, line in job:iter() do
            output = line
            break
        end
        assert.are.same(output, '3')
    end)
end)
