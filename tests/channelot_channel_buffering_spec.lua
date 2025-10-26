describe('channel buffering', function()
    local channelot = require'channelot'

    for _, buffering in ipairs{'unbuffered', 'buffered'} do
        local line_join_char = ({
            buffered = '\n',
            unbuffered = '',
        })[buffering]
        for _, pty in ipairs{false, true} do
            it('works with ' .. buffering .. ' and pty = ' .. tostring(pty), function()
                local job = channelot.job({
                    'bash', '-c', [=[
                    echo different
                    echo lines
                    echo -n same
                    sleep 1
                    echo -n ' line'
                    ]=],
                }, {pty = pty})
                local result = vim.iter(job:iter{stdout = buffering, stderr = 'ignore'}):map(function(_, line)
                    return line
                end):join(line_join_char):gsub('\r', '')
                assert.are.same(result, 'different\nlines\nsame line')
            end)
        end
    end
end)
