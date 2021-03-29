local math = require('math')
local scroll_timer = vim.loop.new_timer()
local lines_to_scroll = 0
local lines_scrolled = 0
local scrolling = false
-- vim.cmd

-- UI variables
local guicursor
local cursorline


-- excecute commands to scroll screen [and cursor] up/down one line
-- `execute` is necessary to allow the use of special characters like <C-y>
-- The bang (!) `normal!` in normal ignores mappings
local function scroll_up(move_cursor)
    local input_keys =  move_cursor and [[k\<C-y>]] or [[\<C-y>]]
    return [[exec "normal! ]] .. input_keys .. [["]]
end
local function scroll_down(move_cursor)
    local input_keys =  move_cursor and [[j\<C-e>]] or [[\<C-e>]]
    return [[exec "normal! ]] .. input_keys .. [["]]
end


-- Hide cursor and cursor line during scrolling for a better visual effect
local function hide_cursor_line()
    cursorline = vim.wo.cursorline
    vim.wo.cursorline = false
    if vim.o.termguicolors then
        guicursor = vim.o.guicursor
        vim.o.guicursor = guicursor .. ',a:Cursor/lCursor'
        vim.cmd('highlight Cursor blend=100')
    end
end


-- Restore hidden cursor line during scrolling
local function restore_cursor_line()
    vim.wo.cursorline = cursorline
    if vim.o.termguicolors then
        vim.o.guicursor = guicursor
        vim.cmd('highlight Cursor blend=0')
    end
end


-- Count number of folded lines
function get_hidden_lines(start_line, finish_line)
    local line = start_line
    local hidden_lines = 0
    repeat
        last_folded_line = vim.fn.foldclosedend(line)
        if last_folded_line ~= -1 then
            hidden_lines = hidden_lines + last_folded_line - line
            line = last_folded_line
        end
        line = line + 1
    until(line == finish_line + 1)
    return hidden_lines
end


-- Checks whether the window edge matches the edge of the buffer
local function at_buffer_edge(direction, move_cursor)
    local buffer_lines = vim.api.nvim_buf_line_count(0)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local window_height = vim.api.nvim_win_get_height(0)
    local cursor_height = vim.fn.winline() -- 1 is the top of the window

    if direction > 0 then
        -- local hidden_lines = get_hidden_lines(
        return cursor_height == cursor_line
    else
        local lowest_line = cursor_line + window_height - cursor_height
        return lowest_line == buffer_lines
    end
end


-- Transforms fraction of window to number of lines
local function height_fraction(fraction)
    return vim.fn.float2nr(vim.fn.round(fraction * vim.api.nvim_win_get_height(0)))
end


neoscroll = {}


-- Scrolling function
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll and move the cursor in the same direction simultaneously 
-- visual_mode: set to true if mapping in visual mode
neoscroll.scroll = function(lines, move_cursor, visual_mode)
    -- Restore selection if in visual mode
    if visual_mode then vim.cmd('normal gv') end

    -- If at the top or bottom edges of the buffer don't scroll further
    if at_buffer_edge(lines, move_cursor) then return end

    -- If lines is a a fraction of the window transform it to lines
    is_float = math.floor(math.abs(lines)) ~= math.abs(lines)
    if is_float then lines = height_fraction(lines) end

    -- If still scrolling just modify the amount of lines to scroll
    if scrolling then
        lines_to_scroll = lines_to_scroll + lines
        return
    end
    scrolling = true

    -- Hide cursor line 
    if vim.g.neoscroll_hide_cursor_line == 1 and move_cursor then
        hide_cursor_line()
    end

    --assign the number of lines to scroll
    lines_to_scroll = lines

    -- Callback function triggered by scroll_timer
    local function scroll_callback()
        scrolling_direction = lines_to_scroll - lines_scrolled
        end_of_buffer = at_buffer_edge(scrolling_direction, move_cursor)
        finished_scrolling = scrolling_direction == 0 or end_of_buffer
        if finished_scrolling then
            if vim.g.neoscroll_hide_cursor_line == 1 and move_cursor
                then restore_cursor_line()
            end
            lines_scrolled = 0
            lines_to_scroll = 0
            scroll_timer:stop()
            scrolling = false
            elseif scrolling_direction < 0 then
                lines_scrolled = lines_scrolled - 1
                vim.cmd(scroll_down(move_cursor))
            else
                lines_scrolled = lines_scrolled + 1
                vim.cmd(scroll_up(move_cursor))
            end
        end

    -- Scroll the first line
    if lines_to_scroll > 0 then
        vim.cmd(scroll_up(move_cursor))
        lines_scrolled = lines_scrolled + 1
    else
        vim.cmd(scroll_down(move_cursor))
        lines_scrolled = lines_scrolled - 1
    end

    time_step = move_cursor and vim.g.neoscroll_time_step_move_cursor
        or vim.g.neoscroll_time_step_no_move_cursor
    -- Start timer to scroll the rest of the lines
    scroll_timer:start(time_step, time_step, vim.schedule_wrap(scroll_callback))

end


-- Default mappings
neoscroll.set_mappings = function()
    vim.api.nvim_set_keymap('n', '<C-u>', [[:lua neoscroll.scroll(vim.wo.scroll, true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('n', '<C-d>', [[:lua neoscroll.scroll(-vim.wo.scroll, true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('x', '<C-u>', [[:<C-u>lua neoscroll.scroll(vim.wo.scroll, true, true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('x', '<C-d>', [[:<C-u>lua neoscroll.scroll(-vim.wo.scroll, true, true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('n', '<C-b>', [[:lua neoscroll.scroll(vim.api.nvim_win_get_height(0), true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('n', '<C-f>', [[:lua neoscroll.scroll(-vim.api.nvim_win_get_height(0), true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('x', '<C-b>', [[:<C-u>lua neoscroll.scroll(vim.api.nvim_win_get_height(0), true, true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('x', '<C-f>', [[:<C-u>lua neoscroll.scroll(-vim.api.nvim_win_get_height(0), true, true)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('n', 'J', [[:lua neoscroll.scroll(0.10, false)<CR>]], {silent=true, noremap=true})
    vim.api.nvim_set_keymap('n', 'K', [[:lua neoscroll.scroll(-0.10, false)<CR>]], {silent=true, noremap=true})
end


return neoscroll
