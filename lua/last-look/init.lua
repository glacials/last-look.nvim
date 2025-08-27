local M = {}

-- defaults
local cfg = {
	diff_command = "vert new",
	use_confirm = true,
	-- saved files: Diff, Write, Quit w/o writing, Cancel
	labels_saved = { "&Diff", "&Write", "&Quit without writing", "&Cancel" },
	-- unnamed files (no Diff): Write As, Quit w/o writing, Cancel
	labels_new = { "&Write As", "&Quit without writing", "&Cancel" },
}

-- utils
local function is_normal(buf)
	return vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == ""
end

local function buf_path(buf)
	return vim.api.nvim_buf_get_name(buf)
end

local function is_readable(path)
	return path ~= "" and vim.fn.filereadable(path) == 1
end

-- diff current buffer against on-disk contents (saved files only)
local function show_diff_with_disk()
	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo[cur_buf].filetype
	local path = buf_path(cur_buf)

	if not is_readable(path) then
		vim.notify("Nothing to diff (unsaved buffer).", vim.log.levels.WARN)
		return
	end

	local scratch = "last-look://" .. path
	local s_buf = vim.fn.bufnr(scratch)
	if s_buf == -1 then
		s_buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
		vim.api.nvim_buf_set_name(s_buf, scratch)
		vim.bo[s_buf].buftype = "nofile"
		vim.bo[s_buf].bufhidden = "wipe"
		vim.bo[s_buf].swapfile = false
		vim.bo[s_buf].filetype = ft
	else
		vim.bo[s_buf].modifiable = true
		vim.api.nvim_buf_set_lines(s_buf, 0, -1, false, {})
	end

	local lines = vim.fn.readfile(path)
	vim.api.nvim_buf_set_lines(s_buf, 0, -1, false, lines)
	vim.bo[s_buf].modifiable = false

	-- open/focus split showing scratch
	local target_win
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(w) == s_buf then
			target_win = w
			break
		end
	end
	if not target_win then
		vim.cmd(cfg.diff_command)
		target_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(target_win, s_buf)
	end

	-- enter diff mode both sides
	vim.api.nvim_set_current_win(target_win)
	vim.cmd("diffthis")
	vim.api.nvim_set_current_win(cur_win)
	vim.cmd("diffthis")
end

-- single-buffer guard (handles saved + unsaved)
local function last_look_current()
	local b = vim.api.nvim_get_current_buf()
	local name = buf_path(b)

	if not is_normal(b) or name:match("^last%-look://") then
		vim.cmd("q")
		return
	end
	if not vim.bo[b].modified then
		vim.cmd("q")
		return
	end

	local has_disk = is_readable(name)
	local labels = has_disk and cfg.labels_saved or cfg.labels_new
	local prompt = has_disk and "Buffer has unsaved changes:" or "Unnamed buffer has unsaved changes:"
	local choice

	if cfg.use_confirm then
		-- indexes now: 1=Diff, 2=Write, 3=Quit w/o writing, 4=Cancel
		choice = vim.fn.confirm(prompt, table.concat(labels, "\n"), 1)
	else
		-- hotkeys: d=diff, w=write, q=quit-no-write, c=cancel
		local map = has_disk and { d = 1, w = 2, q = 3, c = 4 } or { w = 1, q = 2, c = 3 }
		local raw = vim.fn.input(
			has_disk and "[d]iff, [w]rite, [q]uit without writing, [c]ancel: "
				or "[w]rite as, [q]uit without writing, [c]ancel: "
		)
		choice = map[(raw or ""):lower()] or (has_disk and 4 or 3)
	end

	if has_disk then
		if choice == 1 then
			show_diff_with_disk()
		elseif choice == 2 then
			vim.cmd("wq") -- write then quit (your W path)
		elseif choice == 3 then
			vim.cmd("q!")
		else
			-- cancel
		end
	else
		if choice == 1 then -- "Write As"
			vim.cmd("confirm saveas")
			-- after saveas the buffer is named & saved; just close the window
			if not vim.bo[b].modified then
				vim.cmd("q")
			end
		elseif choice == 2 then -- "Quit without writing"
			vim.cmd("q!")
		else
			-- cancel
		end
	end
end

-- guard for :qa / :qall
local function last_look_all()
	local function next_dirty()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if is_normal(buf) and vim.bo[buf].modified then
				return buf
			end
		end
		return nil
	end

	local target = next_dirty()
	if not target then
		vim.cmd("qa") -- nothing dirty; quit all
		return
	end

	vim.api.nvim_set_current_buf(target)
	last_look_current() -- handle one; user can :qa again, or you can loop
	-- If you want automatic iteration, uncomment below:
	-- while true do
	--   local b = next_dirty(); if not b then break end
	--   vim.api.nvim_set_current_buf(b)
	--   last_look_current()
	-- end
	-- if not next_dirty() then vim.cmd('qa') end
end

-- public commands
local function define_commands()
	vim.api.nvim_create_user_command("LastLook", last_look_current, { desc = "last-look: guard :q" })
	vim.api.nvim_create_user_command("LastLookAll", last_look_all, { desc = "last-look: guard :qa" })
	vim.api.nvim_create_user_command("DiffOrig", show_diff_with_disk, { desc = "last-look: open diff view" })
end

-- command-line <CR> mapping: catch bare q/quit/qa/qall (not the ! forms)
local function define_cmdline_mapping()
	-- nuke any legacy abbrevs you might have had
	vim.cmd([[silent! cunabbrev q]])
	vim.cmd([[silent! cunabbrev quit]])
	vim.cmd([[silent! cunabbrev qa]])
	vim.cmd([[silent! cunabbrev qall]])

	vim.keymap.set("c", "<CR>", function()
		local t = vim.fn.getcmdtype()
		local l = vim.fn.getcmdline()
		if t ~= ":" then
			return "\r"
		end
		if l:match("^%s*q%s*$") then
			return "\x15LastLook\r"
		elseif l:match("^%s*quit%s*$") then
			return "\x15LastLook\r"
		elseif l:match("^%s*qa%s*$") then
			return "\x15LastLookAll\r"
		elseif l:match("^%s*qall%s*$") then
			return "\x15LastLookAll\r"
		else
			return "\r"
		end
	end, { expr = true, noremap = true, desc = "last-look: smart :q/:qa remap" })
end

-- setup
function M.setup(opts)
	if opts then
		for k, v in pairs(opts) do
			cfg[k] = v
		end
	end
	define_commands()
	define_cmdline_mapping()
end

-- optional direct API exports
M.diff_orig = show_diff_with_disk

return M
