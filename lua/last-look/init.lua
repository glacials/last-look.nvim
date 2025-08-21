local M = {}

-- Helper: open a vertical diff vs the on-disk file, keep syntax
local function show_diff_with_disk()
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_get_current_buf()
  local ft      = vim.bo[cur_buf].filetype
  local name    = vim.api.nvim_buf_get_name(cur_buf)

  if name == '' or vim.bo[cur_buf].buftype ~= '' or vim.fn.filereadable(name) ~= 1 then
    vim.notify('Nothing diffable here.', vim.log.levels.WARN)
    return
  end

  -- create scratch with file-on-disk
  vim.cmd('vert new')
  vim.cmd('setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile')
  vim.api.nvim_buf_set_name(0, 'on-disk://' .. name)
  vim.cmd('keepjumps read ' .. vim.fn.fnameescape(name))
  vim.cmd('0d_')                 -- remove the extra blank line from :read
  vim.bo.filetype = ft           -- preserve syntax highlighting

  -- enter diff mode on both sides
  vim.cmd('diffthis')
  vim.api.nvim_set_current_win(cur_win)
  vim.cmd('diffthis')
end

-- SmartQuit: if modified, show diff and DO NOT quit; else, do a normal :q
vim.api.nvim_create_user_command('SmartQuit', function()
  local b = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(b)
  if vim.bo[b].modified and name ~= '' and vim.fn.filereadable(name) == 1 then
    show_diff_with_disk()
    vim.notify('Unsaved changes — opened diff. Save (:w) or force quit (:q!).', vim.log.levels.WARN)
    return  -- stay in nvim with the diff visible
  end
  vim.cmd('q')
end, {})

-- Command-line abbreviations: redirect plain :q / :quit to SmartQuit (but NOT :q!)
vim.cmd([[
  cnoreabbrev <expr> q     (getcmdtype()==':' && getcmdline()==#'q')     ? 'SmartQuit' : 'q'
  cnoreabbrev <expr> quit  (getcmdtype()==':' && getcmdline()==#'quit')  ? 'SmartQuit' : 'quit'
]])

-- Optional: keep a manual command too
vim.api.nvim_create_user_command('DiffOrig', show_diff_with_disk, {})
return M

