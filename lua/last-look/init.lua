local M = {}


local function show_diff_with_disk()
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_get_current_buf()
  local ft      = vim.bo[cur_buf].filetype
  local fname   = vim.api.nvim_buf_get_name(cur_buf)

  if fname == '' or vim.bo[cur_buf].buftype ~= '' or vim.fn.filereadable(fname) ~= 1 then
    vim.notify('Nothing diffable here.', vim.log.levels.WARN)
    return
  end

  local scratch_name = 'last-look://' .. fname
  local scratch_buf  = vim.fn.bufnr(scratch_name)

  -- create or reuse the scratch buffer
  if scratch_buf == -1 then
    scratch_buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
    vim.api.nvim_buf_set_name(scratch_buf, scratch_name)
    vim.bo[scratch_buf].buftype   = 'nofile'
    vim.bo[scratch_buf].bufhidden = 'wipe'
    vim.bo[scratch_buf].swapfile  = false
    vim.bo[scratch_buf].filetype  = ft
  else
    -- refresh contents if it exists
    vim.bo[scratch_buf].modifiable = true
    vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, {})
  end

  -- read file-on-disk into scratch (no :read, avoid extra blank line)
  local lines = vim.fn.readfile(fname)
  vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, lines)
  vim.bo[scratch_buf].modifiable = false

  -- open / focus a vertical split showing the scratch
  local target_win
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == scratch_buf then target_win = w break end
  end
  if not target_win then
    vim.cmd('vert new')
    target_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(target_win, scratch_buf)
  end

  -- diff both sides
  vim.api.nvim_set_current_win(target_win)
  vim.cmd('diffthis')
  vim.api.nvim_set_current_win(cur_win)
  vim.cmd('diffthis')
end

-- SmartQuit: skip in non-file buffers; if modified, prompt; otherwise plain :q
local function smart_quit_current()
  local b = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(b)

  -- if we're in the scratch or any non-file buffer, do a plain :q
  if vim.bo[b].buftype ~= '' or name:find('^last%-look://') then
    vim.cmd('q')
    return
  end

  if not vim.bo[b].modified or name == '' or vim.fn.filereadable(name) ~= 1 then
    vim.cmd('q')
    return
  end

  local choices = table.concat({ cfg.labels.save, cfg.labels.discard, cfg.labels.diff, cfg.labels.cancel }, '\n')
  local choice = cfg.use_confirm and vim.fn.confirm('Buffer has unsaved changes:', choices, 1) or 4

  if choice == 1 then
    vim.cmd('w | q')
  elseif choice == 2 then
    vim.cmd('q!')
  elseif choice == 3 then
    show_diff_with_disk()
    vim.notify('Showing diff. Save (:w) or force quit (:q!).', vim.log.levels.WARN)
  end
end

-- LastLook: if modified, show diff and DO NOT quit; else, do a normal :q
vim.api.nvim_create_user_command('LastLook', function()
  local b = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(b)
  if vim.bo[b].modified and name ~= '' and vim.fn.filereadable(name) == 1 then
    show_diff_with_disk()
    vim.notify('Unsaved changes — opening diff. Save (:w) or force quit (:q!).', vim.log.levels.WARN)
    return  -- stay in nvim with the diff visible
  end
  vim.cmd('q')
end, {})

-- LastLookAll: same as above, but for :qa
vim.api.nvim_create_user_command('LastLookAll', function()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr)
       and vim.bo[bufnr].buftype == ''
       and vim.bo[bufnr].modified
       and vim.fn.filereadable(vim.api.nvim_buf_get_name(bufnr)) == 1 then
      -- run your same guard / diff logic here
      vim.api.nvim_set_current_buf(bufnr)
      vim.cmd('LastLook') -- reuse your single-buffer command
      return -- bail after first modified buffer so user can act
    end
  end
  -- if no modified buffers left, safe to quit all
  vim.cmd('qa')
end, { desc = 'Run last-look guard across all buffers' })


vim.keymap.set('c', '<CR>', function()
  local t = vim.fn.getcmdtype()
  local l = vim.fn.getcmdline()
  if t == ':' and l:match('^%s*q%s*$') then
    return '\x15LastLook\r'
  elseif t == ':' and l:match('^%s*quit%s*$') then
    return '\x15LastLook\r'
  elseif t == ':' and l:match('^%s*qa%s*$') then
    return '\x15LastLookAll\r'
  elseif t == ':' and l:match('^%s*qall%s*$') then
    return '\x15LastLookAll\r'
  else
    return '\r'
  end
end, { expr = true, noremap = true, desc = 'last-look: smart :q remap' })


-- Optional: keep a manual command too
vim.api.nvim_create_user_command('DiffOrig', show_diff_with_disk, {})
return M

